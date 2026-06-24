# Minimal fixture mimicking combined module outputs.
mock_results <- function(attr_flags = character(0), dens_flags = character(0)) {
  list(
    attrition = list(
      cohort_size = 25L,
      index_date_summary = data.frame(index_year = c(2130L, 2131L), n = c(10L, 15L)),
      obs_coverage = data.frame(cohort_n = 25L, n_sufficient = 7L,
                                pct_sufficient = 28, min_prior_days = 365L),
      demographics = data.frame(sex = c("MALE", "FEMALE"), mean_age = c(68.5, 71.3),
                                min_age = c(45L, 48L), max_age = c(87L, 91L),
                                n = c(13L, 12L)),
      flags = attr_flags
    ),
    density = list(
      density_by_domain = data.frame(
        domain = c("conditions", "drugs"), months_from_index = c(0L, 0L),
        n_patients = c(25L, 24L), n_records = c(2857L, 2455L),
        records_per_patient = c(114.28, 102.29)),
      followup_summary = data.frame(censoring_reason = c("cohort_exit", "death"),
                                    n = c(19L, 6L), median_followup_days = c(13, 399.5)),
      followup_detail = data.frame(subject_id = 1:25,
                                   effective_end_date = as.Date("2130-01-01"),
                                   cohort_start_date = as.Date("2129-01-01"),
                                   followup_days = rep(365L, 25),
                                   censoring_reason = "cohort_exit"),
      flags = dens_flags
    )
  )
}

test_that("classify_status maps flags correctly", {
  expect_equal(classify_status(character(0)), "pass")
  expect_equal(classify_status("WARN: x"), "warn")
  expect_equal(classify_status("FAIL: x"), "fail")
  expect_equal(classify_status(c("WARN: x", "FAIL: y")), "fail")  # fail dominates
})

test_that("build_check_summary produces one row per present module", {
  cs <- build_check_summary(mock_results(
    attr_flags = "FAIL: low coverage", dens_flags = character(0)))

  expect_equal(nrow(cs), 2L)
  expect_setequal(cs$section, c("Cohort Attrition", "Temporal Data Density"))
  expect_equal(cs$status[cs$section == "Cohort Attrition"], "fail")
  expect_equal(cs$status[cs$section == "Temporal Data Density"], "pass")
  expect_match(cs$detail[cs$section == "Temporal Data Density"], "passed")
})

test_that("build_check_summary skips absent modules", {
  cs <- build_check_summary(list(attrition = mock_results()$attrition))
  expect_equal(nrow(cs), 1L)
  expect_equal(cs$section, "Cohort Attrition")
})

test_that("write_results_json writes valid, well-keyed JSON", {
  td <- tempfile("rwe_json_"); dir.create(td)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)

  p <- write_results_json(mock_results(), td, cdm_schema = "mimic_cdm",
                          cohort_id = 1, package_version = "0.0.0.9000")
  expect_true(file.exists(p))

  parsed <- jsonlite::read_json(p)
  expect_setequal(names(parsed),
                  c("run_date", "package_version", "cdm_schema", "cohort_id",
                    "check_summary", "results"))
  expect_equal(parsed$cdm_schema, "mimic_cdm")
})

test_that("render_validation_report produces HTML + JSON when pandoc is available", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")
  td <- tempfile("rwe_render_"); dir.create(td)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)

  out <- render_validation_report(
    mock_results(attr_flags = "FAIL: Only 28% ..."),
    output_dir = td, cdm_schema = "mimic_cdm", cohort_id = 1,
    package_version = "0.0.0.9000", quiet = TRUE
  )

  expect_true(file.exists(out$html))
  expect_true(file.exists(out$json))
  expect_gt(file.size(out$html), 1000)  # real rendered document
})
