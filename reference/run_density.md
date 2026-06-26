# Module 3 - Temporal Data Density

Profiles longitudinal data accrual around the index date: record density
per patient per month across clinical domains, and follow-up
completeness with a censoring-reason breakdown. Maps to FDA RWE
Reliability (data accrual).

## Usage

``` r
run_density(
  con,
  cdm_schema,
  cohort_table,
  cohort_id,
  obs_window = c(-365, 365),
  sparse_warn_min = 1
)
```

## Arguments

- con:

  A live `DBI` connection (see [`cdm_connect()`](cdm_connect.md)).

- cdm_schema:

  Schema holding the clinical CDM tables (e.g. `"mimic_cdm"`).

- cohort_table:

  Cohort table, schema-qualified.

- cohort_id:

  Integer cohort definition id.

- obs_window:

  Length-2 numeric `c(pre, post)` in days relative to index. Density is
  computed for records inside `[index + pre, index + post]`. Default
  `c(-365, 365)`.

- sparse_warn_min:

  Minimum total records a domain must have within the window before it
  is considered present; domains below this flag `WARN` (likely
  missing/sparse domain). Default 1 (flag only truly empty domains).

## Value

A named list:

- density_by_domain:

  data.frame: `domain`, `months_from_index`, `n_patients`, `n_records`,
  `records_per_patient`

- followup_summary:

  data.frame: one row per `censoring_reason` with `n` and
  `median_followup_days` (median over that group)

- followup_detail:

  per-subject data.frame: `subject_id`, `effective_end_date`,
  `followup_days`, `censoring_reason`

- flags:

  character vector of `WARN:`/`FAIL:` messages
