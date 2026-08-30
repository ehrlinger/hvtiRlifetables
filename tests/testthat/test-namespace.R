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
## code while reporting on something else. So each test makes the child
## fingerprint what it actually loaded and skips unless that is the code under
## test, rather than reporting a result it cannot stand behind. Under
## `R CMD check` the package is installed before the tests run, the two
## fingerprints agree by construction, and nothing skips.
##
## The code handed to the child is written with single quotes inside
## double-quoted R strings. `quotes_linter` wants the outer string
## double-quoted, and escaping the inner ones instead would make the child's
## code unreadable for no gain -- R parses 'table84' and "table84" alike.

## Run `code` in a fresh R with this session's library path and nothing
## attached. Returns the child's combined output, with its exit status in the
## "status" attribute.
detached_r <- function(code) {
  ## `.exe` on Windows, bare elsewhere. Without the extension file.exists() is
  ## FALSE on every Windows machine, so all five tests skipped there and the
  ## issue #18 guard has never once run on that platform -- green, and inert
  ## since 0.1.2. A skip is the one failure mode a passing check cannot show.
  exe <- if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  rscript <- file.path(R.home("bin"), exe)
  ## Qualified: object_usage_linter analyses function bodies, and testthat is
  ## not on the search path it reasons about.
  testthat::skip_if_not(file.exists(rscript), paste0("no ", exe, " in R.home('bin')"))

  ## Handed over as a FILE, not as `-e`. The payload is a deparsed function
  ## full of quotes and newlines; shQuote() defaults to sh quoting, which is
  ## not cmd's, and cmd caps a command line at 8191 characters. Measured: with
  ## the `.exe` guard fixed, the Windows child launched and died producing no
  ## output at all. A script file has neither problem and reads the same on
  ## every platform.
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  writeLines(code, script, useBytes = TRUE)

  ## R_LIBS is set on THIS process and inherited, rather than passed through
  ## system2(env=), which is documented as not supported on Windows -- the
  ## child would silently get the runner's library instead of the one under
  ## test, which is precisely the confusion these tests exist to remove.
  libs <- paste(.libPaths(), collapse = .Platform$path.sep)
  old_libs <- Sys.getenv("R_LIBS", unset = NA)
  Sys.setenv(R_LIBS = libs)
  on.exit(if (is.na(old_libs)) Sys.unsetenv("R_LIBS") else Sys.setenv(R_LIBS = old_libs),
          add = TRUE)

  suppressWarnings(
    system2(rscript, c("--vanilla", shQuote(script)), stdout = TRUE, stderr = TRUE)
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
    ## The child is handed `package_fingerprint()` verbatim rather than a
    ## second copy of it, so the two sessions cannot drift into measuring
    ## different things. Printed before `expr` so it survives an expr that
    ## errors, and free: the child is already running, so it costs no extra
    ## subprocess.
    paste0("hvti_fp <- ", paste(deparse(package_fingerprint), collapse = "\n")),
    "cat('HVTI_FP:', hvti_fp(), '\\n', sep = '')",
    ## Which copy the child actually loaded. A fingerprint mismatch establishes
    ## that the install is not the source; it does not establish WHY, and on
    ## the macOS CI runner -- where this skips and a local R CMD check does not
    ## -- the open question is whether the child resolved a different library
    ## than the one under check. Reported so the answer is in the failure
    ## rather than waiting to be reproduced.
    paste0("cat('HVTI_LIB:', dirname(find.package('hvtiRlifetables')), ",
           "'\\n', sep = '')"),
    expr,
    "cat('HVTI_OK')",
    sep = "; "
  )
}

