## us_cohort_curve(): the cohort reduction as a callable, and the reporting
## grouping that `table=` does not provide. Issues #16 and #17.
##
## test-mean-curve.R already pins the arithmetic itself through
## `individual = FALSE`; what is pinned here is that the export is the same
## arithmetic, and what the grouping does.

cohort <- function() {
  us_matched(age = c(55, 60, 78, 82), male = c(1, 0, 1, 0),
             other = c(0, 0, 1, 1), times = c(0, 5, 10), vintage = "table84")
}

test_that("the ungrouped curve is exactly what individual = FALSE returns", {
  # The two must not be able to drift: us_matched() routes through this.
  x   <- cohort()
  agg <- us_matched(age = c(55, 60, 78, 82), male = c(1, 0, 1, 0),
                    other = c(0, 0, 1, 1), times = c(0, 5, 10),
                    vintage = "table84", individual = FALSE)
  expect_equal(us_cohort_curve(x), agg)
  expect_equal(names(us_cohort_curve(x)), c("time", "smatched", "hmatched"))
})

test_that("the ungrouped curve reproduces the macro's density arithmetic", {
  x <- cohort()
  g <- us_cohort_curve(x)
  mean_s <- tapply(x$smatched, x$time, mean)
  mean_d <- tapply(x$hmatched * x$smatched, x$time, mean)
  expect_equal(g$smatched, as.numeric(mean_s), tolerance = 1e-14)
  expect_equal(g$hmatched, as.numeric(mean_d / mean_s), tolerance = 1e-14)
})

test_that("a grouping splits the curve and reports the group first", {
  x <- cohort()
  band <- factor(c("55-79", "55-79", "55-79", "80+")[x$id],
                 levels = c("55-79", "80+"))
  g <- us_cohort_curve(x, by = band)
  expect_equal(names(g), c("group", "time", "smatched", "hmatched"))
  expect_equal(nrow(g), 6L)
  expect_equal(as.character(g$group), c(rep("55-79", 3), rep("80+", 3)))
  expect_equal(g$time, c(0, 5, 10, 0, 5, 10))
})

test_that("each group's curve is the curve of that group alone", {
  # The property that matters clinically: a stratified panel must equal the
  # panel you would get by subsetting the cohort first.
  x <- cohort()
  band <- c("55-79", "55-79", "55-79", "80+")[x$id]
  g <- us_cohort_curve(x, by = band)
  for (b in unique(band)) {
    alone <- us_cohort_curve(x[band == b, , drop = FALSE])
    got   <- g[g$group == b, c("time", "smatched", "hmatched")]
    rownames(got) <- NULL
    expect_equal(got, alone, tolerance = 1e-14)
  }
})

test_that("a single group reproduces the ungrouped curve", {
  x <- cohort()
  g <- us_cohort_curve(x, by = rep("everyone", nrow(x)))
  expect_equal(g[, c("time", "smatched", "hmatched")], us_cohort_curve(x),
               tolerance = 1e-14)
})

test_that("groups and times keep their order of first appearance", {
  # Not the factor's level order: the caller's row order is the one that
  # matches whatever they are plotting against.
  x <- cohort()
  band <- factor(c("b", "b", "b", "a")[x$id], levels = c("a", "b"))
  g <- us_cohort_curve(x, by = band)
  expect_equal(as.character(g$group), c(rep("b", 3), rep("a", 3)))
})

test_that("grouping by a column of x is just by = x$col", {
  # `by` carries values, so there is no column-name mode to disambiguate.
  x <- cohort()
  x$arm <- c("ctrl", "trt", "ctrl", "trt")[x$id]
  g <- us_cohort_curve(x, by = x$arm)
  expect_equal(names(g), c("group", "time", "smatched", "hmatched"))
  expect_equal(nrow(g), 6L)
  named <- us_cohort_curve(x, by = list(arm = x$arm))
  expect_equal(names(named), c("arm", "time", "smatched", "hmatched"))
  expect_equal(g$smatched, named$smatched)
})

