## Classed conditions, per the hvtiR API rubric: `hvtiRlifetables_<condition>`
## on every error a caller is expected to catch, so a job can handle "wrong
## vintage" apart from "beyond the fits' support" without matching on text.
## Every class also carries `hvtiRlifetables_error`, for a caller that wants
## any of them. Argument-type errors stay plain stop(): they are bugs in the
## calling code, not conditions to handle.
##
## A base condition object with `call = NULL` is the same as
## stop(..., call. = FALSE): no cli, no rlang.
hzl_abort <- function(class, ...) {
  stop(structure(
    class = c(paste0("hvtiRlifetables_", class), "hvtiRlifetables_error",
              "error", "condition"),
    list(message = paste0(...), call = NULL)
  ))
}

## A renamed argument keeps working for one release, warning once per session.
.hzl_warned <- new.env(parent = emptyenv())

hzl_warn_renamed <- function(fn, old, new) {
  key <- paste0(fn, ":", old)
  if (isTRUE(.hzl_warned[[key]])) return(invisible())
  assign(key, TRUE, envir = .hzl_warned)
  warning(structure(
    class = c("hvtiRlifetables_deprecated", "deprecatedWarning", "warning",
              "condition"),
    list(message = paste0(fn, "(): `", old, "` is deprecated; use `", new,
                          "` instead. `", old, "` will be removed in a ",
                          "future release. This warning is shown once per ",
                          "session."),
         call = NULL)
  ))
  invisible()
}
