# hvtiRlifetables

US reference survival: the R replacement for the CORR macro library's `%usmatchd` family
(`uslife.sas`, `usmatchd.sas`, `usmtch08.sas`). Three exports — `us_matched()`,
`us_lifetable_vintages()`, `us_lifetable_model()` — plus the fitted models shipped as
`data/us_lifetable_models.rda`.

This file is the operational contract and applies in full. It is tool neutral, so Codex and
any other agent read the same rules. Claude Code affordances live in `CLAUDE.md`, which
imports this file.

**Read `HANDOFF.md` before starting.** It carries "The three things that will bite", "Two more
things that will bite", and — importantly — **"Decisions already made — do not relitigate"**.
The design and implementation documents are in `docs/specs/` and `docs/plans/`. None of that
is restated here.

## Definition of done

- `devtools::test()` passes. The runner is `tests/testthat.R`.
- `devtools::check()` is **0 errors, 0 warnings, 0 notes**. Verified 2026-08-20 at 0.1.0.
- `lintr::lint_package()` returns **zero** lints. CI runs with `LINTR_ERROR_ON_LINT: true`,
  so any lint fails the build. `R/` and `tests/` were brought to zero on 2026-08-20; keep
  them there.
- `devtools::document()` has been run and `man/` and `NAMESPACE` are committed with the
  source change.

## The automated gates

Six workflow files. Five were adopted 2026-08-20; `house-style` came later. Verified
2026-08-30 against the live repo and PR #21, where the `house-style` check ran and passed.

⚠️ **`house-style` is no longer absent.** It used to be, deliberately — it needs
`.claude/house-style.md` and a `repos.yml` registration, and this repo had neither. Both
have since landed: the file is committed here, and the workflow asserts this repo's entry is
still present in the registry it checks out. An older note calling the gate deliberately
absent is stale.

| workflow | fails on | runs on |
|---|---|---|
| `R-CMD-check.yaml` | `R CMD check` across platforms | push to `main`, PR |
| `check-manual.yaml` | the PDF manual build | push to `main`, release, dispatch — **not PRs** |
| `house-style.yaml` | `.claude/house-style.md` drifting from the vault sources it was composed from | push to `main`, PR |
| `lint.yaml` | any lint at all (`LINTR_ERROR_ON_LINT: true`), and generated docs drifting from their roxygen sources | push to `main`, PR |
| `pkgdown.yaml` | the site build, and deploy on `main` | push to `main`, PR, release, dispatch |
| `test-coverage.yaml` | coverage upload | push to `main`, PR |

⚠️ **`check-manual` does not gate pull requests.** It has no `pull_request:` trigger, so it
runs post-merge on `main`, on a published release, and on `workflow_dispatch`. That is
deliberate and the file's own header comment explains it — do not "fix" the trigger. The
consequence is what matters: a PR green across every check is **not** evidence that the PDF
manual builds, and the raw-Unicode-in-`.Rd` failure this workflow exists to catch will
surface after the merge, not before it. Dispatch it by hand if you need that assurance first.

⚠️ **Check names do not map one-to-one onto workflow filenames.** Six files produce ten check
runs on a PR, because GitHub names a check run after the *job*, not the file:

| file | check runs on a PR |
|---|---|
| `R-CMD-check.yaml` | `macos-latest (release)`, `windows-latest (release)`, `ubuntu-latest (devel)`, `ubuntu-latest (release)`, `ubuntu-latest (oldrel-1)` — five matrix legs, and **nothing named `R-CMD-check`** |
| `check-manual.yaml` | none, per the trigger above |
| `house-style.yaml` | `house-style` |
| `lint.yaml` | `lint` **and** `docs-current` — two jobs sharing one workflow run id |
| `pkgdown.yaml` | `pkgdown` |
| `test-coverage.yaml` | `test-coverage` |

`docs-current` is `pull_request`-only: it regenerates the roxygen output and fails on the
diff, so a push to `main` gets only `lint` from `lint.yaml`. Two practical consequences.
Searching the Actions UI for a check named after a workflow file will not find it. And a
`required_status_checks` rule — the fifth rule type `ggRandomForests` carries, described
below — has to name the **job**, so gating "R CMD check" there means naming the five matrix
legs individually.

## The rule that matters most

