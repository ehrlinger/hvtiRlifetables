# Cohort expected-survival curve, optionally within groups

Reduces the per-patient output of
[`us_matched`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_matched.md)
to the curve a figure actually carries: the cohort's expected survival
at each time, and its hazard. With `by`, one such curve per group.

## Usage

``` r
us_cohort_curve(x, by = NULL)
```

## Arguments

- x:

  A data frame as returned by
  [`us_matched`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_matched.md)
  with `individual = TRUE` – columns `id`, `time`, `smatched` and
  `hmatched`. An already-aggregated frame is rejected rather than
  averaged twice.

- by:

  How to group the result. One of:

  - `NULL` (default), for a single cohort-wide curve;

  - a vector or factor with one value per *row* of `x`, reported in a
    column called `group`;

  - a named list or data frame of such vectors, for a crossed grouping,
    reported under its own names.

  It carries values, not column names: group by a column of `x` with
  `by = x$arm`. Because `x` holds one row per patient per time, a
  patient-level grouping must be expanded to it – see the examples.

## Value

A data frame with columns `time`, `smatched` and `hmatched`, one row per
time – or, with `by`, the grouping columns first and one row per group
per time. Groups and times appear in order of first appearance in `x`,
so a factor grouping does not reorder to its levels.

## The averaging, and why it is here

The reduction follows the SAS macro `%usmatchd` (lines 338-350): the
hazard is converted to a density (`hmatched * smatched`), the
**unweighted** cohort means of survival and of the density are taken at
each time, and the mean hazard is recovered by division. It is
deliberately **not** the mean of the individual hazards; in a
heterogeneous cohort the two differ, and the difference is not cosmetic.

The mean is over **survival**, not over cumulative hazard, and no
patient is weighted by follow-up. Missing values are not dropped: every
value
[`us_matched`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_matched.md)
returns is finite by construction, so an `NA` arriving here is a defect
rather than a datum, and averaging around it would hide it.

## Grouping is not stratification

`us_matched`'s `table` argument chooses which strata the *life table* is
built from – `"sexrace"`, `"race"`, `"sex"`, `"overall"`. `by` chooses
how the resulting curves are grouped for *reporting* – age band,
treatment arm, era. The two axes are independent: a report broken down
by age band is normally still matched on `"sexrace"`.

## See also

[`us_matched`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_matched.md),
whose `individual = FALSE` is the ungrouped case of this function.

## Examples

``` r
x <- us_matched(age = c(55, 60, 78, 82), male = c(1, 0, 1, 0),
                other = c(0, 0, 1, 1), times = c(0, 5, 10),
                vintage = "table84")

# The cohort curve.
us_cohort_curve(x)
#>   time  smatched   hmatched
#> 1    0 1.0000000 0.04305889
#> 2    5 0.7853423 0.05332975
#> 3   10 0.5900473 0.06019834

# The same, broken down by an age band of the study's own choosing. The
# grouping is per patient, so it is expanded to x's one-row-per-patient-
# per-time shape by id.
band <- c("55-79", "55-79", "55-79", "80+")
us_cohort_curve(x, by = factor(band[x$id], levels = c("55-79", "80+")))
#>   group time  smatched   hmatched
#> 1 55-79    0 1.0000000 0.03231654
#> 2 55-79    5 0.8377614 0.03833459
#> 3 55-79   10 0.6827767 0.04338791
#> 4   80+    0 1.0000000 0.07528592
#> 5   80+    5 0.6280851 0.11333294
#> 6   80+   10 0.3118590 0.17061140
```
