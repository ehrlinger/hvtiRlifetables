# hvtiRlifetables 0.1.3

## Bug fixes

- **The `::` regression tests could report a result they could not stand
  behind.** The tests added in 0.1.2 run in a subprocess, which is the only
  way to catch the issue #18 defect — but a fresh R loads the *installed*
  copy of the package, never the source under development. Under
  `devtools::test()` the parent is a `load_all()` session, so the two can
  differ, and both directions mislead: a stale install fails against correct
  source, and a good install passes against source someone has just broken.
  The second is the same shape of defect as issue #18 itself — a test that
  looks like it covers the code while reporting on something else. Each
  subprocess now reports the version it loaded, and the test skips, with the
  two versions named, when that is not the source version. `R CMD check`
  installs the package before testing, so the two always agree there and
  nothing skips.

# hvtiRlifetables 0.1.2

## Bug fixes

- **Every export failed when called with `::`.** `hvtiRlifetables::us_matched()`
  and its two siblings errored with `object 'us_lifetable_models' not found`
  unless the package had first been attached with `library()`. The functions
  referenced the shipped dataset by bare name, and a lazy-loaded dataset is
  promised into the *package* environment rather than the *namespace* — which
  is not on the parent chain package code resolves against. It worked only
  because every caller so far happened to attach the package first. The
  dataset is now loaded explicitly by an internal accessor and stays
  user-visible; nothing about the fitted models or the numbers changes.
  ([#18](https://github.com/ehrlinger/hvtiRlifetables/issues/18))

  The regression test runs in a **subprocess with the package unattached**.
  `tests/testthat.R` calls `library(hvtiRlifetables)` before `test_check()`,
  so an ordinary test in `tests/testthat/` runs attached and passes against
  the broken code — which is how this survived to 0.1.1.

## New features

- `us_cohort_curve()` reduces the per-patient output of `us_matched()` to the
  cohort curve a figure actually carries, and with `by` gives one curve per
  group of the caller's own choosing — age band, treatment arm, era.
  ([#16](https://github.com/ehrlinger/hvtiRlifetables/issues/16),
  [#17](https://github.com/ehrlinger/hvtiRlifetables/issues/17))

  `by` is a **reporting** grouping and is independent of `table=`, which
  chooses which strata the life table itself is built from. A report broken
  down by age band is normally still matched on `"sexrace"`.

  The cohort average already existed as `us_matched(individual = FALSE)`, and
  its arithmetic is unchanged — that call now routes through
  `us_cohort_curve()`, so the two cannot drift into two different averages.
  What is new is that the reduction is reachable without recomputing the
  curves, and that it takes a grouping. Studies deriving the average inline
  can now call it instead, which is the point: the choice of what to average
  is made once, here, and documented.

# hvtiRlifetables 0.1.1

Documentation and metadata only. No change to `us_matched()`, the vintages, or
the shipped fitted models — results are identical to 0.1.0.

- The pkgdown site is live at <https://ehrlinger.github.io/hvtiRlifetables/> and
  is now listed in `DESCRIPTION`. GitHub Pages had never been enabled on this
  repository, so the site 404'd even though the `pkgdown` workflow had been
  deploying to the `gh-pages` branch successfully since 2026-08-20. A green
  deploy is not evidence that a site serves.

# hvtiRlifetables 0.1.0

First release. Reproduces the Cleveland Clinic SAS macro `%usmatchd` in R.

## New features

- `us_matched()` returns age, sex and race matched US reference survival and
  its hazard, for individual patients or as a cohort mean curve. Argument
  names and the `table=` modes mirror the macro so a SAS job translates by
  inspection.
- `us_lifetable_vintages()` reports the available vintages with their
  provenance and, importantly, what each vintage's non-white stratum actually
  contains.
- `us_lifetable_model()` returns a single fitted parameter set for inspection.
- Ships `us_lifetable_models`: 27 fitted three-phase hazard parameter sets —
  nine strata across `table84`, `table2008` and `table2023` — with their
  `_STATUS_` gates, fitted-form flags and covariance blocks.

## What is and is not in this repository

The package ships the **derived** dataset `data/us_lifetable_models.rda`.
CCF's source `.sas7bdat` fitted blocks are **not** tracked here: they were
removed from git history and are `.gitignore`d, because this repository is
public. `data-raw/` carries the build script and the `%usmatchd` macro
variants, not the blocks themselves. Rebuilding the dataset requires
restoring those inputs from the share; `data-raw/build-models.R` names the
location and errors loudly if they are absent.

## Design notes

- `vintage` has no default. Omitting it is an error listing the available
  vintages. The macro's own default silently moved from `table84` to
  `table2023`, and jobs re-run across that change got different numbers with
  no signal.
- `hmatched` is per year regardless of `scale`, matching the macro's source
  rather than its header comment. See the README.
- The `table2023` non-white stratum is stored under code `b` but is a
  risk-weighted average of Black, Asian, American Indian and Hispanic death
  rates. It is not Black. The macro's comment says otherwise and is wrong.
- Both evaluators error rather than return a non-finite value.
  `TemporalHazard`'s early phase is indeterminate at exactly age 0 (`0 * Inf`),
  which affects 9 of the 27 shipped strata.
- An empty cohort returns a zero-row data frame with the documented columns,
  not `NULL`. Unsorted `times` are rejected rather than silently sorted.
- Covariance blocks ship but nothing reads them. They are the only route to a
  confidence band later.

## Known limitation

`TemporalHazard (>= 1.2.0)` is required, and CRAN currently carries 1.1.0, so
the dependency must come from source until 1.2.0 is released. This is also
why the repository has no CI workflow yet.
