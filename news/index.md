# Changelog

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
