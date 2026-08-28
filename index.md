# hvtiRlifetables

Age, sex and race matched US reference survival — the dashed comparison
line on a clinical survival figure — computed in R.

**Status: working.**
[`us_matched()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_matched.md),
[`us_lifetable_vintages()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_lifetable_vintages.md)
and
[`us_lifetable_model()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_lifetable_model.md)
are implemented and tested against the fitted blocks. What is not yet
done is the SAS acceptance check — reproducing a real `%usmatchd` run to
1e-12 — which is PHI-adjacent and so lives in the study’s own `R_parity`
project rather than here. See [the design
spec](https://ehrlinger.github.io/hvtiRlifetables/docs/specs/2026-08-13-hvtirlifetables-design.md).

## What this is

An R replacement for the Cleveland Clinic SAS macro `%usmatchd`.

The surprise that shapes the whole package: **`%usmatchd` is not a
life-table lookup.** It is `PROC HAZPRED` evaluating a stored
three-phase parametric hazard fit on the *age* axis — time origin is
birth, not surgery. So this is not a data package carrying life tables.
It ships ~27 small fitted-parameter blocks and a thin evaluator over
[TemporalHazard](https://github.com/ehrlinger/TemporalHazard).

[`survival::survexp.usr`](https://rdrr.io/pkg/survival/man/survexp.us.html)
cannot substitute. Twelve vintage × interpolation combinations were
tested; the best individual-curve error in every one was 0.09–0.11, with
an age tilt no vintage removes. The reason is structural — there is no
table on the R side of that comparison.

## Interface

Signatures, not runnable calls — `vintage` and `stratum` appear bare
because they have no defaults:

``` r

us_matched(age, male, other, times,
           id         = seq_along(age),
           vintage,
           table      = c("sexrace", "race", "sex", "overall"),
           scale      = c("years", "months", "days"),
           individual = TRUE)

us_lifetable_vintages()                # vintages, provenance, race semantics
us_lifetable_model(vintage, stratum)    # the raw parameter set
```

Argument names mirror the macro so a SAS job translates by inspection.

## Example

A 62-year-old white male and a 71-year-old white female, ten years of
follow-up, against the 1984 fits:

``` r

library(hvtiRlifetables)

us_matched(age   = c(62, 71),
           male  = c(1, 0),
           other = c(0, 0),
           times = seq(0, 10, by = 5),
           vintage = "table84")
#>   id time   agesurv  smatched   hmatched
#> 1  1    0 0.7925575 1.0000000 0.01826492
#> 2  1    5 0.7925575 0.8914976 0.02843656
#> 3  1   10 0.7925575 0.7453229 0.04439022
#> 4  2    0 0.7773741 1.0000000 0.02241349
#> 5  2    5 0.7773741 0.8640873 0.03736907
#> 6  2   10 0.7773741 0.6758045 0.06334817
```

`agesurv` is survival from birth to the patient’s current age;
`smatched` is conditional on having reached it, so it starts at 1. Add
`individual = FALSE` for the cohort mean curve, which is what a figure’s
dashed line usually needs.

Omitting `vintage` is an error, deliberately:

``` r

us_matched(70, 1, 0, times = 5)
#> Error: `vintage` has no default and must be given.
#> Available: table84, table2008, table2023.
```

## `vintage` has no default

Omitting it is an error.

`%usmatchd`’s own default silently moved from `table84` to `table2023`,
and every job re-run across that change got different numbers with no
signal. An analysis that does not state its reference vintage is not
reproducible, so the package refuses to guess. This is deliberate
friction and it is the package’s main value over calling the macro.

## Race semantics — read this before citing a stratum

`table84` names its non-white strata `hzico*`, honestly “other”.
`table2008` and `table2023` name the same strata `hzicb*`, and the
macro’s own comment claims these are Black-race estimates.

**For 2023 that comment is false.** The 2023 “other” category is a
risk-weighted average of Black, Asian, American Indian and Hispanic
death rates, weighted by number at risk, stored under `B` only to keep
the macro’s naming consistent. This package does not propagate the
macro’s error.

## `hmatched` is per year, always

Whatever `scale=` you pass, `time` is in those units but `hmatched` is a
hazard per **year**.

This matches the macro’s source. `usmatchd.sas:227` assigns
`HMATCHED = _HAZARD` with no `SCALEF` multiplication, and `PROC HAZPRED`
is evaluated at `AGE_YR` in years. The macro’s own header comment at
line 47 claims `HMATCHED` is “scaled by SCALE” and is wrong — but it has
never mattered, because every job that consumes it uses `scale="years"`,
where `SCALEF = 1`.

This package reproduces the code, not the comment, because bit-fidelity
to the macro is the acceptance criterion. If you need a per-month or
per-day hazard, multiply by the corresponding `SCALEF` yourself.

## Installation

``` r

# install.packages("remotes")
remotes::install_github("ehrlinger/hvtiRlifetables")
```

**This will not resolve its dependency yet.** The package requires
`TemporalHazard (>= 1.2.0)`, and CRAN currently carries **1.1.0**. The
`>= 1.2.0` bound is real, not defensive — the evaluator calls
`hzr_decompos_g3()`, which 1.1.0 does not provide — so until 1.2.0
reaches CRAN you need it from source:

``` r

remotes::install_github("ehrlinger/TemporalHazard")
```

This is also why the repository has no CI workflow: any run would fail
at the dependency-install step.

## License

GPL-3. The fitted US life-table hazard parameters are the work of The
Cleveland Clinic Foundation.
