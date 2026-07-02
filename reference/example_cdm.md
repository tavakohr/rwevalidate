# Create a small in-memory OMOP CDM for examples and demos

Builds a tiny synthetic OMOP CDM (10 persons) in an in-memory DuckDB
database and returns a live connection. Every table `rwevalidate`
queries for the attrition and density modules is populated, together
with a `cohort` table that has the standard `subject_id`,
`cohort_definition_id`, `cohort_start_date`, and `cohort_end_date`
columns. The clinical tables and a minimal vocabulary both live in the
default `main` schema.

## Usage

``` r
example_cdm()
```

## Value

A live `DBI` connection to an in-memory DuckDB OMOP CDM.

## Details

This exists so the package can be tried, and its examples can run,
without a live database connection. It is a synthetic demo fixture, not
a substitute for a real CDM. The `duckdb` package (a soft dependency)
must be installed. The caller owns the returned connection and should
close it with [`cdm_disconnect()`](cdm_disconnect.md).

## Examples

``` r
if (requireNamespace("duckdb", quietly = TRUE)) {
  con <- example_cdm()
  attrition <- run_attrition(con, cdm_schema = "main",
                             cohort_table = "cohort", cohort_id = 1,
                             vocab_schema = "main")
  print(attrition$cohort_size)
  cdm_disconnect(con)
}
#> duckdb: caching downloaded extensions in the package library:
#> ℹ /home/runner/work/_temp/Library/duckdb/extensions
#> ℹ This is removed when the package is re-installed; see `?duckdb_storage` to choose a different location.
#> [1] 10
```
