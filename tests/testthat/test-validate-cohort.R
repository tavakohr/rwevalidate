test_that("validate_cohort runs end-to-end on a supplied connection (JSON only)", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  td <- tempfile("rwe_vc_"); on.exit(unlink(td, recursive = TRUE), add = TRUE)

  out <- validate_cohort(
    cdm_schema = "main", cohort_table = "test_cohort", cohort_id = 1,
    con = con, vocab_schema = "main", output_dir = td, render_html = FALSE
  )

  expect_named(out, c("results", "report", "flags"))
  expect_identical(out$results$attrition$cohort_size, 12L)
  expect_s3_class(out$results$density$density_by_domain, "data.frame")
  expect_true(file.exists(out$report$json))
  expect_equal(nrow(out$report$check_summary), 2L)
})

test_that("a supplied connection is left open after the call", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  td <- tempfile("rwe_vc_"); on.exit(unlink(td, recursive = TRUE), add = TRUE)

  validate_cohort(cdm_schema = "main", cohort_table = "test_cohort",
                  con = con, vocab_schema = "main", output_dir = td,
                  render_html = FALSE)

  expect_true(DBI::dbIsValid(con))  # we did not own it -> not disconnected
})

test_that("collected flags surface a failing check", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  td <- tempfile("rwe_vc_"); on.exit(unlink(td, recursive = TRUE), add = TRUE)

  # Require 500d prior obs; mock has 400d -> attrition FAIL.
  out <- validate_cohort(
    cdm_schema = "main", cohort_table = "test_cohort", con = con,
    vocab_schema = "main", obs_window = c(-500, 0), output_dir = td,
    render_html = FALSE
  )
  expect_true(any(grepl("^FAIL:", out$flags)))
})

test_that("missing connection args abort when no con is supplied", {
  expect_error(
    validate_cohort(cdm_schema = "main", cohort_table = "test_cohort",
                    render_html = FALSE),
    regexp = "con|dbname"
  )
})

test_that("concept_ids enables Module 1 and adds a third check row", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  td <- tempfile("rwe_vc_"); on.exit(unlink(td, recursive = TRUE), add = TRUE)

  with_ids <- validate_cohort(
    cdm_schema = "main", cohort_table = "test_cohort", con = con,
    vocab_schema = "main", concept_ids = 316139, output_dir = td,
    render_html = FALSE)
  expect_false(is.null(with_ids$results$concepts))
  expect_equal(nrow(with_ids$report$check_summary), 3L)

  without <- validate_cohort(
    cdm_schema = "main", cohort_table = "test_cohort", con = con,
    vocab_schema = "main", output_dir = td, render_html = FALSE)
  expect_null(without$results$concepts)
  expect_equal(nrow(without$report$check_summary), 2L)
})

test_that("validate_cohort renders HTML when pandoc is available", {
  skip_if_not_installed("duckdb")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  td <- tempfile("rwe_vc_"); on.exit(unlink(td, recursive = TRUE), add = TRUE)

  out <- validate_cohort(
    cdm_schema = "main", cohort_table = "test_cohort", con = con,
    vocab_schema = "main", output_dir = td, render_html = TRUE, quiet = TRUE
  )
  expect_true(file.exists(out$report$html))
})
