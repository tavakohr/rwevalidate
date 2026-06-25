# Mock vocab: seed 316139 has descendants {316139, 4229440, 444031}; only the
# first two appear in condition_occurrence (coverage 2/3). One unmapped condition
# row and one unmapped procedure row exercise mapping rates.

test_that("run_concepts returns the documented structure", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_concepts(con, cdm_schema = "main", cohort_table = "test_cohort",
                      cohort_id = 1, concept_ids = 316139, vocab_schema = "main")

  expect_named(res, c("prevalence", "ancestor_coverage",
                      "mapping_by_domain", "flags"))
})

test_that("prevalence counts persons with a descendant-set record", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_concepts(con, cdm_schema = "main", cohort_table = "test_cohort",
                      cohort_id = 1, concept_ids = 316139, vocab_schema = "main")

  expect_identical(res$prevalence$n_with, 12L)
  expect_identical(res$prevalence$n_total, 12L)
  expect_equal(res$prevalence$pct, 100)
})

test_that("ancestor coverage reports present vs total descendants", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_concepts(con, cdm_schema = "main", cohort_table = "test_cohort",
                      cohort_id = 1, concept_ids = 316139, vocab_schema = "main")

  expect_identical(res$ancestor_coverage$total_descendants, 3L)
  expect_identical(res$ancestor_coverage$present_descendants, 2L)
  expect_equal(res$ancestor_coverage$pct_present, 66.7)
})

test_that("mapping rate detects unmapped records and flags a sparse domain", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_concepts(con, cdm_schema = "main", cohort_table = "test_cohort",
                      cohort_id = 1, concept_ids = 316139, vocab_schema = "main")

  cond <- res$mapping_by_domain[res$mapping_by_domain$domain == "condition", ]
  expect_equal(cond$n_records, 15L)
  expect_equal(cond$n_unmapped, 1L)

  proc <- res$mapping_by_domain[res$mapping_by_domain$domain == "procedure", ]
  expect_equal(proc$n_unmapped, 1L)            # 1 of 4 -> 25% unmapped
  expect_true(any(grepl("WARN.*procedure", res$flags)))
})

test_that("absent seed concept yields zero prevalence and a FAIL flag", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_concepts(con, cdm_schema = "main", cohort_table = "test_cohort",
                      cohort_id = 1, concept_ids = 999999, vocab_schema = "main")

  expect_equal(res$prevalence$pct, 0)
  expect_true(any(grepl("^FAIL:", res$flags)))
})
