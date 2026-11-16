# Age, sex and race matched US reference survival

Reproduces the Cleveland Clinic SAS macro `%usmatchd`: for each patient,
a US reference survival curve matched on age, sex and race, together
with its hazard. This is the dashed comparison line on a clinical
survival figure.

## Usage

``` r
us_matched(
  age,
  male,
  other,
  times,
  id = seq_along(age),
  vintage,
  table = c("sexrace", "race", "sex", "overall"),
  scale = c("years", "months", "days"),
  individual = TRUE
)
```

## Arguments

- age:

  Numeric vector of ages **in years**, always in years regardless of
  `scale`. An age of exactly `0` is accepted, but not together with a
  time of `0`: the reference hazard at birth is not defined (the
  `table2008` and `table2023` fits diverge there), so a newborn's
  `hmatched` cannot be reported at `time = 0` and the call stops, naming
  the patients. Start `times` above `0` for such a cohort; `smatched` at
  time `0` is `1` by definition.

- male:

  Numeric vector, `1` male, `0` female. The macro's coding, unchanged. A
  logical vector is read as `TRUE` = `1`.

- other:

  Numeric vector, `1` non-white, `0` white. The macro's coding,
  unchanged. A logical vector is read as `TRUE` = `1`. What "non-white"
  contains differs by vintage – see
  [`us_lifetable_vintages()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_lifetable_vintages.md).

- times:

  Numeric vector of follow-up times in the units of `scale`,
  non-negative.

- id:

  Optional vector of patient identifiers, one per patient and so the
  same length as `age`, with no missing or repeated values, repeated
  into the output once per time. Defaults to `seq_along(age)`.

- vintage:

  Character scalar naming the fitted-model vintage. **There is no
  default.** Omitting it is an error. See Details.

- table:

  How finely to stratify patients, mirroring the macro's `TABLE=` modes.
  `"sexrace"` uses all four crossings, `"race"` uses white against the
  vintage's non-white category, `"sex"` uses male and female,
  `"overall"` sends every patient to the combined stratum and ignores
  `male` and `other`.

- scale:

  Units of `times`. Applies the macro's `SCALEF` of `1`, `1/12` and
  `1/365.2425` respectively.

- individual:

  A single `TRUE` or `FALSE`. If `TRUE` (default), one row per patient
  per time. If `FALSE`, the cohort mean curve, one row per time – the
  ungrouped case of
  [`us_cohort_curve`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_cohort_curve.md),
  which is what to use for a curve within groups of the caller's own
  choosing.

## Value

A data frame. When `individual = TRUE`, columns `id`, `time`, `agesurv`
(survival from birth to the patient's current age), `smatched`
(reference survival over `times`, conditional on having reached `age`)
and `hmatched` (the reference hazard), with one row per patient per
time. When `individual = FALSE`, columns `time`, `smatched` and
`hmatched` only, with one row per distinct time.

## Details

`%usmatchd` is not a life-table lookup. It evaluates a stored
three-phase parametric hazard fit on the **age** axis, time origin
birth, and reads conditional survival off that one smooth curve twice.
That is why the resulting hazard is smooth *within* a one-year age bin
where a life table would be flat.

**`hmatched` is per year regardless of `scale`.** This matches the
macro's source, which assigns `_HAZARD` without applying `SCALEF`,
notwithstanding the macro's own header comment to the contrary.

When `individual = FALSE`, the cohort mean follows the macro's
arithmetic: the hazard is converted to a density
(`hmatched * smatched`), the cohort means of survival and of the density
are taken at each time, and the mean hazard is recovered by division. It
is deliberately **not** the mean of the individual hazards.

## Why `vintage` has no default

The macro's default silently moved twice: from `table84` to `table2008`
between 2010 and 2024, then to `table2023` on 2025-12-23. Every job
re-run across either move got different numbers with no signal. An
analysis that does not state its reference vintage is not reproducible,
so this package refuses to guess. State it literally in analysis code.

## See also

[`us_cohort_curve`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_cohort_curve.md)
to reduce the individual output to a cohort curve, or to one curve per
group;
[`us_lifetable_vintages()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_lifetable_vintages.md)
for the available vintages and what their non-white stratum actually
contains;
[`us_lifetable_model()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_lifetable_model.md)
for the raw fitted parameters.

## Examples

``` r
# A 70-year-old white male, ten years of follow-up, 1984 fits.
r <- us_matched(age = 70, male = 1, other = 0,
                times = seq(0, 10, by = 2), vintage = "table84")
r[, c("time", "smatched", "hmatched")]
#>   time  smatched   hmatched
#> 1    0 1.0000000 0.03713773
#> 2    2 0.9219074 0.04439022
#> 3    4 0.8365127 0.05307329
#> 4    6 0.7447221 0.06346910
#> 5    8 0.6480707 0.07591549
#> 6   10 0.5487891 0.09081692
```
