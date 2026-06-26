# Connect to an OMOP CDM database

Opens a PostgreSQL connection via `RPostgres` and validates that the
required clinical tables (`person`, `observation_period`,
`condition_occurrence`, `drug_exposure`, `measurement`,
`visit_occurrence`, `death`) exist in `cdm_schema` and the vocabulary
tables (`concept`, `concept_ancestor`) exist in `vocab_schema` before
returning. For split-schema CDMs (clinical and vocabulary in different
schemas) pass `vocab_schema`; it defaults to `cdm_schema` for
single-schema builds.

## Usage

``` r
cdm_connect(
  host = "localhost",
  port = 5432,
  dbname,
  user,
  password,
  cdm_schema,
  vocab_schema = cdm_schema
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

  Schema holding the clinical CDM tables.

- vocab_schema:

  Schema holding the vocabulary tables. Defaults to `cdm_schema`.

## Value

A live `DBI` connection to the CDM database.

## Examples

``` r
if (FALSE) { # \dontrun{
con <- cdm_connect(
  dbname = "omop", user = "me", password = "secret",
  cdm_schema = "mimiciv_omop", vocab_schema = "vocab"
)
cdm_disconnect(con)
} # }
```
