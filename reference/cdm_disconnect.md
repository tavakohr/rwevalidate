# Disconnect from a CDM database

Disconnect from a CDM database

## Usage

``` r
cdm_disconnect(con)
```

## Arguments

- con:

  A live `DBI` connection returned by [`cdm_connect()`](cdm_connect.md).

## Value

Invisibly returns the result of
[`DBI::dbDisconnect()`](https://dbi.r-dbi.org/reference/dbDisconnect.html).

## Examples

``` r
# Works on any DBI connection, demonstrated here on the bundled in-memory
# DuckDB example CDM (no database server needed).
if (requireNamespace("duckdb", quietly = TRUE)) {
  con <- example_cdm()
  cdm_disconnect(con)
}
#> duckdb is keeping downloaded extensions in a temporary directory:
#> ℹ /tmp/RtmpvQvU6F/duckdb/extensions
#> This is removed when the R session ends, so extensions are re-downloaded each session.
#> ℹ To keep them, point `options(duckdb.extension_directory =)` or the `DUCKDB_EXTENSION_DIRECTORY` environment variable at a permanent path.
```
