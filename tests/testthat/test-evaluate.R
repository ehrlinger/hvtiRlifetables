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
  # hzl_hazard errors at exactly age 0 (see the age-0 test above), so its
  # length/vectorisation check uses a positive-age vector instead.
  a_pos <- c(1, 40, 70, 100)
  expect_length(hzl_cumhaz(m$params, m$status, a), 5L)
  expect_length(hzl_hazard(m$params, m$status, a_pos), 4L)
  # elementwise agreement with the scalar calls
  expect_equal(
    hzl_cumhaz(m$params, m$status, a),
    vapply(a, function(x) hzl_cumhaz(m$params, m$status, x), numeric(1))
  )
  expect_equal(
    hzl_hazard(m$params, m$status, a_pos),
    vapply(a_pos, function(x) hzl_hazard(m$params, m$status, x), numeric(1))
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
