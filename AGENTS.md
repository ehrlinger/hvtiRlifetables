# hvtiRlifetables

US reference survival: the R replacement for the CORR macro library’s
`%usmatchd` family (`uslife.sas`, `usmatchd.sas`, `usmtch08.sas`). Three
exports —
[`us_matched()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_matched.md),
[`us_lifetable_vintages()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_lifetable_vintages.md),
[`us_lifetable_model()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_lifetable_model.md)
— plus the fitted models shipped as `data/us_lifetable_models.rda`.

This file is the operational contract and applies in full. It is tool
neutral, so Codex and any other agent read the same rules. Claude Code
affordances live in `CLAUDE.md`, which imports this file.

**Read `HANDOFF.md` before starting.** It carries “The three things that
will bite”, “Two more things that will bite”, and — importantly —
**“Decisions already made — do not relitigate”**. The design and
implementation documents are in `docs/specs/` and `docs/plans/`. None of
that is restated here.

## Definition of done

- `devtools::test()` passes. The runner is `tests/testthat.R`.
- `devtools::check()` is **0 errors, 0 warnings, 0 notes**. Verified
  2026-08-20 at 0.1.0.
- [`lintr::lint_package()`](https://lintr.r-lib.org/reference/lint.html)
  returns **zero** lints. CI runs with `LINTR_ERROR_ON_LINT: true`, so
  any lint fails the build. `R/` and `tests/` were brought to zero on
  2026-08-20; keep them there.
- `devtools::document()` has been run and `man/` and `NAMESPACE` are
  committed with the source change.

## The automated gates

Five workflows, adopted 2026-08-20. `house-style` is **deliberately
absent**: it needs `.claude/house-style.md` and a `repos.yml`
registration this repo does not have.

| workflow             | fails on                                      |
|----------------------|-----------------------------------------------|
| `R-CMD-check.yaml`   | `R CMD check` across platforms                |
| `check-manual.yaml`  | the PDF manual build                          |
| `lint.yaml`          | any lint at all (`LINTR_ERROR_ON_LINT: true`) |
| `pkgdown.yaml`       | the site build, and deploy on `main`          |
| `test-coverage.yaml` | coverage upload                               |

## The rule that matters most

⚠️ **In the `table2023` vintage, the stratum code `"b"` does NOT mean
Black.** It is a risk-weighted average of Black, Asian, American Indian
and Hispanic death rates, weighted by number at risk — *despite the
stratum code, and despite the macro’s own comment saying otherwise*.
`VINTAGE_META` records this in `nonwhite_meaning`, and
[`us_lifetable_vintages()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_lifetable_vintages.md)
surfaces it.

Anything that reports a stratum to a reader — a table, a figure legend,
a manuscript sentence — must use `nonwhite_meaning`, not the code.
Writing “Black” because the code says `b` produces a **clinically wrong
statement** that will survive review, because it looks exactly like what
everyone expects.

## Rules for this repo

- **`vintage` has no default and must be supplied.** That is deliberate:
  the vintages differ in how they name and construct the non-white
  category, so there is no safe default. Some entries in `VINTAGE_META`
  carry `usable = FALSE` and are deliberately not offered —
  `usable_vintages()` is the list, not `names(VINTAGE_META)`.
- **The year length is `365.2425`, not `365.241`.** From
  `usmatchd.sas:202-204`. The survival package uses the other constant
  elsewhere, and the difference is real; do not “correct” one to the
  other.
- **`data-raw/sas/` holds the original macros.** They are the parity
  reference. When a behaviour is in question, read the macro rather than
  reasoning from the R.
- **`data/us_lifetable_models.rda` is shipped fitted data.**
  Regenerating it via `data-raw/build-models.R` is a *data* change, not
  a code change: it alters what every downstream analysis gets. Say so
  explicitly in the PR, and check whether a vintage’s stratum set moved.
- **`TemporalHazard` comes from GitHub, not CRAN.** This package Imports
  `>= 1.2.0` and CRAN carries an older release, so `DESCRIPTION` has
  `Remotes: TemporalHazard=ehrlinger/temporal_hazard` and every workflow
  pulls `github::ehrlinger/temporal_hazard` explicitly. Removing either
  breaks CI resolution.