⚠️ **In the `table2023` vintage, the stratum code `"b"` does NOT mean Black.** It is a
risk-weighted average of Black, Asian, American Indian and Hispanic death rates, weighted by
number at risk — *despite the stratum code, and despite the macro's own comment saying
otherwise*. `VINTAGE_META` records this in `nonwhite_meaning`, and
`us_lifetable_vintages()` surfaces it.

Anything that reports a stratum to a reader — a table, a figure legend, a manuscript
sentence — must use `nonwhite_meaning`, not the code. Writing "Black" because the code says
`b` produces a **clinically wrong statement** that will survive review, because it looks
exactly like what everyone expects.

## Rules for this repo

- **`vintage` has no default and must be supplied.** That is deliberate: the vintages differ
  in how they name and construct the non-white category, so there is no safe default. Some
  entries in `VINTAGE_META` carry `usable = FALSE` and are deliberately not offered —
  `usable_vintages()` is the list, not `names(VINTAGE_META)`.
- **The year length is `365.2425`, not `365.241`.** From `usmatchd.sas:202-204`. The survival
  package uses the other constant elsewhere, and the difference is real; do not "correct" one
  to the other.
- **`data-raw/sas/` holds the original macros.** They are the parity reference. When a
  behaviour is in question, read the macro rather than reasoning from the R.
- **`data/us_lifetable_models.rda` is shipped fitted data.** Regenerating it via
  `data-raw/build-models.R` is a *data* change, not a code change: it alters what every
  downstream analysis gets. Say so explicitly in the PR, and check whether a vintage's
  stratum set moved.
- **`TemporalHazard` comes from GitHub, not CRAN.** This package Imports `>= 1.2.0` and CRAN
  carries an older release, so `DESCRIPTION` has
  `Remotes: TemporalHazard=ehrlinger/TemporalHazard` and every workflow pulls
  `github::ehrlinger/TemporalHazard` explicitly. Removing either breaks CI resolution.
- **`docs/` is PROSE here** — `docs/specs/` and `docs/plans/` are tracked design documents,
  not a generated site.
  ⚠️ **pkgdown's site goes to `pkgdown-site/`, and `destination:` in `_pkgdown.yml` is not
  enough on its own.** `pkgdown::build_site_github_pages()` takes `dest_dir = "docs"` as its
  default and **overrides** the config. The workflow passes `dest_dir` explicitly and its
  deploy step names the same folder; the two must agree. Getting this wrong deletes tracked
  design documents, which is why pkgdown refuses and errors instead.
- **Roxygen markdown is NOT enabled** — no `Roxygen: list(markdown = TRUE)` in `DESCRIPTION`,
  so use `\code{}`, `\strong{}`, `\emph{}` and `\link{}`.
- **`.lintr` disables three linters, each for a stated reason**: `object_name_linter`
  (`muE`/`muC`/`muL` are the Blackstone phase amplitudes and match the SAS parameter table),
  `commented_code_linter` (it flags mathematical notation such as
  `H(a) = muE * G(a) + muC * a + muL * G3(a)`), and `indentation_linter` (aligned-argument
  style). `line_length` is 100. `data-raw/` is excluded — developer scripts that never ship.
  Do not disable a fourth linter to reach green; fix the code, as was done for the brace and
  semicolon lints.
- **`testthat` edition 3.** Test files are `test-*.R` with a hyphen.

## Gotchas

- **The pkgdown site is live and its URL is in `DESCRIPTION`** (2026-08-24, 0.1.1). It was
  held out until then because `R CMD check --as-cran` fetches every `DESCRIPTION` URL and
  would report a 404 while the site was unpublished. `_pkgdown.yml` carries the same URL and
  the two must stay in sync.
  ⚠️ **A green `pkgdown` run is not evidence that the site serves.** The workflow deploys to the
  `gh-pages` branch and succeeds whether or not GitHub Pages is configured to serve it.
  Pages had never been enabled here, so every run was green from 2026-08-20 while the site
  returned 404 for four days. Check the site itself, not the workflow:

  ```
  curl -s -o /dev/null -w '%{http_code}\n' https://ehrlinger.github.io/hvtiRlifetables/
  ```
- **`object_usage_linter` over-reports until the package is installed.** 22 such lints
  disappeared once it was; CI installs, so they are an artifact locally rather than a defect.
