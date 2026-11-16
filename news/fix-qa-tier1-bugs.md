* `us_matched()` with a patient aged 0 and a time of 0 now stops naming those
  patients' ids, and says to start `times` above 0. The reference hazard is
  not defined at birth (the `table2008` and `table2023` fits diverge there),
  so the call still stops; before, it stopped inside the evaluator without
  saying who. `?us_matched` documents the limitation under `age`.

* `us_matched()` accepts tied `times`, such as `c(5, 5)`. They stopped with a
  message blaming the `_STATUS_` gating and the vintage.

* `us_matched()` checks that `individual` is a single `TRUE` or `FALSE`, and
  that `male` and `other` are numeric (or logical) as well as 0 or 1. A
  character `"1"` or a factor used to pass through `%in%`'s coercion, and
  `individual = "no"` returned the cohort curve.

* `?us_matched` no longer says `id` is recycled: it is one per patient, the
  same length as `age`, as the code has always required.

* `us_cohort_curve()`, and so `us_matched(individual = FALSE)`, returns
  `time` at full precision. It grouped through factor levels, which returned
  `1/3` as `0.333333333333333`.

* `us_matched()` requires `id` to have no missing or repeated values. The
  output identifies patients by `id` alone, so a shared id merged patients.

* `us_cohort_curve()` stops when the patients in `x` do not share one set of
  times, as when two `us_matched()` calls with different `times` are stacked,
  and when an id appears twice at one time, as when stacked results reuse the
  default ids. The mean at each time would otherwise be over a different set
  of patients along the curve. Row order does not matter. Tied `times` must
  be made unique before `us_cohort_curve()`; `us_matched(individual = FALSE)`
  does that itself.
