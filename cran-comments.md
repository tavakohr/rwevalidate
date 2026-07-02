## Submission summary

This is the first submission of rwevalidate. The package validates an
instantiated OMOP CDM patient cohort for real-world evidence use and writes an
HTML and JSON report.

## R CMD check results

On win-builder (R-release 4.6.1 and R-devel): 0 errors | 0 warnings | 1 note.

The note is the standard "New submission" note, together with two sub-items that
are false positives:

* Possibly misspelled words in DESCRIPTION: "CDM", "OMOP", "RWE", "comparator",
  and "Langan". These are correct. "OMOP" and "CDM" are the OMOP Common Data
  Model and its abbreviation, "RWE" is real-world evidence, "comparator" is the
  standard epidemiological term for the reference arm, and "Langan" is an author
  surname in a cited reference.

A local Windows run additionally reported "unable to verify current time" (no
network time source on that machine) and "qpdf is needed for checks on size
reduction of PDFs" (qpdf not installed locally). Neither appears on the CRAN or
win-builder machines.

## Examples

All examples that need a live OMOP CDM database connection are wrapped in
\dontrun{}, because they require credentials and a populated database that
cannot be provided during a check. The package is fully exercised without a live
database by the test suite, which runs every module against an in-memory DuckDB
mock of a small synthetic CDM.

## Test environments

* Local: Windows 11, R 4.4.2
* GitHub Actions: Ubuntu (release, devel, oldrel), macOS (release),
  Windows (release)

## Reverse dependencies

None. This is a new package.
