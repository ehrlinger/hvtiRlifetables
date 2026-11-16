# The hvtiR API rubric: errors a caller may catch carry
# `hvtiRlifetables_<condition>` and the shared `hvtiRlifetables_error`.

expect_classed <- function(expr, cls) {
  err <- tryCatch(expr, error = function(e) e)
  testthat::expect_s3_class(err, paste0("hvtiRlifetables_", cls))
  testthat::expect_s3_class(err, "hvtiRlifetables_error")
  testthat::expect_null(conditionCall(err))
}

test_that("vintage errors are classed", {
  expect_classed(us_matched(70, 1, 0, times = 5), "vintage")
  expect_classed(us_matched(70, 1, 0, times = 5, vintage = "table1999"),
                 "vintage")
  expect_classed(us_lifetable_model("table2009", "wm"), "vintage")
})

test_that("an unknown stratum is classed", {
  expect_classed(us_lifetable_model("table84", "bm"), "stratum")
})

test_that("leaving the fits' support is classed", {
  expect_classed(us_matched(105, 1, 0, times = 10, vintage = "table84"),
                 "support")
})

test_that("the hazard at exactly age 0 is classed", {
  m <- us_lifetable_model("table84", "wm")
  expect_classed(hzl_hazard(m$params, m$status, 0), "age_zero")
})

test_that("a degenerate model is classed", {
  m <- us_lifetable_model("table84", "wm")
  m$status[c("E0", "C0", "L0")] <- 0L
  expect_classed(hzl_cumhaz(m$params, m$status, 50), "degenerate")
})

test_that("us_cohort_curve(x = ) still works, warning once per session", {
  r <- us_matched(c(50, 60), c(1, 0), c(0, 0), times = c(0, 5),
                  vintage = "table84")
  rm(list = ls(.hzl_warned), envir = .hzl_warned)
  expect_warning(out <- us_cohort_curve(x = r), class = "hvtiRlifetables_deprecated")
  expect_identical(out, us_cohort_curve(r))
  expect_silent(us_cohort_curve(x = r))
  expect_error(us_cohort_curve(r, x = r), "deprecated name")
})

test_that("the newborn and time-grid stops are classed", {
  expect_classed(us_matched(0, 1, 0, times = c(0, 1), vintage = "table84"),
                 "age_zero")
  a <- us_matched(c(50, 60), c(1, 0), c(0, 0), times = c(0, 5, 10),
                  vintage = "table84")
  b <- us_matched(70, 1, 0, times = c(0, 5), id = 3, vintage = "table84")
  expect_classed(us_cohort_curve(rbind(a, b)), "grid")
  s1 <- us_matched(50, 0, 0, times = c(0, 1), id = "s", vintage = "table84")
  s2 <- us_matched(80, 0, 0, times = c(0, 2), id = "s", vintage = "table84")
  expect_classed(us_cohort_curve(rbind(s1, s2)), "grid")
})
