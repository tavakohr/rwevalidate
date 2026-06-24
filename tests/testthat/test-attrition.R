# Mock cohort: 12 patients, all cohort_definition_id = 1, each with exactly
# 400 days of prior observation (cohort_start = obs_start + 400).

test_that("run_attrition returns the documented structure", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_attrition(
    con, cdm_schema = "main", cohort_table = "test_cohort", cohort_id = 1,
    vocab_schema = "main"
  )

  expect_named(res, c("cohort_size", "index_date_summary",
                      "obs_coverage", "demographics", "flags"))
  expect_identical(res$cohort_size, 12L)
  expect_s3_class(res$index_date_summary, "data.frame")
  expect_s3_class(res$demographics, "data.frame")
})

test_that("obs coverage is 100% and produces no flag at default thresholds", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_attrition(
    con, cdm_schema = "main", cohort_table = "test_cohort", cohort_id = 1,
    vocab_schema = "main"  # 400d prior >= 365d default -> all sufficient
  )

  expect_equal(res$obs_coverage$pct_sufficient, 100)
  expect_identical(res$obs_coverage$n_sufficient, 12L)
  expect_length(res$flags, 0)
})

test_that("insufficient prior observation triggers a FAIL flag", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  # Require 500d prior; mock only has 400d -> 0% sufficient -> FAIL (< 50%).
  res <- run_attrition(
    con, cdm_schema = "main", cohort_table = "test_cohort", cohort_id = 1,
    vocab_schema = "main", obs_window = c(-500, 0)
  )

  expect_equal(res$obs_coverage$pct_sufficient, 0)
  expect_length(res$flags, 1)
  expect_match(res$flags, "^FAIL:")
})

test_that("demographics cover all subjects and resolve sex labels", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_attrition(
    con, cdm_schema = "main", cohort_table = "test_cohort", cohort_id = 1,
    vocab_schema = "main"
  )

  expect_equal(sum(res$demographics$n), 12L)
  expect_setequal(res$demographics$sex, c("MALE", "FEMALE"))
  expect_true(all(res$demographics$mean_age > 0))
})

test_that("empty cohort id aborts", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  expect_error(
    run_attrition(con, cdm_schema = "main", cohort_table = "test_cohort",
                  cohort_id = 999, vocab_schema = "main"),
    regexp = "empty"
  )
})
