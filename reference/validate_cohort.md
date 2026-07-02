# Validate a patient cohort for real-world-evidence use

One-call entry point: connects to the OMOP CDM (or uses a supplied
connection), runs the attrition (Module 2) and temporal-density (Module
3) checks, and produces a self-contained HTML report plus a JSON sidecar
aligned with FDA RWE and HARPER frameworks.

## Usage

``` r
validate_cohort(
  cdm_schema,
  cohort_table,
  cohort_id = 1,
  con = NULL,
  vocab_schema = "vocab",
  concept_ids = NULL,
  concept_domain = "condition",
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
  quiet = TRUE
)
```

## Arguments

- cdm_schema:

  Schema holding the clinical CDM tables (e.g. `"mimic_cdm"`).

- cohort_table:

  Cohort table, schema-qualified (e.g.
  `"results.rwevalidate_test_cohort"`).

- cohort_id:

  Integer cohort definition id. Default 1.

- con:

  Optional open `DBI` connection. If `NULL` (default) one is opened from
  the connection arguments and closed on exit.

- vocab_schema:

  Schema holding the vocabulary tables. Default `"vocab"`. Required
  because the clinical schema's `concept` table may be empty in
  split-schema builds.

- concept_ids:

  Optional numeric vector of cohort-defining seed concept id(s). When
  supplied, Module 1 (concept coverage) runs and populates report
  Section 2. When `NULL` (default) Module 1 is skipped.

- concept_domain:

  Domain the seed concepts live in (`"condition"`, `"drug"`,
  `"measurement"`, `"procedure"`). Default `"condition"`.

- comparator_id:

  Optional integer cohort definition id of a comparator arm. When
  supplied, Module 4 (covariate feasibility) runs and populates report
  Section 5. When `NULL` (default) Module 4 is skipped.

- obs_window:

  Length-2 numeric `c(pre, post)` days for attrition prior observation.
  Default `c(-365, 0)`.

- density_window:

  Length-2 numeric `c(pre, post)` days for density. Default
  `c(-365, 365)`.

- output_dir:

  Directory for the report + JSON. Default `"./validation_report"`.

- host, port, dbname, user, password:

  PostgreSQL connection arguments, used only when `con` is `NULL`.

- render_html:

  Render the HTML report. Default `TRUE`. If Pandoc is unavailable, only
  the JSON sidecar is written (with a warning).

- quiet:

  Passed to
  [`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html).
  Default `TRUE`.

## Value

Invisibly, a list with `results` (module outputs + data_source),
`report` (paths + check summary), and `flags` (all collected flags).

## Details

Supply either an open `con` (e.g. for DuckDB testing) or PostgreSQL
connection arguments (`dbname`, `user`, `password`, ...). Connections
opened internally are closed on exit; a connection passed in via `con`
is left open.

## Examples

``` r
# Runnable demo on a small in-memory DuckDB CDM (no database needed).
# render_html = FALSE writes only the JSON sidecar, so Pandoc is not required.
if (requireNamespace("duckdb", quietly = TRUE)) {
  con <- example_cdm()
  out <- validate_cohort(
    cdm_schema   = "main",
    cohort_table = "cohort",
    cohort_id    = 1,
    con          = con,
    vocab_schema = "main",
    output_dir   = tempfile("rwe_demo_"),
    render_html  = FALSE
  )
  print(out$report$check_summary)
  cdm_disconnect(con)
}
#> ℹ Running attrition audit (Module 2)...
#> ℹ Running temporal data density (Module 3)...
#> Module 1 (concept coverage) skipped; supply `concept_ids` to enable.
#> Module 4 (covariate feasibility) skipped; supply `comparator_id` to enable.
#> ✔ Validation complete: 0 fail, 0 warn across 2 checks.
#>                 section status                         maps_to
#> 1      Cohort Attrition   pass HARPER Sec.5 / RECORD-PE Item 6
#> 2 Temporal Data Density   pass  FDA Reliability - data accrual
#>               detail
#> 1 All checks passed.
#> 2 All checks passed.

if (FALSE) { # \dontrun{
# Against a live PostgreSQL OMOP CDM:
validate_cohort(
  cdm_schema   = "mimic_cdm",
  cohort_table = "results.rwevalidate_test_cohort",
  cohort_id    = 1,
  dbname = "FHIR", user = "me", password = "secret",
  vocab_schema = "vocab",
  output_dir   = "./validation_report"
)
} # }
```
