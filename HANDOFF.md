# hvtiRlifetables — session handoff

**Created:** 2026-08-13, from the AVR/LV-function survival study
session. **State:** implemented.
[`us_matched()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_matched.md),
[`us_lifetable_vintages()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_lifetable_vintages.md)
and
[`us_lifetable_model()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_lifetable_model.md)
are complete, with Tier 1, 2 and 4 tests passing and
`R CMD check --as-cran` at 0 errors, 0 warnings, and only the
unavoidable `New submission` note, with the manual. Tier 3 SAS
acceptance still needs writing, in the **study’s** `R_parity` project,
not here.

**Version `0.1.0`** (decided 2026-08-13). **Public repo** at
`github.com/ehrlinger/hvtiRlifetables` (decided 2026-08-14, superseding
“internal only”). The source `.sas7bdat` fits under `data-raw/uslife/`
were removed from git history and are `.gitignore`d — they remain on
disk, because the share is unreliable and they exist nowhere else off
it. The release gate applies in full: CRAN Cookbook audit and
`R CMD check --as-cran` **with** the manual.

**Known blocker:** `DESCRIPTION` requires `TemporalHazard (>= 1.2.0)`,
but CRAN is still at `1.1.0`. No clean machine can install this package,
and CI cannot go green, until `TemporalHazard 1.2.0` reaches CRAN. Do
not “fix” this by relaxing the bound — the evaluator needs the 1.2.0
API.

**Start here:** this is finished work, not a task queue. Read
`docs/specs/2026-08-13-hvtirlifetables-design.md` for background on what
the package is and why it exists, then
`docs/plans/2026-08-14-hvtirlifetables-implementation.md` (written
2026-08-14) for what was built and why. See “Task outline” below for
what actually remains.

------------------------------------------------------------------------

## What this package is

An R replacement for the CCF SAS macro `%usmatchd`, which produces
age/sex/race-matched US reference survival — the dashed line in Figure 1
of the `hs.*` job family.

The one-sentence surprise, established 2026-08-13: **`%usmatchd` is not
a life-table lookup. It is `PROC HAZPRED` evaluating a stored
three-phase HAZARD fit on the age axis.** So this is not a data package
carrying life tables; it ships ~27 small parameter blocks and a thin
`TemporalHazard` wrapper.
[`survival::survexp.usr`](https://rdrr.io/pkg/survival/man/survexp.us.html)
was tested across 12 vintage × interpolation combinations and cannot
substitute — details and numbers in the spec.

## What is already here

| Path | What | Provenance |
|----|----|----|
| `docs/specs/2026-08-13-*-design.md` | the design spec | written this session; the study tree holds a copy that should become a pointer |
| `data-raw/uslife/table{84,2008,2023}/` | 30 fitted-model `.sas7bdat` files | copied from `/Volumes/qhsstudies/general/uslife/<v>/estimates/` |
| `data-raw/sas/` | 5 `%usmatchd` macro variants | copied from `~/Documents/macro.library/` |
| `data-raw/spike-vintage-confirmation.R` | the working reproduction | reproduces this study’s `uslife.sas7bdat` to 6.2e-15 |

**The vendored copies are the point.** The fitted models exist nowhere
else off the share, and the share is an SMB mount that has already
proven unreliable this month. Everything needed to build the package is
now local. Note the `data-raw/uslife/` row above is on disk but not in
git — this repo is public, and those are CCF’s raw fitted blocks, so
they stay untracked and `.gitignore`d. What ships publicly is the
derived `data/us_lifetable_models.rda`, built from these by
`data-raw/build-models.R`.

`data-raw/uslife/` carries three files the package does not need —
`table2008/hzicall_jr`, `hzicall_l`, and `table84` extras are absent by
design (`hzall`, `hzcicall` were not copied). Only the nine
`hzic{all,f,m,w,o|b,wf,wm,of|bf,om|bm}` per vintage are in scope. The
manifest in `data-raw/build-models.R` names them explicitly rather than
globbing, because `table2008` also carries `hzicall_jr` and `hzicall_l`,
which no `%usmatchd` variant references.

## The three things that will bite

1.  **`_STATUS_` gates each phase.** `mu = exp(E0|C0|L0)` **only** when
    that row’s `_STATUS_ == 1`. `_STATUS_ == 0` means the phase is
    absent, not `log mu = 0`. `table84`‘s `hzicom`/`hzicof` have
    `C0 = 0, _STATUS_ = 0`; reading that as `mu = 1` gives a 1/yr hazard
    and zeroes those patients’ survival. Cost me a full debug cycle, and
    its cohort-level signature reads as “wrong vintage” rather than “one
    stratum is broken”.
2.  **`hzr_phase_cumhaz()` / `hzr_phase_hazard()` take
    `(time, t_half, nu, m, type)` directly — not an `hzr_phase` object**
    — and have no `"g3"` type. The late phase comes from
    `hzr_decompos_g3()`, returning `$G3` and `$g3`. Reading the
    `hzr_phase()` docs and inferring the evaluator signature from them
    is wrong; check [`args()`](https://rdrr.io/r/base/args.html).
3.  **`HZICB` in `table2023` is not Black.** Per Toth’s 2025-12-23
    header note it is a risk-weighted average of Black, Asian, American
    Indian and Hispanic rates, stored under `B` for naming consistency.
    The macro’s own comment (`usmatchd.sas:56-58`) still claims
    otherwise. `table84` names the same stratum honestly as `o`. Do not
    propagate the macro’s error into the R docs.

## Task outline

Steps 1-6 and 8 are **done** — see
`docs/plans/2026-08-14-hvtirlifetables-implementation.md`. Remaining:

1.  **Tier 3 SAS acceptance**, in the study’s `R_parity`:
    [`us_matched()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_matched.md)
    against `estimates/uslife.sas7bdat` to 1e-12 on both `SMATCHED` and
    `HMATCHED`, reported **per stratum**, skipping when the share is
    absent. A cohort-wide maximum hid the `_STATUS_` bug behind a
    plausible near-miss; do not report one.
