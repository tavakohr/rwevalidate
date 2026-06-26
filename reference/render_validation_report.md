# Render the validation report (HTML) and write the JSON sidecar

Renders the bundled R Markdown template to a self-contained HTML report
and writes a machine-readable `validation_results.json` alongside it.

## Usage

``` r
render_validation_report(
  results,
  output_dir,
  cdm_schema,
  cohort_id,
  package_version = as.character(utils::packageVersion("rwevalidate")),
  run_date = Sys.time(),
  quiet = TRUE
)
```

## Arguments

- results:

  Combined results list (e.g. `list(attrition = ..., density = ...)`,
  optionally `data_source = ...`).

- output_dir:

  Directory to write the report into (created if needed).

- cdm_schema:

  CDM schema name (for the report header / JSON).

- cohort_id:

  Cohort definition id (for the report header / JSON).

- package_version:

  Package version string. Defaults to the installed `rwevalidate`
  version.

- run_date:

  Timestamp for the run. Defaults to
  [`base::Sys.time()`](https://rdrr.io/r/base/Sys.time.html).

- quiet:

  Passed to
  [`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html).
  Default `TRUE`.

## Value

Invisibly, a list with `html`, `json`, and `check_summary`.
