# hvtiRlifetables Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `us_matched()`, an R replacement for the Cleveland Clinic SAS macro `%usmatchd`, reproducing its age/sex/race-matched US reference survival to 1e-12.

**Architecture:** `%usmatchd` is not a life-table lookup — it is `PROC HAZPRED` evaluating a stored three-phase parametric hazard fit on the **age** axis, time origin birth. So the package ships ~27 small fitted-parameter blocks as `data/us_lifetable_models.rda` and evaluates them through `TemporalHazard`. Three layers, strictly one-directional: `R/evaluate.R` (eleven numbers → a curve, knows nothing about patients) ← `R/models.R` (data accessors, vintage/stratum resolution) ← `R/us_matched.R` (patients, strata, scale, reductions).

**Tech Stack:** R (>= 4.4.0), `TemporalHazard` (>= 1.2.0), `testthat` (3rd edition). `haven` in `data-raw/` only.

**Source spec:** [`docs/specs/2026-08-13-hvtirlifetables-design.md`](../specs/2026-08-13-hvtirlifetables-design.md). Read it before Task 1. This plan does not restate its evidence.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **R >= 4.4.0**; `TemporalHazard >= 1.2.0`; `testthat >= 3.0.0`, edition 3.
- **Version stays `0.1.0` for the whole plan.** Do not bump any digit. Minor and major digits are John's call alone; the patch digit moves only when a vintage is added, which this plan does not do.
- **No literal study or share path in `R/`.** `data-raw/` may reference `/Volumes/...`; `R/` may not. Shipped data is read from the package, never from disk at runtime.
- **No PHI** in the package, its tests, or its fixtures. Tier 3 SAS acceptance is PHI-adjacent and does **not** ship — it lives in the study's `R_parity`.
- **`vintage` has no default.** Omitting it is an error. Never fall back.
- **Fail loudly.** No silent coercion, no fallback vintage, no `NA` returned where an error belongs.
- **`data-raw/uslife/` is gitignored** (public repo). It is present on disk. Never `git add` it.
- **Function naming:** exported functions are `us_*`; internal helpers are `hzl_*` and are not exported.
- **Every exported object needs `@return`** (roxygen). Release gate depends on it.
- **Commit after every task.** Branch from `main` per John's git rules; never commit to `main` directly.

### Known blocker, not caused by this plan

CRAN's `TemporalHazard` is **1.1.0**; `DESCRIPTION` requires `>= 1.2.0`. Local development works (1.2.0 is installed). CI cannot go green and no clean machine can install the package until 1.2.0 reaches CRAN. **Do not relax the bound** — `hzr_decompos_g3()` is needed. Task 8 defers CI for this reason.

### Verified API facts — do not re-derive these

Confirmed by `args()` on 2026-08-14. HANDOFF.md warns that inferring these from the `hzr_phase()` docs gives the wrong answer.

```r
hzr_phase_cumhaz(time, t_half = 1, nu = 1, m = 0, type = c("cdf", "hazard", "constant"))
hzr_phase_hazard(time, t_half = 1, nu = 1, m = 0, type = c("cdf", "hazard", "constant"))
hzr_decompos_g3(time, tau, gamma, alpha, eta)   # returns list(G3 = , g3 = )
```

They take parameters **directly, not an `hzr_phase` object**, and have **no `"g3"` type**. All three are vectorized over `time`.

### The `_STATUS_` rule — the single most dangerous detail

```
mu = exp(E0 | C0 | L0)   ONLY when that row's _STATUS_ == 1
_STATUS_ == 0 means the phase is ABSENT, not log(mu) = 0.
```

`table84/hzicom` and `hzicof` carry `C0 = 0` with `_STATUS_ = 0`. Reading that as `mu = exp(0) = 1` injects a constant hazard of 1/yr and drives those patients' survival to zero. Its cohort-level signature is a plausible near-miss (mean at 10 yr moves 0.035), which reads as "wrong vintage" rather than "one stratum is broken". Task 2 pins it; Task 3 pins it again at the evaluator.

**Second trap, found 2026-08-14:** the six flag rows (`G1FLAG`, `FIXDEL0`, `FIXMNU1`, `G3FLAG`, `FIXGE2`, `FIXGAE2`) carry `_STATUS_ = NA`, not `0`. A naive `status == 1` over all 17 rows yields `NA`, not `FALSE`. Task 1 stores flags separately from parameters so this cannot arise downstream.

### Open question this plan must not silently resolve

**Is `hmatched` scaled by `scale=`?** The design spec says yes. The macro source says no: `usmatchd.sas:227` is `&HMATCHED=_HAZARD;` with no `SCALEF` multiplication, and `PROC HAZPRED` is evaluated at `AGE_YR` in years — so the returned hazard is per-year regardless of `scale=`. The macro's own header comment at line 47 claims the opposite. It has never mattered because the study uses `scale="years"` (`SCALEF = 1`).

**This plan implements the macro source, not the spec or the comment** — `hmatched` is per-year always — because bit-fidelity to the macro is the acceptance criterion. Task 6 pins it with a test and documents it loudly. Flag it to John at the Task 6 checkpoint; if he wants the spec's behaviour, it is a one-line change plus a doc change, not a redesign.

---

## File Structure

| Path | Responsibility | Depends on | Ships |
|---|---|---|---|
| `data-raw/build-models.R` | share/`data-raw` → `.rda`; explicit manifest, maintained entry point | `haven` | no |
| `data/us_lifetable_models.rda` | 27 fitted parameter sets | — | yes |
| `R/data.R` | roxygen docs for the shipped dataset | — | yes |
| `R/models.R` | accessors, vintage/stratum resolution, `_STATUS_` gating | data only | yes |
| `R/evaluate.R` | `H(a)`, `h(a)` from one parameter set | `TemporalHazard` | yes |
| `R/us_matched.R` | stratum assignment, conditioning, `scale`, mean-curve reduction | the two above | yes |
| `R/hvtiRlifetables-package.R` | package-level docs (**exists**) | — | yes |
| `tests/testthat/test-models.R` | Tier 2 `_STATUS_` regression, accessors | | |
| `tests/testthat/test-evaluate.R` | Tier 1 invariants — **the unit tested hardest** | | |
| `tests/testthat/test-us-matched.R` | API, strata, scale, errors | | |
| `tests/testthat/test-mean-curve.R` | the density arithmetic | | |
| `tests/testthat/test-vintage.R` | Tier 4 vintage discrimination | | |

`R/evaluate.R` knows nothing about patients, strata or vintages. Keep it that way — it takes eleven numbers and a time vector, and it is the layer where a bug is cheapest to find.

---

## Task 1: Build and ship the fitted parameter blocks

**Files:**
- Create: `data-raw/build-models.R`
- Create: `data/us_lifetable_models.rda` (generated)
- Create: `R/data.R`
- Test: `tests/testthat/test-data.R`
- Modify: `DESCRIPTION` (re-add `LazyData: true`, dropped in the skeleton because `data/` did not exist)

**Interfaces:**
- Consumes: nothing.
- Produces: dataset `us_lifetable_models`, a data frame with 27 rows and columns
  `vintage` (character), `stratum` (character), `params` (list of named numeric length 11),
  `status` (list of named integer length 11), `flags` (list of named numeric length 6),
  `vcov` (list of 11×11 numeric matrix). `params`/`status`/`vcov` names and dimnames are
  `DELTA THALF NU M TAU GAMMA ALPHA ETA E0 C0 L0` in that order.

**Why the manifest is explicit and not a glob:** `table2008` on disk also carries `hzicall_jr` and `hzicall_l`, which no `%usmatchd` variant references and which must not ship. Globbing would pick them up. Adding a vintage means editing this manifest — that is the intended maintenance action.

- [ ] **Step 1: Write the failing test**

Create `tests/testthat/test-data.R`:

```r
test_that("us_lifetable_models has 27 records, nine strata per vintage", {
  expect_s3_class(us_lifetable_models, "data.frame")
  expect_equal(nrow(us_lifetable_models), 27L)
  expect_setequal(
    unique(us_lifetable_models$vintage),
    c("table84", "table2008", "table2023")
  )
  expect_true(all(table(us_lifetable_models$vintage) == 9L))
})

test_that("table84 names its non-white strata 'o', 2008 and 2023 name them 'b'", {
  s84 <- sort(us_lifetable_models$stratum[us_lifetable_models$vintage == "table84"])
  expect_equal(s84, sort(c("all", "f", "m", "w", "o", "wf", "wm", "of", "om")))

  s23 <- sort(us_lifetable_models$stratum[us_lifetable_models$vintage == "table2023"])
  expect_equal(s23, sort(c("all", "f", "m", "w", "b", "wf", "wm", "bf", "bm")))
})

test_that("the excluded 2008 extras did not sneak in via a glob", {
  expect_false(any(grepl("_jr|_l$", us_lifetable_models$stratum)))
})

test_that("each record carries 11 parameters, 11 statuses, 6 flags, an 11x11 vcov", {
  nm <- c("DELTA", "THALF", "NU", "M", "TAU", "GAMMA", "ALPHA", "ETA",
          "E0", "C0", "L0")
  for (i in seq_len(nrow(us_lifetable_models))) {
    expect_equal(names(us_lifetable_models$params[[i]]), nm)
    expect_equal(names(us_lifetable_models$status[[i]]), nm)
    expect_length(us_lifetable_models$flags[[i]], 6L)
    expect_equal(dim(us_lifetable_models$vcov[[i]]), c(11L, 11L))
    expect_equal(dimnames(us_lifetable_models$vcov[[i]]), list(nm, nm))
  }
})

test_that("status is integer 0/1 with no NA -- the flag rows were separated out", {
  for (i in seq_len(nrow(us_lifetable_models))) {
    st <- us_lifetable_models$status[[i]]
    expect_type(st, "integer")
    expect_false(anyNA(st))
    expect_true(all(st %in% c(0L, 1L)))
  }
})

test_that("the table84 'om' _STATUS_ trap survived the build", {
  # C0 = 0 with _STATUS_ = 0. If a future build coerces this to status 1,
  # every non-white male gets a constant 1/yr hazard and their survival
  # collapses. See the plan's Global Constraints.
  i <- which(us_lifetable_models$vintage == "table84" &
             us_lifetable_models$stratum == "om")
  expect_length(i, 1L)
  expect_equal(unname(us_lifetable_models$params[[i]][["C0"]]), 0)
  expect_equal(unname(us_lifetable_models$status[[i]][["C0"]]), 0L)
  expect_equal(unname(us_lifetable_models$status[[i]][["E0"]]), 1L)
  expect_equal(unname(us_lifetable_models$status[[i]][["L0"]]), 1L)
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "data")'`
Expected: FAIL — `object 'us_lifetable_models' not found`.

