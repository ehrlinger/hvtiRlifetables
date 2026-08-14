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
