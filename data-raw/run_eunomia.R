# Cross-dataset validation: run rwevalidate against OHDSI Eunomia (GiBleed).
#
# Eunomia ships a synthetic OMOP CDM v5.3.1 (~2,694 patients) as SQLite. We copy
# it into DuckDB (whose SQL dialect the package targets) via DuckDB's sqlite
# scanner, instantiate a cohort + complement comparator, and run validate_cohort.
# Standalone portability evidence (second, independent data source) - not shipped.
#
# Usage:  Rscript validation/run_eunomia.R

Sys.setenv(RSTUDIO_PANDOC = "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools")
suppressMessages(library(rwevalidate))

proj    <- "c:/Users/tavak/Documents/SecondBrain/projects/RWE_COHORT_VALIDATOR/RWE_COHORT_VALIDATOR"
out_dir <- file.path(proj, "validation", "reports", "eunomia")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# 1. Eunomia data (cached after first download)
path <- Eunomia::getDatabaseFile("GiBleed", overwrite = FALSE)
path <- gsub("\\\\", "/", path)

# 2. Load into DuckDB via the sqlite scanner (preserves DATE columns)
con <- DBI::dbConnect(duckdb::duckdb())
DBI::dbExecute(con, "INSTALL sqlite"); DBI::dbExecute(con, "LOAD sqlite")
DBI::dbExecute(con, sprintf("ATTACH '%s' AS s (TYPE sqlite)", path))

need <- c("person","observation_period","condition_occurrence","drug_exposure",
          "measurement","procedure_occurrence","visit_occurrence","death",
          "concept","concept_ancestor","cdm_source")
for (t in need) {
  DBI::dbExecute(con, sprintf("CREATE TABLE main.%s AS SELECT * FROM s.%s", t, t))
}
DBI::dbExecute(con, "DETACH s")

# 3. Pick a mid-prevalence condition as the seed (not universal, so the
#    complement comparator is non-empty).
seed <- DBI::dbGetQuery(con, "
  SELECT condition_concept_id AS cid, COUNT(DISTINCT person_id) AS n
  FROM main.condition_occurrence WHERE condition_concept_id <> 0
  GROUP BY 1 HAVING COUNT(DISTINCT person_id) BETWEEN 200 AND 1500
  ORDER BY n DESC LIMIT 1")
seed_id <- as.integer(seed$cid)
seed_nm <- DBI::dbGetQuery(con, sprintf(
  "SELECT concept_name FROM main.concept WHERE concept_id = %d", seed_id))$concept_name
cat(sprintf("Eunomia GiBleed: %d patients; seed concept %d (%s), %d patients\n",
            DBI::dbGetQuery(con,"SELECT COUNT(*) n FROM main.person")$n,
            seed_id, ifelse(length(seed_nm), seed_nm, "?"), seed$n))

# 4. Instantiate target (id 1) + complement comparator (id 2)
DBI::dbExecute(con, "CREATE TABLE rwe_cohort (subject_id BIGINT, cohort_definition_id INT,
                     cohort_start_date DATE, cohort_end_date DATE)")
DBI::dbExecute(con, sprintf("
  INSERT INTO rwe_cohort
  SELECT person_id, 1, MIN(condition_start_date), MAX(condition_end_date)
  FROM main.condition_occurrence
  WHERE condition_concept_id IN (
    SELECT descendant_concept_id FROM main.concept_ancestor WHERE ancestor_concept_id = %d)
  GROUP BY person_id", seed_id))
DBI::dbExecute(con, "
  INSERT INTO rwe_cohort
  SELECT person_id, 2, MIN(condition_start_date), MAX(condition_end_date)
  FROM main.condition_occurrence
  WHERE person_id NOT IN (SELECT subject_id FROM rwe_cohort WHERE cohort_definition_id = 1)
  GROUP BY person_id")
print(DBI::dbGetQuery(con,
  "SELECT cohort_definition_id, COUNT(*) n FROM rwe_cohort GROUP BY 1 ORDER BY 1"))

# 5. Validate (single-schema: clinical + vocab both in 'main')
out <- validate_cohort(
  cdm_schema   = "main", cohort_table = "rwe_cohort", cohort_id = 1,
  comparator_id = 2, concept_ids = seed_id, concept_domain = "condition",
  vocab_schema = "main", output_dir = out_dir, con = con,
  render_html = TRUE, quiet = TRUE)

cat("\n=== Eunomia validation result ===\n")
cat("data_source:\n"); str(out$results$data_source)
cat("\ncheck_summary:\n"); print(out$report$check_summary)
cat("\nHTML:", out$report$html, "size:", file.size(out$report$html), "\n")

DBI::dbDisconnect(con, shutdown = TRUE)
