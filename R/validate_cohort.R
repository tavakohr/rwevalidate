#' Build the data-source summary (FDA Relevance, report Section 1)
#'
#' Best-effort: queries `cdm_source`, `person`, and `observation_period`. Returns
#' `NULL` if any table is absent (e.g. the minimal test mock), so the report
#' degrades gracefully.
#'
#' @keywords internal
#' @noRd
build_data_source <- function(con, cdm_schema) {
  tryCatch({
    src <- DBI::dbGetQuery(con, glue::glue(
      "SELECT cdm_version, cdm_source_name FROM {cdm_schema}.cdm_source LIMIT 1"))
    npat <- as.integer(DBI::dbGetQuery(con, glue::glue(
      "SELECT COUNT(*) AS n FROM {cdm_schema}.person"))$n)
    rng <- DBI::dbGetQuery(con, glue::glue(
      "SELECT MIN(observation_period_start_date) AS lo,
              MAX(observation_period_end_date)   AS hi
         FROM {cdm_schema}.observation_period"))
    list(
      cdm_schema    = cdm_schema,
      cdm_version   = if (nrow(src)) src$cdm_version else NA_character_,
      source_name   = if (nrow(src)) src$cdm_source_name else NA_character_,
      patient_count = npat,
      data_start    = as.character(rng$lo),
      data_end      = as.character(rng$hi)
    )
  }, error = function(e) NULL)
}

#' Validate a patient cohort for real-world-evidence use
#'
#' One-call entry point: connects to the OMOP CDM (or uses a supplied
#' connection), runs the attrition (Module 2) and temporal-density (Module 3)
#' checks, and produces a self-contained HTML report plus a JSON sidecar aligned
#' with FDA RWE and HARPER frameworks.
#'
#' Supply either an open `con` (e.g. for DuckDB testing) or PostgreSQL connection
#' arguments (`dbname`, `user`, `password`, ...). Connections opened internally
#' are closed on exit; a connection passed in via `con` is left open.
#'
#' @param cdm_schema Schema holding the clinical CDM tables (e.g. `"mimic_cdm"`).
#' @param cohort_table Cohort table, schema-qualified
#'   (e.g. `"results.rwevalidate_test_cohort"`).
#' @param cohort_id Integer cohort definition id. Default 1.
#' @param con Optional open `DBI` connection. If `NULL` (default) one is opened
#'   from the connection arguments and closed on exit.
#' @param vocab_schema Schema holding the vocabulary tables. Default `"vocab"`.
#'   Required because the clinical schema's `concept` table may be empty in
#'   split-schema builds.
#' @param comparator_id Reserved for Module 4 (covariate feasibility, v0.2).
#'   Currently ignored with a message if set.
#' @param obs_window Length-2 numeric `c(pre, post)` days for attrition prior
#'   observation. Default `c(-365, 0)`.
#' @param density_window Length-2 numeric `c(pre, post)` days for density.
#'   Default `c(-365, 365)`.
#' @param output_dir Directory for the report + JSON. Default
#'   `"./validation_report"`.
#' @param host,port,dbname,user,password PostgreSQL connection arguments, used
#'   only when `con` is `NULL`.
#' @param render_html Render the HTML report. Default `TRUE`. If Pandoc is
#'   unavailable, only the JSON sidecar is written (with a warning).
#' @param quiet Passed to [rmarkdown::render()]. Default `TRUE`.
#'
#' @return Invisibly, a list with `results` (module outputs + data_source),
#'   `report` (paths + check summary), and `flags` (all collected flags).
#'
#' @examples
#' \dontrun{
#' validate_cohort(
#'   cdm_schema   = "mimic_cdm",
#'   cohort_table = "results.rwevalidate_test_cohort",
#'   cohort_id    = 1,
#'   dbname = "FHIR", user = "me", password = "secret",
#'   vocab_schema = "vocab",
#'   output_dir   = "./validation_report"
#' )
#' }
#'
#' @export
validate_cohort <- function(cdm_schema,
                            cohort_table,
                            cohort_id = 1,
                            con = NULL,
                            vocab_schema = "vocab",
                            comparator_id = NULL,
                            obs_window = c(-365, 0),
                            density_window = c(-365, 365),
                            output_dir = "./validation_report",
                            host = "localhost",
                            port = 5432,
                            dbname = NULL,
                            user = NULL,
                            password = NULL,
                            render_html = TRUE,
                            quiet = TRUE) {

  # --- argument validation ------------------------------------------------
  stopifnot(
    is.character(cdm_schema), length(cdm_schema) == 1,
    is.character(cohort_table), length(cohort_table) == 1,
    is.numeric(cohort_id), length(cohort_id) == 1,
    length(obs_window) == 2, length(density_window) == 2
  )
  if (!is.null(comparator_id)) {
    cli::cli_inform("{.arg comparator_id} is reserved for Module 4 (v0.2) and is ignored in this version.")
  }

  # --- connection (open if not supplied) ----------------------------------
  owns_con <- is.null(con)
  if (owns_con) {
    if (is.null(dbname) || is.null(user) || is.null(password)) {
      cli::cli_abort(
        "Provide an open {.arg con}, or {.arg dbname}/{.arg user}/{.arg password} to open one.")
    }
    con <- cdm_connect(host = host, port = port, dbname = dbname,
                       user = user, password = password, cdm_schema = cdm_schema)
    on.exit(cdm_disconnect(con), add = TRUE)
  } else {
    stopifnot(DBI::dbIsValid(con))
  }

  # --- run modules --------------------------------------------------------
  cli::cli_alert_info("Running attrition audit (Module 2)...")
  attrition <- run_attrition(
    con, cdm_schema = cdm_schema, cohort_table = cohort_table,
    cohort_id = cohort_id, obs_window = obs_window, vocab_schema = vocab_schema)

  cli::cli_alert_info("Running temporal data density (Module 3)...")
  density <- run_density(
    con, cdm_schema = cdm_schema, cohort_table = cohort_table,
    cohort_id = cohort_id, obs_window = density_window)

  data_source <- build_data_source(con, cdm_schema)

  results <- list(
    data_source = data_source,
    attrition   = attrition,
    density     = density
  )
  all_flags <- c(attrition$flags, density$flags)

  # --- report -------------------------------------------------------------
  run_date <- Sys.time()
  if (render_html && rmarkdown::pandoc_available()) {
    cli::cli_alert_info("Rendering HTML report...")
    report <- render_validation_report(
      results, output_dir = output_dir, cdm_schema = cdm_schema,
      cohort_id = cohort_id, run_date = run_date, quiet = quiet)
  } else {
    if (render_html) {
      cli::cli_warn("Pandoc unavailable; writing JSON sidecar only (no HTML).")
    }
    json <- write_results_json(
      results, output_dir = output_dir, cdm_schema = cdm_schema,
      cohort_id = cohort_id, run_date = run_date)
    report <- list(html = NA_character_, json = json,
                   check_summary = build_check_summary(results))
  }

  n_fail <- sum(grepl("^FAIL:", all_flags))
  n_warn <- sum(grepl("^WARN:", all_flags))
  cli::cli_alert_success(
    "Validation complete: {n_fail} fail, {n_warn} warn across {nrow(report$check_summary)} checks.")

  invisible(list(results = results, report = report, flags = all_flags))
}