test_that("a crossed grouping reports both columns", {
  x <- cohort()
  g <- us_cohort_curve(x, by = list(
    arm  = c("ctrl", "trt", "ctrl", "trt")[x$id],
    band = c("55-79", "55-79", "55-79", "80+")[x$id]
  ))
  expect_equal(names(g), c("arm", "band", "time", "smatched", "hmatched"))
  expect_equal(nrow(g), 9L)
})

test_that("an unnamed list `by` is refused", {
  x <- cohort()
  expect_error(us_cohort_curve(x, by = list(c("a", "b", "a", "b")[x$id])),
               "must be fully named")
})

test_that("a `by` of the wrong length names the expansion needed", {
  x <- cohort()
  # The mistake this catches: passing the PATIENT-level grouping straight in,
  # when x carries one row per patient per time.
  expect_error(us_cohort_curve(x, by = c("a", "a", "b", "b")),
               "match\\(x\\$id, ids\\)")
})

test_that("a grouping column may not be called time, smatched or hmatched", {
  x <- cohort()
  expect_error(us_cohort_curve(x, by = list(time = rep("a", nrow(x)))),
               "already uses")
})

test_that("an already-aggregated frame is refused rather than averaged twice", {
  agg <- us_matched(age = c(60, 70), male = c(1, 0), other = c(0, 0),
                    times = c(0, 5), vintage = "table84", individual = FALSE)
  expect_error(us_cohort_curve(agg), "already a cohort curve")
})

test_that("a frame that is not us_matched output at all is refused", {
  expect_error(us_cohort_curve(data.frame(id = 1, time = 1)), "missing the column")
  expect_error(us_cohort_curve(1:10), "must be the data frame")
})

test_that("an empty cohort returns the documented columns with zero rows", {
  empty <- us_matched(numeric(0), numeric(0), numeric(0), times = c(0, 5),
                      vintage = "table84")
  expect_equal(nrow(empty), 0L)
  g <- us_cohort_curve(empty)
  expect_s3_class(g, "data.frame")
  expect_equal(nrow(g), 0L)
  expect_equal(names(g), c("time", "smatched", "hmatched"))

  gg <- us_cohort_curve(empty, by = factor(character(0)))
  expect_equal(nrow(gg), 0L)
  expect_equal(names(gg), c("group", "time", "smatched", "hmatched"))
})

test_that("the grouped curves keep the survival invariants", {
  x <- us_matched(age = c(55, 65, 75, 85), male = c(1, 0, 1, 0),
                  other = c(0, 1, 0, 1), times = seq(0, 10, by = 1),
                  vintage = "table84")
  g <- us_cohort_curve(x, by = factor(c("y", "y", "o", "o")[x$id]))
  for (lev in unique(as.character(g$group))) {
    s <- g$smatched[g$group == lev]
    expect_equal(s[1], 1)
    expect_true(all(diff(s) <= 0))
  }
  expect_true(all(g$hmatched > 0))
})

test_that("grouping is independent of the table= stratification", {
  # Issue #17's whole point: the life table stays sexrace while the REPORT is
  # split by a study-chosen band.
  x <- us_matched(age = c(55, 60, 78, 82), male = c(1, 0, 1, 0),
                  other = c(0, 0, 1, 1), times = c(0, 5),
                  vintage = "table84", table = "sexrace")
  g <- us_cohort_curve(x, by = factor(c("y", "y", "o", "o")[x$id]))
  expect_equal(nrow(g), 4L)
  # Older band, lower expected survival at five years. If the grouping had
  # silently changed the matching, this would not hold.
  s_y <- g$smatched[g$group == "y" & g$time == 5]
  s_o <- g$smatched[g$group == "o" & g$time == 5]
  expect_gt(s_y, s_o)
})
