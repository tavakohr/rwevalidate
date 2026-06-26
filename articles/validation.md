# Validation: cohorts, datasets, and methodology

This article documents how `rwevalidate` was validated before release:
the cohorts and datasets used, the results, and the **method to
reproduce them**. No patient-level data is included; MIMIC-IV is
credentialed and is not distributed with the package. Only the procedure
and the cohort-defining seed concepts are recorded, so the validation
can be re-run by anyone with access to the same data.

## Datasets

| Dataset | Source | CDM | Patients | Role |
|----|----|----|----|----|
| `mimic_cdm` | MIMIC-IV (real ICU) | v5.3.1 | 100 | domain/edge battery |
| `mimiciv_omop` | MIMIC-IV (real) | v5.4 | 5,000 | gold-phenotype validation |
| Eunomia / GiBleed | Synthea (synthetic) | v5.3.1 | 2,694 | independent cross-dataset |

MIMIC-IV requires PhysioNet credentialing; both MIMIC builds are local.
Eunomia is public and downloads on demand via the `Eunomia` package.

## Tier 1 - domain battery (100-patient CDM)

Cohorts spanning every index domain plus an empty-cohort edge case, each
run through [`validate_cohort()`](../reference/validate_cohort.md) with
a complement comparator. All ran without error; the empty cohort aborts
with a clear message (the intended guard).

``` r

kbl(data.frame(
  cohort = c("Heart failure","Atrial fibrillation","Obesity","Acetaminophen",
             "Oxycodone","Mech ventilation","CBC lymphocytes","Empty (edge)"),
  domain = c("condition","condition","condition","drug","drug","procedure",
             "measurement","condition"),
  n = c(25,30,20,89,64,45,91,0),
  status = c(rep("ok",7),"handled-error")
))
```

| cohort              | domain      |   n | status        |
|:--------------------|:------------|----:|:--------------|
| Heart failure       | condition   |  25 | ok            |
| Atrial fibrillation | condition   |  30 | ok            |
| Obesity             | condition   |  20 | ok            |
| Acetaminophen       | drug        |  89 | ok            |
| Oxycodone           | drug        |  64 | ok            |
| Mech ventilation    | procedure   |  45 | ok            |
| CBC lymphocytes     | measurement |  91 | ok            |
| Empty (edge)        | condition   |   0 | handled-error |

## Tier 2 - gold-standard OHDSI phenotypes (5,000-patient CDM)

Five cohorts from the **OHDSI Phenotype Library** (via the sibling
`omop-phenotype-pipeline` project) instantiated on `mimiciv_omop`. All
four modules ran on cohorts of 481-849 patients.

``` r

kbl(data.frame(
  phenotype = c("Type 2 diabetes","Cardiac valve + AF","Acute liver injury",
                "Drug-induced pancreatitis","Treatment-resistant depression"),
  cohort_id = c(288, 1103, 736, 253, 1009),
  n_target = c(645, 481, 849, 485, 775),
  status = "ok (4 checks)"
))
```

| phenotype                      | cohort_id | n_target | status        |
|:-------------------------------|----------:|---------:|:--------------|
| Type 2 diabetes                |       288 |      645 | ok (4 checks) |
| Cardiac valve + AF             |      1103 |      481 | ok (4 checks) |
| Acute liver injury             |       736 |      849 | ok (4 checks) |
| Drug-induced pancreatitis      |       253 |      485 | ok (4 checks) |
| Treatment-resistant depression |      1009 |      775 | ok (4 checks) |

## Tier 3 - independent synthetic source (Eunomia)

The same tool on Eunomia/GiBleed returns a **data-appropriate** traffic
light: attrition passes (full longitudinal histories) where MIMIC fails
(ICU-short windows), and power is adequate at large N. Evidence the
checks reflect real data characteristics rather than fixed output.

## Reproducing the validation

The harness scripts live in `data-raw/` of the source repository
(`run_battery.R`, `run_phenotypes.R`, `run_eunomia.R`). They are not
part of the installed package. The steps below are the method.

### 1. Connect (split-schema)

Production CDMs usually keep the vocabulary in a separate schema.
[`cdm_connect()`](../reference/cdm_connect.md) validates clinical tables
in `cdm_schema` and vocabulary tables in `vocab_schema`.

``` r

con <- cdm_connect(
  dbname = "FHIR", user = "...", password = "...",
  cdm_schema = "mimiciv_omop",   # clinical
  vocab_schema = "vocab"          # concept, concept_ancestor
)
```

