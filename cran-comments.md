# cran-comments

## Resubmission

Thanks very much for the quick review. This is version 0.1.2, and it fixes the
three words you flagged in the Description.

I rewrote the two framework names so they no longer use the mixed-case styling
that the spell check picked up. "HARmonized Protocol Template to Enhance
Reproducibility" is now "Harmonized Protocol Template to Enhance
Reproducibility (HARPER)", and "REporting of studies ... for
PharmacoEpidemiology" is now "Reporting of Studies Conducted Using
Observational Routinely-Collected Data for Pharmacoepidemiology (RECORD-PE)".
Each acronym still appears in parentheses, so the Description continues to
spell it out, and the spell check is now clean.

Everything from the first review still holds. Every acronym is explained the
first time it appears, the references use the authors (year) <doi:...> form,
and cdm_connect() is the only example left in \dontrun{}, because it needs a
live PostgreSQL server. Every other exported function has an example that runs
during the check against the small DuckDB database the package ships with.

## Submission summary

The package checks an existing OMOP CDM patient cohort for real-world evidence
use and writes an HTML and JSON report.

## R CMD check results

Local (Windows 11, R 4.6.0), R CMD check --as-cran: 0 errors | 0 warnings |
0 notes.

The one remaining note is the usual "New submission" note. It also lists a few
words as possibly misspelled in the Description ("CDM", "OMOP", "RWE",
"comparator", and "Langan"), but all of them are correct: OMOP, CDM, and RWE
are the abbreviations the Description spells out at first use, "comparator" is
the usual epidemiology term for the reference arm, and "Langan" is an author
name in one of the references.

## Examples

cdm_connect() is the only example wrapped in \dontrun{}, since it needs a live
PostgreSQL server and credentials. Every other exported function has an example
that runs during the check, using the in-memory DuckDB CDM from the
example_cdm() helper. The tests cover every module the same way.

## Test environments

* Local: Windows 11, R 4.6.0
* GitHub Actions: Ubuntu (release, devel, oldrel), macOS (release),
  Windows (release)

## Reverse dependencies

None. This is a new package.
