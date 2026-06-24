# Mock OMOP CDM for unit tests.
#
# setup_mock_cdm() spins up an in-memory DuckDB instance loaded with a minimal
# synthetic OMOP v5.3.1 subset (12 patients) covering every table the package
# queries, plus a `test_cohort` table mirroring results.rwevalidate_test_cohort.
# This is the shared substrate for all module tests — keep it general.

#' @return A live DBI connection to an in-memory DuckDB with synthetic CDM data.
#'   Caller is responsible for disconnecting (use teardown / on.exit).
setup_mock_cdm <- function(n = 12L) {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")

  ids <- seq_len(n)

  # --- person -------------------------------------------------------------
  # Alternate gender concepts: 8507 = MALE, 8532 = FEMALE.
  person <- data.frame(
    person_id           = ids,
    gender_concept_id   = ifelse(ids %% 2 == 0, 8532L, 8507L),
    year_of_birth       = 1940L + (ids * 3L),
    race_concept_id     = 0L,
    ethnicity_concept_id = 0L
  )

  # --- observation_period -------------------------------------------------
  # ~3 years of coverage, staggered start per patient.
  op_start <- as.Date("2015-01-01") + (ids * 30L)
  observation_period <- data.frame(
    observation_period_id          = ids,
    person_id                      = ids,
    observation_period_start_date  = op_start,
    observation_period_end_date    = op_start + 365L * 3L,
    period_type_concept_id         = 44814724L
  )

  # --- condition_occurrence ----------------------------------------------
  # One heart-failure condition (concept 316139) per patient, ~1y into coverage.
  cond_start <- op_start + 400L
  condition_occurrence <- data.frame(
    condition_occurrence_id   = ids,
    person_id                 = ids,
    condition_concept_id      = 316139L,
    condition_start_date      = cond_start,
    condition_end_date        = cond_start + 30L,
    condition_type_concept_id = 32020L
  )

  # --- drug_exposure ------------------------------------------------------
  drug_start <- cond_start + 5L
  drug_exposure <- data.frame(
    drug_exposure_id            = ids,
    person_id                   = ids,
    drug_concept_id             = 1308216L, # lisinopril (illustrative)
    drug_exposure_start_date    = drug_start,
    drug_exposure_end_date      = drug_start + 90L,
    drug_type_concept_id        = 38000177L
  )

  # --- measurement --------------------------------------------------------
  meas_date <- cond_start + 2L
  measurement <- data.frame(
    measurement_id          = ids,
    person_id               = ids,
    measurement_concept_id  = 3016723L, # creatinine (illustrative)
    measurement_date        = meas_date,
    value_as_number         = 1.0 + (ids / 10),
    measurement_type_concept_id = 44818702L
  )

  # --- visit_occurrence ---------------------------------------------------
  visit_start <- cond_start
  visit_occurrence <- data.frame(
    visit_occurrence_id   = ids,
    person_id             = ids,
    visit_concept_id      = 9201L, # inpatient
    visit_start_date      = visit_start,
    visit_end_date        = visit_start + 7L,
    visit_type_concept_id = 44818517L
  )

  # --- death --------------------------------------------------------------
  # First two patients die; rest survive.
  dead <- ids[ids <= 2L]
  death <- data.frame(
    person_id          = dead,
    death_date         = op_start[dead] + 365L * 2L,
    death_type_concept_id = 38003569L
  )

  # --- concept (minimal vocabulary) --------------------------------------
  concept <- data.frame(
    concept_id   = c(8507L, 8532L, 316139L, 1308216L, 3016723L, 9201L),
    concept_name = c("MALE", "FEMALE", "Heart failure", "lisinopril",
                     "Creatinine", "Inpatient Visit"),
    domain_id        = c("Gender", "Gender", "Condition", "Drug",
                         "Measurement", "Visit"),
    vocabulary_id    = c("Gender", "Gender", "SNOMED", "RxNorm",
                         "LOINC", "Visit"),
    standard_concept = "S"
  )

  # --- concept_ancestor ---------------------------------------------------
  # 316139 (Heart failure) is its own descendant so the cohort SQL resolves.
  concept_ancestor <- data.frame(
    ancestor_concept_id   = 316139L,
    descendant_concept_id = 316139L,
    min_levels_of_separation = 0L,
    max_levels_of_separation = 0L
  )

  # --- test_cohort (mirrors results.rwevalidate_test_cohort) -------------
  test_cohort <- data.frame(
    subject_id            = ids,
    cohort_definition_id  = 1L,
    cohort_start_date     = cond_start,
    cohort_end_date       = cond_start + 200L
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
    test_cohort          = test_cohort
  )

  for (nm in names(tables)) {
    DBI::dbWriteTable(con, nm, tables[[nm]], overwrite = TRUE)
  }

  con
}
