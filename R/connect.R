#' Required clinical CDM tables (validated in the clinical schema)
#'
#' @keywords internal
#' @noRd
REQUIRED_CLINICAL_TABLES <- c(
  "person",
  "observation_period",
  "condition_occurrence",
  "drug_exposure",
  "measurement",
  "visit_occurrence",
  "death"
)

#' Required vocabulary tables (validated in the vocabulary schema)
#'
#' @keywords internal
#' @noRd
REQUIRED_VOCAB_TABLES <- c("concept", "concept_ancestor")

#' Lower-cased table names present in a schema
#'
#' Uses `information_schema.tables` (available on both PostgreSQL and DuckDB).
#'
#' @keywords internal
#' @noRd
schema_tables <- function(con, schema) {
  DBI::dbGetQuery(
    con,
    glue::glue_sql(
      "SELECT LOWER(table_name) AS table_name
         FROM information_schema.tables
        WHERE LOWER(table_schema) = LOWER({schema})",
      .con = con
    )
  )$table_name
}

#' Validate that required CDM tables exist
#'
#' Clinical tables are checked in `cdm_schema` and vocabulary tables in
#' `vocab_schema` (they may be the same schema). Aborts listing any missing
#' tables and the schema they were expected in. Comparison is case-insensitive.
#'
#' @param con A live `DBI` connection.
#' @param cdm_schema Schema holding the clinical CDM tables.
#' @param vocab_schema Schema holding the vocabulary tables. Defaults to
#'   `cdm_schema` (single-schema builds).
#' @param clinical,vocab Character vectors of required table names.
#'
#' @return Invisibly `TRUE` when all required tables are present; otherwise
#'   aborts with a `cli` error.
#'
#' @keywords internal
#' @noRd
validate_cdm_tables <- function(con, cdm_schema, vocab_schema = cdm_schema,
                                clinical = REQUIRED_CLINICAL_TABLES,
                                vocab = REQUIRED_VOCAB_TABLES) {
  missing_clin  <- setdiff(tolower(clinical), schema_tables(con, cdm_schema))

  vocab_present <- if (identical(tolower(vocab_schema), tolower(cdm_schema))) {
    schema_tables(con, cdm_schema)
  } else {
    schema_tables(con, vocab_schema)
  }
  missing_vocab <- setdiff(tolower(vocab), vocab_present)

  if (length(missing_clin) > 0 || length(missing_vocab) > 0) {
    msg <- "Required CDM table(s) missing."
    bullets <- c(msg)
    if (length(missing_clin) > 0) {
      bullets <- c(bullets,
        "x" = "Clinical schema {.val {cdm_schema}} missing: {.val {missing_clin}}")
    }
    if (length(missing_vocab) > 0) {
      bullets <- c(bullets,
        "x" = "Vocabulary schema {.val {vocab_schema}} missing: {.val {missing_vocab}}")
    }
    bullets <- c(bullets,
      "i" = "Pass {.arg vocab_schema} if the vocabulary lives in a separate schema.")
    cli::cli_abort(bullets)
  }

  invisible(TRUE)
}

#' Connect to an OMOP CDM database
#'
#' Opens a PostgreSQL connection via `RPostgres` and validates that the required
#' clinical tables (`person`, `observation_period`, `condition_occurrence`,
#' `drug_exposure`, `measurement`, `visit_occurrence`, `death`) exist in
#' `cdm_schema` and the vocabulary tables (`concept`, `concept_ancestor`) exist
#' in `vocab_schema` before returning. For split-schema CDMs (clinical and
#' vocabulary in different schemas) pass `vocab_schema`; it defaults to
#' `cdm_schema` for single-schema builds.
#'
#' @param host Database host. Default `"localhost"`.
#' @param port Database port. Default `5432`.
#' @param dbname Database name.
#' @param user Database user.
#' @param password Database password.
#' @param cdm_schema Schema holding the clinical CDM tables.
#' @param vocab_schema Schema holding the vocabulary tables. Defaults to
#'   `cdm_schema`.
#'
#' @return A live `DBI` connection to the CDM database.
#'
#' @examples
#' \dontrun{
#' con <- cdm_connect(
#'   dbname = "omop", user = "me", password = "secret",
#'   cdm_schema = "mimiciv_omop", vocab_schema = "vocab"
#' )
#' cdm_disconnect(con)
#' }
#'
#' @export
cdm_connect <- function(host = "localhost",
                        port = 5432,
                        dbname,
                        user,
                        password,
                        cdm_schema,
                        vocab_schema = cdm_schema) {
  if (missing(dbname) || missing(user) || missing(password) || missing(cdm_schema)) {
    cli::cli_abort(
      "{.arg dbname}, {.arg user}, {.arg password}, and {.arg cdm_schema} are required."
    )
  }

  con <- DBI::dbConnect(
    RPostgres::Postgres(),
    host     = host,
    port     = port,
    dbname   = dbname,
    user     = user,
    password = password
  )

  # If validation fails, close the connection we just opened before aborting.
  tryCatch(
    validate_cdm_tables(con, cdm_schema, vocab_schema),
    error = function(e) {
      DBI::dbDisconnect(con)
      cli::cli_abort(conditionMessage(e), call = NULL)
    }
  )

  cli::cli_alert_success(
    "Connected to {.val {dbname}} (clinical {.val {cdm_schema}}, vocab {.val {vocab_schema}})."
  )
  con
}

#' Disconnect from a CDM database
#'
#' @param con A live `DBI` connection returned by [cdm_connect()].
#'
#' @return Invisibly returns the result of [DBI::dbDisconnect()].
#'
#' @export
cdm_disconnect <- function(con) {
  invisible(DBI::dbDisconnect(con))
}
