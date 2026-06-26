# Validate rwevalidate against real OHDSI gold-standard phenotype cohorts
# instantiated on the 5,000-patient MIMIC-IV CDM (mimiciv_omop, CDM v5.4).
#
# Cohort definitions come from the sibling omop-phenotype-pipeline project
# (OHDSI Phenotype Library gold concept sets). For each phenotype we expand the
# gold seed concepts to descendants (minus the excluded set) via vocab, find
# qualifying patients across clinical domains, and index on the first qualifying
# event - the standard OHDSI concept-set cohort. A complement comparator enables
# Module 4. observation_period is derived (the mimiciv_omop build lacks it).
#
# Usage:  Rscript validation/run_phenotypes.R

Sys.setenv(RSTUDIO_PANDOC = "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools")
suppressMessages(library(rwevalidate))

proj <- "c:/Users/tavak/Documents/SecondBrain/projects/RWE_COHORT_VALIDATOR/RWE_COHORT_VALIDATOR"
gold_dir <- "c:/Users/tavak/Documents/SecondBrain/projects/omop-phenotype-pipeline/data/gold_standards"
out_dir  <- file.path(proj, "validation", "reports", "phenotypes")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

CDM <- "mimiciv_omop"; VOCAB <- "vocab"; CT <- "results.phenotype_cohorts"

# Raw connection (cdm_connect would reject the schema before we derive
# observation_period; we verify cdm_connect's split-schema check after deriving).
con <- DBI::dbConnect(RPostgres::Postgres(), host=Sys.getenv("PG_HOST"),
  port=as.integer(Sys.getenv("PG_PORT")), dbname=Sys.getenv("PG_DBNAME"),
  user=Sys.getenv("PG_USER"), password=Sys.getenv("PG_PASS"))