- [ ] **Step 3: Write the build script**

Create `data-raw/build-models.R`:

```r
## Build data/us_lifetable_models.rda from CCF's fitted .sas7bdat blocks.
##
## MAINTAINED ENTRY POINT, not a one-off migration. CCF refits the US life
## tables periodically -- table2023 was added by Andrew Toth on 2025-12-23.
## Adding a vintage is: drop its directory into data-raw/uslife/, add a row
## to MANIFEST below, re-run this script, bump the PATCH digit, ship.
##
## Run from the package root:  Rscript data-raw/build-models.R
##
## data-raw/uslife/ is gitignored -- the blocks are CCF's and the repo is
## public. They are on disk deliberately: the /Volumes/qhsstudies share is
## unreliable and these files exist nowhere else off it. If they are missing,
## re-copy from /Volumes/qhsstudies/general/uslife/<vintage>/estimates/.

library(haven)

SRC <- "data-raw/uslife"

## The eleven fitted parameters, in the order the .sas7bdat rows carry them.
## This order is also the row/column order of the covariance block.
PARAM_NAMES <- c("DELTA", "THALF", "NU", "M", "TAU", "GAMMA", "ALPHA", "ETA",
                 "E0", "C0", "L0")

## The six leading rows are fitted-form flags, not parameters. They carry
## _STATUS_ = NA. They ship as metadata and are never read by the evaluator:
## the shape parameters plus _STATUS_ fully determine the curve.
FLAG_NAMES <- c("G1FLAG", "FIXDEL0", "FIXMNU1", "G3FLAG", "FIXGE2", "FIXGAE2")

## EXPLICIT manifest. Do NOT replace with list.files() -- table2008 on disk
## also carries hzicall_jr and hzicall_l, which no %usmatchd variant
## references and which must not ship.
MANIFEST <- list(
  table84   = c(all = "hzicall", f  = "hzicf",  m  = "hzicm",
                w   = "hzicw",   o  = "hzico",
                wf  = "hzicwf",  wm = "hzicwm", of = "hzicof", om = "hzicom"),
  table2008 = c(all = "hzicall", f  = "hzicf",  m  = "hzicm",
                w   = "hzicw",   b  = "hzicb",
                wf  = "hzicwf",  wm = "hzicwm", bf = "hzicbf", bm = "hzicbm"),
  table2023 = c(all = "hzicall", f  = "hzicf",  m  = "hzicm",
                w   = "hzicw",   b  = "hzicb",
                wf  = "hzicwf",  wm = "hzicwm", bf = "hzicbf", bm = "hzicbm")
)

read_block <- function(vintage, file) {
  path <- file.path(SRC, vintage, paste0(file, ".sas7bdat"))
  if (!file.exists(path)) {
    stop("missing fitted block: ", path,
         "\nRe-copy from /Volumes/qhsstudies/general/uslife/", vintage,
         "/estimates/", call. = FALSE)
  }
  d <- as.data.frame(read_sas(path))
  rownames(d) <- d[["_NAME_"]]

  if (!all(PARAM_NAMES %in% rownames(d))) {
    stop(path, " is missing parameters: ",
         paste(setdiff(PARAM_NAMES, rownames(d)), collapse = ", "),
         call. = FALSE)
  }
  if (!all(FLAG_NAMES %in% rownames(d))) {
    stop(path, " is missing flags: ",
         paste(setdiff(FLAG_NAMES, rownames(d)), collapse = ", "),
         call. = FALSE)
  }

  status <- as.integer(d[PARAM_NAMES, "_STATUS_"])
  names(status) <- PARAM_NAMES
  ## Loud, because a silent NA here is the _STATUS_ trap in a new disguise.
  if (anyNA(status)) {
    stop(path, " has NA _STATUS_ on a parameter row: ",
         paste(PARAM_NAMES[is.na(status)], collapse = ", "), call. = FALSE)
  }
  if (!all(status %in% c(0L, 1L))) {
    stop(path, " has _STATUS_ outside {0, 1}", call. = FALSE)
  }

  params <- as.numeric(d[PARAM_NAMES, "_EST_"])
  names(params) <- PARAM_NAMES

  flags <- as.numeric(d[FLAG_NAMES, "_EST_"])
  names(flags) <- FLAG_NAMES

  ## Columns 4-14 of the parameter rows are the 11 x 11 covariance block.
  ## Nothing in v1 reads it. It ships because it is the only route to a
  ## confidence band later and it costs bytes.
  vcov <- as.matrix(d[PARAM_NAMES, PARAM_NAMES])
  storage.mode(vcov) <- "double"
  dimnames(vcov) <- list(PARAM_NAMES, PARAM_NAMES)

  list(params = params, status = status, flags = flags, vcov = vcov)
}

rows <- list()
for (vintage in names(MANIFEST)) {
  files <- MANIFEST[[vintage]]
  for (stratum in names(files)) {
    b <- read_block(vintage, files[[stratum]])
    rows[[length(rows) + 1L]] <- data.frame(
      vintage = vintage,
      stratum = stratum,
      params  = I(list(b$params)),
      status  = I(list(b$status)),
      flags   = I(list(b$flags)),
      vcov    = I(list(b$vcov)),
      stringsAsFactors = FALSE
    )
  }
}

us_lifetable_models <- do.call(rbind, rows)
rownames(us_lifetable_models) <- NULL

stopifnot(nrow(us_lifetable_models) == 27L)

save(us_lifetable_models,
     file = "data/us_lifetable_models.rda",
     compress = "xz", version = 3)

cat("wrote data/us_lifetable_models.rda:",
    nrow(us_lifetable_models), "records,",
    format(file.size("data/us_lifetable_models.rda")), "bytes\n")
```

- [ ] **Step 4: Run the build script**

```bash
mkdir -p data && Rscript data-raw/build-models.R
```

Expected: `wrote data/us_lifetable_models.rda: 27 records, <N> bytes`. Any `missing fitted block` error means `data-raw/uslife/` is not populated — restore it before continuing.

- [ ] **Step 5: Re-add `LazyData` to DESCRIPTION**

The skeleton dropped it because `data/` did not exist. Add this line after `Config/testthat/edition: 3`:

```
LazyData: true
```

- [ ] **Step 6: Document the dataset**

Create `R/data.R`:

```r
#' Fitted US life-table hazard model parameters
#'
#' The fitted three-phase parametric hazard models that the Cleveland Clinic
#' SAS macro `%usmatchd` evaluates, one record per vintage per stratum. These
#' are fitted models, not life tables: `%usmatchd` runs `PROC HAZPRED` against
#' a stored fit on the **age** axis, with time origin at birth.
#'
#' @format A data frame with 27 rows and 6 columns:
#' \describe{
#'   \item{vintage}{character. One of `"table84"`, `"table2008"`,
#'     `"table2023"`. Vintages are not interchangeable: model *structure*
#'     differs, not only fitted values.}
#'   \item{stratum}{character. One of `"all"`, `"f"`, `"m"`, `"w"`, `"wf"`,
#'     `"wm"`, plus the vintage's non-white codes — `"o"`, `"of"`, `"om"` for
#'     `table84`; `"b"`, `"bf"`, `"bm"` for `table2008` and `table2023`.}
#'   \item{params}{list column of named numeric vectors, length 11:
#'     `DELTA`, `THALF`, `NU`, `M`, `TAU`, `GAMMA`, `ALPHA`, `ETA`, `E0`,
#'     `C0`, `L0`.}
#'   \item{status}{list column of named integer vectors, length 11. The
#'     `_STATUS_` gate. `mu = exp(E0 | C0 | L0)` **only** where the
#'     corresponding status is `1`; status `0` means the phase is absent
#'     from the model, not that `log(mu)` is zero.}
#'   \item{flags}{list column of named numeric vectors, length 6:
#'     `G1FLAG`, `FIXDEL0`, `FIXMNU1`, `G3FLAG`, `FIXGE2`, `FIXGAE2`. These
#'     record which sub-form was fitted. They are metadata only and are never
#'     read during evaluation.}
#'   \item{vcov}{list column of 11 by 11 numeric matrices, the parameter
#'     covariance blocks. Nothing in this version reads them; they ship
#'     because they are the only route to a confidence band later.}
#' }
#'
#' @section Race semantics:
#' `table84` names its non-white strata `o`, honestly "other". `table2008`
#' and `table2023` name the same strata `b`, and the macro's own comment
#' asserts these are Black-race estimates. For 2023 that assertion is
#' **false**: the category is a risk-weighted average of Black, Asian,
#' American Indian and Hispanic death rates, weighted by number at risk,
#' stored under `B` only to keep the macro's naming consistent. See
#' [us_lifetable_vintages()], which reports this per vintage.
#'
#' @source Fitted by The Cleveland Clinic Foundation. Built into this package
#'   by `data-raw/build-models.R`, which is not run at install time. That
#'   script's header names the share location to restore the inputs from —
#'   deliberately kept out of `R/`, which must carry no literal share path.
"us_lifetable_models"
```

- [ ] **Step 7: Regenerate docs and run the tests**

```bash
Rscript -e 'roxygen2::roxygenise("."); devtools::test(filter = "data")'
```

Expected: PASS, 6 tests.

- [ ] **Step 8: Verify the fits are still untracked**

```bash
git status --porcelain data-raw/uslife/ | wc -l
```

Expected: `0`. If it is not zero, **stop** — `.gitignore` has been broken and the CCF blocks are about to be published.

- [ ] **Step 9: Commit**

```bash
git add data-raw/build-models.R data/us_lifetable_models.rda R/data.R man/ DESCRIPTION tests/testthat/test-data.R
git commit -m "feat: build and ship the fitted US life-table parameter blocks"
```

---

## Task 2: Model accessors and `_STATUS_` gating

**Files:**
- Create: `R/models.R`
- Test: `tests/testthat/test-models.R`

**Interfaces:**
- Consumes: `us_lifetable_models` (Task 1).
- Produces:
  - `us_lifetable_vintages()` → data frame, columns `vintage`, `n_strata`, `nonwhite_code`, `nonwhite_meaning`, `added`. **No `source` column** — see below.
  - `us_lifetable_model(vintage, stratum)` → list with `vintage`, `stratum`, `params`, `status`, `flags`, `vcov`.
  - `hzl_mu(params, status, name)` → numeric scalar (internal). `exp(params[[name]])` if `status[[name]] == 1L`, else `0`.
  - `hzl_nonwhite_code(vintage)` → `"o"` for `table84`, `"b"` otherwise (internal).
  - `hzl_check_vintage(vintage)` → invisible `TRUE` or an error (internal).

- [ ] **Step 1: Write the failing test**

