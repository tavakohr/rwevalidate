# Multi-cohort robustness battery for rwevalidate.
#
# Instantiates several cohorts on the live mimic_cdm CDM spanning all index
# domains (condition / drug / procedure / measurement) plus sizes and an
# empty-cohort edge case, runs validate_cohort() on each (all four modules via a
# complement comparator), and writes a robustness summary. Standalone evidence
# that the package handles varied cohorts -- not shipped in the package.
#
# Usage:  Rscript validation/run_battery.R   (reads PG_* from ~/.Renviron)

Sys.setenv(RSTUDIO_PANDOC = "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools")
suppressMessages(library(rwevalidate))

proj    <- "c:/Users/tavak/Documents/SecondBrain/projects/RWE_COHORT_VALIDATOR/RWE_COHORT_VALIDATOR"
out_dir <- file.path(proj, "validation", "reports")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
battery_tbl <- "results.rwevalidate_battery"

con <- cdm_connect(host=Sys.getenv("PG_HOST"), port=as.integer(Sys.getenv("PG_PORT")),
  dbname=Sys.getenv("PG_DBNAME"), user=Sys.getenv("PG_USER"),
  password=Sys.getenv("PG_PASS"), cdm_schema="mimic_cdm")

DOMAIN <- list(
  condition   = list(tbl="condition_occurrence", col="condition_concept_id",   d="condition_start_date",   e="condition_end_date"),
  drug        = list(tbl="drug_exposure",         col="drug_concept_id",        d="drug_exposure_start_date", e="drug_exposure_end_date"),
  procedure   = list(tbl="procedure_occurrence",  col="procedure_concept_id",   d="procedure_date",         e="procedure_date"),
  measurement = list(tbl="measurement",           col="measurement_concept_id", d="measurement_date",       e="measurement_date")
)

# id, label, domain, seed concept
specs <- list(
  list(id=10, label="Heart failure",         domain="condition",   seed=316139),
  list(id=11, label="Atrial fibrillation",   domain="condition",   seed=313217),
  list(id=12, label="Obesity",               domain="condition",   seed=4215968),
  list(id=13, label="Acetaminophen (drug)",  domain="drug",        seed=1125315),
  list(id=14, label="Oxycodone (drug)",      domain="drug",        seed=1124957),
  list(id=15, label="Mech ventilation (proc)",domain="procedure",  seed=4141149),
  list(id=16, label="CBC lymphocytes (meas)",domain="measurement", seed=3004327),
  list(id=17, label="EDGE: empty cohort",    domain="condition",   seed=999999999)
)

# fresh battery table
DBI::dbExecute(con, sprintf("DROP TABLE IF EXISTS %s", battery_tbl))
DBI::dbExecute(con, sprintf(
  "CREATE TABLE %s (subject_id BIGINT, cohort_definition_id INT,
     cohort_start_date DATE, cohort_end_date DATE)", battery_tbl))

instantiate <- function(s) {
  dm <- DOMAIN[[s$domain]]
  # target: persons with a descendant of the seed in the domain
  DBI::dbExecute(con, glue::glue(
    "INSERT INTO {battery_tbl}
     SELECT person_id, {s$id}, MIN(d.{dm$d}), MAX(d.{dm$e})
     FROM mimic_cdm.{dm$tbl} d
     WHERE d.{dm$col} IN (
       SELECT descendant_concept_id FROM vocab.concept_ancestor WHERE ancestor_concept_id = {s$seed})
     GROUP BY person_id"))
  # comparator (id+100): complement, generic condition-based index
  DBI::dbExecute(con, glue::glue(
    "INSERT INTO {battery_tbl}
     SELECT person_id, {s$id + 100}, MIN(condition_start_date), MAX(condition_end_date)
     FROM mimic_cdm.condition_occurrence
     WHERE person_id NOT IN (SELECT subject_id FROM {battery_tbl} WHERE cohort_definition_id = {s$id})
     GROUP BY person_id"))
  as.integer(DBI::dbGetQuery(con, glue::glue(
    "SELECT COUNT(*) n FROM {battery_tbl} WHERE cohort_definition_id = {s$id}"))$n)
}

rows <- lapply(specs, function(s) {
  n_t <- instantiate(s)
  t0 <- Sys.time()
  res <- tryCatch(
    validate_cohort(
      cdm_schema="mimic_cdm", cohort_table=battery_tbl, cohort_id=s$id,
      comparator_id=s$id + 100, concept_ids=s$seed, concept_domain=s$domain,
      vocab_schema="vocab",
      output_dir=file.path(out_dir, paste0("cohort_", s$id)),
      con=con, render_html=TRUE, quiet=TRUE),
    error=function(e) e)
  elapsed <- round(as.numeric(difftime(Sys.time(), t0, units="secs")), 2)

  if (inherits(res, "error")) {
    data.frame(id=s$id, label=s$label, domain=s$domain, n_target=n_t,
               status="handled-error", n_fail=NA, n_warn=NA, elapsed_s=elapsed,
               note=conditionMessage(res), stringsAsFactors=FALSE)
  } else {
    fl <- res$flags
    data.frame(id=s$id, label=s$label, domain=s$domain, n_target=n_t,
               status="ok",
               n_fail=sum(grepl("^FAIL:", fl)), n_warn=sum(grepl("^WARN:", fl)),
               elapsed_s=elapsed,
               note=paste(nrow(res$report$check_summary), "checks"),
               stringsAsFactors=FALSE)
  }
})
summary <- do.call(rbind, rows)

# sample full HTML report for the HF cohort
invisible(validate_cohort(
  cdm_schema="mimic_cdm", cohort_table=battery_tbl, cohort_id=10,
  comparator_id=110, concept_ids=316139, concept_domain="condition",
  vocab_schema="vocab", output_dir=file.path(out_dir, "sample_hf_html"),
  con=con, render_html=TRUE, quiet=TRUE))

cdm_disconnect(con)

print(summary, row.names=FALSE)
csv <- file.path(proj, "validation", "robustness_summary.csv")
utils::write.csv(summary, csv, row.names=FALSE)
cat("\nwritten:", csv, "\n")