- **`docs/` is PROSE here** — `docs/specs/` and `docs/plans/` are
  tracked design documents, not a generated site. ⚠️ **pkgdown’s site
  goes to `pkgdown-site/`, and `destination:` in `_pkgdown.yml` is not
  enough on its own.**
  [`pkgdown::build_site_github_pages()`](https://pkgdown.r-lib.org/reference/build_site_github_pages.html)
  takes `dest_dir = "docs"` as its default and **overrides** the config.
  The workflow passes `dest_dir` explicitly and its deploy step names
  the same folder; the two must agree. Getting this wrong deletes
  tracked design documents, which is why pkgdown refuses and errors
  instead.
- **Roxygen markdown is NOT enabled** — no
  `Roxygen: list(markdown = TRUE)` in `DESCRIPTION`, so use `\code{}`,
  `\strong{}`, `\emph{}` and `\link{}`.
- **`.lintr` disables three linters, each for a stated reason**:
  `object_name_linter` (`muE`/`muC`/`muL` are the Blackstone phase
  amplitudes and match the SAS parameter table), `commented_code_linter`
  (it flags mathematical notation such as
  `H(a) = muE * G(a) + muC * a + muL * G3(a)`), and `indentation_linter`
  (aligned-argument style). `line_length` is 100. `data-raw/` is
  excluded — developer scripts that never ship. Do not disable a fourth
  linter to reach green; fix the code, as was done for the brace and
  semicolon lints.
- **`testthat` edition 3.** Test files are `test-*.R` with a hyphen.

## Gotchas

- **The pkgdown URL is deliberately absent from `DESCRIPTION`.**
  `_pkgdown.yml` explains why: `R CMD check --as-cran` fetches every
  `DESCRIPTION` URL and would report a 404 while the site is
  unpublished. 🔴 **CI to publish it now exists (2026-08-20).** Once the
  first deploy lands and the site returns 200, add the URL to
  `DESCRIPTION` — `_pkgdown.yml` says to do it in the same commit. Until
  then
  [`pkgdown::check_pkgdown()`](https://pkgdown.r-lib.org/reference/check_pkgdown.html)
  aborts with “URL is missing package url”, which is accepted
  deliberately.
- **`object_usage_linter` over-reports until the package is installed.**
  22 such lints disappeared once it was; CI installs, so they are an
  artifact locally rather than a defect.
- The package is **0.x** — the API is not frozen, but the vintage
  semantics above are not an API question.

## Git and versioning

- **Never push to `main`.** Branch, then open a PR and let the
  maintainer merge.
- **`main` is protected by a GitHub ruleset, and nothing in this repo
  records that.** A clone shows no trace of it, so it is stated here.
  The ruleset is named `protect main`, is identical across all twelve
  repositories in the HVTI R package family, and enforces four rules on
  the default branch: no deletion, no force-push, pull-request-only, and
  an **automatic Copilot code review** on every PR. A rejected push
  comes from the server, not a local hook. ⚠️ It currently requires
  **zero approvals**. `require_code_owner_review` is set but inert
  because no repository in the family has a `CODEOWNERS` file, so a PR
  can merge unreviewed.
- Versions are **straight three digits** (`0.1.0`). Never a `.9000`
  suffix or a fourth digit.
- **Patch-digit bumps only**, as fixes land. Minor and major are the
  maintainer’s decision.
- Bump `DESCRIPTION`, refresh its `Date`, and add the matching `NEWS.md`
  entry in the same commit.

## Change discipline

1.  **Think before coding.** Do not assume, ask. Read `HANDOFF.md`’s “do
    not relitigate” section before proposing a design change — several
    were settled deliberately.
2.  **Simplicity first.** Write the minimum that solves the stated
    problem.
3.  **Surgical changes.** Touch only what the task requires. Raise
    nearby problems separately.
4.  **Goal-driven execution.** State what done looks like before
    starting, and use tests as the criterion. For anything touching
    strata or vintages, “done” includes checking what a reader would
    conclude from the label.

## Prose

Documentation prose follows the house voice. This package’s
documentation has one obligation above style: **never let a stratum code
stand in for its meaning.** The `"b"` case above is the reason.
