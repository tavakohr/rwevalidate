# Contributing to rwevalidate

Thanks for your interest in improving `rwevalidate`. Bug reports,
feature ideas, and pull requests are all welcome.

## Reporting bugs and requesting features

Please open an issue at
<https://github.com/tavakohr/rwevalidate/issues>. For a bug, include
your R version, your operating system, and a small reproducible example
if you can.

## Development setup

You do not need a live PostgreSQL database to develop or test the
package. The test suite runs against a synthetic OMOP CDM built in an
in-memory DuckDB database, so `R CMD check` works offline.

``` r

# Install the development dependencies once
install.packages(c("devtools", "duckdb"))

# Run the test suite (uses the DuckDB mock)
devtools::test()

# Run the full package check
devtools::check()
```

You can also try the package by hand without any database using the
bundled demo CDM:

``` r

con <- rwevalidate::example_cdm()
rwevalidate::validate_cohort(
  cdm_schema = "main", cohort_table = "cohort", cohort_id = 1,
  con = con, vocab_schema = "main",
  output_dir = tempfile("rwe_demo_"), render_html = FALSE
)
rwevalidate::cdm_disconnect(con)
```

## Pull requests

1.  Fork the repository and create a branch for your change.
2.  Keep the change focused, and add or update tests under
    `tests/testthat/`.
3.  If you change a function’s documentation, regenerate the help files
    with `devtools::document()` (or `roxygen2::roxygenise()`).
4.  Make sure `devtools::check()` passes with no new errors, warnings,
    or notes.
5.  Open a pull request and describe what the change does and why.

## Continuous integration

Every push to `main` runs GitHub Actions that:

- run `R CMD check` on Ubuntu, macOS, and Windows,
- build a test-coverage report through Codecov, and
- build and deploy the `pkgdown` documentation site to
  <https://tavakohr.github.io/rwevalidate/>.

Your pull request runs the same `R CMD check` matrix, so you can see the
result before it is merged.
