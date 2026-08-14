test_that("us_lifetable_models has 27 records, nine strata per vintage", {
  expect_s3_class(us_lifetable_models, "data.frame")
  expect_equal(nrow(us_lifetable_models), 27L)
  expect_setequal(
    unique(us_lifetable_models$vintage),
    c("table84", "table2008", "table2023")
  )
  expect_true(all(table(us_lifetable_models$vintage) == 9L))
})

test_that("table84 names its non-white strata 'o', 2008 and 2023 name them 'b'", {
  s84 <- sort(us_lifetable_models$stratum[us_lifetable_models$vintage == "table84"])
  expect_equal(s84, sort(c("all", "f", "m", "w", "o", "wf", "wm", "of", "om")))

  s23 <- sort(us_lifetable_models$stratum[us_lifetable_models$vintage == "table2023"])
  expect_equal(s23, sort(c("all", "f", "m", "w", "b", "wf", "wm", "bf", "bm")))
})

test_that("the excluded 2008 extras did not sneak in via a glob", {
  expect_false(any(grepl("_jr|_l$", us_lifetable_models$stratum)))
})

test_that("each record carries 11 parameters, 11 statuses, 6 flags, an 11x11 vcov", {
  nm <- c("DELTA", "THALF", "NU", "M", "TAU", "GAMMA", "ALPHA", "ETA",
          "E0", "C0", "L0")
  for (i in seq_len(nrow(us_lifetable_models))) {
    expect_equal(names(us_lifetable_models$params[[i]]), nm)
    expect_equal(names(us_lifetable_models$status[[i]]), nm)
    expect_length(us_lifetable_models$flags[[i]], 6L)
    expect_equal(dim(us_lifetable_models$vcov[[i]]), c(11L, 11L))
    expect_equal(dimnames(us_lifetable_models$vcov[[i]]), list(nm, nm))
  }
})

test_that("status is integer 0/1 with no NA -- the flag rows were separated out", {
  for (i in seq_len(nrow(us_lifetable_models))) {
    st <- us_lifetable_models$status[[i]]
    expect_type(st, "integer")
    expect_false(anyNA(st))
    expect_true(all(st %in% c(0L, 1L)))
  }
})

test_that("the table84 'om' _STATUS_ trap survived the build", {
  # C0 = 0 with _STATUS_ = 0. If a future build coerces this to status 1,
  # every non-white male gets a constant 1/yr hazard and their survival
  # collapses. See the plan's Global Constraints.
  i <- which(us_lifetable_models$vintage == "table84" &
             us_lifetable_models$stratum == "om")
  expect_length(i, 1L)
  expect_equal(unname(us_lifetable_models$params[[i]][["C0"]]), 0)
  expect_equal(unname(us_lifetable_models$status[[i]][["C0"]]), 0L)
  expect_equal(unname(us_lifetable_models$status[[i]][["E0"]]), 1L)
  expect_equal(unname(us_lifetable_models$status[[i]][["L0"]]), 1L)
})
