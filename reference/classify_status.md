# Classify a vector of module flags into a traffic-light status

Flags are strings prefixed `"FAIL:"` or `"WARN:"` (see the module
functions). Any `FAIL` -\> `"fail"` (red); else any `WARN` -\> `"warn"`
(amber); else `"pass"` (green).

## Usage

``` r
classify_status(flags)
```

## Arguments

- flags:

  Character vector of flag messages (may be empty).

## Value

A single string: `"pass"`, `"warn"`, or `"fail"`.
