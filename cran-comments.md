## Submission summary

This is the first submission of rwevalidate. The package validates an
instantiated OMOP CDM patient cohort for real-world evidence use and writes an
HTML and JSON report.

## R CMD check results

0 errors | 0 warnings | 2 notes, on local Windows (R 4.4.2).

The two notes are both about the local environment, not the package:

* "New submission" is expected for a first release.
* "unable to verify current time" comes from the check machine having no
  network time source.

A local run also reported the optional "qpdf is needed for checks on size
reduction of PDFs" note. That is a missing local tool, not a package issue, and
does not appear on the CRAN check machines that have qpdf installed.

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
