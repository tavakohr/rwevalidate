# cran-comments

## Resubmission

This is a resubmission (version 0.1.2) addressing Uwe Ligges's comment of
2026-07-11 on version 0.1.1. Thank you for the review.

The three mixed-case fragments flagged in the Description ("HARmonized",
"REporting", "PharmacoEpidemiology") have been rewritten in normal
capitalization: "the Harmonized Protocol Template to Enhance Reproducibility
(HARPER)" and "the Reporting of Studies Conducted Using Observational
Routinely-Collected Data for Pharmacoepidemiology (RECORD-PE) statement". The
acronyms themselves remain in parentheses, so the Description still explains
them, and the spell check no longer flags the expansions.

The earlier review of 2026-07-10 (Konstanze Lauseker) is still addressed:
all acronyms are explained at first use, the references use the
authors (year) <doi:...> form, and only cdm_connect() keeps a \dontrun{}
example (it requires a live PostgreSQL server; every other exported function
has a runnable example against the bundled DuckDB example CDM).

## Submission summary

The package validates an instantiated OMOP CDM patient cohort for real-world
evidence use and writes an HTML and JSON report.

## R CMD check results

Local (Windows 11, R 4.6.0), R CMD check --as-cran: 0 errors | 0 warnings |
0 notes.

The only remaining note is the standard "New submission" note, together with
one sub-item that is a false positive:

* Possibly misspelled words in DESCRIPTION: "CDM", "OMOP", "RWE",
  "comparator", and "Langan". These are all correct: OMOP, CDM, and RWE are
  the abbreviations that the Description expands at first use; "comparator" is
  the standard epidemiological term for the reference arm; and "Langan" is an
  author surname in a cited reference.

## Examples

The only example wrapped in \dontrun{} is cdm_connect(), which requires a
live PostgreSQL server and credentials (see Resubmission point 3). All other
exported functions have executable examples that run during the check against
an in-memory DuckDB CDM via the exported example_cdm() helper. The test suite
exercises every module the same way.

## Test environments

* Local: Windows 11, R 4.6.0
* GitHub Actions: Ubuntu (release, devel, oldrel), macOS (release),
  Windows (release)

## Reverse dependencies

None. This is a new package.
