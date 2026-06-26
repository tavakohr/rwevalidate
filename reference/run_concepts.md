# Module 1 - Concept Coverage

Profiles whether the cohort-defining concepts are present, well-mapped,
and richly represented in the CDM. Maps to FDA RWE Relevance (are the
data fit for the question?). This is the first module to read the
vocabulary schema.

## Usage

``` r
run_concepts(
  con,
  cdm_schema,
  cohort_table,
  cohort_id,
  concept_ids,
  domain = "condition",
  vocab_schema = "vocab",
  prevalence_warn_pct = 10,
  prevalence_fail_pct = 1,
  unmapped_warn_pct = 20
)
```

## Arguments

- con:

  A live `DBI` connection (see [`cdm_connect()`](cdm_connect.md)).

- cdm_schema:

  Schema holding the clinical CDM tables.

- cohort_table:

  Cohort table, schema-qualified (currently unused; reserved for
  cohort-restricted prevalence in a later version).

- cohort_id:

  Integer cohort definition id (reserved, see `cohort_table`).

- concept_ids:

  Numeric vector of cohort-defining seed concept id(s). Their
  descendants are expanded via `{vocab_schema}.concept_ancestor`.

- domain:

  Domain the seed concepts live in; one of the names of the internal
  domain map (`"condition"`, `"drug"`, `"measurement"`, `"procedure"`).
  Default `"condition"`.

- vocab_schema:

  Schema holding the vocabulary tables. Default `"vocab"`.

- prevalence_warn_pct, prevalence_fail_pct:

  Concept-prevalence thresholds (percent of CDM persons with at least
  one descendant record). Below warn flags `WARN`, below fail flags
  `FAIL`. Defaults 10 and 1.

- unmapped_warn_pct:

  Per-domain unmapped-record threshold (percent mapped to
  `concept_id = 0`) above which a `WARN` is flagged. Default 20.

## Value

A named list:

- prevalence:

  data.frame: `n_with`, `n_total`, `pct`

- ancestor_coverage:

  data.frame: `total_descendants`, `present_descendants`, `pct_present`

- mapping_by_domain:

  data.frame: `domain`, `n_records`, `n_unmapped`, `pct_mapped`

- flags:

  character vector of `WARN:`/`FAIL:` messages
