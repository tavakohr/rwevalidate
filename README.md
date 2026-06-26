# rwevalidate

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/tavakohr/rwevalidate/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/tavakohr/rwevalidate/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/tavakohr/rwevalidate/graph/badge.svg)](https://app.codecov.io/gh/tavakohr/rwevalidate)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

Validate patient cohorts for real-world-evidence (RWE) studies on OMOP CDM data.

One function call produces a structured HTML + JSON validation report aligned with
FDA RWE guidance (Relevance + Reliability) and HARPER protocol requirements.

> **Status:** v0.1 core complete — attrition (Module 2), temporal density
> (Module 3), HTML + JSON report, and the `validate_cohort()` entry point.
> Concept coverage (Module 1) and covariate feasibility (Module 4) are v0.2.

## Installation

```r
# from a local clone
install.packages(".", repos = NULL, type = "source")
```

Requires R (>= 4.1) and the packages under `Imports` in `DESCRIPTION`.
HTML rendering needs Pandoc (bundled with RStudio; otherwise set
`RSTUDIO_PANDOC`). Without Pandoc the JSON sidecar is still written.

## Quick start — one call

```r
library(rwevalidate)

out <- validate_cohort(
  cdm_schema     = "mimic_cdm",                       # clinical schema
  cohort_table   = "results.rwevalidate_test_cohort",
  cohort_id      = 1,
  vocab_schema   = "vocab",                           # vocabulary schema (split-schema CDMs)
  obs_window     = c(-365, 0),                        # prior-observation window (attrition)
  density_window = c(-365, 365),                      # window for data density
  output_dir     = "./validation_report",
  # PostgreSQL connection args (omit if passing an open `con=`):
  host = "localhost", port = 5432,
  dbname = "<your_db>", user = "<your_user>", password = "<your_password>"
)

out$flags                  # collected WARN:/FAIL: messages
out$report$check_summary   # traffic-light table
# -> ./validation_report/validation_report.html  + validation_results.json
```

Already have a connection (e.g. a DuckDB test instance)? Pass it as `con=` and
it is left open for you. Lower-level helpers — `cdm_connect()`,
`run_attrition()`, `run_density()`, `render_validation_report()` — can also be
called directly.

## Scope

- **Cohort input:** instantiated cohort tables (no ATLAS JSON parsing in v0.1).
- **CDM version:** targets v5.3.1 (MIMIC-IV reference environment).
- **Split-schema aware:** clinical (`cdm_schema`) and vocabulary (`vocab_schema`)
  may live in separate schemas.
- **No OHDSI tool dependencies:** does not import CohortDiagnostics, DQD, or Achilles.
