* `us_cohort_curve()`'s first argument is now `data`, per the hvtiR API
  rubric. `x` still works for this release, with a once-per-session
  `hvtiRlifetables_deprecated` warning, and will then be removed. Positional
  calls such as `us_cohort_curve(r)` are unaffected.

* Errors a caller may want to handle now carry a condition class:
  `hvtiRlifetables_vintage` (missing, unknown or empty vintage),
  `hvtiRlifetables_stratum`, `hvtiRlifetables_support` (age plus follow-up
  beyond 110), `hvtiRlifetables_age_zero` (including a newborn at time 0),
  `hvtiRlifetables_grid` (patients in `us_cohort_curve()` not sharing one set
  of times, or an id repeated at one time) and `hvtiRlifetables_degenerate`,
  each also `hvtiRlifetables_error`. Messages are unchanged apart from a
  `fn(): ` prefix where they were touched.

* `?us_cohort_curve` is written in roxygen markdown, as the rest of the
  package is.
