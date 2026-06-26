# Connect to an OMOP CDM database

Opens a PostgreSQL connection via `RPostgres` and validates that the
required CDM tables (`person`, `observation_period`,
`condition_occurrence`, `drug_exposure`, `measurement`,
`visit_occurrence`, `death`, `concept`, `concept_ancestor`) exist in
`cdm_schema` before returning.

## Usage

``` r
cdm_connect(
  host = "localhost",
  port = 5432,
  dbname,
  user,
  password,
  cdm_schema
)
```

## Arguments

- host:

  Database host. Default `"localhost"`.

- port:

  Database port. Default `5432`.

- dbname:

  Database name.

- user:

  Database user.

- password:

  Database password.

- cdm_schema:

  Schema holding the CDM tables, used for table validation.

## Value

A live `DBI` connection to the CDM database.

## Examples

``` r
if (FALSE) { # \dontrun{
con <- cdm_connect(
  dbname = "omop", user = "me", password = "secret",
  cdm_schema = "mimic_cdm"
)
cdm_disconnect(con)
} # }
```