Create `tests/testthat/test-models.R`:

```r
test_that("us_lifetable_vintages reports the three usable vintages", {
  v <- us_lifetable_vintages()
  expect_s3_class(v, "data.frame")
  expect_setequal(v$vintage, c("table84", "table2008", "table2023"))
  expect_true(all(v$n_strata == 9L))
})

test_that("us_lifetable_vintages does not repeat the macro's race error", {
  v <- us_lifetable_vintages()
  expect_equal(v$nonwhite_code[v$vintage == "table84"], "o")
  expect_equal(v$nonwhite_code[v$vintage == "table2023"], "b")
  # The 2023 'b' stratum is NOT Black. Assert the documentation says so.
  expect_no_match(
    v$nonwhite_meaning[v$vintage == "table2023"],
    "^Black$"
  )
  expect_match(v$nonwhite_meaning[v$vintage == "table2023"], "risk-weighted")
  expect_match(v$nonwhite_meaning[v$vintage == "table84"], "[Oo]ther")
})

test_that("us_lifetable_model returns one parameter set", {
  m <- us_lifetable_model("table84", "wm")
  expect_type(m, "list")
  expect_equal(m$vintage, "table84")
  expect_equal(m$stratum, "wm")
  expect_length(m$params, 11L)
  expect_length(m$status, 11L)
  expect_equal(dim(m$vcov), c(11L, 11L))
  expect_equal(unname(m$params[["THALF"]]), 0.05188786, tolerance = 1e-7)
})

test_that("an unknown vintage errors and lists what is available", {
  expect_error(us_lifetable_model("table1999", "wm"), "table1999")
  expect_error(us_lifetable_model("table1999", "wm"), "table84")
  expect_error(us_lifetable_model("table1999", "wm"), "table2023")
})

test_that("table2009 errors as empty on disk, not as not-found", {
  expect_error(us_lifetable_model("table2009", "wm"), "empty")
})

test_that("a stratum absent from a vintage errors and names the alternative", {
  # 'o' exists in table84 only; 'b' in 2008/2023 only. Match on the quoted
  # stratum and on the naming hint, not on a bare letter -- a one-character
  # regex matches almost any error message and would pass vacuously.
  expect_error(us_lifetable_model("table2023", "o"),
               'has no stratum "o"', fixed = TRUE)
  expect_error(us_lifetable_model("table2023", "o"), "table84 uses")
  expect_error(us_lifetable_model("table84", "b"),
               'has no stratum "b"', fixed = TRUE)
})

test_that("a missing vintage errors rather than defaulting", {
  expect_error(us_lifetable_model(stratum = "wm"), "vintage")
})

test_that("hzl_nonwhite_code follows the vintage's naming", {
  expect_equal(hzl_nonwhite_code("table84"), "o")
  expect_equal(hzl_nonwhite_code("table2008"), "b")
  expect_equal(hzl_nonwhite_code("table2023"), "b")
})

test_that("hzl_mu honours the _STATUS_ gate -- Tier 2 regression", {
  # THE trap. table84/om has C0 = 0 with _STATUS_ = 0. Reading that as
  # exp(0) = 1 injects a constant 1/yr hazard and collapses survival for
  # every non-white male.
  m <- us_lifetable_model("table84", "om")
  expect_equal(hzl_mu(m$params, m$status, "C0"), 0)
  expect_gt(hzl_mu(m$params, m$status, "E0"), 0)
  expect_gt(hzl_mu(m$params, m$status, "L0"), 0)
})

test_that("hzl_mu exponentiates only when status is 1", {
  p <- c(E0 = -4, C0 = -7, L0 = 0)
  s <- c(E0 = 1L, C0 = 0L, L0 = 1L)
  expect_equal(hzl_mu(p, s, "E0"), exp(-4))
  expect_equal(hzl_mu(p, s, "C0"), 0)      # NOT exp(-7)
  expect_equal(hzl_mu(p, s, "L0"), 1)      # exp(0), because status is 1
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "models")'`
Expected: FAIL — `could not find function "us_lifetable_vintages"`.

- [ ] **Step 3: Write the implementation**

Create `R/models.R`:

```r
## Vintages the package knows about, including ones it deliberately refuses.
## table2009 is an empty directory on the share. Whether it was never
## populated or lost is unresolved; either way it cannot be used, and the
## error must say "empty" rather than "not found" so nobody goes looking.
VINTAGE_META <- list(
  table84 = list(
    nonwhite_code    = "o",
    nonwhite_meaning = "Other (all non-white), named honestly by this vintage",
    added            = NA_character_,
    usable           = TRUE
  ),
  table2008 = list(
    nonwhite_code    = "b",
    nonwhite_meaning = "Black, per the macro's documentation; not independently verified",
    added            = NA_character_,
    usable           = TRUE
  ),
  table2009 = list(
    nonwhite_code    = NA_character_,
    nonwhite_meaning = NA_character_,
    added            = NA_character_,
    usable           = FALSE
  ),
  table2023 = list(
    nonwhite_code    = "b",
    nonwhite_meaning = paste(
      "risk-weighted average of Black, Asian, American Indian and Hispanic",
      "death rates, weighted by number at risk. NOT Black, despite the",
      "stratum code and despite the macro's own comment."
    ),
    added            = "2025-12-23",
    usable           = TRUE
  )
)

usable_vintages <- function() {
  names(VINTAGE_META)[vapply(VINTAGE_META, function(x) x$usable, logical(1))]
}

hzl_check_vintage <- function(vintage) {
  if (missing(vintage) || is.null(vintage)) {
    stop("`vintage` has no default and must be given. Available: ",
         paste(usable_vintages(), collapse = ", "),
         ".\nThis package refuses to guess: the SAS macro's default silently ",
         "moved from table84 to table2023, and every job re-run across that ",
         "change got different numbers with no signal.", call. = FALSE)
  }
  if (!is.character(vintage) || length(vintage) != 1L) {
    stop("`vintage` must be a single character string.", call. = FALSE)
  }
  if (identical(vintage, "table2009")) {
    stop("vintage \"table2009\" is empty on disk -- the estimates directory ",
         "exists but was never populated. It is not a missing file; there is ",
         "nothing to load. Available: ",
         paste(usable_vintages(), collapse = ", "), ".", call. = FALSE)
  }
  if (!vintage %in% usable_vintages()) {
    stop("unknown vintage \"", vintage, "\". Available: ",
         paste(usable_vintages(), collapse = ", "), ".", call. = FALSE)
  }
  invisible(TRUE)
}

hzl_nonwhite_code <- function(vintage) {
  hzl_check_vintage(vintage)
  VINTAGE_META[[vintage]]$nonwhite_code
}

#' Available US life-table vintages
#'
#' Reports the fitted-model vintages this package ships, with the provenance
#' and race semantics needed to choose one. Vintages are **not**
#' interchangeable — model structure differs, not only fitted values.
#'
#' @return A data frame with one row per usable vintage and columns:
#'   `vintage` (character identifier), `n_strata` (integer, always 9),
#'   `nonwhite_code` (character, the stratum code this vintage uses for its
#'   non-white category), `nonwhite_meaning` (character, what that category
#'   actually contains), `added` (character date the fits were added, where
#'   known, otherwise `NA`).
#'
#'   There is deliberately no `source` column: `R/` carries no literal share
#'   path. `data-raw/build-models.R` names the location the fits are restored
#'   from.
#'
#' @section Read `nonwhite_meaning` before citing a stratum:
#' The `table2023` non-white category is stored under code `b` but is a
#' risk-weighted average of Black, Asian, American Indian and Hispanic death
#' rates. It is not Black. The macro's own comment says otherwise and is
#' wrong.
#'
#' @examples
#' us_lifetable_vintages()
#'
#' @export
us_lifetable_vintages <- function() {
  v <- usable_vintages()
  data.frame(
    vintage          = v,
    n_strata         = vapply(v, function(x)
                         sum(us_lifetable_models$vintage == x), integer(1)),
    nonwhite_code    = vapply(v, function(x)
                         VINTAGE_META[[x]]$nonwhite_code, character(1)),
    nonwhite_meaning = vapply(v, function(x)
                         VINTAGE_META[[x]]$nonwhite_meaning, character(1)),
    added            = vapply(v, function(x)
                         VINTAGE_META[[x]]$added, character(1)),
    row.names        = NULL,
    stringsAsFactors = FALSE
  )
}

#' One fitted parameter set
#'
#' Returns the raw fitted model for a single vintage and stratum, for
#' inspection. [us_matched()] is the function most callers want.
#'
#' @param vintage Character scalar. One of the identifiers returned by
#'   [us_lifetable_vintages()]. **There is no default**; omitting it is an
#'   error.
#' @param stratum Character scalar. One of `"all"`, `"f"`, `"m"`, `"w"`,
#'   `"wf"`, `"wm"`, or the vintage's non-white codes — `"o"`, `"of"`, `"om"`
#'   for `table84`, `"b"`, `"bf"`, `"bm"` otherwise.
#'
#' @return A list with elements `vintage` (character), `stratum` (character),
#'   `params` (named numeric of length 11), `status` (named integer of length
#'   11, the `_STATUS_` gate), `flags` (named numeric of length 6, metadata
#'   only), and `vcov` (11 by 11 numeric matrix, unused in this version).
#'
#' @examples
#' m <- us_lifetable_model("table84", "wm")
#' m$params[["THALF"]]
#'
#' # The _STATUS_ gate: table84's non-white male stratum has no constant
#' # phase. Its C0 is 0 *and absent*, not 0 *and meaning exp(0) = 1*.
#' om <- us_lifetable_model("table84", "om")
#' om$params[["C0"]]
#' om$status[["C0"]]
#'
#' @export
us_lifetable_model <- function(vintage, stratum) {
  hzl_check_vintage(vintage)
  if (missing(stratum) || !is.character(stratum) || length(stratum) != 1L) {
    stop("`stratum` must be a single character string.", call. = FALSE)
  }

  in_vintage <- us_lifetable_models$vintage == vintage
  i <- which(in_vintage & us_lifetable_models$stratum == stratum)

  if (length(i) != 1L) {
    available <- sort(us_lifetable_models$stratum[in_vintage])
    stop("vintage \"", vintage, "\" has no stratum \"", stratum,
         "\". Available: ", paste(available, collapse = ", "),
         ".\nNote that vintages differ in how they name the non-white ",
         "stratum: table84 uses \"o\", table2008 and table2023 use \"b\".",
         call. = FALSE)
  }

  list(
    vintage = vintage,
    stratum = stratum,
    params  = us_lifetable_models$params[[i]],
    status  = us_lifetable_models$status[[i]],
    flags   = us_lifetable_models$flags[[i]],
    vcov    = us_lifetable_models$vcov[[i]]
  )
}

## The _STATUS_ gate, in one place.
##
## mu = exp(X0) ONLY when status[[X0]] == 1. A status of 0 means the phase is
## absent from the fitted model -- NOT that log(mu) is zero. Reading a
## status-0 C0 as exp(0) = 1 injects a constant hazard of one death per
## person-year. It fails loudly per patient but its cohort signature is a
## plausible near-miss, which is what makes it dangerous.
hzl_mu <- function(params, status, name) {
  if (isTRUE(status[[name]] == 1L)) exp(params[[name]]) else 0
}
```

