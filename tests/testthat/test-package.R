test_that("the package loads and declares its dependency on TemporalHazard", {
  expect_true(requireNamespace("hvtiRlifetables", quietly = TRUE))
  expect_gte(
    packageVersion("TemporalHazard"),
    package_version("1.2.0")
  )
})
