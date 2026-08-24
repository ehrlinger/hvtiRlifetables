---
name: code-review
description: Review pull requests in hvtiRlifetables. Use for every pull request review in this repository. Supplies the domain invariants that make a change wrong in ways the diff alone does not show — vintage and stratum semantics, the SAS parity constants, and which files are data rather than code — and lists the intentional style choices that must not be reported as defects.
license: GPL-3.0
---

# Reviewing hvtiRlifetables

This package reproduces the Cleveland Clinic SAS macro `%usmatchd`: age-, sex- and
race-matched US reference survival, evaluated from a stored three-phase parametric hazard
fit rather than interpolated from a life table. Its failure mode is not a crash. It is a
number that looks right, reaches a manuscript, and is clinically wrong.

Review for that. The automated gates below already cover the mechanical layer, so do not
spend the review there.

## Weight the review here

Most defects in this package are **semantic, not syntactic**, and are invisible in a diff
unless you know the domain. In priority order:

### 1. Stratum `"b"` does not mean Black

⚠️ **The highest-value check in this repository.** In the `table2023` vintage the stratum
code `"b"` is a risk-weighted average of Black, Asian, American Indian and Hispanic death
rates, weighted by number at risk — despite the stratum code, and despite the SAS macro's
own comment saying otherwise.

**Flag any change that reports a stratum to a reader using the code rather than
`nonwhite_meaning`.** That means tables, figure legends, axis labels, roxygen text,
vignette prose, `NEWS.md`, and test fixtures that assert a label. `VINTAGE_META` records
the true meaning and `us_lifetable_vintages()` surfaces it.

Writing "Black" because the code says `b` produces a clinically wrong statement that
survives review precisely because it looks like what everyone expects. Assume a human
reviewer will not catch it.

### 2. Vintage semantics

- **`vintage` must never acquire a default.** The vintages differ in how they name and
  construct the non-white category, so there is no safe default. Flag any new or changed
  signature that defaults it, and any documentation that implies one.
- **`usable_vintages()` is the list of offered vintages, not `names(VINTAGE_META)`.** Some
  entries carry `usable = FALSE` deliberately. Flag iteration over `VINTAGE_META` where the
  usable set is meant.

### 3. SAS parity constants

- **The year length is `365.2425`, not `365.241`** (`usmatchd.sas:202-204`). The `survival`
  package uses the other constant elsewhere. Flag any change that "corrects" one to the
  other in either direction.
- **`data-raw/sas/` holds the original macros and is the parity reference.** When a review
  question turns on intended behaviour, cite the macro rather than reasoning from the R.

### 4. Data changes disguised as code changes

**`data/us_lifetable_models.rda` is shipped fitted data.** Regenerating it via
`data-raw/build-models.R` alters what every downstream analysis gets. Flag any PR that
touches it without saying so explicitly in the description, and ask whether a vintage's
stratum set moved.

### 5. Dependency and build wiring that CI cannot catch late

- **`TemporalHazard` resolves from GitHub, not CRAN.** This package Imports `>= 1.2.0` and
  CRAN carries an older release. `DESCRIPTION` needs
  `Remotes: TemporalHazard=ehrlinger/temporal_hazard` and every workflow needs its explicit
  `github::ehrlinger/temporal_hazard` pull. Flag removal of either — it breaks resolution.
- **`docs/` is tracked prose here** (`docs/specs/`, `docs/plans/`), not a generated site.
  pkgdown builds to `pkgdown-site/`, and `dest_dir` must be passed explicitly because
  `build_site_github_pages()` overrides `destination:` in `_pkgdown.yml`. Flag any change
  that routes pkgdown output at `docs/`; it deletes tracked design documents.
- **The pkgdown URL appears in both `DESCRIPTION` and `_pkgdown.yml`** and the two must stay
  in sync. Note that a green `pkgdown` run is not evidence the site serves — it deploys to
  `gh-pages` and succeeds whether or not Pages is configured.

### 6. Family invariants

This package is a member of the HVTI R package family, installed as a unit by `hvtiR`.

⭐ **`hvtiR` is not a member of its own registry.** `hvtiR::members()` returns the
membership and does not list `hvtiR` itself, because an installer resolving itself would be
circular. Two consequences for review:

- **`hvtiR::members()` is the authority** for both membership and the package-to-repository
  mapping. Package names do not always match repository slugs, so the mapping is stored
  rather than derived. Do not flag a name/slug mismatch as an error without checking it
  there.
- **Never approve prose that states a bare package count.** A number the reader cannot check
  against what is on the page will drift the moment a member is added. Require the
  arithmetic to be visible.

## Do not report these

A wrong comment is not free. It costs reviewer attention, and each thread has to be read
and dismissed by a human who must first confirm it is wrong. Do not raise:

- **`muE` / `muC` / `muL` naming.** These are the Blackstone phase amplitudes and match the
  SAS parameter table. `object_name_linter` is disabled for this reason.
- **Aligned-argument indentation.** `indentation_linter` is disabled deliberately.
- **Mathematical notation in comments**, such as
  `H(a) = muE * G(a) + muC * a + muL * G3(a)`. It is not commented-out code;
  `commented_code_linter` is disabled for this reason.
- **Markdown syntax expectations in roxygen.** Markdown is *not* enabled — there is no
  `Roxygen: list(markdown = TRUE)` in `DESCRIPTION`, so `\code{}`, `\strong{}`, `\emph{}`
  and `\link{}` are correct, not legacy.
- **Style already enforced by `lintr`.** CI runs with `LINTR_ERROR_ON_LINT: true` and
  `line_length` is 100, so any real lint has already failed the build.
- **API stability concerns on their own.** The package is 0.x and the API is not frozen.
  Vintage and stratum semantics above are not API questions and are still in scope.

Exactly three linters are disabled, each for a stated reason in `.lintr`. **Do flag a fourth
disabled linter** if one appears in a diff to reach a green build — that is a defect.

## Already covered by CI — do not re-review

`R-CMD-check.yaml` (multi-platform `R CMD check`), `check-manual.yaml` (PDF manual build),
`lint.yaml` (any lint fails the build), `pkgdown.yaml` (site build and deploy),
`test-coverage.yaml`. The definition of done is `devtools::check()` at 0 errors, 0 warnings,
0 notes, zero lints, and `man/`/`NAMESPACE` regenerated and committed with the source change.
