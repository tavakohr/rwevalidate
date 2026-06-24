#' Required OMOP CDM tables
#'
#' The minimum set of CDM tables the validation modules query. Connection
#' setup aborts if any are missing from the target schema.
#'
#' @keywords internal
#' @noRd
REQUIRED_CDM_TABLES <- c(
  "person",
  "observation_period",
  "condition_occurrence",
  "drug_exposure",
  "measurement",
  "visit_occurrence",
  "death",
  "concept",
  "concept_ancestor"
)

#' Validate that required CDM tables exist in a schema
#'
#' Queries `information_schema.tables` (available on both PostgreSQL and DuckDB)
#' for the given schema and aborts if any required CDM table is missing. Table
#' name comparison is case-insensitive.
#'
#' @param con A live `DBI` connection.
#' @param cdm_schema Name of the schema holding the CDM tables.
#' @param required Character vector of required table names. Defaults to the
#'   package's `REQUIRED_CDM_TABLES`.
#'
#' @return Invisibly returns `TRUE` when all required tables are present.
#'   Otherwise aborts with a `cli` error listing the missing tables.
#'
#' @keywords internal
#' @noRd
validate_cdm_tables <- function(con, cdm_schema, required = REQUIRED_CDM_TABLES) {
  present <- DBI::dbGetQuery(
    con,
    glue::glue_sql(
      "SELECT LOWER(table_name) AS table_name
         FROM information_schema.tables
        WHERE LOWER(table_schema) = LOWER({cdm_schema})",
      .con = con
    )
  )$table_name

  missing <- setdiff(tolower(required), present)

  if (length(missing) > 0) {
    cli::cli_abort(c(
      "Required CDM table(s) missing from schema {.val {cdm_schema}}.",
      "x" = "Missing: {.val {missing}}",
      "i" = "Confirm the schema name and that this is a complete CDM build."
    ))
  }

  invisible(TRUE)
}

#' Connect to an OMOP CDM database
#'
#' Opens a PostgreSQL connection via `RPostgres` and validates that the required
#' CDM tables (`person`, `observation_period`, `condition_occurrence`,
#' `drug_exposure`, `measurement`, `visit_occurrence`, `death`, `concept`,
#' `concept_ancestor`) exist in `cdm_schema` before returning.
#'
#' @param host Database host. Default `"localhost"`.
#' @param port Database port. Default `5432`.
#' @param dbname Database name.
#' @param user Database user.
#' @param password Database password.
#' @param cdm_schema Schema holding the CDM tables, used for table validation.
#'
#' @return A live `DBI` connection to the CDM database.
#'
#' @examples
#' \dontrun{
#' con <- cdm_connect(
#'   dbname = "omop", user = "me", password = "secret",
#'   cdm_schema = "mimic_cdm"
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
                        cdm_schema) {
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
    validate_cdm_tables(con, cdm_schema),
    error = function(e) {
      DBI::dbDisconnect(con)
      cli::cli_abort(conditionMessage(e), call = NULL)
    }
  )

  cli::cli_alert_success(
    "Connected to {.val {dbname}} ({.val {cdm_schema}}); required CDM tables present."
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