- [ ] **Step 4: Regenerate docs and run the tests**

```bash
Rscript -e 'roxygen2::roxygenise("."); devtools::test(filter = "models")'
```

Expected: PASS, 10 tests.

- [ ] **Step 5: Commit**

```bash
git add R/models.R tests/testthat/test-models.R man/ NAMESPACE
git commit -m "feat: add model accessors with _STATUS_ gating and vintage policy"
```

---

## Task 3: The evaluator

This is the unit worth testing hardest. It takes eleven numbers and a time vector and knows nothing about patients, strata or vintages. Keep it that way.

**Files:**
- Create: `R/evaluate.R`
- Test: `tests/testthat/test-evaluate.R`

**Interfaces:**
- Consumes: `hzl_mu()` (Task 2), `TemporalHazard`.
- Produces:
  - `hzl_cumhaz(params, status, age)` → numeric vector, same length as `age`. Cumulative hazard from birth to `age`.
  - `hzl_hazard(params, status, age)` → numeric vector, same length as `age`. Instantaneous hazard at `age`.
  - `hzl_check_model(params, status)` → invisible `TRUE` or error (internal).

The mathematics, on the age axis with time origin at birth:

```
H(a) = muE * hzr_phase_cumhaz(a, THALF, NU, M, type = "cdf")
     + muC * a
     + muL * hzr_decompos_g3(a, TAU, GAMMA, ALPHA, ETA)$G3

h(a) = muE * hzr_phase_hazard(a, THALF, NU, M, type = "cdf")
     + muC
     + muL * hzr_decompos_g3(a, TAU, GAMMA, ALPHA, ETA)$g3
```

Note `muC * a` in the cumulative and bare `muC` in the hazard — a constant hazard integrates to a linear cumulative hazard.

- [ ] **Step 1: Write the failing test**

Create `tests/testthat/test-evaluate.R`:

```r
wm84 <- function() us_lifetable_model("table84", "wm")
om84 <- function() us_lifetable_model("table84", "om")

test_that("cumulative hazard is zero at birth", {
  # Not exactly 0 in floating point -- table84/wm evaluates to ~1.7e-311,
  # a denormal from the early phase. Assert negligible rather than exact.
  m <- wm84()
  expect_lt(abs(hzl_cumhaz(m$params, m$status, 0)), 1e-12)
})

test_that("cumulative hazard is non-negative and non-decreasing in age", {
  m <- wm84()
  a <- seq(0, 100, by = 0.5)
  H <- hzl_cumhaz(m$params, m$status, a)
  expect_true(all(H >= 0))
  expect_true(all(diff(H) >= 0))
})

test_that("hazard is strictly positive across the supported age range", {
  # Range starts above 0. Exactly age 0 is a numerical singularity -- see the
  # next test. Every age above it is finite and positive: verified 2026-08-14
  # by sweeping all 27 shipped strata over 1e-12 to 110.
  m <- wm84()
  h <- hzl_hazard(m$params, m$status, seq(0.5, 100, by = 0.5))
  expect_true(all(h > 0))
  expect_true(all(is.finite(h)))
})

test_that("the hazard errors at exactly age 0 rather than returning NaN", {
  # TemporalHazard's early phase is indeterminate at exactly 0: it computes
  # G <- exp(-bt^(-1/nu)), which underflows to 0, then g <- G * bt^num1 where
  # bt^num1 overflows to Inf -- so 0 * Inf = NaN. This hits 9 of the 27
  # shipped strata (every one with an active early phase of this shape).
  #
  # H(0) is unaffected and is ~1.7e-311, which is why the cumulative-hazard
  # test above passes.
  #
  # A silent NaN reaching a figure is exactly the "result-shaped nothing"
  # failure this project keeps hitting, so the evaluator errors instead.
  m <- wm84()
  expect_error(hzl_hazard(m$params, m$status, 0), "not finite")
  expect_error(hzl_hazard(m$params, m$status, c(0, 50)), "not finite")
  # ...and the moment you step off 0, it is well behaved.
  expect_true(all(is.finite(hzl_hazard(m$params, m$status, c(1e-12, 1e-6)))))
})

test_that("both evaluators are vectorised and length-preserving", {
  m <- wm84()
  a <- c(0, 1, 40, 70, 100)
  expect_length(hzl_cumhaz(m$params, m$status, a), 5L)
  expect_length(hzl_hazard(m$params, m$status, a), 5L)
  # elementwise agreement with the scalar calls
  expect_equal(
    hzl_cumhaz(m$params, m$status, a),
    vapply(a, function(x) hzl_cumhaz(m$params, m$status, x), numeric(1))
  )
})

test_that("the hazard is the derivative of the cumulative hazard", {
  # Numerical check. If these two drift apart, one of the three phases is
  # paired with the wrong TemporalHazard entry point.
  m <- wm84()
  a <- c(20, 45, 70, 90)
  eps <- 1e-6
  numeric_deriv <- (hzl_cumhaz(m$params, m$status, a + eps) -
                    hzl_cumhaz(m$params, m$status, a - eps)) / (2 * eps)
  expect_equal(hzl_hazard(m$params, m$status, a), numeric_deriv,
               tolerance = 1e-6)
})

test_that("hazard rises with age over the adult range", {
  m <- wm84()
  h <- hzl_hazard(m$params, m$status, c(40, 50, 60, 70, 80, 90))
  expect_true(all(diff(h) > 0))
})

test_that("a status-0 phase contributes exactly zero -- Tier 2 at the evaluator", {
  # table84/om has C0 = 0 with _STATUS_ = 0. Build a copy whose C0 status is
  # flipped to 1 and confirm the two differ by exactly the constant phase.
  m <- om84()
  a <- c(10, 50, 80)

  broken_status <- m$status
  broken_status[["C0"]] <- 1L   # the bug, deliberately reintroduced

  correct <- hzl_hazard(m$params, m$status, a)
  broken  <- hzl_hazard(m$params, broken_status, a)

  # exp(C0) = exp(0) = 1, a hazard of one death per person-year
  expect_equal(broken - correct, rep(1, 3))
  # and it is catastrophic, not subtle, at the survival level
  expect_lt(exp(-hzl_cumhaz(m$params, broken_status, 80)), 1e-30)
  expect_gt(exp(-hzl_cumhaz(m$params, m$status, 80)), 0.1)
})

test_that("a model with no active phase is an error, not a flat zero curve", {
  m <- wm84()
  dead <- m$status
  dead[c("E0", "C0", "L0")] <- 0L
  expect_error(hzl_cumhaz(m$params, dead, 50), "no active phase")
})

test_that("strata within a vintage give different curves", {
  # Guards against an accessor bug that returns the same record for every
  # stratum -- which would pass every invariant above.
  a <- 70
  wm <- us_lifetable_model("table84", "wm")
  wf <- us_lifetable_model("table84", "wf")
  expect_false(isTRUE(all.equal(
    hzl_hazard(wm$params, wm$status, a),
    hzl_hazard(wf$params, wf$status, a)
  )))
  # and the well-known direction: male hazard exceeds female at age 70
  expect_gt(hzl_hazard(wm$params, wm$status, a),
            hzl_hazard(wf$params, wf$status, a))
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "evaluate")'`
Expected: FAIL — `could not find function "hzl_cumhaz"`.

- [ ] **Step 3: Write the implementation**

Create `R/evaluate.R`:

```r
## The evaluator. Eleven numbers and a time vector in, a curve out.
##
## This file knows nothing about patients, strata or vintages, and must stay
## that way -- it is the layer where a bug is cheapest to find.
##
## %usmatchd evaluates a stored three-phase HAZARD fit on the AGE axis, time
## origin birth. The three phases are additive:
##
##   H(a) = muE * G(a) + muC * a + muL * G3(a)
##   h(a) = muE * g(a) + muC     + muL * g3(a)
##
## Note muC * a in the cumulative against bare muC in the hazard: a constant
## hazard integrates to a linear cumulative hazard.
##
## The TemporalHazard entry points below take parameters DIRECTLY, not an
## hzr_phase object, and have no "g3" type -- the late phase comes from
## hzr_decompos_g3(), which returns $G3 and $g3. Inferring these signatures
## from the hzr_phase() documentation gives the wrong answer; they were
## confirmed with args().

## A non-finite hazard or cumulative hazard silently poisons every downstream
## survival number. Catch it here.
hzl_assert_finite <- function(x, age, what) {
  if (!all(is.finite(x))) {
    bad <- age[!is.finite(x)]
    stop(what, " is not finite at age ",
         paste(utils::head(bad, 5), collapse = ", "),
         if (length(bad) > 5) ", ..." else "",
         ".\nTemporalHazard's early phase is indeterminate at exactly age 0 ",
         "(0 * Inf); evaluate at a positive age. Any other age reaching this ",
         "message means the fitted parameters are degenerate.", call. = FALSE)
  }
  invisible(TRUE)
}

hzl_check_model <- function(params, status) {
  if (!any(vapply(c("E0", "C0", "L0"),
                  function(n) isTRUE(status[[n]] == 1L), logical(1)))) {
    stop("this model has no active phase: E0, C0 and L0 all have ",
         "_STATUS_ != 1. A model with no phases is not a valid model.",
         call. = FALSE)
  }
  invisible(TRUE)
}

## Cumulative hazard from birth to `age`.
hzl_cumhaz <- function(params, status, age) {
  hzl_check_model(params, status)

  muE <- hzl_mu(params, status, "E0")
  muC <- hzl_mu(params, status, "C0")
  muL <- hzl_mu(params, status, "L0")

  out <- numeric(length(age))

  if (muE != 0) {
    out <- out + muE * TemporalHazard::hzr_phase_cumhaz(
      age,
      t_half = params[["THALF"]],
      nu     = params[["NU"]],
      m      = params[["M"]],
      type   = "cdf"
    )
  }
  if (muC != 0) {
    out <- out + muC * age
  }
  if (muL != 0) {
    out <- out + muL * TemporalHazard::hzr_decompos_g3(
      age,
      tau   = params[["TAU"]],
      gamma = params[["GAMMA"]],
      alpha = params[["ALPHA"]],
      eta   = params[["ETA"]]
    )$G3
  }
  hzl_assert_finite(out, age, "the cumulative hazard")
  out
}

## Instantaneous hazard at `age`.
hzl_hazard <- function(params, status, age) {
  hzl_check_model(params, status)

  muE <- hzl_mu(params, status, "E0")
  muC <- hzl_mu(params, status, "C0")
  muL <- hzl_mu(params, status, "L0")

  out <- numeric(length(age))

  if (muE != 0) {
    out <- out + muE * TemporalHazard::hzr_phase_hazard(
      age,
      t_half = params[["THALF"]],
      nu     = params[["NU"]],
      m      = params[["M"]],
      type   = "cdf"
    )
  }
  if (muC != 0) {
    out <- out + muC
  }
  if (muL != 0) {
    out <- out + muL * TemporalHazard::hzr_decompos_g3(
      age,
      tau   = params[["TAU"]],
      gamma = params[["GAMMA"]],
      alpha = params[["ALPHA"]],
      eta   = params[["ETA"]]
    )$g3
  }
  hzl_assert_finite(out, age, "the hazard")
  out
}
```

