# Write the JSON sidecar (no rendering)

Exposed separately so results can be persisted even when Pandoc is
unavailable for HTML rendering.

## Usage

``` r
write_results_json(
  results,
  output_dir,
  cdm_schema,
  cohort_id,
  package_version = as.character(utils::packageVersion("rwevalidate")),
  run_date = Sys.time(),
  check_summary = NULL
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

- check_summary:

  Optional pre-built summary; rebuilt if `NULL`.

## Value

The path to the written JSON file (invisibly).
