# Getting started with rwevalidate

`rwevalidate` validates an **already-instantiated** patient cohort on an
OMOP CDM database for real-world-evidence (RWE) use, and produces a
structured HTML + JSON report aligned with FDA RWE guidance (Relevance
and Reliability) and the HARPER protocol framework. It does **not**
generate cohorts – the cohort definition (SQL or ATLAS) stays upstream.

The code below is not executed when the vignette is built (it needs a
live database); it is the exact sequence you would run against your own
CDM.

## Try it without a database

Before pointing the package at a real CDM, you can see it run end to end
on a small synthetic one. [`example_cdm()`](../reference/example_cdm.md)
builds a tiny OMOP CDM (10 patients, one heart-failure cohort) in an
in-memory DuckDB database and returns a live connection. This is the
only chunk in this article that actually runs, and it needs the `duckdb`
package.

``` r

library(rwevalidate)

con <- example_cdm()

out <- validate_cohort(
  cdm_schema   = "main",
  cohort_table = "cohort",
  cohort_id    = 1,
  con          = con,
  vocab_schema = "main",
  output_dir   = tempfile("rwe_demo_"),
  render_html  = FALSE
)
#> ℹ Running attrition audit (Module 2)...
#> ℹ Running temporal data density (Module 3)...
#> Module 1 (concept coverage) skipped; supply `concept_ids` to enable.
#> Module 4 (covariate feasibility) skipped; supply `comparator_id` to enable.
#> ✔ Validation complete: 0 fail, 0 warn across 2 checks.

out$report$check_summary
#>                 section status                         maps_to
#> 1      Cohort Attrition   pass HARPER Sec.5 / RECORD-PE Item 6
#> 2 Temporal Data Density   pass  FDA Reliability - data accrual
#>               detail
#> 1 All checks passed.
#> 2 All checks passed.
cdm_disconnect(con)
```

The fixture is entirely synthetic and contains no real patient data.
Everything below shows how to run the same call against your own OMOP
CDM.

## 1. Connect

[`cdm_connect()`](../reference/cdm_connect.md) opens a PostgreSQL
connection and verifies the required clinical tables exist in
`cdm_schema` before returning.

``` r

library(rwevalidate)

con <- cdm_connect(
  host       = "localhost",
  port       = 5432,
  dbname     = "your_db",
  user       = "your_user",
  password   = "your_password",
  cdm_schema = "mimic_cdm"
)
```

Many CDM builds are **split-schema**: clinical tables in one schema and
the vocabulary (`concept`, `concept_ancestor`) in another. Pass the
vocabulary schema via `vocab_schema` (default `"vocab"`).

## 2. Instantiate a cohort (upstream)

`rwevalidate` reads a cohort table with the columns `subject_id`,
`cohort_definition_id`, `cohort_start_date`, `cohort_end_date`. For
example, a heart-failure cohort using SNOMED concept 316139 and its
descendants:

``` r

DBI::dbExecute(con, "
  CREATE TABLE results.my_cohort AS
  SELECT person_id AS subject_id, 1 AS cohort_definition_id,
         MIN(condition_start_date) AS cohort_start_date,
         MAX(condition_end_date)   AS cohort_end_date
  FROM mimic_cdm.condition_occurrence
  WHERE condition_concept_id IN (
    SELECT descendant_concept_id FROM vocab.concept_ancestor
    WHERE ancestor_concept_id = 316139)
  GROUP BY person_id")
```

## 3. Validate in one call

[`validate_cohort()`](../reference/validate_cohort.md) runs the modules
and writes the report. Supply an open `con` or the connection arguments
directly.

``` r

results <- validate_cohort(
  cdm_schema    = "mimic_cdm",
  cohort_table  = "results.my_cohort",
  cohort_id     = 1,
  concept_ids   = 316139,   # enables Module 1 (concept coverage)
  comparator_id = 2,        # enables Module 4 (covariate feasibility)
  vocab_schema  = "vocab",
  output_dir    = "./validation_report",
  con           = con
)
```

This writes `validation_report.html` and `validation_results.json` to
`output_dir`, and returns a list with `results` (per-module output),
`report` (paths + traffic-light summary), and `flags`.

``` r

results$report$check_summary   # one row per check: pass / warn / fail
results$flags                  # all WARN:/FAIL: messages
```

## 4. Run modules individually

Each module is also callable on its own when you only need one view.

``` r

run_attrition(con, "mimic_cdm", "results.my_cohort", cohort_id = 1,
              vocab_schema = "vocab")

run_density(con, "mimic_cdm", "results.my_cohort", cohort_id = 1)

run_concepts(con, "mimic_cdm", "results.my_cohort", cohort_id = 1,
             concept_ids = 316139, vocab_schema = "vocab")

run_covariates(con, "mimic_cdm", "results.my_cohort", cohort_id = 1,
               comparator_id = 2, vocab_schema = "vocab")
```

## 5. Interpreting the traffic light

Every check returns `"pass"` (green), `"warn"` (amber), or `"fail"`
(red). Thresholds are documented arguments – for example
prior-observation coverage warns below 70% and fails below 50%, and
covariates with `|SMD| > 0.1` are flagged as imbalanced. Tune them to
your study’s requirements.

``` r

cdm_disconnect(con)
```