- The package is **0.x** — the API is not frozen, but the vintage semantics above are not an
  API question.

## Git and versioning

- **Never push to `main`.** Branch, then open a PR and let the maintainer merge.
- **`main` is protected by a GitHub ruleset, and nothing in this repo records that.** A clone
  shows no trace of it, so it is stated here. The ruleset is named `protect main` and enforces
  **four** rules on the default branch: no deletion, no force-push, pull-request-only, and an
  **automatic Copilot code review** on every PR. A rejected push comes from the server, not a
  local hook.
  It requires **zero approvals**, and `require_code_owner_review` is set but inert because no
  repository in the family has a `CODEOWNERS` file.
  `require_extra_approval_for_unattributed_changes` is `true`; a `Co-Authored-By:` trailer does
  not trip it (measured on PR #9).
  ⚠️ **`required_review_thread_resolution` was `true` until 2026-08-21 and is now `false`.**
  Do not reason from an older note that says otherwise — including this file's own earlier
  wording, and the "five rules" phrasing that went with it. While it was on, a PR with nine
  green checks, `mergeable: MERGEABLE` and zero required approvals still sat at
  `mergeStateStatus: BLOCKED` until two Copilot threads were explicitly resolved (measured on
  PR #6), and replying to a thread did not resolve it. That failure mode is currently switched
  off family-wide. Re-read the live ruleset rather than trusting this paragraph if a merge is
  blocked for no visible reason:

  ```
  gh api repos/ehrlinger/<repo>/rulesets --jq '.[]|select(.name=="protect main")|.id'
  ```

  🔴 **The family is not uniform, despite what this file used to claim.** Measured 2026-08-24
  across the **fourteen** repositories carrying `protect main` (not twelve): `hvtiPlotR`,
  `hvtiRtables`, `hvtiRdatabuild`, `hvtiBoostmtree` and `TemporalHazard` have
  `require_code_owner_review` `false` where the rest have `true` — inert either way.
  `ggRandomForests` alone adds a fifth rule type, `required_status_checks`, gating on the three
  `R CMD check` platforms — kept deliberately, as that package's CRAN merge gate.
  **`bypass_actors` is now empty in all fourteen**, `current_user_can_bypass` is `never`, and
  nobody can push through the ruleset — maintainer included. That is a *change*, not a
  standing fact: `TemporalHazard` and `hvtiRtemplates` granted repository admins
  `bypass_mode: always` until 2026-08-24, when both were cleared to match the other twelve.
  Restoring either means re-adding
  `{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}`.

  If a review thread ever does need resolving — the setting can come back — the state lives
  where neither `gh pr view` nor `gh pr checks` shows it by default:

  ```
  gh api graphql -f query='{repository(owner:"ehrlinger",name:"<repo>"){pullRequest(number:<n>){
    reviewThreads(first:100){nodes{id isResolved isOutdated path}}}}}'
  ```

  `first:100` is the page maximum and is deliberate: a page size that silently truncates
  would let this query report "all resolved" while an unresolved thread sat past the cut —
  a false all-clear from the very diagnostic meant to prevent one.

  Resolve with the `resolveReviewThread` mutation, passing the id as a typed variable
  (`-F threadId=...`) — inlining a `PRRT_…` id in the query string fails to parse.
- Versions are **straight three digits** (`0.1.0`). Never a `.9000` suffix or a fourth digit.
- **Patch-digit bumps only**, as fixes land. Minor and major are the maintainer's decision.
- Bump `DESCRIPTION`, refresh its `Date`, and add the matching `NEWS.md` entry in the same
  commit.

## Change discipline

1. **Think before coding.** Do not assume, ask. Read `HANDOFF.md`'s "do not relitigate"
   section before proposing a design change — several were settled deliberately.
2. **Simplicity first.** Write the minimum that solves the stated problem.
3. **Surgical changes.** Touch only what the task requires. Raise nearby problems separately.
4. **Goal-driven execution.** State what done looks like before starting, and use tests as the
   criterion. For anything touching strata or vintages, "done" includes checking what a reader
   would conclude from the label.

## Prose

Documentation prose follows the house voice. This package's documentation has one obligation
above style: **never let a stratum code stand in for its meaning.** The `"b"` case above is the
reason.
