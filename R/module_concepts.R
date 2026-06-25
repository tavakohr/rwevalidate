#' Clinical domains and their standard-concept columns
#'
#' Used by `run_concepts()` for prevalence, ancestor coverage, and mapping rates.
#'
#' @keywords internal
#' @noRd
CONCEPT_DOMAIN_COLS <- list(
  condition   = list(table = "condition_occurrence",  concept_col = "condition_concept_id"),
  drug        = list(table = "drug_exposure",         concept_col = "drug_concept_id"),
  measurement = list(table = "measurement",           concept_col = "measurement_concept_id"),
  procedure   = list(table = "procedure_occurrence",  concept_col = "procedure_concept_id")
)

#' Module 1 - Concept Coverage
#'
#' Profiles whether the cohort-defining concepts are present, well-mapped, and
#' richly represented in the CDM. Maps to FDA RWE Relevance (are the data fit for
#' the question?). This is the first module to read the vocabulary schema.
#'
#' @param con A live `DBI` connection (see [cdm_connect()]).
#' @param cdm_schema Schema holding the clinical CDM tables.
#' @param cohort_table Cohort table, schema-qualified (currently unused; reserved
#'   for cohort-restricted prevalence in a later version).
#' @param cohort_id Integer cohort definition id (reserved, see `cohort_table`).
#' @param concept_ids Numeric vector of cohort-defining seed concept id(s). Their
#'   descendants are expanded via `{vocab_schema}.concept_ancestor`.
#' @param domain Domain the seed concepts live in; one of the names of the
#'   internal domain map (`"condition"`, `"drug"`, `"measurement"`,
#'   `"procedure"`). Default `"condition"`.
#' @param vocab_schema Schema holding the vocabulary tables. Default `"vocab"`.
#' @param prevalence_warn_pct,prevalence_fail_pct Concept-prevalence thresholds
#'   (percent of CDM persons with at least one descendant record). Below warn
#'   flags `WARN`, below fail flags `FAIL`. Defaults 10 and 1.
#' @param unmapped_warn_pct Per-domain unmapped-record threshold (percent mapped
#'   to `concept_id = 0`) above which a `WARN` is flagged. Default 20.
#'
#' @return A named list:
#'   \describe{
#'     \item{prevalence}{data.frame: `n_with`, `n_total`, `pct`}
#'     \item{ancestor_coverage}{data.frame: `total_descendants`,
#'       `present_descendants`, `pct_present`}
#'     \item{mapping_by_domain}{data.frame: `domain`, `n_records`, `n_unmapped`,
#'       `pct_mapped`}
#'     \item{flags}{character vector of `WARN:`/`FAIL:` messages}
#'   }
#'
#' @export
run_concepts <- function(con,
                         cdm_schema,
                         cohort_table,
                         cohort_id,
                         concept_ids,
                         domain = "condition",
                         vocab_schema = "vocab",
                         prevalence_warn_pct = 10,
                         prevalence_fail_pct = 1,
                         unmapped_warn_pct = 20) {

  stopifnot(
    DBI::dbIsValid(con),
    is.numeric(concept_ids), length(concept_ids) >= 1,
    domain %in% names(CONCEPT_DOMAIN_COLS)
  )
  ids <- paste(as.integer(concept_ids), collapse = ", ")
  flags <- character(0)
  dspec <- CONCEPT_DOMAIN_COLS[[domain]]

  descendant_subq <- glue::glue(
    "SELECT descendant_concept_id FROM {vocab_schema}.concept_ancestor
      WHERE ancestor_concept_id IN ({ids})")

  # --- 1a. Concept prevalence ---------------------------------------------
  prevalence <- DBI::dbGetQuery(con, glue::glue(
    "SELECT
        (SELECT COUNT(DISTINCT person_id)
           FROM {cdm_schema}.{dspec$table}
          WHERE {dspec$concept_col} IN ({descendant_subq})) AS n_with,
        (SELECT COUNT(*) FROM {cdm_schema}.person) AS n_total"
  ))
  prevalence$n_with  <- as.integer(prevalence$n_with)
  prevalence$n_total <- as.integer(prevalence$n_total)
  prevalence$pct <- if (prevalence$n_total > 0) {
    round(100 * prevalence$n_with / prevalence$n_total, 1)
  } else NA_real_

  pct <- prevalence$pct
  if (!is.na(pct)) {
    if (pct < prevalence_fail_pct) {
      flags <- c(flags, glue::glue(
        "FAIL: Cohort-defining concept prevalence is {pct}% of CDM persons (< {prevalence_fail_pct}%)."))
    } else if (pct < prevalence_warn_pct) {
      flags <- c(flags, glue::glue(
        "WARN: Cohort-defining concept prevalence is {pct}% of CDM persons (< {prevalence_warn_pct}%)."))
    }
  }

  # --- 1b. Ancestor coverage ----------------------------------------------
  ancestor_coverage <- DBI::dbGetQuery(con, glue::glue(
    "SELECT
        (SELECT COUNT(*) FROM {vocab_schema}.concept_ancestor
          WHERE ancestor_concept_id IN ({ids})) AS total_descendants,
        (SELECT COUNT(DISTINCT {dspec$concept_col})
           FROM {cdm_schema}.{dspec$table}
          WHERE {dspec$concept_col} IN ({descendant_subq})) AS present_descendants"
  ))
  ancestor_coverage$total_descendants   <- as.integer(ancestor_coverage$total_descendants)
  ancestor_coverage$present_descendants <- as.integer(ancestor_coverage$present_descendants)
  ancestor_coverage$pct_present <- if (ancestor_coverage$total_descendants > 0) {
    round(100 * ancestor_coverage$present_descendants /
            ancestor_coverage$total_descendants, 1)
  } else NA_real_

  # --- 1c. Vocabulary mapping rate by domain ------------------------------
  map_parts <- lapply(names(CONCEPT_DOMAIN_COLS), function(dom) {
    sp <- CONCEPT_DOMAIN_COLS[[dom]]
    row <- DBI::dbGetQuery(con, glue::glue(
      "SELECT COUNT(*) AS n_records,
              SUM(CASE WHEN {sp$concept_col} = 0 THEN 1 ELSE 0 END) AS n_unmapped
         FROM {cdm_schema}.{sp$table}"))
    n_records  <- as.integer(row$n_records)
    n_unmapped <- as.integer(row$n_unmapped)
    pct_mapped <- if (n_records > 0) round(100 * (n_records - n_unmapped) / n_records, 1) else NA_real_

    if (!is.na(pct_mapped) && n_records > 0) {
      pct_unmapped <- 100 - pct_mapped
      if (pct_unmapped > unmapped_warn_pct) {
        flags[[length(flags) + 1L]] <<- glue::glue(
          "WARN: Domain '{dom}' has {pct_unmapped}% records unmapped (concept_id = 0).")
      }
    }
    data.frame(domain = dom, n_records = n_records, n_unmapped = n_unmapped,
               pct_mapped = pct_mapped, stringsAsFactors = FALSE)
  })
  mapping_by_domain <- do.call(rbind, map_parts)
  rownames(mapping_by_domain) <- NULL

  list(
    prevalence        = prevalence,
    ancestor_coverage = ancestor_coverage,
    mapping_by_domain = mapping_by_domain,
    flags             = flags
  )
}