- [ ] **Step 4: Run the tests**

```bash
Rscript -e 'devtools::test(filter = "evaluate")'
```

Expected: PASS, 10 tests.

- [ ] **Step 5: Commit**

```bash
git add R/evaluate.R tests/testthat/test-evaluate.R
git commit -m "feat: add the three-phase age-axis evaluator"
```

---

## Task 4: `us_matched()` for individual curves

**Files:**
- Create: `R/us_matched.R`
- Test: `tests/testthat/test-us-matched.R`

**Interfaces:**
- Consumes: `us_lifetable_model()`, `hzl_nonwhite_code()`, `hzl_check_vintage()` (Task 2); `hzl_cumhaz()`, `hzl_hazard()` (Task 3).
- Produces:
  - `us_matched(age, male, other, times, id, vintage, table, scale, individual)` → data frame. With `individual = TRUE`: columns `id`, `time`, `agesurv`, `smatched`, `hmatched`, one row per patient per time, ordered by `id` then `time`.
  - `hzl_assign_stratum(male, other, table, vintage)` → character vector (internal).
  - `hzl_scalef(scale)` → numeric scalar (internal): `1`, `1/12`, `1/365.2425`.
  - `hzl_assert_varies(smatched, times)` → invisible `TRUE` or error (internal).

`individual = FALSE` is deliberately **not** implemented in this task — it lands in Task 5. Here it errors as not-yet-implemented so the API shape is fixed but nothing silently returns a wrong reduction.

The macro's arithmetic, from `usmatchd.sas:210-227`:

```
YEARS   = time * SCALEF          # times are in `scale` units
AGE_YR  = age + YEARS
agesurv    = exp(-H(age))
smatched(t)= exp(-H(AGE_YR)) / agesurv  ==  exp(-(H(age + years) - H(age)))
hmatched(t)= h(AGE_YR)
```

**`hmatched` is per year regardless of `scale`** — see the Open question in Global Constraints.

- [ ] **Step 1: Write the failing test**

Create `tests/testthat/test-us-matched.R`:

```r
test_that("us_matched returns one row per patient per time, correctly shaped", {
  r <- us_matched(age = c(60, 70), male = c(1, 0), other = c(0, 0),
                  times = c(0, 5, 10), vintage = "table84")
  expect_s3_class(r, "data.frame")
  expect_equal(nrow(r), 6L)
  expect_equal(names(r), c("id", "time", "agesurv", "smatched", "hmatched"))
  expect_equal(r$time, c(0, 5, 10, 0, 5, 10))
  expect_equal(r$id, c(1L, 1L, 1L, 2L, 2L, 2L))
})

test_that("smatched is 1 at time zero and non-increasing thereafter", {
  r <- us_matched(age = 70, male = 1, other = 0, times = seq(0, 10, by = 0.5),
                  vintage = "table84")
  expect_equal(r$smatched[1], 1)
  expect_true(all(diff(r$smatched) <= 0))
  expect_true(all(r$smatched > 0 & r$smatched <= 1))
})

test_that("hmatched is positive and agesurv is constant within a patient", {
  r <- us_matched(age = 70, male = 1, other = 0, times = c(0, 5, 10),
                  vintage = "table84")
  expect_true(all(r$hmatched > 0))
  expect_equal(length(unique(r$agesurv)), 1L)
  expect_true(r$agesurv[1] > 0 && r$agesurv[1] < 1)
})

test_that("the conditioning identity holds", {
  # S(t1 + t2 | age) == S(t1 | age) * S(t2 | age + t1)
  a <- 65; t1 <- 3; t2 <- 4
  s_both <- us_matched(a, 1, 0, t1 + t2, vintage = "table84")$smatched
  s_1    <- us_matched(a, 1, 0, t1, vintage = "table84")$smatched
  s_2    <- us_matched(a + t1, 1, 0, t2, vintage = "table84")$smatched
  expect_equal(s_both, s_1 * s_2, tolerance = 1e-12)
})

test_that("table= selects the stratification, matching the macro's modes", {
  args <- list(age = 70, male = 1, other = 1, times = 5, vintage = "table84")
  overall <- do.call(us_matched, c(args, table = "overall"))$smatched
  sex     <- do.call(us_matched, c(args, table = "sex"))$smatched
  race    <- do.call(us_matched, c(args, table = "race"))$smatched
  sexrace <- do.call(us_matched, c(args, table = "sexrace"))$smatched
  expect_equal(length(unique(c(overall, sex, race, sexrace))), 4L)
})

test_that("table='overall' ignores male and other entirely", {
  a <- us_matched(70, 1, 0, 5, vintage = "table84", table = "overall")$smatched
  b <- us_matched(70, 0, 1, 5, vintage = "table84", table = "overall")$smatched
  expect_equal(a, b)
})

test_that("hzl_assign_stratum resolves the vintage's non-white naming", {
  expect_equal(
    hzl_assign_stratum(male = c(1, 0, 1, 0), other = c(0, 0, 1, 1),
                       table = "sexrace", vintage = "table84"),
    c("wm", "wf", "om", "of")
  )
  expect_equal(
    hzl_assign_stratum(male = c(1, 0, 1, 0), other = c(0, 0, 1, 1),
                       table = "sexrace", vintage = "table2023"),
    c("wm", "wf", "bm", "bf")
  )
  expect_equal(
    hzl_assign_stratum(1, 1, table = "race", vintage = "table84"), "o"
  )
  expect_equal(
    hzl_assign_stratum(1, 1, table = "sex", vintage = "table84"), "m"
  )
  expect_equal(
    hzl_assign_stratum(1, 1, table = "overall", vintage = "table84"), "all"
  )
})

test_that("scale converts times to years on the age axis", {
  # 60 months == 5 years: identical curves, different `time` labels.
  y <- us_matched(70, 1, 0, times = 5,  vintage = "table84", scale = "years")
  m <- us_matched(70, 1, 0, times = 60, vintage = "table84", scale = "months")
  expect_equal(y$smatched, m$smatched, tolerance = 1e-12)
  expect_equal(y$time, 5)
  expect_equal(m$time, 60)
})

test_that("days uses the macro's 365.2425, not survival's 365.241", {
  expect_equal(hzl_scalef("days"), 1 / 365.2425)
  expect_equal(hzl_scalef("months"), 1 / 12)
  expect_equal(hzl_scalef("years"), 1)
})

test_that("hmatched is per year regardless of scale -- matches the macro source", {
  # usmatchd.sas:227 is `&HMATCHED=_HAZARD;` with no SCALEF multiplication,
  # despite the macro's own header comment at line 47 claiming otherwise.
  # See the plan's Global Constraints. If this test is ever changed, change
  # the documentation in the same commit.
  y <- us_matched(70, 1, 0, times = 5,  vintage = "table84", scale = "years")
  m <- us_matched(70, 1, 0, times = 60, vintage = "table84", scale = "months")
  expect_equal(y$hmatched, m$hmatched, tolerance = 1e-12)
})

test_that("vintage is required and never guessed", {
  expect_error(us_matched(70, 1, 0, times = 5), "vintage")
  expect_error(us_matched(70, 1, 0, times = 5), "refuses to guess")
})

test_that("out-of-support ages error rather than extrapolate", {
  expect_error(us_matched(-1, 1, 0, times = 5, vintage = "table84"), "age")
  expect_error(us_matched(105, 1, 0, times = 10, vintage = "table84"), "110")
})

test_that("mismatched input lengths error", {
  expect_error(
    us_matched(age = c(60, 70), male = 1, other = c(0, 0), times = 5,
               vintage = "table84"),
    "same length"
  )
})

test_that("non-binary male or other errors", {
  expect_error(us_matched(70, 2, 0, times = 5, vintage = "table84"), "male")
  expect_error(us_matched(70, 1, 0.5, times = 5, vintage = "table84"), "other")
})

test_that("negative times error", {
  expect_error(us_matched(70, 1, 0, times = c(-1, 5), vintage = "table84"),
               "negative")
})

test_that("unsorted times are rejected rather than silently returned", {
  # Out-of-order input previously returned smatched = c(0.549, 1.000, 0.791):
  # a survival curve that zigzags, breaking the package's own monotonicity
  # invariant without any signal.
  expect_error(us_matched(70, 1, 0, times = c(10, 0, 5), vintage = "table84"),
               "non-decreasing")
  # Ties are non-decreasing and stay legal.
  expect_no_error(us_matched(70, 1, 0, times = c(0, 5, 5, 10),
                             vintage = "table84"))
})

test_that("empty times error in the package's own words", {
  # Previously leaked data.frame()'s internals:
  # "arguments imply differing number of rows: 0, 1".
  expect_error(us_matched(70, 1, 0, times = numeric(0), vintage = "table84"),
               "must not be empty")
})

test_that("an empty cohort returns a zero-row data frame, not NULL", {
  # A cohort filtered to nothing is legitimate input. Returning NULL would
  # break nrow(), $ and rbind() downstream with no error at the call site.
  r <- us_matched(numeric(0), numeric(0), numeric(0), times = c(0, 5),
                  vintage = "table84")
  expect_s3_class(r, "data.frame")
  expect_equal(nrow(r), 0L)
  expect_equal(names(r), c("id", "time", "agesurv", "smatched", "hmatched"))
})

test_that("an empty cohort emits no warning", {
  # max(numeric(0)) warns and returns -Inf, which also silently defeated the
  # 110-year support check.
  expect_silent(us_matched(numeric(0), numeric(0), numeric(0),
                           times = c(0, 5), vintage = "table84"))
})

test_that("ids are carried through", {
  r <- us_matched(age = c(60, 70), male = c(1, 1), other = c(0, 0),
                  times = c(0, 5), id = c("a", "b"), vintage = "table84")
  expect_equal(r$id, c("a", "a", "b", "b"))
})

test_that("individual = FALSE is not yet implemented and says so", {
  expect_error(
    us_matched(70, 1, 0, times = 5, vintage = "table84", individual = FALSE),
    "not yet implemented"
  )
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "us-matched")'`
Expected: FAIL — `could not find function "us_matched"`.

