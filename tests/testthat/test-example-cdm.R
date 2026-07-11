# example_cdm() is the exported, database-free demo fixture used by every
# runnable example. These tests exercise it directly so the fixture is covered
# and stays in sync with the modules it is meant to demonstrate.

test_that("example_cdm builds a two-arm CDM with all required tables", {
  skip_if_not_installed("duckdb")
  con <- example_cdm()
  on.exit(cdm_disconnect(con), add = TRUE)

  required <- c("person", "observation_period", "condition_occurrence",
                "drug_exposure", "measurement", "visit_occurrence",
                "procedure_occurrence", "death", "concept", "concept_ancestor",
                "cohort")
  expect_true(all(required %in% DBI::dbListTables(con)))

  cohort <- DBI::dbGetQuery(con, "SELECT * FROM cohort")
  expect_setequal(unique(cohort$cohort_definition_id), c(1L, 2L))
  expect_equal(sum(cohort$cohort_definition_id == 1L), 10L)  # target arm
  expect_equal(sum(cohort$cohort_definition_id == 2L), 10L)  # comparator arm
})

test_that("all four modules run against example_cdm", {
  skip_if_not_installed("duckdb")
  con <- example_cdm()
  on.exit(cdm_disconnect(con), add = TRUE)

  attrition <- run_attrition(con, cdm_schema = "main", cohort_table = "cohort",
                             cohort_id = 1, vocab_schema = "main")
  expect_equal(attrition$cohort_size, 10L)

  density <- run_density(con, cdm_schema = "main", cohort_table = "cohort",
                         cohort_id = 1)
  expect_true(nrow(density$density_by_domain) > 0)

  concepts <- run_concepts(con, cdm_schema = "main", concept_ids = 316139,
                           domain = "condition", vocab_schema = "main")
  expect_equal(nrow(concepts$mapping_by_domain), 4L)

  covariates <- run_covariates(con, cdm_schema = "main", cohort_table = "cohort",
                               cohort_id = 1, comparator_id = 2,
                               vocab_schema = "main")
  expect_named(covariates, c("smd_table", "prevalence_table", "power", "flags"))
})
