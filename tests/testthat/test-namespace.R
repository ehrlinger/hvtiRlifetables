## Regression tests for the lazy-data namespace bug (issue #18): every export
## failed under `::` because package code referenced the lazy-loaded dataset
## by bare name, and a lazy-loaded dataset lives in the package environment
## rather than the namespace.
##
## ⚠️ These MUST run in a subprocess. `tests/testthat.R` calls
## `library(hvtiRlifetables)` before `test_check()`, so every other file in
## this directory runs with the package ATTACHED -- and the broken code passes
## when attached. A test written here in the ordinary way would have proved
## nothing, which is exactly how the defect survived to 0.1.1.

## Run `code` in a fresh R with this session's library path and nothing
## attached. Returns the child's combined output, with its exit status in the
## "status" attribute.
detached_r <- function(code) {
  rscript <- file.path(R.home("bin"), "Rscript")
  skip_if_not(file.exists(rscript), "no Rscript in R.home('bin')")
  libs <- paste(.libPaths(), collapse = .Platform$path.sep)
  suppressWarnings(
    system2(rscript, c("--vanilla", "-e", shQuote(code)),
            stdout = TRUE, stderr = TRUE,
            env = paste0("R_LIBS=", shQuote(libs)))
  )
}

## Written as one `;`-joined line: the child receives it as a single -e
## argument, and a literal newline inside shQuote() is portable but harder to
## read in a failure message than the flat form.
detached_call <- function(expr) {
  paste(
    ## One element, not two: joining with "; " between the condition and the
    ## body would emit `if (cond); stop(...)`, which is not the guard.
    paste0('if ("package:hvtiRlifetables" %in% search()) ',
           'stop("the child attached the package, so this test cannot ',
           'detect the bug")'),
    expr,
    'cat("HVTI_OK")',
    sep = "; "
  )
}

test_that("us_lifetable_vintages() works through :: without library()", {
  out <- detached_r(detached_call(
    'v <- hvtiRlifetables::us_lifetable_vintages(); stopifnot(nrow(v) == 3L)'
  ))
  expect_true("HVTI_OK" %in% out, info = paste(out, collapse = "\n"))
  expect_no_match(paste(out, collapse = "\n"), "not found")
})

test_that("us_lifetable_model() works through :: without library()", {
  out <- detached_r(detached_call(paste0(
    'm <- hvtiRlifetables::us_lifetable_model(vintage = "table84", ',
    'stratum = "wm"); stopifnot(length(m$params) == 11L)'
  )))
  expect_true("HVTI_OK" %in% out, info = paste(out, collapse = "\n"))
  expect_no_match(paste(out, collapse = "\n"), "not found")
})

test_that("us_matched() works through :: without library()", {
  out <- detached_r(detached_call(paste0(
    'r <- hvtiRlifetables::us_matched(age = 60, male = 1, other = 0, ',
    'times = c(1, 5), vintage = "table84"); stopifnot(nrow(r) == 2L, ',
    'all(r$smatched > 0 & r$smatched <= 1))'
  )))
  expect_true("HVTI_OK" %in% out, info = paste(out, collapse = "\n"))
  expect_no_match(paste(out, collapse = "\n"), "not found")
})

test_that("us_cohort_curve() works through :: without library()", {
  out <- detached_r(detached_call(paste0(
    'x <- hvtiRlifetables::us_matched(age = c(60, 70), male = c(1, 0), ',
    'other = c(0, 0), times = c(1, 5), vintage = "table84"); ',
    'g <- hvtiRlifetables::us_cohort_curve(x); stopifnot(nrow(g) == 2L)'
  )))
  expect_true("HVTI_OK" %in% out, info = paste(out, collapse = "\n"))
  expect_no_match(paste(out, collapse = "\n"), "not found")
})

test_that("the dataset is still user-visible under ::", {
  ## The fix loads the data explicitly rather than moving it to
  ## R/sysdata.rda, so it must remain a browsable dataset.
  out <- detached_r(detached_call(
    'd <- hvtiRlifetables::us_lifetable_models; stopifnot(nrow(d) == 27L)'
  ))
  expect_true("HVTI_OK" %in% out, info = paste(out, collapse = "\n"))
})

test_that("hzl_models() returns the shipped dataset", {
  m <- hzl_models()
  expect_s3_class(m, "data.frame")
  expect_equal(nrow(m), 27L)
  ## Identical to the attached copy: the accessor must not be reading some
  ## other object that merely has the right shape.
  expect_equal(m, us_lifetable_models)
})
