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
