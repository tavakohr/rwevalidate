# rwevalidate 0.1.0

First public release. `rwevalidate` validates an instantiated OMOP CDM cohort
for real-world-evidence use and produces a regulator-aligned HTML + JSON report
from a single `validate_cohort()` call.

## Features

* **`cdm_connect()` / `cdm_disconnect()`** - open a PostgreSQL CDM connection and
  validate that the required clinical tables exist (split-schema aware).
* **Module 1 - `run_concepts()`** - concept prevalence, ancestor coverage, and
  per-domain vocabulary mapping rate (FDA Relevance).
* **Module 2 - `run_attrition()`** - cohort size, index-date distribution,
  prior-observation coverage, and demographics at index (HARPER / RECORD-PE).
* **Module 3 - `run_density()`** - records per patient per month by domain and
  follow-up completeness with a censoring breakdown (FDA Reliability).
* **Module 4 - `run_covariates()`** - standardized mean differences (love plot),
  per-arm prevalence, and a power calculation against a comparator (HARPER).
* **Reporting** - `render_validation_report()` writes a self-contained HTML
  report with a traffic-light summary plus a machine-readable
  `validation_results.json` sidecar; `write_results_json()` works without Pandoc.
* **`validate_cohort()`** - one entry point that wires connection, all modules,
  and the report. Accepts an open `con` or PostgreSQL connection arguments;
  `concept_ids` enables Module 1, `comparator_id` enables Module 4.

## Notes

* Targets OMOP CDM v5.3.1. Validated against MIMIC-IV on PostgreSQL and a
  synthetic DuckDB mock used by the test suite.
* No dependency on CohortDiagnostics, DataQualityDashboard, or Achilles.
* All thresholds are documented, configurable function arguments.
