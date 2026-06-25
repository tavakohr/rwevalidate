#' Classify a vector of module flags into a traffic-light status
#'
#' Flags are strings prefixed `"FAIL:"` or `"WARN:"` (see the module functions).
#' Any `FAIL` -> `"fail"` (red); else any `WARN` -> `"warn"` (amber); else
#' `"pass"` (green).
#'
#' @param flags Character vector of flag messages (may be empty).
#' @return A single string: `"pass"`, `"warn"`, or `"fail"`.
#' @export
classify_status <- function(flags) {
  if (length(flags) == 0) return("pass")
  if (any(grepl("^FAIL:", flags))) return("fail")
  if (any(grepl("^WARN:", flags))) return("warn")
  "pass"
}

#' Build the traffic-light validation summary table
#'
#' Collects each module's flags into one row per validation section, mapping to
#' the regulatory framework the section addresses.
#'
#' @param results The combined results list (named module outputs, e.g.
#'   `attrition`, `density`). Modules absent from the list are skipped.
#' @return A data.frame with columns `section`, `status`, `maps_to`, `detail`.
#' @export
build_check_summary <- function(results) {
  spec <- list(
    concepts  = list(section = "Concept Coverage",
                     maps_to = "FDA Relevance - concept fitness"),
    attrition = list(section = "Cohort Attrition",
                     maps_to = "HARPER Sec.5 / RECORD-PE Item 6"),
    density   = list(section = "Temporal Data Density",
                     maps_to = "FDA Reliability - data accrual")
  )

  rows <- lapply(names(spec), function(key) {
    mod <- results[[key]]
    if (is.null(mod)) return(NULL)
    flags <- mod$flags %||% character(0)
    data.frame(
      section = spec[[key]]$section,
      status  = classify_status(flags),
      maps_to = spec[[key]]$maps_to,
      detail  = if (length(flags)) paste(flags, collapse = " ") else "All checks passed.",
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0) {
    return(data.frame(section = character(0), status = character(0),
                      maps_to = character(0), detail = character(0),
                      stringsAsFactors = FALSE))
  }
  do.call(rbind, rows)
}

#' Render the validation report (HTML) and write the JSON sidecar
#'
#' Renders the bundled R Markdown template to a self-contained HTML report and
#' writes a machine-readable `validation_results.json` alongside it.
#'
#' @param results Combined results list (e.g. `list(attrition = ..., density = ...)`,
#'   optionally `data_source = ...`).
#' @param output_dir Directory to write the report into (created if needed).
#' @param cdm_schema CDM schema name (for the report header / JSON).
#' @param cohort_id Cohort definition id (for the report header / JSON).
#' @param package_version Package version string. Defaults to the installed
#'   `rwevalidate` version.
#' @param run_date Timestamp for the run. Defaults to [base::Sys.time()].
#' @param quiet Passed to [rmarkdown::render()]. Default `TRUE`.
#'
#' @return Invisibly, a list with `html`, `json`, and `check_summary`.
#' @export
render_validation_report <- function(results,
                                      output_dir,
                                      cdm_schema,
                                      cohort_id,
                                      package_version = as.character(
                                        utils::packageVersion("rwevalidate")),
                                      run_date = Sys.time(),
                                      quiet = TRUE) {

  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)

  template <- system.file("report_template.Rmd", package = "rwevalidate")
  if (!nzchar(template)) {
    cli::cli_abort("Report template not found in the installed {.pkg rwevalidate}.")
  }
  if (!rmarkdown::pandoc_available()) {
    cli::cli_abort(c(
      "Pandoc is required to render the HTML report but was not found.",
      "i" = "The JSON sidecar can still be written; install Pandoc / RStudio to enable HTML."
    ))
  }

  check_summary <- build_check_summary(results)

  rmarkdown::render(
    input             = template,
    output_file       = "validation_report.html",
    output_dir        = output_dir,
    intermediates_dir = tempdir(),
    params = list(
      results         = results,
      cdm_schema      = cdm_schema,
      cohort_id       = cohort_id,
      check_summary   = check_summary,
      package_version = package_version,
      run_date        = format(run_date)
    ),
    envir = new.env(parent = globalenv()),
    quiet = quiet
  )
  html_path <- file.path(output_dir, "validation_report.html")

  json_path <- write_results_json(
    results, output_dir, cdm_schema, cohort_id, package_version, run_date,
    check_summary
  )

  cli::cli_alert_success("Report written to {.path {html_path}}")
  invisible(list(html = html_path, json = json_path, check_summary = check_summary))
}

#' Write the JSON sidecar (no rendering)
#'
#' Exposed separately so results can be persisted even when Pandoc is
#' unavailable for HTML rendering.
#'
#' @inheritParams render_validation_report
#' @param check_summary Optional pre-built summary; rebuilt if `NULL`.
#' @return The path to the written JSON file (invisibly).
#' @export
write_results_json <- function(results,
                               output_dir,
                               cdm_schema,
                               cohort_id,
                               package_version = as.character(
                                 utils::packageVersion("rwevalidate")),
                               run_date = Sys.time(),
                               check_summary = NULL) {
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  if (is.null(check_summary)) check_summary <- build_check_summary(results)

  json_path <- file.path(output_dir, "validation_results.json")
  jsonlite::write_json(
    list(
      run_date        = format(run_date),
      package_version = package_version,
      cdm_schema      = cdm_schema,
      cohort_id       = cohort_id,
      check_summary   = check_summary,
      results         = results
    ),
    path = json_path, pretty = TRUE, auto_unbox = TRUE
  )
  invisible(json_path)
}

# rlang's %||% without importing the operator into the namespace doc.
`%||%` <- function(x, y) if (is.null(x)) y else x
