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

test_that("negative or unsorted times error", {
  expect_error(us_matched(70, 1, 0, times = c(-1, 5), vintage = "table84"),
               "negative")
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
