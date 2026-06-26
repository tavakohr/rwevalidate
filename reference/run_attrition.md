# Module 2 - Cohort Attrition Audit

Profiles an instantiated cohort: size, index-date distribution, prior
observation coverage, and demographics at index. Maps to HARPER section
5 and RECORD-PE item 6. All thresholds are arguments.

## Usage

``` r
run_attrition(
  con,
  cdm_schema,
  cohort_table,
  cohort_id,
  obs_window = c(-365, 0),
  vocab_schema = "vocab",
  obs_warn_pct = 70,
  obs_fail_pct = 50,
  attrition_warn_threshold = 0.5
)
```

## Arguments

- con:

  A live `DBI` connection (see [`cdm_connect()`](cdm_connect.md)).

- cdm_schema:

  Schema holding the clinical CDM tables (e.g. `"mimic_cdm"`).

- cohort_table:

  Cohort table, schema-qualified (e.g.
  `"results.rwevalidate_test_cohort"`). Must have columns `subject_id`,
  `cohort_definition_id`, `cohort_start_date`, `cohort_end_date`.

- cohort_id:

  Integer cohort definition id to profile.

- obs_window:

  Length-2 numeric `c(pre, post)` in days relative to index. The
  required prior-observation window is `abs(obs_window[1])` days
  (default 365).

- vocab_schema:

  Schema holding the vocabulary tables (`concept`). In this split-schema
  environment the clinical schema's `concept` table is empty, so the
  gender label is resolved from `vocab_schema`. Default `"vocab"`.

- obs_warn_pct, obs_fail_pct:

  Prior-observation coverage thresholds (percent of cohort with
  sufficient prior observation). Below `obs_warn_pct` flags `WARN`,
  below `obs_fail_pct` flags `FAIL`. Defaults 70 and 50.

- attrition_warn_threshold:

  Reserved for stepwise inclusion-criteria attrition (single-criterion
  drop fraction). Not exercised in v0.1 because criteria lists are not
  yet a supported input. Default 0.5.

## Value

A named list:

- cohort_size:

  integer - distinct subjects in the cohort

- index_date_summary:

  data.frame of `index_year`, `n`

- obs_coverage:

  data.frame: `cohort_n`, `n_sufficient`, `pct_sufficient`,
  `min_prior_days`

- demographics:

  data.frame: `sex`, `mean_age`, `min_age`, `max_age`, `n`

- flags:

  character vector of `WARN:`/`FAIL:` messages (empty if all pass)
