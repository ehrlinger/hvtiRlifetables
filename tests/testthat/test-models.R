test_that("us_lifetable_vintages reports the three usable vintages", {
  v <- us_lifetable_vintages()
  expect_s3_class(v, "data.frame")
  expect_setequal(v$vintage, c("table84", "table2008", "table2023"))
  expect_true(all(v$n_strata == 9L))
})

test_that("us_lifetable_vintages does not repeat the macro's race error", {
  v <- us_lifetable_vintages()
  expect_equal(v$nonwhite_code[v$vintage == "table84"], "o")
  expect_equal(v$nonwhite_code[v$vintage == "table2023"], "b")
  # The 2023 'b' stratum is NOT Black. Assert the documentation says so.
  expect_no_match(
    v$nonwhite_meaning[v$vintage == "table2023"],
    "^Black$"
  )
  expect_match(v$nonwhite_meaning[v$vintage == "table2023"], "risk-weighted")
  expect_match(v$nonwhite_meaning[v$vintage == "table84"], "[Oo]ther")
})

test_that("us_lifetable_model returns one parameter set", {
  m <- us_lifetable_model("table84", "wm")
  expect_type(m, "list")
  expect_equal(m$vintage, "table84")
  expect_equal(m$stratum, "wm")
  expect_length(m$params, 11L)
  expect_length(m$status, 11L)
  expect_equal(dim(m$vcov), c(11L, 11L))
  expect_equal(unname(m$params[["THALF"]]), 0.05188786, tolerance = 1e-7)
})

test_that("an unknown vintage errors and lists what is available", {
  expect_error(us_lifetable_model("table1999", "wm"), "table1999")
  expect_error(us_lifetable_model("table1999", "wm"), "table84")
  expect_error(us_lifetable_model("table1999", "wm"), "table2023")
})

test_that("table2009 errors as empty on disk, not as not-found", {
  expect_error(us_lifetable_model("table2009", "wm"), "empty")
})

test_that("a stratum absent from a vintage errors and names the alternative", {
  # 'o' exists in table84 only; 'b' in 2008/2023 only. Match on the quoted
  # stratum and on the naming hint, not on a bare letter -- a one-character
  # regex matches almost any error message and would pass vacuously.
  expect_error(us_lifetable_model("table2023", "o"),
               'has no stratum "o"', fixed = TRUE)
  expect_error(us_lifetable_model("table2023", "o"), "table84 uses")
  expect_error(us_lifetable_model("table84", "b"),
               'has no stratum "b"', fixed = TRUE)
})

test_that("a missing vintage errors rather than defaulting", {
  expect_error(us_lifetable_model(stratum = "wm"), "vintage")
})

test_that("hzl_nonwhite_code follows the vintage's naming", {
  expect_equal(hzl_nonwhite_code("table84"), "o")
  expect_equal(hzl_nonwhite_code("table2008"), "b")
  expect_equal(hzl_nonwhite_code("table2023"), "b")
})

test_that("hzl_mu honours the _STATUS_ gate -- Tier 2 regression", {
  # THE trap. table84/om has C0 = 0 with _STATUS_ = 0. Reading that as
  # exp(0) = 1 injects a constant 1/yr hazard and collapses survival for
  # every non-white male.
  m <- us_lifetable_model("table84", "om")
  expect_equal(hzl_mu(m$params, m$status, "C0"), 0)
  expect_gt(hzl_mu(m$params, m$status, "E0"), 0)
  expect_gt(hzl_mu(m$params, m$status, "L0"), 0)
})

test_that("hzl_mu exponentiates only when status is 1", {
  p <- c(E0 = -4, C0 = -7, L0 = 0)
  s <- c(E0 = 1L, C0 = 0L, L0 = 1L)
  expect_equal(hzl_mu(p, s, "E0"), exp(-4))
  expect_equal(hzl_mu(p, s, "C0"), 0)      # NOT exp(-7)
  expect_equal(hzl_mu(p, s, "L0"), 1)      # exp(0), because status is 1
})
