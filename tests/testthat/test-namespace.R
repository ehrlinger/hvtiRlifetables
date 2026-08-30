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
##
## ⚠️ A fresh R loads the INSTALLED copy of the package, never the source
## under development. Under `devtools::test()` the parent is a `load_all()`
## session, so these tests report on whatever is in the library -- which may be
## older than the source, newer than it, or absent. Both directions mislead: a
## stale install fails against correct source, and -- the dangerous one -- a
## good install passes against source someone has just broken. That is the same
## shape of defect as issue #18 itself: a test that looks like it covers the
## code while reporting on something else. So each test asks the child which
## version it holds and skips when that is not the source version, rather than
## reporting a result it cannot stand behind. Under `R CMD check` the package
## is installed before the tests run, the two always agree, and nothing skips.
##
## The check is version equality, which is a proxy for code identity rather
## than a proof of it: source edited without a version bump still reads as a
## match. `AGENTS.md` ("Git and versioning") requires the patch digit and a
## `NEWS.md` entry to move with every change, which is what makes the proxy
## hold here.
##
## The code handed to the child is written with single quotes inside
## double-quoted R strings. `quotes_linter` wants the outer string
## double-quoted, and escaping the inner ones instead would make the child's
## code unreadable for no gain -- R parses 'table84' and "table84" alike.

## Run `code` in a fresh R with this session's library path and nothing
## attached. Returns the child's combined output, with its exit status in the
## "status" attribute.
detached_r <- function(code) {
  rscript <- file.path(R.home("bin"), "Rscript")
  ## Qualified: object_usage_linter analyses function bodies, and testthat is
  ## not on the search path it reasons about.
  testthat::skip_if_not(file.exists(rscript), "no Rscript in R.home('bin')")
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
    paste0("if ('package:hvtiRlifetables' %in% search()) ",
           "stop('the child attached the package, so this test cannot ",
           "detect the bug')"),
    ## Printed before `expr` so it survives an expr that errors, and free:
    ## the child is already running, so this costs no extra subprocess.
    paste0("cat('HVTI_VERSION:', ",
           "as.character(utils::packageVersion('hvtiRlifetables')), ",
           "'\\n', sep = '')"),
    expr,
    "cat('HVTI_OK')",
    sep = "; "
  )
}

## Skip unless the copy the child loaded is the source being tested. `out` is
## a finished child's output, so the version is read back rather than probed
## for -- and NA when the child never got that far, which is what an
## uninstalled package looks like from here.
skip_unless_install_is_source <- function(out) {
  line <- grep("^HVTI_VERSION:", out, value = TRUE)
  child <- if (length(line) == 1L) sub("^HVTI_VERSION:", "", line) else NA_character_
  ## Under `load_all()` this reads the source DESCRIPTION; under `R CMD check`
  ## it reads the installed one, which is the copy the child loads.
  source_version <- as.character(utils::packageVersion("hvtiRlifetables"))
  reason <- if (is.na(child)) {
    paste0("hvtiRlifetables ", source_version, " is not installed in the ",
           "library the subprocess sees, so these tests have nothing to check")
  } else {
    paste0("installed hvtiRlifetables is ", child, " but the source is ",
           source_version, "; the subprocess can only report on the installed ",
           "copy, so install the source (devtools::install()) before trusting ",
           "these tests")
  }
  testthat::skip_if_not(identical(child, source_version), reason)
}

test_that("us_lifetable_vintages() works through :: without library()", {
  out <- detached_r(detached_call(
    "v <- hvtiRlifetables::us_lifetable_vintages(); stopifnot(nrow(v) == 3L)"
  ))
  skip_unless_install_is_source(out)
  expect_true("HVTI_OK" %in% out, info = paste(out, collapse = "\n"))
  expect_no_match(paste(out, collapse = "\n"), "not found")
})

test_that("us_lifetable_model() works through :: without library()", {
  out <- detached_r(detached_call(paste0(
    "m <- hvtiRlifetables::us_lifetable_model(vintage = 'table84', ",
    "stratum = 'wm'); stopifnot(length(m$params) == 11L)"
  )))
  skip_unless_install_is_source(out)
  expect_true("HVTI_OK" %in% out, info = paste(out, collapse = "\n"))
  expect_no_match(paste(out, collapse = "\n"), "not found")
})

test_that("us_matched() works through :: without library()", {
  out <- detached_r(detached_call(paste0(
    "r <- hvtiRlifetables::us_matched(age = 60, male = 1, other = 0, ",
    "times = c(1, 5), vintage = 'table84'); stopifnot(nrow(r) == 2L, ",
    "all(r$smatched > 0 & r$smatched <= 1))"
  )))
  skip_unless_install_is_source(out)
  expect_true("HVTI_OK" %in% out, info = paste(out, collapse = "\n"))
  expect_no_match(paste(out, collapse = "\n"), "not found")
})

test_that("us_cohort_curve() works through :: without library()", {
  out <- detached_r(detached_call(paste0(
    "x <- hvtiRlifetables::us_matched(age = c(60, 70), male = c(1, 0), ",
    "other = c(0, 0), times = c(1, 5), vintage = 'table84'); ",
    "g <- hvtiRlifetables::us_cohort_curve(x); stopifnot(nrow(g) == 2L)"
  )))
  skip_unless_install_is_source(out)
  expect_true("HVTI_OK" %in% out, info = paste(out, collapse = "\n"))
  expect_no_match(paste(out, collapse = "\n"), "not found")
})

test_that("the dataset is still user-visible under ::", {
  ## The fix loads the data explicitly rather than moving it to
  ## R/sysdata.rda, so it must remain a browsable dataset.
  out <- detached_r(detached_call(
    "d <- hvtiRlifetables::us_lifetable_models; stopifnot(nrow(d) == 27L)"
  ))
  skip_unless_install_is_source(out)
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
