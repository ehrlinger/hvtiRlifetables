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
