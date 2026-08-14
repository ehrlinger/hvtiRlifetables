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