## One md5 over everything the package puts into a session: every object in
## the namespace, deparsed, plus the shipped dataset. Two sessions running the
## same package code agree on it; two running different code do not. A version
## string cannot do this job -- source edited without a version bump reads as a
## match, which is the exact case that produces a false pass.
##
## Deparsed rather than hashed directly, because the objects themselves differ
## between the two load paths where their text does not: an installed package
## is byte-compiled and a `load_all()` one is not. `deparse()` sees through
## that, and ignores `srcref` too, so a source-kept install and a stripped one
## still agree. Both measured against this package, not assumed.
##
## `.__DEVTOOLS__`, `.__NAMESPACE__.` and `.__S3MethodsTable__.` are the only
## names that differ between the two namespaces -- R's and pkgload's
## bookkeeping rather than the package's own objects -- so the `.__` prefix is
## dropped and the remaining 20 names match exactly.
##
## `.hzl_data` is a mutable cache and is deliberately left in the walk.
## `deparse()` renders an environment as the opaque "<environment>" rather than
## descending into it, so a warm cache and a cold one hash alike -- measured,
## and relied on by the suite, which warms it in test-models.R before this file
## runs. Its NAME still contributes, so renaming or dropping the cache does
## move the fingerprint, which is the behaviour worth keeping.
##
## The dataset is fingerprinted separately because it is NOT in the namespace:
## a lazy-loaded dataset is promised into the package environment, which is the
## whole of issue #18. The package environment is not walked instead, because
## `load_all()` defaults to `export_all = TRUE` and fills it with every
## internal object, where an installed package holds only the exports.
##
## ⚠️ In the child this runs BEFORE the assertion body and reaches the dataset
## through `::`, which forces the lazy-data promise. Measured against the
## pre-fix 0.1.1 package: that does NOT mask the issue #18 defect, because
## forcing the promise populates the package environment while package code
## resolves against the namespace. Should that ever stop holding, this file
## silently stops testing anything -- so re-measure it rather than assuming.
package_fingerprint <- function() {
  ns <- asNamespace("hvtiRlifetables")
  nms <- ls(ns, all.names = TRUE)
  ## method = "radix" sorts by byte, never by the collation locale. R CMD check
  ## forces LC_COLLATE=C on the parent while a --vanilla child inherits the
  ## machine's own locale, and the two orders differ: VINTAGE_META sorts third
  ## under C and last under en_US, because that collation ignores case. Same
  ## objects, different concatenation, different hash -- which is why this
  ## skipped on the macOS runner and not on Linux.
  nms <- sort(nms[!startsWith(nms, ".__")], method = "radix")
  code <- unlist(lapply(nms, function(n) c(n, deparse(get(n, ns)))))
  ## compress = FALSE: the bytes only have to be reproducible, not small, and
  ## a compressor is one more thing that could differ between two R builds.
  data_file <- tempfile()
  ## version = 2 for the same reason. RDS 3 writes the session's NATIVE
  ## ENCODING into its header, so identical data serialises to different bytes
  ## under C and under en_US. Version 2 has no such header. This is the second,
  ## independent locale dependency here -- fixing the sort alone left the
  ## fingerprints still disagreeing, which is how it was found.
  saveRDS(hvtiRlifetables::us_lifetable_models, data_file, compress = FALSE,
          version = 2)
  both <- tempfile()
  writeLines(c(code, unname(tools::md5sum(data_file))), both, useBytes = TRUE)
  unname(tools::md5sum(both))
}

## Skip unless the copy the child loaded is the code under test. `out` is a
## finished child's output, so the fingerprint is read back rather than probed
## for -- and NA when the child never got that far.
skip_unless_install_is_source <- function(out) {
  line <- grep("^HVTI_FP:", out, value = TRUE)
  child <- if (length(line) == 1L) sub("^HVTI_FP:", "", line) else NA_character_
  here <- package_fingerprint()
  reason <- if (is.na(child)) {
    ## No fingerprint means the child died before printing one, and WHY is not
    ## knowable from here: the package missing from its library is the most
    ## common cause but not the only one -- an installed package whose dataset
    ## is unreadable fails here too, and reads identically. Naming a cause that
    ## has not been established, and discarding the evidence for it, is the
    ## error these tests exist to prevent, so the child's own output is handed
    ## over instead of a guess.
    paste0("the subprocess printed no fingerprint, so there is no way to tell ",
           "what it loaded. Its own output was:\n", paste(out, collapse = "\n"))
  } else {
    ## The library is named, not guessed at: "run devtools::install()" is the
    ## right advice only when the child read the library under test, and the
    ## macOS runner is the case where that may not hold.
    lib_line <- grep("^HVTI_LIB:", out, value = TRUE)
    child_lib <- if (length(lib_line) == 1L) sub("^HVTI_LIB:", "", lib_line) else "unknown"
    paste0("the installed hvtiRlifetables is not the code under test ",
           "(subprocess ", substr(child, 1, 10), ", source ",
           substr(here, 1, 10), "); the subprocess loaded it from ", child_lib,
           " and can only report on that copy. If that is the library under ",
           "test, run devtools::install(); if it is not, the subprocess is ",
           "resolving the wrong one")
  }
  testthat::skip_if_not(identical(child, here), reason)
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
