test_that("the documented public API is exported", {
  # Guards against a roxygen regeneration silently dropping an @export.
  # Deliberately not a `requireNamespace()` smoke test: tests/testthat.R has
  # already attached the package, so that assertion can never fail and
  # therefore tests nothing.
  expect_setequal(
    getNamespaceExports("hvtiRlifetables"),
    c("us_matched", "us_cohort_curve", "us_lifetable_vintages",
      "us_lifetable_model")
  )
})

test_that("internal helpers stay internal", {
  # hzl_* is the internal prefix. Exporting one would make it public API we
  # then have to keep stable.
  expect_false(any(grepl("^hzl_", getNamespaceExports("hvtiRlifetables"))))
})
