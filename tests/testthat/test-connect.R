test_that("validate_cdm_tables passes when all required tables present", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  # DuckDB writes to the default 'main' schema.
  expect_true(validate_cdm_tables(con, cdm_schema = "main"))
})

test_that("validate_cdm_tables aborts and names the missing table", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  DBI::dbRemoveTable(con, "death")

  expect_error(
    validate_cdm_tables(con, cdm_schema = "main"),
    regexp = "death"
  )
})

test_that("validate_cdm_tables comparison is case-insensitive", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  expect_true(
    validate_cdm_tables(con, cdm_schema = "main",
                        clinical = c("PERSON", "Death"), vocab = character(0))
  )
})

test_that("validate_cdm_tables reports a missing vocabulary table", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  DBI::dbRemoveTable(con, "concept_ancestor")

  expect_error(
    validate_cdm_tables(con, cdm_schema = "main", vocab_schema = "main"),
    regexp = "concept_ancestor"
  )
})

test_that("validate_cdm_tables aborts when the vocab schema lacks vocab tables", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  # 'nonesuch' schema has no tables -> vocab check fails there, clinical passes.
  expect_error(
    validate_cdm_tables(con, cdm_schema = "main", vocab_schema = "nonesuch"),
    regexp = "concept"
  )
})

test_that("check_ident accepts valid identifiers and rejects injection", {
  expect_invisible(check_ident("mimic_cdm", "cdm_schema"))
  expect_invisible(check_ident("results.my_cohort", "cohort_table"))
  expect_error(check_ident("a; DROP TABLE person", "cohort_table"), "identifier")
  expect_error(check_ident("a.b.c", "cohort_table"), "identifier")
  expect_error(check_ident(c("a", "b"), "cdm_schema"), "identifier")
  expect_error(check_ident(NA_character_, "cdm_schema"), "identifier")
})

test_that("run_covariates rejects a comparator equal to the cohort id", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  expect_error(
    run_covariates(con, cdm_schema = "main", cohort_table = "test_cohort",
                   cohort_id = 1, comparator_id = 1, vocab_schema = "main"),
    regexp = "differ"
  )
})

test_that("cdm_disconnect closes the connection", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()

  expect_true(DBI::dbIsValid(con))
  cdm_disconnect(con)
  expect_false(DBI::dbIsValid(con))
})
