# Package index

## Entry point

One call that runs the whole validation pipeline and writes the report.

- [`validate_cohort()`](validate_cohort.md) : Validate a patient cohort
  for real-world-evidence use

## Connection

Open and close a CDM connection with table validation.

- [`cdm_connect()`](cdm_connect.md) : Connect to an OMOP CDM database
- [`cdm_disconnect()`](cdm_disconnect.md) : Disconnect from a CDM
  database

## Demo data

A small synthetic OMOP CDM in DuckDB for examples and trying the package
offline.

- [`example_cdm()`](example_cdm.md) : Create a small in-memory OMOP CDM
  for examples and demos

## Validation modules

The four checks, callable individually.

- [`run_concepts()`](run_concepts.md) : Module 1 - Concept Coverage
- [`run_attrition()`](run_attrition.md) : Module 2 - Cohort Attrition
  Audit
- [`run_density()`](run_density.md) : Module 3 - Temporal Data Density
- [`run_covariates()`](run_covariates.md) : Module 4 - Covariate
  Feasibility

## Reporting

Render the HTML report, write the JSON sidecar, and build the summary.

- [`render_validation_report()`](render_validation_report.md) : Render
  the validation report (HTML) and write the JSON sidecar
- [`write_results_json()`](write_results_json.md) : Write the JSON
  sidecar (no rendering)
- [`build_check_summary()`](build_check_summary.md) : Build the
  traffic-light validation summary table
- [`classify_status()`](classify_status.md) : Classify a vector of
  module flags into a traffic-light status
