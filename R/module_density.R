#' Domains profiled by `run_density()`
#'
#' Maps a friendly domain label to its CDM table and date column.
#'
#' @keywords internal
#' @noRd
DENSITY_DOMAINS <- list(
  conditions   = list(table = "condition_occurrence", date_col = "condition_start_date"),
  drugs        = list(table = "drug_exposure",        date_col = "drug_exposure_start_date"),
  measurements = list(table = "measurement",          date_col = "measurement_date"),
  visits       = list(table = "visit_occurrence",     date_col = "visit_start_date")
)

#' Records-per-patient-per-month for one domain, relative to index
#'
#' Portable across PostgreSQL and DuckDB: `date - date` yields integer days on
#' both, and `FLOOR(days / 30.0)` floors correctly for pre-index (negative)
#' months, unlike integer division which truncates toward zero.
#'
#' @keywords internal
#' @noRd
density_one_domain <- function(con, cdm_schema, cohort_table, cohort_id,
                               domain_table, date_col, obs_window) {
  pre  <- as.integer(obs_window[1])
  post <- as.integer(obs_window[2])

  DBI::dbGetQuery(con, glue::glue(
    "SELECT
        months_from_index,
        COUNT(DISTINCT subject_id) AS n_patients,
        COUNT(*) AS n_records,
        ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT subject_id), 2) AS records_per_patient
       FROM (
         SELECT
           c.subject_id,
           FLOOR((d.{date_col} - c.cohort_start_date) / 30.0) AS months_from_index
         FROM {cohort_table} c
         JOIN {cdm_schema}.{domain_table} d ON c.subject_id = d.person_id
        WHERE c.cohort_definition_id = {cohort_id}
          AND d.{date_col} BETWEEN c.cohort_start_date + ({pre})
                               AND c.cohort_start_date + ({post})
       ) sub
      GROUP BY months_from_index
      ORDER BY months_from_index"
  ))
}

#' Module 3 - Temporal Data Density
#'
#' Profiles longitudinal data accrual around the index date: record density per
#' patient per month across clinical domains, and follow-up completeness with a
#' censoring-reason breakdown. Maps to FDA RWE Reliability (data accrual).
#'
#' @param con A live `DBI` connection (see [cdm_connect()]).
#' @param cdm_schema Schema holding the clinical CDM tables (e.g. `"mimic_cdm"`).
#' @param cohort_table Cohort table, schema-qualified.
#' @param cohort_id Integer cohort definition id.
#' @param obs_window Length-2 numeric `c(pre, post)` in days relative to index.
#'   Density is computed for records inside `[index + pre, index + post]`.
#'   Default `c(-365, 365)`.
#' @param sparse_warn_min Minimum total records a domain must have within the
#'   window before it is considered present; domains below this flag `WARN`
#'   (likely missing/sparse domain). Default 1 (flag only truly empty domains).
#'
#' @return A named list:
#'   \describe{
#'     \item{density_by_domain}{data.frame: `domain`, `months_from_index`,
#'       `n_patients`, `n_records`, `records_per_patient`}
#'     \item{followup_summary}{data.frame: one row per `censoring_reason` with
#'       `n` and `median_followup_days` (median over that group)}
#'     \item{followup_detail}{per-subject data.frame: `subject_id`,
#'       `effective_end_date`, `followup_days`, `censoring_reason`}
#'     \item{flags}{character vector of `WARN:`/`FAIL:` messages}
#'   }
#'
#' @export
run_density <- function(con,
                        cdm_schema,
                        cohort_table,
                        cohort_id,
                        obs_window = c(-365, 365),
                        sparse_warn_min = 1) {

  stopifnot(
    DBI::dbIsValid(con),
    length(obs_window) == 2,
    is.numeric(cohort_id), length(cohort_id) == 1
  )
  check_ident(cdm_schema, "cdm_schema")
  check_ident(cohort_table, "cohort_table")
  cohort_id <- as.integer(cohort_id)
  flags <- character(0)

  # --- 3a. Domain-level record density ------------------------------------
  parts <- lapply(names(DENSITY_DOMAINS), function(dom) {
    spec <- DENSITY_DOMAINS[[dom]]
    df <- density_one_domain(
      con, cdm_schema, cohort_table, cohort_id,
      spec$table, spec$date_col, obs_window
    )
    if (nrow(df) > 0) {
      df$months_from_index  <- as.integer(df$months_from_index)
      df$n_patients         <- as.integer(df$n_patients)
      df$n_records          <- as.integer(df$n_records)
      df$records_per_patient <- as.numeric(df$records_per_patient)
      df <- cbind(domain = dom, df, stringsAsFactors = FALSE)
    } else {
      df <- data.frame(
        domain = character(0), months_from_index = integer(0),
        n_patients = integer(0), n_records = integer(0),
        records_per_patient = numeric(0), stringsAsFactors = FALSE
      )
    }
    df
  })
  density_by_domain <- do.call(rbind, parts)
  rownames(density_by_domain) <- NULL

  # Flag any domain whose total record count in the window is below the sparse
  # threshold (a likely missing or under-populated domain). Done in one pass
  # over the assembled table so the loop above stays a pure map.
  for (dom in names(DENSITY_DOMAINS)) {
    total_records <- sum(density_by_domain$n_records[density_by_domain$domain == dom])
    if (total_records < sparse_warn_min) {
      flags <- c(flags, glue::glue(
        "WARN: Domain '{dom}' has {total_records} records in the observation window (possible missing/sparse domain)."
      ))
    }
  }

  # --- 3b. Follow-up completeness -----------------------------------------
  followup_detail <- DBI::dbGetQuery(con, glue::glue(
    "SELECT
        c.subject_id,
        c.cohort_start_date,
        c.cohort_end_date,
        op.observation_period_end_date,
        LEAST(c.cohort_end_date,
              COALESCE(op.observation_period_end_date, c.cohort_end_date)) AS effective_end_date,
        CASE
          WHEN op.person_id IS NULL THEN 'no_observation'
          WHEN d.person_id IS NOT NULL THEN 'death'
          WHEN c.cohort_end_date <= op.observation_period_end_date THEN 'cohort_exit'
          ELSE 'end_of_data'
        END AS censoring_reason
       FROM {cohort_table} c
       LEFT JOIN {cdm_schema}.observation_period op
         ON c.subject_id = op.person_id
        AND c.cohort_start_date BETWEEN op.observation_period_start_date
                                    AND op.observation_period_end_date
       LEFT JOIN {cdm_schema}.death d ON c.subject_id = d.person_id
      WHERE c.cohort_definition_id = {cohort_id}"
  ))

  followup_detail$followup_days <- as.integer(
    as.Date(followup_detail$effective_end_date) -
    as.Date(followup_detail$cohort_start_date)
  )

  if (nrow(followup_detail) > 0) {
    followup_summary <- stats::aggregate(
      followup_days ~ censoring_reason, data = followup_detail,
      FUN = stats::median
    )
    names(followup_summary)[names(followup_summary) == "followup_days"] <- "median_followup_days"
    counts <- as.data.frame(table(censoring_reason = followup_detail$censoring_reason),
                            stringsAsFactors = FALSE)
    names(counts)[names(counts) == "Freq"] <- "n"
    followup_summary <- merge(counts, followup_summary, by = "censoring_reason")
  } else {
    followup_summary <- data.frame(
      censoring_reason = character(0), n = integer(0),
      median_followup_days = numeric(0), stringsAsFactors = FALSE
    )
  }

  list(
    density_by_domain = density_by_domain,
    followup_summary  = followup_summary,
    followup_detail   = followup_detail,
    flags             = flags
  )
}
