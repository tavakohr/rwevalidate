#' Create a small in-memory OMOP CDM for examples and demos
#'
#' Builds a tiny synthetic OMOP CDM (10 persons) in an in-memory DuckDB database
#' and returns a live connection. Every table `rwevalidate` queries for the
#' attrition and density modules is populated, together with a `cohort` table
#' that has the standard `subject_id`, `cohort_definition_id`,
#' `cohort_start_date`, and `cohort_end_date` columns. The clinical tables and a
#' minimal vocabulary both live in the default `main` schema.
#'
#' This exists so the package can be tried, and its examples can run, without a
#' live database connection. It is a synthetic demo fixture, not a substitute for
#' a real CDM. The `duckdb` package (a soft dependency) must be installed. The
#' caller owns the returned connection and should close it with
#' [cdm_disconnect()].
#'
#' @return A live `DBI` connection to an in-memory DuckDB OMOP CDM.
#'
#' @examples
#' if (requireNamespace("duckdb", quietly = TRUE)) {
#'   con <- example_cdm()
#'   attrition <- run_attrition(con, cdm_schema = "main",
#'                              cohort_table = "cohort", cohort_id = 1,
#'                              vocab_schema = "main")
#'   print(attrition$cohort_size)
#'   cdm_disconnect(con)
#' }
#'
#' @export
example_cdm <- function() {
  if (!requireNamespace("duckdb", quietly = TRUE)) {
    cli::cli_abort(c(
      "The {.pkg duckdb} package is required for {.fn example_cdm}.",
      "i" = "Install it with {.code install.packages(\"duckdb\")}."
    ))
  }

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")

  n   <- 10L
  ids <- seq_len(n)

  op_start <- as.Date("2015-01-01") + ids * 30L
  index    <- op_start + 400L

  person <- data.frame(
    person_id         = ids,
    gender_concept_id = ifelse(ids %% 2 == 0, 8532L, 8507L),
    year_of_birth     = 1945L + ids * 3L,
    race_concept_id   = 0L,
    ethnicity_concept_id = 0L
  )

  observation_period <- data.frame(
    observation_period_id         = ids,
    person_id                     = ids,
    observation_period_start_date = op_start,
    observation_period_end_date   = op_start + 365L * 3L,
    period_type_concept_id        = 44814724L
  )

  condition_occurrence <- data.frame(
    condition_occurrence_id   = ids,
    person_id                 = ids,
    condition_concept_id      = 316139L,        # heart failure
    condition_start_date      = index,
    condition_end_date        = index + 30L,
    condition_type_concept_id = 32020L
  )

  drug_exposure <- data.frame(
    drug_exposure_id         = ids,
    person_id                = ids,
    drug_concept_id          = 1308216L,
    drug_exposure_start_date = index + 5L,
    drug_exposure_end_date   = index + 95L,
    drug_type_concept_id     = 38000177L
  )

  measurement <- data.frame(
    measurement_id             = ids,
    person_id                  = ids,
    measurement_concept_id     = 3016723L,
    measurement_date           = index + 2L,
    value_as_number            = 1 + ids / 10,
    measurement_type_concept_id = 44818702L
  )

  visit_occurrence <- data.frame(
    visit_occurrence_id   = ids,
    person_id             = ids,
    visit_concept_id      = 9201L,
    visit_start_date      = index,
    visit_end_date        = index + 7L,
    visit_type_concept_id = 44818517L
  )

  # First two persons die; the rest exit via the cohort end date.
  dead <- ids[ids <= 2L]
  death <- data.frame(
    person_id             = dead,
    death_date            = op_start[dead] + 365L * 2L,
    death_type_concept_id = 38003569L
  )

  concept <- data.frame(
    concept_id       = c(8507L, 8532L, 316139L, 1308216L, 3016723L, 9201L),
    concept_name     = c("MALE", "FEMALE", "Heart failure", "lisinopril",
                         "Creatinine", "Inpatient Visit"),
    domain_id        = c("Gender", "Gender", "Condition", "Drug",
                         "Measurement", "Visit"),
    vocabulary_id    = c("Gender", "Gender", "SNOMED", "RxNorm", "LOINC",
                         "Visit"),
    standard_concept = "S"
  )

  concept_ancestor <- data.frame(
    ancestor_concept_id      = 316139L,
    descendant_concept_id    = 316139L,
    min_levels_of_separation = 0L,
    max_levels_of_separation = 0L
  )

  cohort <- data.frame(
    subject_id           = ids,
    cohort_definition_id = 1L,
    cohort_start_date    = index,
    cohort_end_date      = index + 200L
  )

  tables <- list(
    person               = person,
    observation_period   = observation_period,
    condition_occurrence = condition_occurrence,
    drug_exposure        = drug_exposure,
    measurement          = measurement,
    visit_occurrence     = visit_occurrence,
    death                = death,
    concept              = concept,
    concept_ancestor     = concept_ancestor,
    cohort               = cohort
  )
  for (nm in names(tables)) {
    DBI::dbWriteTable(con, nm, tables[[nm]], overwrite = TRUE)
  }

  con
}
