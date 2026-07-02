#' Standardized mean difference (continuous covariate)
#'
#' @param m1,m2 Arm means. @param sd1,sd2 Arm standard deviations.
#' @return The SMD `(m1 - m2) / sqrt((sd1^2 + sd2^2) / 2)`; `NA` if the pooled SD is 0.
#' @keywords internal
#' @noRd
smd_continuous <- function(m1, m2, sd1, sd2) {
  pooled <- sqrt((sd1^2 + sd2^2) / 2)
  if (is.na(pooled) || pooled == 0) return(NA_real_)
  (m1 - m2) / pooled
}

#' Standardized mean difference (binary covariate)
#'
#' @param p1,p2 Arm proportions in `[0, 1]`.
#' @return The SMD `(p1 - p2) / sqrt((p1(1-p1) + p2(1-p2)) / 2)`; `NA` if pooled is 0.
#' @keywords internal
#' @noRd
smd_binary <- function(p1, p2) {
  pooled <- sqrt((p1 * (1 - p1) + p2 * (1 - p2)) / 2)
  if (is.na(pooled) || pooled == 0) return(NA_real_)
  (p1 - p2) / pooled
}

#' Distinct-subject counts per arm for the top concepts in a domain
#'
#' @keywords internal
#' @noRd
concept_presence_by_arm <- function(con, cdm_schema, cohort_table, vocab_schema,
                                     table, concept_col, cid_t, cid_c,
                                     pre, post, top_n) {
  out <- DBI::dbGetQuery(con, glue::glue(
    "WITH cov AS (
       SELECT DISTINCT c.cohort_definition_id AS arm, c.subject_id,
              d.{concept_col} AS cid
       FROM {cohort_table} c
       JOIN {cdm_schema}.{table} d ON c.subject_id = d.person_id
        AND d.{date_col(table)} BETWEEN c.cohort_start_date + ({pre})
                                    AND c.cohort_start_date + ({post})
      WHERE c.cohort_definition_id IN ({cid_t}, {cid_c})
        AND d.{concept_col} <> 0
     )
     SELECT cov.cid, cc.concept_name,
            SUM(CASE WHEN cov.arm = {cid_t} THEN 1 ELSE 0 END) AS n_t,
            SUM(CASE WHEN cov.arm = {cid_c} THEN 1 ELSE 0 END) AS n_c
       FROM cov JOIN {vocab_schema}.concept cc ON cov.cid = cc.concept_id
      GROUP BY cov.cid, cc.concept_name
      ORDER BY (SUM(CASE WHEN cov.arm = {cid_t} THEN 1 ELSE 0 END) +
                SUM(CASE WHEN cov.arm = {cid_c} THEN 1 ELSE 0 END)) DESC
      LIMIT {top_n}"
  ))
  out$cid <- as.integer(out$cid)
  out$n_t <- as.integer(out$n_t)
  out$n_c <- as.integer(out$n_c)
  out
}

#' Date column for a clinical domain table
#' @keywords internal
#' @noRd
date_col <- function(table) {
  switch(table,
    condition_occurrence = "condition_start_date",
    drug_exposure        = "drug_exposure_start_date",
    procedure_occurrence = "procedure_date",
    measurement          = "measurement_date",
    cli::cli_abort("No date column mapping for table {.val {table}}.")
  )
}