- [ ] **Step 3: Write the implementation**

Create `R/us_matched.R`:

```r
## SCALEF, from usmatchd.sas:202-204. Note 365.2425, which is not the
## 365.241 used elsewhere in the survival package.
hzl_scalef <- function(scale) {
  switch(scale,
    years  = 1,
    months = 1 / 12,
    days   = 1 / 365.2425,
    stop("unknown scale \"", scale, "\".", call. = FALSE)
  )
}

## Map each patient to a stratum code, honouring the vintage's naming for the
## non-white category. Mirrors the macro's TABLE= modes exactly.
hzl_assign_stratum <- function(male, other, table, vintage) {
  nw <- hzl_nonwhite_code(vintage)
  n <- max(length(male), length(other))

  switch(table,
    overall = rep("all", n),
    sex     = ifelse(male == 1, "m", "f"),
    race    = ifelse(other == 1, nw, "w"),
    sexrace = paste0(ifelse(other == 1, nw, "w"), ifelse(male == 1, "m", "f")),
    stop("unknown table \"", table, "\".", call. = FALSE)
  )
}

## A cohort filtered to nothing is a legitimate input, not an error. Return
## the documented columns with zero rows so `nrow()`, `$` and `rbind()` all
## behave -- returning NULL instead would be a wrong-typed value that only
## fails downstream, which is exactly the silent-failure shape this package
## exists to avoid. `id[0]` preserves the caller's id type.
hzl_empty_result <- function(id, individual) {
  if (isTRUE(individual)) {
    data.frame(id = id[0], time = numeric(0), agesurv = numeric(0),
               smatched = numeric(0), hmatched = numeric(0),
               stringsAsFactors = FALSE)
  } else {
    data.frame(time = numeric(0), smatched = numeric(0),
               hmatched = numeric(0), stringsAsFactors = FALSE)
  }
}

## The failure shape this study has now hit five times: a reference curve
## that does not move. Catch it here rather than in a figure.
hzl_assert_varies <- function(smatched, times) {
  if (length(times) < 2L) return(invisible(TRUE))
  if (all(smatched == 1) || all(smatched == 0)) {
    stop("the reference survival curve is identically ",
         if (all(smatched == 1)) "1" else "0",
         " -- this is not a survival curve. Check the _STATUS_ gating and ",
         "the vintage.", call. = FALSE)
  }
  if (length(unique(smatched)) == 1L) {
    stop("the reference survival curve is constant across `times`. ",
         "Check that `times` actually varies and that the model has an ",
         "active phase.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Age, sex and race matched US reference survival
#'
#' Reproduces the Cleveland Clinic SAS macro `%usmatchd`: for each patient, a
#' US reference survival curve matched on age, sex and race, together with its
#' hazard. This is the dashed comparison line on a clinical survival figure.
#'
#' @param age Numeric vector of ages **in years**, always in years regardless
#'   of `scale`.
#' @param male Numeric vector, `1` male, `0` female. The macro's coding,
#'   unchanged.
#' @param other Numeric vector, `1` non-white, `0` white. The macro's coding,
#'   unchanged. What "non-white" contains differs by vintage — see
#'   [us_lifetable_vintages()].
#' @param times Numeric vector of follow-up times in the units of `scale`,
#'   non-negative.
#' @param id Optional vector of patient identifiers, recycled into the output.
#'   Defaults to `seq_along(age)`.
#' @param vintage Character scalar naming the fitted-model vintage. **There is
#'   no default.** Omitting it is an error. See Details.
#' @param table How finely to stratify patients, mirroring the macro's
#'   `TABLE=` modes. `"sexrace"` uses all four crossings, `"race"` uses white
#'   against the vintage's non-white category, `"sex"` uses male and female,
#'   `"overall"` sends every patient to the combined stratum and ignores
#'   `male` and `other`.
#' @param scale Units of `times`. Applies the macro's `SCALEF` of `1`,
#'   `1/12` and `1/365.2425` respectively.
#' @param individual If `TRUE` (default), one row per patient per time. If
#'   `FALSE`, the cohort mean curve, one row per time.
#'
#' @return A data frame. When `individual = TRUE`, columns `id`, `time`,
#'   `agesurv` (survival from birth to the patient's current age),
#'   `smatched` (reference survival over `times`, conditional on having
#'   reached `age`) and `hmatched` (the reference hazard), with one row per
#'   patient per time. When `individual = FALSE`, columns `time`, `smatched`
#'   and `hmatched` only, with one row per time.
#'
#' @details
#' `%usmatchd` is not a life-table lookup. It evaluates a stored three-phase
#' parametric hazard fit on the **age** axis, time origin birth, and reads
#' conditional survival off that one smooth curve twice. That is why the
#' resulting hazard is smooth *within* a one-year age bin where a life table
#' would be flat.
#'
#' **`hmatched` is per year regardless of `scale`.** This matches the macro's
#' source, which assigns `_HAZARD` without applying `SCALEF`, notwithstanding
#' the macro's own header comment to the contrary.
#'
#' @section Why `vintage` has no default:
#' The macro's default silently moved from `table84` to `table2023`, and every
#' job re-run across that change got different numbers with no signal. An
#' analysis that does not state its reference vintage is not reproducible, so
#' this package refuses to guess. State it literally in analysis code.
#'
#' @seealso [us_lifetable_vintages()] for the available vintages and what
#'   their non-white stratum actually contains; [us_lifetable_model()] for the
#'   raw fitted parameters.
#'
#' @examples
#' # A 70-year-old white male, ten years of follow-up, 1984 fits.
#' r <- us_matched(age = 70, male = 1, other = 0,
#'                 times = seq(0, 10, by = 2), vintage = "table84")
#' r[, c("time", "smatched", "hmatched")]
#'
#' @export
us_matched <- function(age, male, other, times,
                       id         = seq_along(age),
                       vintage,
                       table      = c("sexrace", "race", "sex", "overall"),
                       scale      = c("years", "months", "days"),
                       individual = TRUE) {

  hzl_check_vintage(vintage)
  table <- match.arg(table)
  scale <- match.arg(scale)

  n <- length(age)
  if (length(male) != n || length(other) != n) {
    stop("`age`, `male` and `other` must be the same length; got ",
         n, ", ", length(male), " and ", length(other), ".", call. = FALSE)
  }
  if (length(id) != n) {
    stop("`id` must be the same length as `age`; got ", length(id),
         " and ", n, ".", call. = FALSE)
  }
  if (!is.numeric(age) || anyNA(age)) {
    stop("`age` must be numeric with no missing values.", call. = FALSE)
  }
  if (!all(male %in% c(0, 1))) {
    stop("`male` must be 0 or 1 (the macro's coding).", call. = FALSE)
  }
  if (!all(other %in% c(0, 1))) {
    stop("`other` must be 0 or 1 (the macro's coding).", call. = FALSE)
  }
  if (!is.numeric(times) || anyNA(times)) {
    stop("`times` must be numeric with no missing values.", call. = FALSE)
  }
  if (any(times < 0)) {
    stop("`times` must not be negative.", call. = FALSE)
  }
  if (length(times) == 0L) {
    stop("`times` must not be empty.", call. = FALSE)
  }
  if (is.unsorted(times)) {
    ## Rows follow `times` in the order given, so out-of-order input returns a
    ## `smatched` column that is not monotone -- a survival curve that
    ## zigzags. Reject rather than silently sorting: the caller's row order
    ## may be meaningful to them, and quietly reordering it is its own bug.
    ## Ties are fine; is.unsorted() tests non-decreasing.
    stop("`times` must be in non-decreasing order; got ",
         paste(utils::head(times, 5), collapse = ", "),
         if (length(times) > 5) ", ..." else "",
         ".\nSort `times` before calling.", call. = FALSE)
  }
  if (any(age < 0)) {
    stop("`age` must not be negative; got a minimum of ", min(age), ".",
         call. = FALSE)
  }

  if (!isTRUE(individual)) {
    stop("`individual = FALSE` is not yet implemented.", call. = FALSE)
  }

  ## Before max(): max(numeric(0)) is -Inf and warns, which would both
  ## pollute output and silently defeat the support check below.
  if (n == 0L) {
    return(hzl_empty_result(id, individual))
  }

  scalef <- hzl_scalef(scale)
  years  <- times * scalef
  max_age <- max(age) + max(years)
  if (max_age > 110) {
    stop("age + follow-up reaches ", round(max_age, 1),
         " years, beyond the fits' support of 110. These models are not ",
         "extrapolated past the life table's range.", call. = FALSE)
  }

  strata <- hzl_assign_stratum(male, other, table, vintage)

  ## Cache one model per distinct stratum rather than per patient.
  models <- stats::setNames(
    lapply(unique(strata), function(s) us_lifetable_model(vintage, s)),
    unique(strata)
  )

  parts <- lapply(seq_len(n), function(i) {
    m <- models[[strata[i]]]
    H_age <- hzl_cumhaz(m$params, m$status, age[i])
    H_fu  <- hzl_cumhaz(m$params, m$status, age[i] + years)
    smatched <- exp(-(H_fu - H_age))
    hzl_assert_varies(smatched, times)
    data.frame(
      id       = rep(id[i], length(times)),
      time     = times,
      agesurv  = exp(-H_age),
      smatched = smatched,
      hmatched = hzl_hazard(m$params, m$status, age[i] + years),
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}
```

- [ ] **Step 4: Regenerate docs and run the tests**

```bash
Rscript -e 'roxygen2::roxygenise("."); devtools::test(filter = "us-matched")'
```

Expected: PASS, 20 tests.

- [ ] **Step 5: Commit**

```bash
git add R/us_matched.R tests/testthat/test-us-matched.R man/ NAMESPACE
git commit -m "feat: add us_matched() for individual reference survival curves"
```

---

## Task 5: The mean-curve reduction

The macro's default, and easy to get subtly wrong. It is **not** the mean of the hazards.

**Files:**
- Modify: `R/us_matched.R` (replace the `individual = FALSE` stub)
- Test: `tests/testthat/test-mean-curve.R`

**Interfaces:**
- Consumes: everything from Task 4.
- Produces: `us_matched(..., individual = FALSE)` → data frame with columns `time`, `smatched`, `hmatched`, one row per time.

