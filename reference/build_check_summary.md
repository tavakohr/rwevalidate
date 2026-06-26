# Build the traffic-light validation summary table

Collects each module's flags into one row per validation section,
mapping to the regulatory framework the section addresses.

## Usage

``` r
build_check_summary(results)
```

## Arguments

- results:

  The combined results list (named module outputs, e.g. `attrition`,
  `density`). Modules absent from the list are skipped.

## Value

A data.frame with columns `section`, `status`, `maps_to`, `detail`.