#' Module 4 - Covariate Feasibility
#'
#' Compares a target cohort against a comparator on baseline covariates:
#' standardized mean differences (SMD love-plot data), a per-arm prevalence table,
#' and a simple power calculation. Maps to HARPER Sec.4 (comparability). Runs only
#' when a `comparator_id` is supplied.
#'
#' @param con A live `DBI` connection (see [cdm_connect()]).
#' @param cdm_schema Schema holding the clinical CDM tables.
#' @param cohort_table Cohort table, schema-qualified, containing both arms.
#' @param cohort_id Integer cohort definition id of the target arm.
#' @param comparator_id Integer cohort definition id of the comparator arm.
#' @param vocab_schema Schema holding the vocabulary tables. Default `"vocab"`.
#' @param covariate_window Length-2 numeric `c(pre, post)` days defining the
#'   baseline window relative to index for comorbidity/drug covariates.
#'   Default `c(-365, 0)`.
#' @param top_n Number of top conditions/drugs to profile. Default 20.
#' @param smd_warn_threshold Absolute SMD above which a covariate is flagged
#'   imbalanced. Default 0.1 (standard).
#' @param power_baseline_rate,power_effect_rate Assumed comparator and target
#'   event rates for the two-proportion power calculation. Defaults 0.15, 0.30.
#' @param power_sig_level Significance level for the power calculation. Default 0.05.
#' @param power_warn_threshold Power below this value flags a `WARN`. Default 0.80.
#'
#' @return A named list: `smd_table`, `prevalence_table`, `power`, `flags`.
#' @export
run_covariates <- function(con,
                           cdm_schema,
                           cohort_table,
                           cohort_id,
                           comparator_id,
                           vocab_schema = "vocab",
                           covariate_window = c(-365, 0),
                           top_n = 20,
                           smd_warn_threshold = 0.1,
                           power_baseline_rate = 0.15,
                           power_effect_rate = 0.30,
                           power_sig_level = 0.05,
                           power_warn_threshold = 0.80) {

  stopifnot(
    DBI::dbIsValid(con),
    is.numeric(cohort_id), length(cohort_id) == 1,
    is.numeric(comparator_id), length(comparator_id) == 1,
    length(covariate_window) == 2
  )
  check_ident(cdm_schema, "cdm_schema")
  check_ident(vocab_schema, "vocab_schema")
  check_ident(cohort_table, "cohort_table")
  cid_t <- as.integer(cohort_id)
  cid_c <- as.integer(comparator_id)
  if (identical(cid_t, cid_c)) {
    cli::cli_abort(
      "{.arg comparator_id} must differ from {.arg cohort_id} (both are {cid_t}).")
  }
  pre   <- as.integer(covariate_window[1])
  post  <- as.integer(covariate_window[2])
  flags <- character(0)

  # --- per-arm demographics ----------------------------------------------
  demo <- DBI::dbGetQuery(con, glue::glue(
    "SELECT c.cohort_definition_id AS arm,
            COUNT(*) AS n,
            AVG(EXTRACT(YEAR FROM c.cohort_start_date) - p.year_of_birth) AS mean_age,
            STDDEV(EXTRACT(YEAR FROM c.cohort_start_date) - p.year_of_birth) AS sd_age,
            AVG(CASE WHEN p.gender_concept_id = 8532 THEN 1.0 ELSE 0.0 END) AS p_female
       FROM {cohort_table} c
       JOIN {cdm_schema}.person p ON c.subject_id = p.person_id
      WHERE c.cohort_definition_id IN ({cid_t}, {cid_c})
      GROUP BY c.cohort_definition_id"
  ))
  arm_t <- demo[demo$arm == cid_t, ]
  arm_c <- demo[demo$arm == cid_c, ]
  if (nrow(arm_t) == 0 || nrow(arm_c) == 0) {
    cli::cli_abort("Both arms must be present: target {cid_t} and comparator {cid_c}.")
  }
  n_t <- as.integer(arm_t$n)
  n_c <- as.integer(arm_c$n)

  # --- top comorbidities (conditions) for SMD + prevalence ---------------
  cond <- concept_presence_by_arm(
    con, cdm_schema, cohort_table, vocab_schema,
    "condition_occurrence", "condition_concept_id", cid_t, cid_c, pre, post, top_n)
  cond$arm1_pct <- round(100 * cond$n_t / n_t, 1)
  cond$arm2_pct <- round(100 * cond$n_c / n_c, 1)

  # --- top drugs for prevalence ------------------------------------------
  drug <- concept_presence_by_arm(
    con, cdm_schema, cohort_table, vocab_schema,
    "drug_exposure", "drug_concept_id", cid_t, cid_c, pre, post, top_n)
  drug$arm1_pct <- round(100 * drug$n_t / n_t, 1)
  drug$arm2_pct <- round(100 * drug$n_c / n_c, 1)

  # --- SMD table (age + sex + comorbidities) -----------------------------
  smd_rows <- list(
    data.frame(covariate = "Age (years)", type = "continuous",
               arm1 = round(arm_t$mean_age, 2), arm2 = round(arm_c$mean_age, 2),
               smd = smd_continuous(arm_t$mean_age, arm_c$mean_age,
                                    arm_t$sd_age, arm_c$sd_age),
               stringsAsFactors = FALSE),
    data.frame(covariate = "Female", type = "binary",
               arm1 = round(arm_t$p_female, 3), arm2 = round(arm_c$p_female, 3),
               smd = smd_binary(arm_t$p_female, arm_c$p_female),
               stringsAsFactors = FALSE)
  )
  if (nrow(cond) > 0) {
    smd_rows[[length(smd_rows) + 1L]] <- data.frame(
      covariate = cond$concept_name, type = "binary",
      arm1 = round(cond$n_t / n_t, 3), arm2 = round(cond$n_c / n_c, 3),
      smd = mapply(smd_binary, cond$n_t / n_t, cond$n_c / n_c),
      stringsAsFactors = FALSE)
  }
  smd_table <- do.call(rbind, smd_rows)
  smd_table$abs_smd <- abs(smd_table$smd)
  smd_table <- smd_table[order(-smd_table$abs_smd), ]
  rownames(smd_table) <- NULL

  n_imbalanced <- sum(smd_table$abs_smd > smd_warn_threshold, na.rm = TRUE)
  if (n_imbalanced > 0) {
    flags <- c(flags, glue::glue(
      "WARN: {n_imbalanced} of {nrow(smd_table)} covariates have |SMD| > {smd_warn_threshold} (baseline imbalance)."))
  }

  # --- prevalence table (conditions + drugs) -----------------------------
  # Filter out the empty domains first so a run with no coded covariates in
  # either domain returns a typed empty data.frame instead of erroring on
  # rownames(NULL).
  prevalence_parts <- Filter(Negate(is.null), list(
    if (nrow(cond) > 0) data.frame(domain = "condition", concept_id = cond$cid,
      concept_name = cond$concept_name, arm1_pct = cond$arm1_pct,
      arm2_pct = cond$arm2_pct, stringsAsFactors = FALSE),
    if (nrow(drug) > 0) data.frame(domain = "drug", concept_id = drug$cid,
      concept_name = drug$concept_name, arm1_pct = drug$arm1_pct,
      arm2_pct = drug$arm2_pct, stringsAsFactors = FALSE)
  ))
  prevalence_table <- if (length(prevalence_parts) > 0) {
    do.call(rbind, prevalence_parts)
  } else {
    data.frame(domain = character(0), concept_id = integer(0),
               concept_name = character(0), arm1_pct = numeric(0),
               arm2_pct = numeric(0), stringsAsFactors = FALSE)
  }
  rownames(prevalence_table) <- NULL

  # --- power calculation -------------------------------------------------
  pt <- tryCatch(
    stats::power.prop.test(n = min(n_t, n_c), p1 = power_effect_rate,
                           p2 = power_baseline_rate, sig.level = power_sig_level),
    error = function(e) NULL)
  power_val <- if (!is.null(pt)) round(pt$power, 3) else NA_real_
  power <- data.frame(
    n_target = n_t, n_comparator = n_c,
    assumed_p_target = power_effect_rate, assumed_p_comparator = power_baseline_rate,
    sig_level = power_sig_level, power = power_val, stringsAsFactors = FALSE)

  if (!is.na(power_val) && power_val < power_warn_threshold) {
    flags <- c(flags, glue::glue(
      "WARN: Estimated power {power_val} < {power_warn_threshold} at n = {min(n_t, n_c)} per arm (assumed {power_baseline_rate} vs {power_effect_rate})."))
  }

  list(
    smd_table        = smd_table,
    prevalence_table = prevalence_table,
    power            = power,
    flags            = flags
  )
}
