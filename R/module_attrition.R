#' Module 2 — Cohort Attrition Audit
#'
#' Profiles an instantiated cohort: size, index-date distribution, prior
#' observation coverage, and demographics at index. Maps to HARPER section 5 and
#' RECORD-PE item 6. All thresholds are arguments.
#'
#' @param con A live `DBI` connection (see [cdm_connect()]).
#' @param cdm_schema Schema holding the clinical CDM tables (e.g. `"mimic_cdm"`).
#' @param cohort_table Cohort table, schema-qualified
#'   (e.g. `"results.rwevalidate_test_cohort"`). Must have columns
#'   `subject_id`, `cohort_definition_id`, `cohort_start_date`, `cohort_end_date`.
#' @param cohort_id Integer cohort definition id to profile.
#' @param obs_window Length-2 numeric `c(pre, post)` in days relative to index.
#'   The required prior-observation window is `abs(obs_window[1])` days
#'   (default 365).
#' @param vocab_schema Schema holding the vocabulary tables (`concept`). In this
#'   split-schema environment the clinical schema's `concept` table is empty, so
#'   the gender label is resolved from `vocab_schema`. Default `"vocab"`.
#' @param obs_warn_pct,obs_fail_pct Prior-observation coverage thresholds (percent
#'   of cohort with sufficient prior observation). Below `obs_warn_pct` flags
#'   `WARN`, below `obs_fail_pct` flags `FAIL`. Defaults 70 and 50.
#' @param attrition_warn_threshold Reserved for stepwise inclusion-criteria
#'   attrition (single-criterion drop fraction). Not exercised in v0.1 because
#'   criteria lists are not yet a supported input. Default 0.5.
#'
#' @return A named list:
#'   \describe{
#'     \item{cohort_size}{integer — distinct subjects in the cohort}
#'     \item{index_date_summary}{data.frame of `index_year`, `n`}
#'     \item{obs_coverage}{data.frame: `cohort_n`, `n_sufficient`, `pct_sufficient`, `min_prior_days`}
#'     \item{demographics}{data.frame: `sex`, `mean_age`, `min_age`, `max_age`, `n`}
#'     \item{flags}{character vector of `WARN:`/`FAIL:` messages (empty if all pass)}
#'   }
#'
#' @export
run_attrition <- function(con,
                          cdm_schema,
                          cohort_table,
                          cohort_id,
                          obs_window = c(-365, 0),
                          vocab_schema = "vocab",
                          obs_warn_pct = 70,
                          obs_fail_pct = 50,
                          attrition_warn_threshold = 0.5) {

  stopifnot(
    DBI::dbIsValid(con),
    length(obs_window) == 2,
    is.numeric(cohort_id), length(cohort_id) == 1
  )
  cohort_id <- as.integer(cohort_id)
  min_prior_days <- abs(as.integer(obs_window[1]))
  flags <- character(0)

  # --- 2a. Cohort size ----------------------------------------------------
  cohort_size <- as.integer(DBI::dbGetQuery(con, glue::glue(
    "SELECT COUNT(DISTINCT subject_id) AS n
       FROM {cohort_table}
      WHERE cohort_definition_id = {cohort_id}"
  ))$n)

  if (isTRUE(cohort_size == 0)) {
    cli::cli_abort("Cohort {.val {cohort_id}} in {.val {cohort_table}} is empty.")
  }

  # --- 2b. Index date distribution by year --------------------------------
  index_date_summary <- DBI::dbGetQuery(con, glue::glue(
    "SELECT EXTRACT(YEAR FROM cohort_start_date)::int AS index_year,
            COUNT(*) AS n
       FROM {cohort_table}
      WHERE cohort_definition_id = {cohort_id}
      GROUP BY 1 ORDER BY 1"
  ))
  index_date_summary$n <- as.integer(index_date_summary$n)

  # --- 2c. Prior observation coverage -------------------------------------
  obs_coverage <- DBI::dbGetQuery(con, glue::glue(
    "SELECT
        COUNT(*) AS cohort_n,
        SUM(CASE WHEN prior_days >= {min_prior_days} THEN 1 ELSE 0 END) AS n_sufficient,
        ROUND(100.0 * SUM(CASE WHEN prior_days >= {min_prior_days}
                               THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_sufficient
       FROM (
         SELECT
           c.subject_id,
           c.cohort_start_date - op.observation_period_start_date AS prior_days
         FROM {cohort_table} c
         JOIN {cdm_schema}.observation_period op
           ON c.subject_id = op.person_id
          AND c.cohort_start_date BETWEEN op.observation_period_start_date
                                      AND op.observation_period_end_date
        WHERE c.cohort_definition_id = {cohort_id}
       ) sub"
  ))
  obs_coverage$cohort_n      <- as.integer(obs_coverage$cohort_n)
  obs_coverage$n_sufficient  <- as.integer(obs_coverage$n_sufficient)
  obs_coverage$pct_sufficient <- as.numeric(obs_coverage$pct_sufficient)
  obs_coverage$min_prior_days <- min_prior_days

  pct <- obs_coverage$pct_sufficient
  if (length(pct) == 1 && !is.na(pct)) {
    if (pct < obs_fail_pct) {
      flags <- c(flags, glue::glue(
        "FAIL: Only {pct}% of cohort has >= {min_prior_days}d prior observation (< {obs_fail_pct}%)."
      ))
    } else if (pct < obs_warn_pct) {
      flags <- c(flags, glue::glue(
        "WARN: Only {pct}% of cohort has >= {min_prior_days}d prior observation (< {obs_warn_pct}%)."
      ))
    }
  }

  # --- 2d. Age and sex at index -------------------------------------------
  demographics <- DBI::dbGetQuery(con, glue::glue(
    "SELECT
        gc.concept_name AS sex,
        ROUND(AVG(EXTRACT(YEAR FROM c.cohort_start_date) - p.year_of_birth), 1) AS mean_age,
        MIN(EXTRACT(YEAR FROM c.cohort_start_date) - p.year_of_birth)::int AS min_age,
        MAX(EXTRACT(YEAR FROM c.cohort_start_date) - p.year_of_birth)::int AS max_age,
        COUNT(*) AS n
       FROM {cohort_table} c
       JOIN {cdm_schema}.person p ON c.subject_id = p.person_id
       LEFT JOIN {vocab_schema}.concept gc ON p.gender_concept_id = gc.concept_id
      WHERE c.cohort_definition_id = {cohort_id}
      GROUP BY gc.concept_name ORDER BY n DESC"
  ))
  demographics$mean_age <- as.numeric(demographics$mean_age)
  demographics$min_age  <- as.integer(demographics$min_age)
  demographics$max_age  <- as.integer(demographics$max_age)
  demographics$n        <- as.integer(demographics$n)

  list(
    cohort_size        = cohort_size,
    index_date_summary = index_date_summary,
    obs_coverage       = obs_coverage,
    demographics       = demographics,
    flags              = flags
  )
}
