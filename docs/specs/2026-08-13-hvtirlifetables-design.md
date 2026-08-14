# hvtiRlifetables Design

**Status:** Implemented 2026-08-14, except Tier 3 acceptance (which lives in
the study's `R_parity`). Plan:
`docs/plans/2026-08-14-hvtirlifetables-implementation.md`.

**One deviation from this spec, deliberate.** The spec says `hmatched` is
returned in the units of `scale`. The macro's source says otherwise —
`usmatchd.sas:227` applies no `SCALEF` — and the implementation follows the
source. See the README.
**Date:** 2026-08-13
**Supersedes:** the `hvtiRlifetables` scoping note of 2026-08-12, which assumed a life-table data package. That assumption was wrong; see [Evidence](#evidence).

**Goal:** Reproduce the CCF SAS macro `%usmatchd` in R, so the nine `hs.*` jobs — age, race and sex-matched US reference survival, the dashed line in Figure 1 — can be rendered without SAS.

**Architecture:** A small R package shipping the *fitted model parameters* that `%usmatchd` evaluates, one set per vintage per stratum, plus a thin reader and a `predict()`-style wrapper over `TemporalHazard`.

**Tech stack:** R (>= 4.4), `TemporalHazard` (>= 1.2.0), `testthat`. `haven` in `data-raw/` only.

**Relocation:** this file lives here because the spike evidence and the acceptance fixture live in this study. It moves to `hvtiRlifetables/docs/specs/` when the repo is created, and this copy becomes a pointer.

---

## Global constraints

- **NO GIT in the study tree.** Inherited from `docs/plans/2026-08-12-r-hazard-job-templates.md`. This spec is written, not committed. Git applies normally in the `hvtiRlifetables` repo once it exists.
- **No PHI** in the package, its tests, or its fixtures. The parameter blocks are population life-table fits and contain none; the acceptance fixture does (see [Testing](#testing)).
- **No literal study path in package code.** Vintage data is shipped *inside* the package, not read from `/studies` at runtime. `data-raw/` may reference the share; `R/` may not.
- **Versioning:** initial version is **`0.1.0`** (decided 2026-08-13). Straight three digits, no `.9000`. Minor and major digits do not move without John; adding a vintage bumps the patch digit.
- **Visibility: public repo, fits untracked** (decided 2026-08-14, superseding the 2026-08-13 "internal only" decision). `github.com/ehrlinger/hvtiRlifetables` is public. The source `.sas7bdat` parameter blocks under `data-raw/uslife/` are **not tracked** — they were removed from git history on 2026-08-14 and are `.gitignore`d, while remaining on disk because the share is unreliable and they exist nowhere else off it. What ships publicly is the derived `data/us_lifetable_models.rda`.

  **Note the limit of this.** The `.rda` carries the same fitted numbers in a different container. Stripping the `.sas7bdat` files changes the format and the provenance trail, not the confidentiality of the values. If the fitted parameters themselves must not be public, the `.rda` cannot ship either and the package needs a different data-distribution design. That question is not settled by this decision.

---

## Problem

`%usmatchd` produces, for each patient, a reference survival curve `SMATCHED(t)` matched on age, sex and race, plus its hazard `HMATCHED(t)`. Nine `hs.*` jobs in this study consume it. There is no R equivalent.

Two things were assumed on 2026-08-12 and both were wrong:

1. That `%usmatchd` looks up a life table. It does not.
2. That `survival::survexp.usr` supplies most of the machinery. It supplies none of it.

## Evidence

Read from `/Volumes/qhsprograms/apps/sas/macro.library/usmatchd.sas` and confirmed numerically 2026-08-13.

### What the macro actually does

`%usmatchd` runs `PROC HAZPRED` against a **stored fitted three-phase HAZARD model**, `INHAZ=USLIFE84.HZICWM` and siblings, evaluated on the **age axis** — time origin is birth, not surgery:

```
AGESURV  = _SURVIV  evaluated at  TIME AGE          (survival birth -> current age)
SMATCHED = _SURVIV / AGESURV  evaluated at  TIME AGE_YR,  AGE_YR = AGE + t
HMATCHED = _HAZARD  evaluated at  TIME AGE_YR
```

So `SMATCHED` is conditional survival read off one smooth parametric curve, evaluated twice. That is why its hazard is smooth *within* a one-year age bin (0.037274 -> 0.037496 across 0.067 yr for a 70-year-old white male) where a life table would be flat.

### Why `survexp.usr` cannot substitute

Twelve combinations were tested — vintages 1975–2000 × {step, log-linear at bin edge, log-linear at bin midpoint}. Best individual-curve error in every combination: max |S| difference **0.09 to 0.11**. The median hazard ratio can be tuned to 1.000 by choosing a vintage, but the error has an age tilt no vintage removes (ratio 1.28 at age <= 50 falling to 0.89 at 85+).

The reason is structural, not a data disagreement: there is no table on the R side of that comparison. CCF's object is a parametric fit, and the tilt is that fit's shape.

**One trap for anyone re-running this:** at 1980 + step interpolation the *cohort mean* 10-year survival agrees to +0.0017. That is an averaging coincidence — individual curves under the same setting are off by up to 0.11. A mean-curve check passes here and means nothing.

### Vintages on disk

`/Volumes/qhsstudies/general/uslife/<vintage>/estimates/`:

| Vintage | Macro entry point | Strata files | Notes |
|---|---|---|---|
| `table84` | `usmatchd84.sas`, `usmatchd10172003.sas` | `hzic{all,f,m,w,o,wf,wm,of,om}` | non-white named `o` = other |
| `table2008` | `usmtch08.sas` | `hzic{all,f,m,w,b,wf,wm,bf,bm}` | non-white named `b` |
| `table2009` | — | **directory is empty** | not usable |
| `table2023` | `usmatchd.sas` (current default) | `hzic{all,f,m,w,b,wf,wm,bf,bm}` | non-white named `b`; see below |

Nine strata per vintage, matching the macro's four `TABLE=` modes: `OVERALL` -> `all`; `SEX` -> `f`, `m`; `RACE` -> `w`, `o`/`b`; `SEXRACE` -> `wf`, `wm`, `of`/`bf`, `om`/`bm`. (`table84` also carries `hzall`, `hzcicall`; `table2008` also carries `hzicall_jr`, `hzicall_l`, `pemldall`, `pemlstro`. These are not referenced by any `%usmatchd` variant and do not ship.)

Vintages are not interchangeable. Model *structure* differs, not just fitted values — white male `G1FLAG` 2 -> 6, `G3FLAG` 4 -> 3, `THALF` 0.0519 -> 0.00544, `NU` 4.595 -> -2.771.

**Correction, 2026-08-14:** that arrow is `table84` -> **`table2008`**, which the original wording left unstated. `table2023` is structurally like 2008 — same flags, `THALF` 0.005437 — but its white-male `NU` is **-2.000**, not -2.771. All three are distinct fits. Verified directly against the shipped blocks; pinned by `test-vintage.R`.

### The vintage list grows

CCF refits the life tables periodically — `table2023` was added by Andrew Toth on 2025-12-23. New vintages will land, and each one changes data without touching code. **This is the property that justifies a separate package**, and it has two design consequences:

- `data-raw/build-models.R` is a maintained entry point, not a one-off migration script. Adding a vintage must be: drop the new `estimates/` directory path into a manifest, re-run, bump the patch digit, ship.
- **The default vintage must never track "latest".** `usmatchd.sas` silently re-pointed its default from `table84` to `table2023`, and any job that re-ran across that change got different numbers with no signal. That is exactly how a published figure quietly becomes irreproducible. See [Vintage policy](#vintage-policy).

### This study's vintage: `table84`

Confirmed against `estimates/uslife.sas7bdat` (3,049 patients × 151 grid points, 0–10 yr):

| Vintage | AGESURV max abs diff | HMATCHED(t=0) max abs diff | SMATCHED(10 yr) max abs diff |
|---|---|---|---|
| **table84** | **7.8e-16** | **1.7e-16** | **2.2e-15** |
| table2008 | 1.3e-01 | 1.9e-01 | 1.3e-01 |
| table2023 | 2.4e-01 | 2.1e-01 | 2.1e-01 |

Full 151-point curve at `table84`: `SMATCHED` max abs diff **6.2e-15**, `HMATCHED` max abs diff **3.0e-15**, cohort mean at 10 yr matching to `0` in double precision. That is accumulated machine epsilon — identity, not agreement.

### The `_STATUS_` rule

Each `hzic*.sas7bdat` is 17 rows × 14 columns: six flag rows (`G1FLAG`, `FIXDEL0`, `FIXMNU1`, `G3FLAG`, `FIXGE2`, `FIXGAE2`), then eleven parameter rows (`DELTA`, `THALF`, `NU`, `M`, `TAU`, `GAMMA`, `ALPHA`, `ETA`, `E0`, `C0`, `L0`). Columns 4–14 are the 11 × 11 covariance block.

**`mu = exp(E0 | C0 | L0)` only when that row's `_STATUS_ == 1`. `_STATUS_ == 0` means the phase is absent from the model, not `log mu = 0`.**

This is the single most dangerous detail in the port. `table84`'s other-race strata (`hzicom`, `hzicof`) carry `C0 = 0` with `_STATUS_ = 0`. Reading that as `mu = exp(0) = 1` injects a constant hazard of 1/yr and drives those patients' survival to zero.

It fails loudly — but its whole-cohort signature is misleading. With 206 of 3,049 patients affected, the cohort mean at 10 yr moves by 0.035, which reads as "close, wrong vintage" rather than "one stratum is catastrophically broken". Per-stratum error reporting is what names it. This is the study's recurring "result-shaped nothing" pattern in its plausible-near-miss form.

`G1FLAG` and `G3FLAG` are inert for evaluation. They record which sub-form was fitted; the shape parameters plus `_STATUS_` fully determine the curve. They ship as metadata, and are not read by the evaluator.

### Race semantics

`table84` names its non-white strata `hzico*` — honestly "other". `table2008` and `table2023` name the same strata `hzicb*`, and the macro comment at `usmatchd.sas:56-58` still asserts these are Black-race estimates.

For 2023 that comment is **false**. Per Andrew Toth's header note dated 2025-12-23, the 2023 "other" category is a risk-weighted average of Black, Asian, American Indian and Hispanic death rates, weighted by number at risk, stored under `B` "to keep the macro naming consistent."

`HZICB` in 2023 is not Black. The package must not propagate that error.

---

## Design

### What ships

Nine parameter sets × three usable vintages = 27 records. Each is 17 named numbers plus an 11 × 11 covariance matrix. Kilobytes total.

Stored as a single `data/us_lifetable_models.rda`: a data frame keyed `vintage`, `stratum`, with list-columns `params` (named numeric), `status` (named integer), `vcov` (11 × 11 matrix). Built by `data-raw/build-models.R`, which reads the `.sas7bdat` files from the share with `haven` and is **not** run at install time.

Shipping the covariance block costs almost nothing and is the only route to a confidence band on the reference curve later. It is not used by v1.

### Public API

```r
us_matched(age, male, other, times,
           id         = seq_along(age),
           vintage    = "table84",
           table      = c("sexrace", "race", "sex", "overall"),
           scale      = c("years", "months", "days"),
           individual = TRUE)
```

`age` in years; `male` 1 = male, 0 = female; `other` 1 = non-white, 0 = white — the macro's coding, unchanged. All three are per-patient vectors of equal length.

Returns a data frame with `id`, `time`, `agesurv`, `smatched`, `hmatched` when `individual = TRUE`; when `FALSE`, one row per time with `smatched` and `hmatched` only, via the mean-curve reduction below.

Argument names and the `table=` modes mirror `%usmatchd` so a SAS job translates by inspection. `table=` selects how finely patients are stratified, exactly as in the macro: `"overall"` sends every patient to `all` and ignores `male` and `other`; `"sex"` uses `f`/`m`; `"race"` uses `w` and the vintage's non-white stratum; `"sexrace"` uses all four crossings.

```r
us_lifetable_vintages()          # available vintages, with provenance and race semantics
us_lifetable_model(vintage, stratum)   # the raw parameter set, for inspection
```

### Vintage policy

`vintage` has **no default**. Omitting it is an error that lists the available vintages and says which one the caller probably wants.

This is deliberate friction, and it is the package's main value over calling the macro. `%usmatchd`'s default moved from `table84` to `table2023` and every job that re-ran across that change silently got different numbers. An analysis that does not state its vintage is not reproducible, so the package refuses to guess.

`us_lifetable_vintages()` returns, per vintage: the identifier, the source `estimates/` path, the strata present, the non-white stratum's actual composition (see [Race semantics](#race-semantics)), and the date the fits were added where known. Adding a vintage bumps the **patch** digit — new data, no new API.

Corollary for the study jobs: every `hs.*` document states `vintage = "table84"` literally, with a comment naming this spec. A reader must be able to see which reference population a figure used without running anything.

### Evaluation

Three additive phases on the age axis, using `TemporalHazard` exports only:

```
H(a) = muE * hzr_phase_cumhaz(a, THALF, NU, M, type = "cdf")
     + muC * a
     + muL * hzr_decompos_g3(a, TAU, GAMMA, ALPHA, ETA)$G3

h(a) = muE * hzr_phase_hazard(a, THALF, NU, M, type = "cdf")
     + muC
     + muL * hzr_decompos_g3(a, TAU, GAMMA, ALPHA, ETA)$g3

agesurv     = exp(-H(age))
smatched(t) = exp(-(H(age + t) - H(age)))
hmatched(t) = h(age + t)
```

with `muX = if (status[["X0"]] == 1) exp(params[["X0"]]) else 0`.

Note the API shapes: `hzr_phase_cumhaz()` and `hzr_phase_hazard()` take `(time, t_half, nu, m, type)` **directly, not an `hzr_phase` object**, and they have no `"g3"` type — the late phase comes from `hzr_decompos_g3()`, which returns `$G3` and `$g3`.

### Mean curves (`individual = FALSE`)

The macro's default. Reproduce its arithmetic exactly, from `usmatchd.sas:338-350`: convert hazard to a density (`HMATCHED * SMATCHED`), take the cohort mean of `SMATCHED` and of the density at each time, then divide to recover a mean hazard. Not the mean of the hazards.

### Units

`scale` applies `SCALEF` of `1`, `1/12`, `1/365.2425`, matching `usmatchd.sas:202-204`. `times` and the returned `hmatched` are in the units of `scale`; `age` is always in years. Note the macro's `365.2425`, which is not the `365.241` used elsewhere in `survival`.

### Module boundaries

| File | Responsibility | Depends on |
|---|---|---|
| `R/models.R` | accessors over the shipped data; vintage/stratum resolution; `_STATUS_` gating | data only |
| `R/evaluate.R` | `H(a)`, `h(a)` from one parameter set | `TemporalHazard` |
| `R/us_matched.R` | stratum assignment, grid construction, conditioning, mean-curve reduction | the two above |
| `data-raw/build-models.R` | share -> `.rda`; **not shipped** | `haven` |

`R/evaluate.R` knows nothing about patients, strata or vintages — it takes eleven numbers and a time vector. That is the unit worth testing hardest.

### Error handling

Fail loudly, per the study's standing lesson:

- Unknown `vintage` or `stratum` — error listing what is available. Never fall back to a default vintage.
- `table2009` — error naming it as empty on disk, not "not found".
- A stratum whose `E0`, `C0` and `L0` all have `_STATUS_ != 1` — error. A model with no phases is not a valid model.
- `age < 0` or `age + max(times) > 110` — error; the fits are not extrapolated beyond the life table's support.
- **`assert_varies()`**: the returned `smatched` must not be constant across `times`, and must not be identically 1 or 0. A reference curve that does not move is the failure shape this study has now hit five times.

### Testing

**Tier 1 — invariants, no fixture.** `smatched(0) == 1`; monotone non-increasing in `t`; `hmatched > 0`; conditioning identity `S(t1 + t2 | age) == S(t1 | age) * S(t2 | age + t1)`; `individual = FALSE` reduces to the documented density arithmetic.

**Tier 2 — the `_STATUS_` regression.** Evaluate `table84` / `om` and assert `muC == 0`. Assert directly that a phase with `_STATUS_ == 0` contributes zero, so the trap cannot silently return.

**Tier 3 — SAS acceptance, per-stratum.** Against `estimates/uslife.sas7bdat`: `SMATCHED` and `HMATCHED` to **1e-12** (the spike achieved 6.2e-15; 1e-12 leaves headroom without accepting a real regression). Errors reported **per stratum**, never as a single cohort-wide maximum — a cohort statistic hid the `_STATUS_` bug behind a plausible near-miss.

Tier 3 needs patient ages and so is PHI-adjacent. It does not ship in the package. It lives in this study's `R_parity` project and is skipped when the share is absent, following the existing `skip_if_not(file.exists(...))` convention.

**Tier 4 — vintage discrimination.** Assert `table2008` and `table2023` do *not* reproduce this study's fixture. Guards against a future refactor quietly defaulting the vintage: passing Tier 3 while ignoring `vintage=` is otherwise undetectable.

---

## Out of scope (v1)

- Confidence bands on the reference curve. The covariance blocks ship; nothing reads them.
- Re-fitting new vintages from NCHS data. The package distributes CCF's existing fits; it does not reproduce the fitting.
- `survexp.usr` interoperability or a translation layer, **for v1**. Not closed as a direction - see Future work.
- The 31 `uslife*.sas7bdat` stratum outputs in this study's `estimates/`. They are this study's `%usmatchd` results, reproducible from the package, and are not package data.

## Future work - an ecosystem-based approximation

The 2026-08-13 spike established that `survival::survexp.usr` **cannot reproduce
`%usmatchd`**, and that finding stands: twelve vintage x interpolation
combinations, best individual-curve error 0.09-0.11 in every one, with an age
tilt (ratio 1.28 at age <= 50 falling to 0.89 at 85+) that no vintage removes.
The reason is structural rather than a data disagreement - CCF's object is a
fitted parametric three-phase hazard evaluated on the age axis, so there is no
table on the R side of the comparison.

**What that closed was substitution, not the direction.** Reopened as future
work, because an approximation has uses exact reproduction does not:

1. **A documented approximation mode** for anyone without access to CCF's fitted
   `.sas7bdat` blocks - collaborators, external reviewers, or a public release of
   downstream methods. It would carry the measured error as a stated bound, never
   as a default.
2. **Interoperability**, letting a curve produced here be compared against
   `survexp` output on the same axes, which is what a reviewer asking "why not
   just use `survexp`?" actually needs to see.
3. **Revisiting if the ecosystem changes.** The gap is that R has no parametric
   US reference fit. If one appears, the comparison is worth re-running.

**Two traps for whoever picks this up.** Both cost the original spike time:

- A **cohort-mean check passes and means nothing.** At 1975-2000 vintage with
  step interpolation the cohort mean 10-year survival agrees to +0.0017 while
  individual curves are off by up to 0.11. Validate per-curve, per-stratum.
- The error is **not a constant offset** and cannot be calibrated away by
  choosing a vintage. The median hazard ratio can be tuned to 1.000; the age
  tilt remains.

Scope, acceptance bounds, and whether an approximation belongs in this package
at all are undecided. This is a direction, not a plan.

## Open questions

1. ~~Initial version.~~ **Resolved 2026-08-13: `0.1.0`.**
2. ~~Repo location and visibility.~~ **Resolved 2026-08-14: public at `github.com/ehrlinger/hvtiRlifetables`, source `.sas7bdat` fits untracked.** Supersedes the 2026-08-13 "internal only" resolution. See Global constraints, including the caveat that this does not by itself make the fitted *values* publishable.
3. **`table2009`.** Empty on disk. Whether a copy exists elsewhere, or the directory was never populated, is unresolved — worth one question to Andrew Toth before the package documents it as unavailable.
4. **Provenance of each vintage's underlying NCHS release.** The fits are dated by directory name (`table84`, `table2008`, `table2023`) and the 2023 fit has a documented author and date. The 1984 fit's source and author are not recorded anywhere found. Citable provenance would be worth having before anyone publishes a figure that leans on it.

## Success criteria

1. `us_matched()` reproduces `estimates/uslife.sas7bdat` to 1e-12 on both `SMATCHED` and `HMATCHED`, checked per stratum.
2. `table2008` and `table2023` demonstrably fail that same check.
3. `R CMD check --as-cran` with the manual: 0/0/0.
4. A `hs.*` job renders in `R_hazard` with no SAS and no read from `/studies/general/uslife`.
