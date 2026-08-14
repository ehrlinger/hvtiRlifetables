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
  expect_equal(unname(p84[["THALF"]]), 0.051887864,  tolerance = 1e-7)
  expect_equal(unname(p08[["THALF"]]), 0.0054385105, tolerance = 1e-7)
  expect_equal(unname(p84[["NU"]]),  4.5952045, tolerance = 1e-6)
  expect_equal(unname(p08[["NU"]]), -2.77111, tolerance = 1e-6)
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
