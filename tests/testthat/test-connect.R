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
    validate_cdm_tables(con, cdm_schema = "main", required = c("PERSON", "Death"))
  )
})

test_that("cdm_disconnect closes the connection", {
  skip_if_not_installed("duckdb")
  con <- setup_mock_cdm()

  expect_true(DBI::dbIsValid(con))
  cdm_disconnect(con)
  expect_false(DBI::dbIsValid(con))
})
