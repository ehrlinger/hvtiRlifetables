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
#'     `"wm"`, plus the vintage's non-white codes -- `"o"`, `"of"`, `"om"` for
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

## Reaching this package's own dataset from package code.
##
## `us_lifetable_models` is lazy-loaded, and a lazy-loaded dataset is promised
## into the PACKAGE environment, never into the namespace. A function's
## enclosing environment is the namespace, whose parents run namespace ->
## imports -> base -> global; the package environment is not on that chain. So
## a bare `us_lifetable_models` anywhere in R/ resolves only while the
## package happens to be ATTACHED, and every export failed under `::` -- with
## "object 'us_lifetable_models' not found", naming an internal object the
## caller has never heard of. It went unseen because every caller so far had
## run library() first.
##
## The dataset stays user-visible rather than moving to R/sysdata.rda: it is
## documented above, it is what someone inspects when a stratum looks wrong,
## and demoting it would remove a public object to fix an internal bug.
##
## Cached because the lookup below is not free and us_matched() reaches for
## the models once per distinct stratum. parent = emptyenv() so a failed
## lookup here cannot fall through to something else with the same name.
.hzl_data <- new.env(parent = emptyenv())

hzl_models <- function() {
  if (is.null(.hzl_data$us_lifetable_models)) {
    .hzl_data$us_lifetable_models <- hzl_load_models()
  }
  .hzl_data$us_lifetable_models
}

## Three places the dataset can be, and the package must work in all three:
## installed (attached or not), and loaded by devtools::load_all() during
## development. The development case is not hypothetical politeness -- it is
## the case in which this whole class of bug is INVISIBLE, because load_all()
## makes the data reachable by bare name and an installed package does not.
## A fix that only worked when installed would break `devtools::test()`.
hzl_load_models <- function() {
  ns <- asNamespace("hvtiRlifetables")

  ## Where an installed package's lazy-load database is bound. Reachable from
  ## here by asking for it, but NOT on the parent chain a bare name resolves
  ## against -- which is the whole of issue #18.
  lazy <- tryCatch(getNamespaceInfo(ns, "lazydata"), error = function(e) NULL)
  if (is.environment(lazy) &&
        exists("us_lifetable_models", envir = lazy, inherits = FALSE)) {
    return(get("us_lifetable_models", envir = lazy, inherits = FALSE))
  }

  ## load_all() binds data/ into the namespace itself in some versions.
  if (exists("us_lifetable_models", envir = ns, inherits = FALSE)) {
    return(get("us_lifetable_models", envir = ns, inherits = FALSE))
  }

  ## An installed package whose lazy-load database was not consulted above --
  ## LazyData off, say. data() warns rather than errors when it finds
  ## nothing, which would leave NULL to fail further down as "$ on NULL", so
  ## the miss is named here instead.
  found <- new.env(parent = emptyenv())
  data("us_lifetable_models", package = "hvtiRlifetables", envir = found)
  if (!exists("us_lifetable_models", envir = found, inherits = FALSE)) {
    stop("the fitted models dataset could not be loaded from the installed ",
         "package. Reinstall hvtiRlifetables; data/us_lifetable_models.rda ",
         "is missing or unreadable.", call. = FALSE)
  }
  get("us_lifetable_models", envir = found, inherits = FALSE)
}
