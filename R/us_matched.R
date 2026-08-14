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
#'   unchanged. What "non-white" contains differs by vintage -- see
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
