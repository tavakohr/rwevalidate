# Mock arms: 1 = persons 1-12 (HF, mixed age/sex); 2 = persons 13-24
# (younger, mostly male, hypertension). SMDs vs arm 1 are clearly non-zero.

test_that("SMD helpers match hand-computed values", {
  # continuous: (2-1)/sqrt((1+1)/2) = 1
  expect_equal(smd_continuous(2, 1, 1, 1), 1)
  # binary: (0.5-0.1)/sqrt((0.25+0.09)/2)
  expect_equal(smd_binary(0.5, 0.1), 0.4 / sqrt((0.25 + 0.09) / 2))
  # degenerate (zero pooled variance) -> NA
  expect_true(is.na(smd_binary(1, 0)))
  expect_true(is.na(smd_continuous(5, 3, 0, 0)))
})

test_that("run_covariates returns the documented structure", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_covariates(con, cdm_schema = "main", cohort_table = "test_cohort",
                        cohort_id = 1, comparator_id = 2, vocab_schema = "main")

  expect_named(res, c("smd_table", "prevalence_table", "power", "flags"))
  expect_true(all(c("covariate", "type", "arm1", "arm2", "smd", "abs_smd")
                  %in% names(res$smd_table)))
})

test_that("age SMD is large and the table is sorted by abs_smd", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_covariates(con, cdm_schema = "main", cohort_table = "test_cohort",
                        cohort_id = 1, comparator_id = 2, vocab_schema = "main")

  age <- res$smd_table[res$smd_table$covariate == "Age (years)", ]
  expect_true(is.finite(age$smd))
  expect_gt(abs(age$smd), 0.1)
  # sorted descending by abs_smd (NA last)
  a <- res$smd_table$abs_smd[!is.na(res$smd_table$abs_smd)]
  expect_false(is.unsorted(rev(a)))
})

test_that("prevalence table covers conditions and drugs per arm", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_covariates(con, cdm_schema = "main", cohort_table = "test_cohort",
                        cohort_id = 1, comparator_id = 2, vocab_schema = "main")

  expect_setequal(unique(res$prevalence_table$domain), c("condition", "drug"))
  expect_true(all(c("arm1_pct", "arm2_pct") %in% names(res$prevalence_table)))
})

test_that("imbalance and low power are flagged", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- run_covariates(con, cdm_schema = "main", cohort_table = "test_cohort",
                        cohort_id = 1, comparator_id = 2, vocab_schema = "main")

  expect_true(any(grepl("SMD", res$flags)))
  expect_true(any(grepl("power", res$flags)))
  expect_true(res$power$power < 0.8)
})

test_that("comparator_id enables Module 4 in validate_cohort", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  td <- tempfile("rwe_vc_"); on.exit(unlink(td, recursive = TRUE), add = TRUE)

  out <- validate_cohort(
    cdm_schema = "main", cohort_table = "test_cohort", cohort_id = 1,
    comparator_id = 2, con = con, vocab_schema = "main",
    output_dir = td, render_html = FALSE)

  expect_false(is.null(out$results$covariates))
  expect_true("Covariate Feasibility" %in% out$report$check_summary$section)
})