2.  **CI**, once `TemporalHazard 1.2.0` reaches CRAN. Blocked until
    then.
3.  **The `hs.*` job template** that consumes
    [`us_matched()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_matched.md).
    Belongs in `hvtiRtemplates` / `~/Documents/template/`, not here.

## Two more things that will bite

Discovered during implementation; costly enough to find that a future
maintainer shouldn’t have to rediscover them.

4.  **`hzl_hazard()` errors at exactly age 0.** `TemporalHazard`’s early
    phase computes `exp(-bt^(-1/nu))` (underflows to 0) times `bt^num1`
    (overflows to `Inf`), giving `NaN`. This affects **9 of the 27**
    shipped strata. `H(0)` is unaffected. Every age above 0, down to
    1e-12, is finite and strictly positive in all 27.
5.  **The spec’s “THALF 0.0519 -\> 0.00544, NU 4.595 -\> -2.771” is
    `table84` -\> `table2008`**, which the original wording left
    unstated. `table2023` is structurally like 2008 but its white-male
    `NU` is **-2.000**, not -2.771. Pinned by
    `tests/testthat/test-vintage.R`.

## Decisions already made — do not relitigate

- Separate package, not a `hvtiRutilities` function. It versions on the
  life tables’ cadence: a CCF refit changes data without touching code,
  and reproducing a 2008 paper means pinning that paper’s vintage.
- `vintage` has **no default**. `%usmatchd`’s default silently moved
  `table84` -\> `table2023`; jobs re-run across that change got
  different numbers with no signal. The package refuses to guess.
- This study (AVR/LV-function) is `table84`, confirmed to 6.2e-15.
  `table2008` and `table2023` are excluded by two orders of magnitude.
- Covariance blocks ship in v1 but nothing reads them. Deliberate mild
  YAGNI violation — they are the only route to a confidence band later,
  and they cost bytes.

## Open — needs John or someone else

1.  ~~Initial version digit.~~ Resolved 2026-08-13: `0.1.0`.
2.  ~~May these CCF-fitted parameter blocks live in a repo?~~ Partly
    resolved 2026-08-14: public repo, source `.sas7bdat` untracked.
    **Still open:** `data/us_lifetable_models.rda` is now tracked and
    shipping in a public repo, carrying the same fitted numbers as the
    untracked `.sas7bdat` files. If the *values* are not publishable,
    stripping the `.sas7bdat` files did not solve the problem, and the
    data-distribution design needs revisiting for something already
    published, not something ahead of us. One question to CCF, asked
    promptly.
3.  **`table2009`** is an empty directory on the share. Never populated,
    or lost? One question to Andrew Toth.
4.  **Provenance of the 1984 fit** — no recorded source, author or NCHS
    release found anywhere. Worth having before a published figure leans
    on it.

## Sibling work in flight

`hvtiRtemplates` and `hvtiRutilities` are being built at the same time.
Two contact points to check before duplicating anything:

- `~/Documents/template/` is a local mirror of the CCF study skeleton
  (`analyses/ datasets/ descriptive/ distributions/ documents/ estimates/ graphs/`)
  — presumably what `hvtiRtemplates` will encode. The `hs.*` job
  template that consumes
  [`us_matched()`](https://ehrlinger.github.io/hvtiRlifetables/reference/us_matched.md)
  belongs there, not here.
- Note a change of direction: the 2026-08-12 decision was that templates
  live *inside* `hvtiRutilities` and `hvtiRtemplates` would not exist.
  John is now building it separately. Take the current direction; the
  note is only so the older reasoning is not mistaken for the live one.
