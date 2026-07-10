# cran-comments

## Resubmission

This is a resubmission (version 0.1.1) addressing the review comments of
2026-07-10 (Konstanze Lauseker). Thank you for the review.

1. **Acronyms in the Description.** All acronyms are now explained at first
   use in the Description text: Observational Medical Outcomes Partnership
   (OMOP), Common Data Model (CDM), real-world evidence (RWE), Hypertext
   Markup Language (HTML), JavaScript Object Notation (JSON), United States
   Food and Drug Administration (FDA), HARmonized Protocol Template to
   Enhance Reproducibility (HARPER), and REporting of studies Conducted
   using Observational Routinely collected Data for PharmacoEpidemiology
   (RECORD-PE).

2. **Reference format.** References in the Description are now written as
   authors (year) <doi:...> with the year in parentheses:
   FDA (2023) <https://www.fda.gov/media/171667/download>,
   Wang and others (2022) <doi:10.1002/pds.5507>, and
   Langan and others (2018) <doi:10.1136/bmj.k3532>.

3. **\dontrun{} usage.** The \dontrun{} example in validate_cohort() has been
   removed; the function's remaining example is executable and runs during
   checks against a small in-memory DuckDB CDM built by the exported
   example_cdm() helper (no external database or credentials needed). The
   equivalent live-database call is shown as illustrative code in the
   function's Details section. A single \dontrun{} example remains, in
   cdm_connect(): this function opens a connection to a live PostgreSQL
   server and genuinely cannot be executed without a running server and real
   credentials. \donttest{} is not possible here because \donttest examples
   are executed during CRAN incoming checks and would fail without a
   database. A new executable example (using the DuckDB example CDM) was
   added to cdm_disconnect(), so every function that can be demonstrated
   without a database server now has a runnable example.

## Submission summary

The package validates an instantiated OMOP CDM patient cohort for real-world
evidence use and writes an HTML and JSON report.

## R CMD check results

0 errors | 0 warnings | 1 note.

The note is the standard "New submission" note, together with one sub-item
that is a false positive:

* Possibly misspelled words in DESCRIPTION: "comparator" and author surnames
  such as "Langan". These are correct: "comparator" is the standard
  epidemiological term for the reference arm, and "Langan" is an author
  surname in a cited reference. All acronyms flagged previously (OMOP, CDM,
  RWE) are now expanded at first use.

## Examples

The only example wrapped in \dontrun{} is cdm_connect(), which requires a
live PostgreSQL server and credentials (see Resubmission point 3). All other
exported functions have executable examples that run during the check against
an in-memory DuckDB CDM via the exported example_cdm() helper. The test suite
exercises every module the same way.

## Test environments

* Local: Windows 11, R 4.4.2
* GitHub Actions: Ubuntu (release, devel, oldrel), macOS (release),
  Windows (release)

## Reverse dependencies

None. This is a new package.
