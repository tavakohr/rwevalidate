# Changelog

## rwevalidate 0.1.2

CRAN resubmission addressing a second review comment; no functional
changes.

- DESCRIPTION: write the HARPER and RECORD-PE framework names in normal
  capitalization (“Harmonized…”, “Reporting…”, “Pharmacoepidemiology”)
  instead of the mixed-case styling that the CRAN spell check flagged.
  The acronyms remain in parentheses.

## rwevalidate 0.1.1

CRAN resubmission addressing reviewer feedback; no functional changes.

- DESCRIPTION: all acronyms (OMOP, CDM, RWE, HTML, JSON, FDA, HARPER,
  RECORD-PE) are now explained at first use, and references follow the
  `authors (year) <doi:...>` format.
- Removed the `\dontrun{}` example from
  [`validate_cohort()`](../reference/validate_cohort.md); the
  live-database call is now shown in the function’s Details section.
- Added an executable example to
  [`cdm_disconnect()`](../reference/cdm_disconnect.md). The only
  remaining `\dontrun{}` example is
  [`cdm_connect()`](../reference/cdm_connect.md), which requires a live
  PostgreSQL server and credentials.
- Expanded the Title to spell out “OMOP Common Data Model”.
- [`example_cdm()`](../reference/example_cdm.md) now builds a 20-person,
  two-arm demo CDM (target and comparator), so every exported module —
  including [`run_covariates()`](../reference/run_covariates.md) — has a
  runnable example against the bundled database.
- Added `@examples` to
  [`run_attrition()`](../reference/run_attrition.md),
  [`run_density()`](../reference/run_density.md),
  [`run_concepts()`](../reference/run_concepts.md), and
  [`run_covariates()`](../reference/run_covariates.md).

## rwevalidate 0.1.0

First public release. `rwevalidate` validates an instantiated OMOP CDM
cohort for real-world-evidence use and produces a regulator-aligned
HTML + JSON report from a single
[`validate_cohort()`](../reference/validate_cohort.md) call.

### Features

- **[`cdm_connect()`](../reference/cdm_connect.md) /
  [`cdm_disconnect()`](../reference/cdm_disconnect.md)** - open a
  PostgreSQL CDM connection and validate that the required clinical
  tables exist (split-schema aware).
- **Module 1 - [`run_concepts()`](../reference/run_concepts.md)** -
  concept prevalence, ancestor coverage, and per-domain vocabulary
  mapping rate (FDA Relevance).
- **Module 2 - [`run_attrition()`](../reference/run_attrition.md)** -
  cohort size, index-date distribution, prior-observation coverage, and
  demographics at index (HARPER / RECORD-PE).
- **Module 3 - [`run_density()`](../reference/run_density.md)** -
  records per patient per month by domain and follow-up completeness
  with a censoring breakdown (FDA Reliability).
- **Module 4 - [`run_covariates()`](../reference/run_covariates.md)** -
  standardized mean differences (love plot), per-arm prevalence, and a
  power calculation against a comparator (HARPER).
- **Reporting** -
  [`render_validation_report()`](../reference/render_validation_report.md)
  writes a self-contained HTML report with a traffic-light summary plus
  a machine-readable `validation_results.json` sidecar;
  [`write_results_json()`](../reference/write_results_json.md) works
  without Pandoc.
- **[`validate_cohort()`](../reference/validate_cohort.md)** - one entry
  point that wires connection, all modules, and the report. Accepts an
  open `con` or PostgreSQL connection arguments; `concept_ids` enables
  Module 1, `comparator_id` enables Module 4.

### Notes

- Targets OMOP CDM v5.3.1. Validated against MIMIC-IV on PostgreSQL and
  a synthetic DuckDB mock used by the test suite.
- No dependency on CohortDiagnostics, DataQualityDashboard, or Achilles.
- All thresholds are documented, configurable function arguments.