### 2. Derive `observation_period` (if absent)

The `mimiciv_omop` build ships without `observation_period`. Derive one
row per person spanning their first to last dated event across clinical
domains:

``` r

DBI::dbExecute(con, "
  CREATE TABLE mimiciv_omop.observation_period AS
  SELECT ROW_NUMBER() OVER (ORDER BY person_id) AS observation_period_id,
         person_id,
         MIN(d) AS observation_period_start_date,
         MAX(d) AS observation_period_end_date,
         44814724 AS period_type_concept_id
  FROM (
    SELECT person_id, condition_start_date d FROM mimiciv_omop.condition_occurrence
    UNION ALL SELECT person_id, drug_exposure_start_date FROM mimiciv_omop.drug_exposure
    UNION ALL SELECT person_id, measurement_date FROM mimiciv_omop.measurement
    UNION ALL SELECT person_id, procedure_date FROM mimiciv_omop.procedure_occurrence
    UNION ALL SELECT person_id, visit_start_date FROM mimiciv_omop.visit_occurrence
  ) e WHERE d IS NOT NULL GROUP BY person_id")
```

### 3. Instantiate a cohort (OHDSI concept-set method)

For each phenotype, expand the gold **seed** concepts to descendants via
`concept_ancestor`, remove the **excluded** descendants, and index on
the first qualifying event across domains. `subject_id` is `NUMERIC`
because `mimiciv_omop` person ids exceed `bigint`.

``` r

DBI::dbExecute(con, "
  INSERT INTO results.phenotype_cohorts
  SELECT person_id, 288 AS cohort_definition_id, MIN(d), MAX(d) FROM (
    SELECT person_id, condition_start_date d FROM mimiciv_omop.condition_occurrence
     WHERE condition_concept_id IN (
       SELECT descendant_concept_id FROM vocab.concept_ancestor
        WHERE ancestor_concept_id IN ( /* gold seeds */ )
          AND descendant_concept_id NOT IN (
            SELECT descendant_concept_id FROM vocab.concept_ancestor
             WHERE ancestor_concept_id IN ( /* excluded */ )))
    /* UNION ALL the drug/measurement/procedure domains likewise */
  ) e GROUP BY person_id")
```

### 4. Seeds used (replicable)

The exact seed and excluded concept ids for all five phenotypes ship
with the package and can be read back:

``` r

seeds <- read.csv(system.file("extdata", "phenotype_seeds.csv",
                              package = "rwevalidate"))
kbl(seeds[, c("cohort_id", "phenotype", "n_seed", "n_excluded")])
```

| cohort_id | phenotype          | n_seed | n_excluded |
|----------:|:-------------------|-------:|-----------:|
|       288 | t2dm               |     17 |          6 |
|      1103 | cardiac_valve_af   |    181 |          0 |
|       736 | acute_liver_injury |     30 |          9 |
|       253 | drug_pancreatitis  |     31 |          2 |
|      1009 | trd                |     69 |         15 |

``` r

# Example: the Type 2 diabetes seed concept ids
strsplit(seeds$seed_concept_ids[seeds$phenotype == "t2dm"], ";")[[1]]
#>  [1] "443238"   "201820"   "442793"   "195771"   "37392407" "4184637" 
#>  [7] "40484649" "42689695" "765533"   "43531006" "765650"   "45770986"
#> [13] "201254"   "45768456" "40484648" "4128019"  "435216"
```

The authoritative cohort definitions are the OHDSI Phenotype Library
entries for cohort ids 288, 1103, 736, 253, and 1009
(<https://github.com/OHDSI/PhenotypeLibrary>). Only the numeric seed ids
are recorded here, for reproducibility; the definitions themselves are
not copied.

### 5. Validate

``` r

validate_cohort(
  cdm_schema   = "mimiciv_omop",
  cohort_table = "results.phenotype_cohorts",
  cohort_id    = 288,
  comparator_id = 10288,           # complement
  concept_ids  = c(443238, 201820, 442793),  # seeds -> Module 1
  concept_domain = "condition",
  vocab_schema = "vocab",
  output_dir   = "./validation_report"
)
```

## Machine-readable results

Summary tables ship under `inst/extdata/`:

``` r

list.files(system.file("extdata", package = "rwevalidate"))
#> [1] "phenotype_seeds.csv"    "phenotype_summary.csv"  "robustness_summary.csv"
```
