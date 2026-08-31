# Changelog

## hvtiRlifetables 0.1.3

### Bug fixes

- **The `::` regression tests could report a result they could not stand
  behind.** The tests added in 0.1.2 run in a subprocess, which is the
  only way to catch the issue
  [\#18](https://github.com/ehrlinger/hvtiRlifetables/issues/18) defect
  — but a fresh R loads the *installed* copy of the package, never the
  source under development. Under `devtools::test()` the parent is a
  `load_all()` session, so the two can differ, and both directions
  mislead: a stale install fails against correct source, and a good
  install passes against source someone has just broken. The second is
  the same shape of defect as issue
  [\#18](https://github.com/ehrlinger/hvtiRlifetables/issues/18) itself
  — a test that looks like it covers the code while reporting on
  something else.

  Each subprocess now fingerprints what it loaded — every object in the
  namespace, deparsed, plus the shipped dataset — and the test skips
  unless that is the code under test. The fingerprint is code identity
  rather than a version string, so source edited *without* a version
  bump is caught too, which is the case that produced a false pass.

- **The `::` tests ran on Linux only, and nothing said so.** They
  skipped on every macOS and Windows CI job — `SKIP 5 | PASS 474`
  against Linux’s `SKIP 0 | PASS 483` — while all ten checks stayed
  green. A skip is the one failure mode a passing check cannot show you,
  and on Windows the issue
  [\#18](https://github.com/ehrlinger/hvtiRlifetables/issues/18) guard
  had never run at all since 0.1.2. Three causes, found in that order:

  - `detached_r()` looked for `Rscript` in `R.home("bin")`, where
    Windows has `Rscript.exe`. The extension is now chosen per platform.
  - The child was then launched via `-e`, and with the guard above fixed
    it launched and produced no output at all. Two causes were proposed
    for that and both are false, measured rather than reasoned:
    [`shQuote()`](https://rdrr.io/r/base/shQuote.html) already defaults
    to `type = "cmd"` on Windows, and the payload is 860 characters
    against `cmd`’s 8191-char cap. What the payload does carry is 14
    literal newlines — it is a deparsed function — and a Windows command
    line cannot carry one; that is the best available explanation and is
    *not* itself measured, no Windows machine being to hand. The code is
    handed over as a script file now, which is platform-neutral
    regardless of which of those was the mechanism, and `R_LIBS` is set
    on the parent and inherited rather than passed through
    `system2(env=)`, which Windows does not support.
  - The fingerprint was **locale-dependent, in two independent ways**.
    `R CMD check` forces `LC_COLLATE=C` on the parent while a
    `--vanilla` child inherits the machine’s locale:
    [`sort()`](https://rdrr.io/r/base/sort.html) then orders the
    namespace differently — `VINTAGE_META` sorts third under `C` and
    last under `en_US`, which ignores case — and
    [`saveRDS()`](https://rdrr.io/r/base/readRDS.html) version 3 writes
    the session’s native encoding into its header, so identical data
    serialises to different bytes. Same package, two fingerprints. Now
    `sort(method = "radix")` and `saveRDS(version = 2)`, both
    byte-ordered and neither locale-aware.

  The fingerprint is now identical under `C`, `en_US.UTF-8` and
  `de_DE.UTF-8`.

## hvtiRlifetables 0.1.2

### Bug fixes

- **Every export failed when called with `::`.**
  [`hvtiRlifetables::us_matched()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_matched.md)
  and its two siblings errored with
  `object 'us_lifetable_models' not found` unless the package had first
  been attached with [`library()`](https://rdrr.io/r/base/library.html).
  The functions referenced the shipped dataset by bare name, and a
  lazy-loaded dataset is promised into the *package* environment rather
  than the *namespace* — which is not on the parent chain package code
  resolves against. It worked only because every caller so far happened
  to attach the package first. The dataset is now loaded explicitly by
  an internal accessor and stays user-visible; nothing about the fitted
  models or the numbers changes.
  ([\#18](https://github.com/ehrlinger/hvtiRlifetables/issues/18))

  The regression test runs in a **subprocess with the package
  unattached**. `tests/testthat.R` calls
  [`library(hvtiRlifetables)`](https://ehrlinger.github.io/hvtiRlifetables/)
  before `test_check()`, so an ordinary test in `tests/testthat/` runs
  attached and passes against the broken code — which is how this
  survived to 0.1.1.

### New features

- [`us_cohort_curve()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_cohort_curve.md)
  reduces the per-patient output of
  [`us_matched()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_matched.md)
  to the cohort curve a figure actually carries, and with `by` gives one
  curve per group of the caller’s own choosing — age band, treatment
  arm, era.
  ([\#16](https://github.com/ehrlinger/hvtiRlifetables/issues/16),
  [\#17](https://github.com/ehrlinger/hvtiRlifetables/issues/17))

  `by` is a **reporting** grouping and is independent of `table=`, which
  chooses which strata the life table itself is built from. A report
  broken down by age band is normally still matched on `"sexrace"`.

  The cohort average already existed as
  `us_matched(individual = FALSE)`, and its arithmetic is unchanged —
  that call now routes through
  [`us_cohort_curve()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_cohort_curve.md),
  so the two cannot drift into two different averages. What is new is
  that the reduction is reachable without recomputing the curves, and
  that it takes a grouping. Studies deriving the average inline can now
  call it instead, which is the point: the choice of what to average is
  made once, here, and documented.

## hvtiRlifetables 0.1.1

Documentation and metadata only. No change to
[`us_matched()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_matched.md),
the vintages, or the shipped fitted models — results are identical to
0.1.0.

- The pkgdown site is live at
  <https://ehrlinger.github.io/hvtiRlifetables/> and is now listed in
  `DESCRIPTION`. GitHub Pages had never been enabled on this repository,
  so the site 404’d even though the `pkgdown` workflow had been
  deploying to the `gh-pages` branch successfully since 2026-08-20. A
  green deploy is not evidence that a site serves.

## hvtiRlifetables 0.1.0

First release. Reproduces the Cleveland Clinic SAS macro `%usmatchd` in
R.

### New features

- [`us_matched()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_matched.md)
  returns age, sex and race matched US reference survival and its
  hazard, for individual patients or as a cohort mean curve. Argument
  names and the `table=` modes mirror the macro so a SAS job translates
  by inspection.
- [`us_lifetable_vintages()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_lifetable_vintages.md)
  reports the available vintages with their provenance and, importantly,
  what each vintage’s non-white stratum actually contains.
- [`us_lifetable_model()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_lifetable_model.md)
  returns a single fitted parameter set for inspection.
- Ships `us_lifetable_models`: 27 fitted three-phase hazard parameter
  sets — nine strata across `table84`, `table2008` and `table2023` —
  with their `_STATUS_` gates, fitted-form flags and covariance blocks.

### What is and is not in this repository

The package ships the **derived** dataset
`data/us_lifetable_models.rda`. CCF’s source `.sas7bdat` fitted blocks
are **not** tracked here: they were removed from git history and are
`.gitignore`d, because this repository is public. `data-raw/` carries
the build script and the `%usmatchd` macro variants, not the blocks
themselves. Rebuilding the dataset requires restoring those inputs from
the share; `data-raw/build-models.R` names the location and errors
loudly if they are absent.

### Design notes

- `vintage` has no default. Omitting it is an error listing the
  available vintages. The macro’s own default silently moved from
  `table84` to `table2023`, and jobs re-run across that change got
  different numbers with no signal.
- `hmatched` is per year regardless of `scale`, matching the macro’s
  source rather than its header comment. See the README.
- The `table2023` non-white stratum is stored under code `b` but is a
  risk-weighted average of Black, Asian, American Indian and Hispanic
  death rates. It is not Black. The macro’s comment says otherwise and
  is wrong.
- Both evaluators error rather than return a non-finite value.
  `TemporalHazard`’s early phase is indeterminate at exactly age 0
  (`0 * Inf`), which affects 9 of the 27 shipped strata.
- An empty cohort returns a zero-row data frame with the documented
  columns, not `NULL`. Unsorted `times` are rejected rather than
  silently sorted.
- Covariance blocks ship but nothing reads them. They are the only route
  to a confidence band later.

### Known limitation

`TemporalHazard (>= 1.2.0)` is required, and CRAN currently carries
1.1.0, so the dependency must come from source until 1.2.0 is released.
This is also why the repository has no CI workflow yet.
