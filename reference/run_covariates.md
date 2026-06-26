# Module 4 - Covariate Feasibility

Compares a target cohort against a comparator on baseline covariates:
standardized mean differences (SMD love-plot data), a per-arm prevalence
table, and a simple power calculation. Maps to HARPER Sec.4
(comparability). Runs only when a `comparator_id` is supplied.

## Usage

``` r
run_covariates(
  con,
  cdm_schema,
  cohort_table,
  cohort_id,
  comparator_id,
  vocab_schema = "vocab",
  covariate_window = c(-365, 0),
  top_n = 20,
  smd_warn_threshold = 0.1,
  power_baseline_rate = 0.15,
  power_effect_rate = 0.3,
  power_sig_level = 0.05
)
```

## Arguments

- con:

  A live `DBI` connection (see [`cdm_connect()`](cdm_connect.md)).

- cdm_schema:

  Schema holding the clinical CDM tables.

- cohort_table:

  Cohort table, schema-qualified, containing both arms.

- cohort_id:

  Integer cohort definition id of the target arm.

- comparator_id:

  Integer cohort definition id of the comparator arm.

- vocab_schema:

  Schema holding the vocabulary tables. Default `"vocab"`.

- covariate_window:

  Length-2 numeric `c(pre, post)` days defining the baseline window
  relative to index for comorbidity/drug covariates. Default
  `c(-365, 0)`.

- top_n:

  Number of top conditions/drugs to profile. Default 20.

- smd_warn_threshold:

  Absolute SMD above which a covariate is flagged imbalanced. Default
  0.1 (standard).

- power_baseline_rate, power_effect_rate:

  Assumed comparator and target event rates for the two-proportion power
  calculation. Defaults 0.15, 0.30.

- power_sig_level:

  Significance level for the power calculation. Default 0.05.

## Value

A named list: `smd_table`, `prevalence_table`, `power`, `flags`.