The arithmetic, from `usmatchd.sas:338-350`, in order:

```
1. density  = hmatched * smatched          (per patient, per time)
2. smatched = mean(smatched)   by time     (across patients)
   density  = mean(density)    by time
3. hmatched = density / smatched
```

- [ ] **Step 1: Write the failing test**

Create `tests/testthat/test-mean-curve.R`:

```r
test_that("individual = FALSE returns one row per time", {
  r <- us_matched(age = c(60, 70, 80), male = c(1, 0, 1), other = c(0, 0, 1),
                  times = c(0, 5, 10), vintage = "table84",
                  individual = FALSE)
  expect_equal(nrow(r), 3L)
  expect_equal(names(r), c("time", "smatched", "hmatched"))
  expect_equal(r$time, c(0, 5, 10))
})

test_that("the mean curve reproduces the macro's density arithmetic exactly", {
  age <- c(60, 70, 80); male <- c(1, 0, 1); other <- c(0, 0, 1)
  times <- c(0, 5, 10)

  ind <- us_matched(age, male, other, times, vintage = "table84")
  agg <- us_matched(age, male, other, times, vintage = "table84",
                    individual = FALSE)

  # Recompute by hand, following usmatchd.sas:338-350
  ind$density <- ind$hmatched * ind$smatched
  mean_s <- tapply(ind$smatched, ind$time, mean)
  mean_d <- tapply(ind$density,  ind$time, mean)

  expect_equal(agg$smatched, as.numeric(mean_s), tolerance = 1e-14)
  expect_equal(agg$hmatched, as.numeric(mean_d / mean_s), tolerance = 1e-14)
})

test_that("the mean hazard is NOT the mean of the hazards", {
  # The distinction the macro is careful about. With a heterogeneous cohort
  # these differ; if they ever agree exactly, the reduction is wrong.
  age <- c(50, 90); male <- c(1, 1); other <- c(0, 0)
  times <- c(0, 10)

  agg <- us_matched(age, male, other, times, vintage = "table84",
                    individual = FALSE)
  ind <- us_matched(age, male, other, times, vintage = "table84")
  naive <- as.numeric(tapply(ind$hmatched, ind$time, mean))

  expect_false(isTRUE(all.equal(agg$hmatched, naive)))
})

test_that("a single-patient cohort reduces to that patient's own curve", {
  ind <- us_matched(70, 1, 0, c(0, 5, 10), vintage = "table84")
  agg <- us_matched(70, 1, 0, c(0, 5, 10), vintage = "table84",
                    individual = FALSE)
  expect_equal(agg$smatched, ind$smatched, tolerance = 1e-14)
  expect_equal(agg$hmatched, ind$hmatched, tolerance = 1e-14)
})

test_that("an empty cohort returns a zero-row aggregate frame", {
  # Removing the individual = FALSE stub lets the n == 0 early return serve
  # both shapes. The aggregate shape has no `id` column.
  r <- us_matched(numeric(0), numeric(0), numeric(0), times = c(0, 5),
                  vintage = "table84", individual = FALSE)
  expect_s3_class(r, "data.frame")
  expect_equal(nrow(r), 0L)
  expect_equal(names(r), c("time", "smatched", "hmatched"))
})

test_that("the mean curve keeps the survival invariants", {
  agg <- us_matched(age = c(55, 65, 75, 85), male = c(1, 0, 1, 0),
                    other = c(0, 1, 0, 1), times = seq(0, 10, by = 1),
                    vintage = "table84", individual = FALSE)
  expect_equal(agg$smatched[1], 1)
  expect_true(all(diff(agg$smatched) <= 0))
  expect_true(all(agg$hmatched > 0))
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Rscript -e 'devtools::test(filter = "mean-curve")'`
Expected: FAIL with `individual = FALSE is not yet implemented`.

- [ ] **Step 3: Remove the stub**

In `R/us_matched.R`, delete these four lines:

```r
  if (!isTRUE(individual)) {
    stop("`individual = FALSE` is not yet implemented.", call. = FALSE)
  }
```

- [ ] **Step 4: Add the reduction**

In `R/us_matched.R`, replace the final three lines of `us_matched()` —

```r
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}
```

— with:

```r
  out <- do.call(rbind, parts)
  rownames(out) <- NULL

  if (isTRUE(individual)) {
    return(out)
  }

  hzl_mean_curve(out)
}

## The macro's mean-curve reduction, from usmatchd.sas:338-350.
##
## Convert hazard to a density, take the cohort mean of survival and of the
## density at each time, then divide to recover a mean hazard. This is NOT
## the mean of the hazards, and the difference is not cosmetic in a
## heterogeneous cohort.
hzl_mean_curve <- function(out) {
  density  <- out$hmatched * out$smatched
  by_time  <- factor(out$time, levels = unique(out$time))

  mean_s <- tapply(out$smatched, by_time, mean)
  mean_d <- tapply(density,      by_time, mean)

  data.frame(
    time     = as.numeric(levels(by_time)),
    smatched = as.numeric(mean_s),
    hmatched = as.numeric(mean_d / mean_s),
    stringsAsFactors = FALSE
  )
}
```

- [ ] **Step 5: Update the `individual` documentation**

In the roxygen block for `us_matched()`, the `@param individual` and `@return`
entries already describe `FALSE` correctly. Add this note to `@details`, after
the `hmatched` paragraph:

```r
#' When `individual = FALSE`, the cohort mean follows the macro's arithmetic:
#' the hazard is converted to a density (`hmatched * smatched`), the cohort
#' means of survival and of the density are taken at each time, and the mean
#' hazard is recovered by division. It is deliberately **not** the mean of
#' the individual hazards.
```

- [ ] **Step 6: Regenerate docs and run all tests**

```bash
Rscript -e 'roxygen2::roxygenise("."); devtools::test()'
```

Expected: PASS, all files. The `individual = FALSE is not yet implemented`
test in `test-us-matched.R` will now **fail** — delete that test block, since
Task 5 is what implements it.

- [ ] **Step 7: Commit**

```bash
git add R/us_matched.R tests/testthat/ man/
git commit -m "feat: add the macro's mean-curve density reduction"
```

---

## Task 6: Vintage discrimination and the `hmatched` scale decision

Tier 4 from the spec. Guards against a future refactor quietly ignoring `vintage=` — a bug that would pass every other test in the suite, including the study's Tier 3 acceptance check.

**Files:**
- Create: `tests/testthat/test-vintage.R`
- Modify: `README.md` (document the `hmatched` units decision)

**Interfaces:** consumes the full public API. Produces nothing new.

- [ ] **Step 1: Write the tests**

Create `tests/testthat/test-vintage.R`:

```r
test_that("the three vintages give materially different curves", {
  # Tier 4. If a refactor drops `vintage` on the floor and always loads one
  # vintage, every other test in this suite still passes. This is the only
  # thing that catches it.
  args <- list(age = 70, male = 1, other = 0, times = 10)
  s84   <- do.call(us_matched, c(args, vintage = "table84"))$smatched
  s2008 <- do.call(us_matched, c(args, vintage = "table2008"))$smatched
  s2023 <- do.call(us_matched, c(args, vintage = "table2023"))$smatched

  expect_equal(length(unique(c(s84, s2008, s2023))), 3L)
  # Not a rounding difference -- the spike measured 0.13 to 0.24 apart.
  expect_gt(abs(s84 - s2008), 0.01)
  expect_gt(abs(s84 - s2023), 0.01)
})

test_that("vintages differ in model structure, not only fitted values", {
  # The spec cites white-male THALF 0.0519 -> 0.00544 and NU 4.595 -> -2.771
  # without naming the target vintage. Verified 2026-08-14: those numbers are
  # table84 -> table2008. table2023 is structurally like 2008 (same flags,
  # THALF 0.005437) but its NU is -2.000, not -2.771. Pin all three so the
  # ambiguity cannot resurface.
  f84 <- us_lifetable_model("table84",   "wm")$flags
  f08 <- us_lifetable_model("table2008", "wm")$flags
  expect_equal(unname(f84[["G1FLAG"]]), 2)
  expect_equal(unname(f84[["G3FLAG"]]), 4)
  expect_equal(unname(f08[["G1FLAG"]]), 6)
  expect_equal(unname(f08[["G3FLAG"]]), 3)

  p84 <- us_lifetable_model("table84",   "wm")$params
  p08 <- us_lifetable_model("table2008", "wm")$params
  p23 <- us_lifetable_model("table2023", "wm")$params
  expect_equal(unname(p84[["THALF"]]), 0.05188786,  tolerance = 1e-7)
  expect_equal(unname(p08[["THALF"]]), 0.005438513, tolerance = 1e-7)
  expect_equal(unname(p84[["NU"]]),  4.595204, tolerance = 1e-6)
  expect_equal(unname(p08[["NU"]]), -2.771113, tolerance = 1e-6)
  expect_equal(unname(p23[["NU"]]), -1.999947, tolerance = 1e-6)
})

test_that("the non-white stratum resolves per vintage, not globally", {
  # A hardcoded "b" would silently error on table84; a hardcoded "o" would
  # silently error on 2023. Both directions must work.
  expect_silent(us_matched(70, 1, 1, 5, vintage = "table84",
                           table = "race"))
  expect_silent(us_matched(70, 1, 1, 5, vintage = "table2023",
                           table = "race"))
  expect_false(isTRUE(all.equal(
    us_matched(70, 1, 1, 5, vintage = "table84",   table = "race")$smatched,
    us_matched(70, 1, 1, 5, vintage = "table2023", table = "race")$smatched
  )))
})

test_that("every shipped stratum evaluates without error", {
  # Sweeps all 27 records. Catches a single malformed block that the
  # targeted tests above would miss.
  for (i in seq_len(nrow(us_lifetable_models))) {
    v <- us_lifetable_models$vintage[i]
    s <- us_lifetable_models$stratum[i]
    m <- us_lifetable_model(v, s)
    h <- hzl_hazard(m$params, m$status, c(1, 40, 70, 100))
    expect_true(all(h > 0), info = paste(v, s))
    expect_true(all(is.finite(h)), info = paste(v, s))
    H <- hzl_cumhaz(m$params, m$status, c(1, 40, 70, 100))
    expect_true(all(diff(H) > 0), info = paste(v, s))
  }
})
```

- [ ] **Step 2: Run the tests**

```bash
Rscript -e 'devtools::test(filter = "vintage")'
```

Expected: PASS, 4 tests.

- [ ] **Step 3: Document the `hmatched` units decision in README**

Add this section to `README.md`, immediately after the "Race semantics" section:

