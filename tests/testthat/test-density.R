# Mock: 12 patients, one record per domain near index; subjects 1-2 die,
# rest exit via cohort_end. followup_days = 200 for everyone.

test_that("run_density returns the documented structure", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_density(con, cdm_schema = "main",
                     cohort_table = "test_cohort", cohort_id = 1)

  expect_named(res, c("density_by_domain", "followup_summary",
                      "followup_detail", "flags"))
  expect_s3_class(res$density_by_domain, "data.frame")
})

test_that("all four domains are profiled with full record counts", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_density(con, cdm_schema = "main",
                     cohort_table = "test_cohort", cohort_id = 1)

  expect_setequal(unique(res$density_by_domain$domain),
                  c("conditions", "drugs", "measurements", "visits"))
  # one record per patient for drugs/measurements/visits (12 each); conditions
  # has extra HF-descendant + unmapped rows from the mock (15).
  per_domain <- tapply(res$density_by_domain$n_records,
                       res$density_by_domain$domain, sum)
  expect_equal(per_domain[["drugs"]], 12L)
  expect_equal(per_domain[["measurements"]], 12L)
  expect_equal(per_domain[["visits"]], 12L)
  expect_equal(per_domain[["conditions"]], 15L)
  expect_length(res$flags, 0)
})

test_that("follow-up censoring distinguishes death from cohort exit", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_density(con, cdm_schema = "main",
                     cohort_table = "test_cohort", cohort_id = 1)

  expect_equal(nrow(res$followup_detail), 12L)
  deaths <- res$followup_summary$n[res$followup_summary$censoring_reason == "death"]
  expect_equal(deaths, 2L)
  expect_true(all(res$followup_detail$followup_days == 200L))
})

test_that("an empty domain triggers a sparse WARN flag", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  DBI::dbExecute(con, "DELETE FROM measurement")

  res <- run_density(con, cdm_schema = "main",
                     cohort_table = "test_cohort", cohort_id = 1)

  expect_true(any(grepl("WARN.*measurements", res$flags)))
})

test_that("pre-index months floor negative (portable month bucketing)", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  # Move person 1's condition to 45 days BEFORE index (still inside the window).
  # floor(-45/30) = -2, so the bucket must be negative; integer-trunc would give -1.
  DBI::dbExecute(con, "
    UPDATE condition_occurrence
       SET condition_start_date = (
         SELECT cohort_start_date FROM test_cohort WHERE subject_id = 1
       ) - 45
     WHERE person_id = 1")

  res <- run_density(con, cdm_schema = "main",
                     cohort_table = "test_cohort", cohort_id = 1)
  cond <- res$density_by_domain[res$density_by_domain$domain == "conditions", ]
  expect_true(any(cond$months_from_index < 0))
})