# --- 1. Derive observation_period (one row per person; full data span) -------
has_op <- nrow(DBI::dbGetQuery(con, glue::glue(
  "SELECT 1 FROM information_schema.tables
    WHERE table_schema='{CDM}' AND table_name='observation_period'"))) > 0
if (!has_op) {
  message("Deriving ", CDM, ".observation_period ...")
  DBI::dbExecute(con, glue::glue(
    "CREATE TABLE {CDM}.observation_period AS
     SELECT ROW_NUMBER() OVER (ORDER BY person_id) AS observation_period_id,
            person_id,
            MIN(d) AS observation_period_start_date,
            MAX(d) AS observation_period_end_date,
            44814724 AS period_type_concept_id
     FROM (
       SELECT person_id, condition_start_date d FROM {CDM}.condition_occurrence
       UNION ALL SELECT person_id, drug_exposure_start_date FROM {CDM}.drug_exposure
       UNION ALL SELECT person_id, measurement_date FROM {CDM}.measurement
       UNION ALL SELECT person_id, procedure_date FROM {CDM}.procedure_occurrence
       UNION ALL SELECT person_id, visit_start_date FROM {CDM}.visit_occurrence
     ) e WHERE d IS NOT NULL GROUP BY person_id"))
}
cat("observation_period rows:",
    as.integer(DBI::dbGetQuery(con, glue::glue("SELECT COUNT(*) n FROM {CDM}.observation_period"))$n), "\n")

# Verify the split-schema cdm_connect now accepts this schema (clinical in
# mimiciv_omop, vocab in vocab) - proves the package change works live.
test_con <- cdm_connect(host=Sys.getenv("PG_HOST"), port=as.integer(Sys.getenv("PG_PORT")),
  dbname=Sys.getenv("PG_DBNAME"), user=Sys.getenv("PG_USER"), password=Sys.getenv("PG_PASS"),
  cdm_schema=CDM, vocab_schema=VOCAB)
cdm_disconnect(test_con)
cat("split-schema cdm_connect: OK\n")

# --- 2. Load gold phenotype definitions --------------------------------------
files <- c("p01_t2dm.json","p02_cardiac_valve_af.json","p03_acute_liver_injury.json",
           "p04_drug_pancreatitis.json","p05_trd.json")
phenos <- lapply(files, function(f) {
  j <- jsonlite::read_json(file.path(gold_dir, f), simplifyVector = TRUE)
  list(id = j$cohort_id, name = j$cohort_name,
       gold = as.integer(j$gold_concept_ids),
       excl = if (length(j$excluded_concept_ids)) as.integer(j$excluded_concept_ids) else integer(0))
})

# --- 3. Instantiate cohorts (concept-set expansion minus exclusions) ---------
DBI::dbExecute(con, glue::glue("DROP TABLE IF EXISTS {CT}"))
DBI::dbExecute(con, glue::glue(
  "CREATE TABLE {CT} (subject_id NUMERIC, cohort_definition_id INT,
     cohort_start_date DATE, cohort_end_date DATE)"))  # NUMERIC: mimiciv_omop person_id exceeds bigint

inlist <- function(x) paste(x, collapse = ", ")
instantiate <- function(p) {
  gold <- inlist(p$gold)
  excl_clause <- if (length(p$excl))
    glue::glue("AND descendant_concept_id NOT IN (
       SELECT descendant_concept_id FROM {VOCAB}.concept_ancestor
       WHERE ancestor_concept_id IN ({inlist(p$excl)}))") else ""
  qset <- glue::glue(
    "SELECT descendant_concept_id FROM {VOCAB}.concept_ancestor
      WHERE ancestor_concept_id IN ({gold}) {excl_clause}")
  DBI::dbExecute(con, glue::glue(
    "INSERT INTO {CT}
     SELECT person_id, {p$id}, MIN(d), MAX(d) FROM (
       SELECT person_id, condition_start_date d FROM {CDM}.condition_occurrence WHERE condition_concept_id IN ({qset})
       UNION ALL SELECT person_id, drug_exposure_start_date FROM {CDM}.drug_exposure WHERE drug_concept_id IN ({qset})
       UNION ALL SELECT person_id, measurement_date FROM {CDM}.measurement WHERE measurement_concept_id IN ({qset})
       UNION ALL SELECT person_id, procedure_date FROM {CDM}.procedure_occurrence WHERE procedure_concept_id IN ({qset})
     ) e GROUP BY person_id"))
  # complement comparator (id + 10000), condition-indexed
  DBI::dbExecute(con, glue::glue(
    "INSERT INTO {CT}
     SELECT person_id, {p$id + 10000}, MIN(condition_start_date), MAX(condition_end_date)
     FROM {CDM}.condition_occurrence
     WHERE person_id NOT IN (SELECT subject_id FROM {CT} WHERE cohort_definition_id = {p$id})
     GROUP BY person_id"))
  as.integer(DBI::dbGetQuery(con, glue::glue(
    "SELECT COUNT(*) n FROM {CT} WHERE cohort_definition_id = {p$id}"))$n)
}

# --- 4. Validate each phenotype ----------------------------------------------
rows <- lapply(phenos, function(p) {
  n_t <- instantiate(p)
  t0 <- Sys.time()
  res <- tryCatch(validate_cohort(
    cdm_schema=CDM, cohort_table=CT, cohort_id=p$id, comparator_id=p$id + 10000,
    concept_ids=p$gold, concept_domain="condition", vocab_schema=VOCAB,
    output_dir=file.path(out_dir, p$name), con=con, render_html=TRUE, quiet=TRUE),
    error=function(e) e)
  el <- round(as.numeric(difftime(Sys.time(), t0, units="secs")), 2)
  if (inherits(res, "error")) {
    data.frame(cohort_id=p$id, phenotype=p$name, n_target=n_t, status="error",
               fail=NA, warn=NA, elapsed_s=el, detail=conditionMessage(res), stringsAsFactors=FALSE)
  } else {
    cs <- res$report$check_summary
    data.frame(cohort_id=p$id, phenotype=p$name, n_target=n_t, status="ok",
               fail=sum(cs$status=="fail"), warn=sum(cs$status=="warn"),
               elapsed_s=el, detail=paste(nrow(cs),"checks"), stringsAsFactors=FALSE)
  }
})
summary <- do.call(rbind, rows)
cdm_disconnect(con)

print(summary, row.names = FALSE)
csv <- file.path(proj, "validation", "phenotype_summary.csv")
utils::write.csv(summary, csv, row.names = FALSE)
cat("\nwritten:", csv, "\nreports:", out_dir, "\n")