```markdown
## `hmatched` is per year, always

Whatever `scale=` you pass, `time` is in those units but `hmatched` is a
hazard per **year**.

This matches the macro's source. `usmatchd.sas:227` assigns `HMATCHED =
_HAZARD` with no `SCALEF` multiplication, and `PROC HAZPRED` is evaluated at
`AGE_YR` in years. The macro's own header comment at line 47 claims
`HMATCHED` is "scaled by SCALE" and is wrong — but it has never mattered,
because every job that consumes it uses `scale="years"`, where `SCALEF = 1`.

This package reproduces the code, not the comment, because bit-fidelity to
the macro is the acceptance criterion. If you need a per-month or per-day
hazard, multiply by the corresponding `SCALEF` yourself.
```

- [ ] **Step 4: Checkpoint — flag this to John**

Stop here and surface the `hmatched` units question. It is the one place this
plan makes a judgement call the spec disagrees with. If John wants the spec's
behaviour instead, it is a one-line change in `us_matched()` plus the README
section above — not a redesign.

- [ ] **Step 5: Commit**

```bash
git add tests/testthat/test-vintage.R README.md
git commit -m "test: add Tier 4 vintage discrimination; document hmatched units"
```

---

## Task 7: Release gate

**Files:**
- Modify: `NEWS.md`
- Create: `_pkgdown.yml`
- Modify: `.Rbuildignore` (already ignores `^_pkgdown\.yml$` and `^docs$` — verify)

Per John's standing rules, the full release gate applies whether or not this
goes to CRAN. `R CMD check --as-cran` **with** the manual (no `--no-manual`),
built from a clean `git archive` export rather than the working tree.

- [ ] **Step 1: Update NEWS.md**

Replace the body of `NEWS.md` with:

```markdown
# hvtiRlifetables 0.1.0

Initial release.

## New features

- `us_matched()` reproduces the CCF SAS macro `%usmatchd`: age, sex and race
  matched US reference survival and its hazard, for individual patients or as
  a cohort mean curve. Argument names and the `table=` modes mirror the macro
  so a SAS job translates by inspection.
- `us_lifetable_vintages()` reports the available vintages with their
  provenance and, importantly, what each vintage's non-white stratum actually
  contains.
- `us_lifetable_model()` returns a single fitted parameter set for inspection.
- Ships `us_lifetable_models`, 27 fitted three-phase hazard parameter sets —
  nine strata across `table84`, `table2008` and `table2023` — with their
  `_STATUS_` gates, fitted-form flags and covariance blocks.

## Design notes

- `vintage` has no default. Omitting it is an error listing the available
  vintages. The macro's default silently moved from `table84` to `table2023`
  and jobs re-run across that change got different numbers with no signal.
- `hmatched` is per year regardless of `scale`, matching the macro's source
  rather than its header comment. See the README.
- The `table2023` non-white stratum is stored under code `b` but is a
  risk-weighted average of Black, Asian, American Indian and Hispanic death
  rates. It is not Black. The macro's comment says otherwise and is wrong.
- Covariance blocks ship but nothing reads them. They are the only route to a
  confidence band later.
```

- [ ] **Step 2: Add a pkgdown config**

Create `_pkgdown.yml`:

```yaml
url: https://ehrlinger.github.io/hvtiRlifetables/

template:
  bootstrap: 5

destination: pkgdown

reference:
  - title: Reference survival
    contents:
      - us_matched
  - title: Vintages and fitted models
    contents:
      - us_lifetable_vintages
      - us_lifetable_model
      - us_lifetable_models
```

Note the non-default `destination:` — `docs/` holds `docs/specs/` and
`docs/plans/` and must not be overwritten by pkgdown. Add `^pkgdown$` to
`.Rbuildignore` if it is not already there (it is).

- [ ] **Step 3: Build from a clean export and check**

Building from the working tree fabricates two spurious problems: an empty
`inst/doc` invents vignette WARNINGs, and in a git worktree `.git` is a
*file*, so `R CMD build`'s VCS exclusion misses it and it lands in the
tarball as a "hidden files and directories" NOTE. Neither is a real defect.

```bash
rm -rf /tmp/hvtiRlifetables-export && mkdir -p /tmp/hvtiRlifetables-export && git archive HEAD | tar -x -C /tmp/hvtiRlifetables-export
```

The export will **not** contain `data-raw/uslife/` (gitignored) — that is
correct and expected. `data/us_lifetable_models.rda` is tracked and will be
there, which is what `R CMD check` needs.

```bash
cd /tmp && R CMD build /tmp/hvtiRlifetables-export && R CMD check --as-cran hvtiRlifetables_0.1.0.tar.gz
```

Expected: `Status: OK`, 0 errors, 0 warnings, 0 notes.

- [ ] **Step 4: Run the CRAN Cookbook spot-checks**

Verify against <https://contributor.r-project.org/cran-cookbook/>. The ones
that recur:

- `\value` / `@return` on every exported object — `us_matched`,
  `us_lifetable_vintages`, `us_lifetable_model`. The dataset needs `@format`,
  which it has.
- No `\dontrun{}`; use `\donttest{}` if any example gets slow. None should.
- Title Case in `Title:`. Currently "Age, Sex and Race Matched US Reference
  Survival" — correct.
- Quoted software names in `Description:` — `'SAS'`, `'TemporalHazard'`,
  `'usmatchd'`. Already done.
- Space-free `<doi:...>` in `Description:`. Already done.
- No `<<-`, no `.GlobalEnv` writes, no `set.seed()`, no `options()`/`par()`/
  `setwd()` changes, no `print()`/`cat()`/`message()` in function bodies.
  `data-raw/build-models.R` uses `cat()` and is not shipped, which is fine.
- Tarball under 5 MB. It will be far under.
- Check time budget under 10 minutes overall. Read the per-step `[Ns]`
  timings from the check log. This package has no vignettes and a small test
  suite, so it should be well under a minute.

- [ ] **Step 5: Check URLs**

```bash
Rscript -e 'urlchecker::url_check()'
```

Expected: no broken URLs. The pkgdown URL will 404 until the site is first
published — that is expected and not a blocker.

- [ ] **Step 6: Commit**

```bash
git add NEWS.md _pkgdown.yml
git commit -m "docs: prepare 0.1.0 release notes and pkgdown config"
```

---

## Task 8: Update the handoff and open the PR

**Files:**
- Modify: `HANDOFF.md`
- Modify: `docs/specs/2026-08-13-hvtirlifetables-design.md`

**No CI in this task.** `.github/workflows/` is deliberately deferred: CRAN's
`TemporalHazard` is 1.1.0 and `DESCRIPTION` requires `>= 1.2.0`, so any
workflow added now fails at the dependency-install step and stays red. Add CI
in a follow-up once `TemporalHazard 1.2.0` is on CRAN.

- [ ] **Step 1: Update HANDOFF.md**

Replace the `**State (2026-08-14):**` paragraph with:

```markdown
**State:** implemented. `us_matched()`, `us_lifetable_vintages()` and
`us_lifetable_model()` are complete, with Tier 1, 2 and 4 tests passing and
`R CMD check --as-cran` at 0/0/0 with the manual. Tier 3 SAS acceptance
still needs writing, in the **study's** `R_parity` project, not here.
```

Replace the task outline (items 1-8) with:

```markdown
## Task outline

Steps 1-6 and 8 are **done** — see
`docs/plans/2026-08-14-hvtirlifetables-implementation.md`. Remaining:

1. **Tier 3 SAS acceptance**, in the study's `R_parity`: `us_matched()`
   against `estimates/uslife.sas7bdat` to 1e-12 on both `SMATCHED` and
   `HMATCHED`, reported **per stratum**, skipping when the share is absent.
   A cohort-wide maximum hid the `_STATUS_` bug behind a plausible
   near-miss; do not report one.
2. **CI**, once `TemporalHazard 1.2.0` reaches CRAN. Blocked until then.
3. **The `hs.*` job template** that consumes `us_matched()`. Belongs in
   `hvtiRtemplates` / `~/Documents/template/`, not here.
```

- [ ] **Step 2: Mark the spec implemented**

At the top of `docs/specs/2026-08-13-hvtirlifetables-design.md`, change:

```markdown
**Status:** Design, awaiting review. Not yet built.
```

to:

```markdown
**Status:** Implemented 2026-08-14, except Tier 3 acceptance (which lives in
the study's `R_parity`). Plan:
`docs/plans/2026-08-14-hvtirlifetables-implementation.md`.

**One deviation from this spec, deliberate.** The spec says `hmatched` is
returned in the units of `scale`. The macro's source says otherwise —
`usmatchd.sas:227` applies no `SCALEF` — and the implementation follows the
source. See the README.
```

- [ ] **Step 3: Verify the CCF fits are still untracked**

```bash
git status --porcelain data-raw/uslife/ | wc -l
```

Expected: `0`. If not, **stop** — do not push.

- [ ] **Step 4: Final full check**

```bash
Rscript -e 'devtools::test()' && Rscript -e 'devtools::check(manual = TRUE, cran = TRUE)'
```

Expected: all tests pass; `0 errors | 0 warnings | 0 notes`.

- [ ] **Step 5: Commit and open the PR**

```bash
git add HANDOFF.md docs/
git commit -m "docs: mark the design spec implemented and update the handoff"
```

```bash
git push -u origin HEAD
```

```bash
gh pr create --base main --title "feat: implement us_matched() reference survival" --body "Implements the design spec. us_matched(), us_lifetable_vintages() and us_lifetable_model(), with Tier 1, 2 and 4 tests and R CMD check --as-cran at 0/0/0 with the manual.

One deliberate deviation from the spec: hmatched is per year regardless of scale=, matching usmatchd.sas:227 rather than the spec and the macro's own header comment. Documented in the README.

Tier 3 SAS acceptance is not here by design (PHI-adjacent, lives in the study's R_parity). CI is deferred until TemporalHazard 1.2.0 reaches CRAN.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

---

## Deferred, with reasons

Not oversights — each was considered and pushed out.

| Item | Why deferred |
|---|---|
| Tier 3 SAS acceptance | PHI-adjacent. Lives in the study's `R_parity`, skipping when the share is absent. Per spec. |
| GitHub Actions CI | CRAN's `TemporalHazard` is 1.1.0; `DESCRIPTION` needs `>= 1.2.0`. Any workflow added now is permanently red. |
| Confidence bands | Covariance blocks ship; nothing reads them. Explicit v1 non-goal. |
| `survexp.usr` approximation mode | Spec's "Future work". Scope and acceptance bounds undecided. |
| Adding `table2009` | Empty on disk. Needs one question to Andrew Toth first. |
| A vignette | No CRAN target yet, and the README plus `us_matched()` examples cover the API. Add when the `hs.*` template exists to show a real figure. |
