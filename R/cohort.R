## The cohort reduction, and the one place the averaging decision is made.
##
## What gets overlaid on an actuarial curve is not a patient's expected
## survival but the cohort's at each time, and before this function existed
## every study derived that for itself. The choices are not obvious -- average
## survival or average cumulative hazard, weight by follow-up or not -- so two
## studies could average differently and neither would know. They are settled
## here, once, and documented.

## Resolve `by` into a data frame of grouping columns, or NULL.
##
## `by` always carries VALUES, never column names. Accepting a character
## vector of column names as well would make the meaning of `by = "arm"`
## depend on whether `data` happens to have a column called `arm` -- one
## argument with two readings, resolved from the data. Grouping by a column of
## `data` is `by = data$arm`, which needs no rule.
hzl_resolve_by <- function(data, by) {
  if (is.null(by)) {
    return(NULL)
  }

  if (is.data.frame(by) || is.list(by)) {
    if (is.null(names(by)) || !all(nzchar(names(by)))) {
      stop("a list or data frame `by` must be fully named -- the names become ",
           "the grouping columns of the result.", call. = FALSE)
    }
    g <- as.data.frame(by, stringsAsFactors = FALSE)
  } else {
    g <- data.frame(group = by, stringsAsFactors = FALSE)
  }

  if (nrow(g) != nrow(data)) {
    stop("`by` has ", nrow(g), " value(s) but `data` has ", nrow(data),
         " row(s). `data` carries one row per patient per time, so a ",
         "patient-level grouping must be expanded to it -- for a grouping ",
         "`g` whose order matches the ids in `data`, that is ",
         "`g[match(data$id, ids)]`.", call. = FALSE)
  }
  clash <- intersect(names(g), c("time", "smatched", "hmatched"))
  if (length(clash)) {
    stop("`by` would name a grouping column ", paste(clash, collapse = ", "),
         ", which the returned curve already uses. Rename it.", call. = FALSE)
  }
  g
}

## Every patient averaged into one curve must carry the same `times`. The
## mean at a time is over the rows at that time, so a patient missing a time
## -- two us_matched() calls with different `times`, stacked -- silently
## changes the denominator part of the way along the curve. Checked per
## curve, so groups may legitimately differ from one another. Ids are matched
## on their values, not through factor(), which would drop NA and compare
## numeric ids as 15-digit strings.
##
## The output cannot tell two patients sharing an id from one patient, so an
## id seen twice at one time is refused outright: it is either a collision
## between stacked results (default ids all start at 1) or tied `times`, and
## averaging either would weight some rows twice at some times only. With
## that excluded, each patient's times are a set, compared sorted so that
## row order does not matter.
hzl_check_grid <- function(data) {
  if (nrow(data) == 0L) return(invisible(TRUE))
  ids <- unique(data$id)
  pid <- match(data$id, ids)
  dup <- duplicated(data.frame(pid = pid, time = data$time))
  if (any(dup)) {
    first <- which(dup)[[1L]]
    hzl_abort("grid",
              "us_cohort_curve(): id ", ids[[pid[[first]]]], " appears more ",
              "than once at time ", data$time[[first]], ", so its rows cannot ",
              "be told apart. Either results with overlapping ids were ",
              "stacked -- give every patient a distinct `id` -- or `times` ",
              "has ties -- pass unique(times).")
  }
  grids <- lapply(split(data$time, pid), sort)
  same  <- vapply(grids, identical, logical(1), grids[[1L]])
  if (!all(same)) {
    hzl_abort("grid",
              "us_cohort_curve(): the patients in `data` do not share one ",
              "set of times -- id ",
              paste(utils::head(ids[!same], 5), collapse = ", "),
              if (sum(!same) > 5) ", ..." else "",
              " differ from id ", ids[[1L]], ". Averaging would change ",
              "the denominator along the curve. Call us_matched() once, with ",
              "one `times`, for the whole cohort.")
  }
  invisible(TRUE)
}

#' Cohort expected-survival curve, optionally within groups
#'
#' Reduces the per-patient output of [us_matched()] to the curve a figure
#' actually carries: the cohort's expected survival at each time, and its
#' hazard. With `by`, one such curve per group.
#'
#' @param data A data frame as returned by [us_matched()] with
#'   `individual = TRUE` -- columns `id`, `time`, `smatched` and `hmatched`.
#'   An already-aggregated frame is rejected rather than averaged twice.
#' @param by How to group the result. One of:
#'   * `NULL` (default), for a single cohort-wide curve;
#'   * a vector or factor with one value per *row* of `data`, reported in a
#'     column called `group`;
#'   * a named list or data frame of such vectors, for a crossed grouping,
#'     reported under its own names.
#'
#'   It carries values, not column names: group by a column of `data` with
#'   `by = data$arm`. Because `data` holds one row per patient per time, a
#'   patient-level grouping must be expanded to it -- see the examples.
#' @param x Deprecated; use `data`. Still accepted, with a warning once per
#'   session, and to be removed in a future release.
#'
#' @return A data frame with columns `time`, `smatched` and `hmatched`, one
#'   row per distinct time -- or, with `by`, the grouping columns first and
#'   one row per group per distinct time. Groups and times appear in order of
#'   first appearance in `data`, so a factor grouping does not reorder to its
#'   levels.
#'
#' @section The averaging, and why it is here:
#' The reduction follows the SAS macro `%usmatchd` (lines 338-350): the
#' hazard is converted to a density (`hmatched * smatched`), the
#' **unweighted** cohort means of survival and of the density are taken at
#' each time, and the mean hazard is recovered by division. It is deliberately
#' **not** the mean of the individual hazards; in a heterogeneous cohort the
#' two differ, and the difference is not cosmetic.
#'
#' The mean is over **survival**, not over cumulative hazard, and no patient
#' is weighted by follow-up. Missing values are not dropped: every value
#' [us_matched()] returns is finite by construction, so an `NA` arriving here
#' is a defect rather than a datum, and averaging around it would hide it.
#'
#' @section Grouping is not stratification:
#' `us_matched()`'s `table` argument chooses which strata the *life table* is
#' built from -- `"sexrace"`, `"race"`, `"sex"`, `"overall"`. `by` chooses how
#' the resulting curves are grouped for *reporting* -- age band, treatment
#' arm, era. The two axes are independent: a report broken down by age band
#' is normally still matched on `"sexrace"`.
#'
#' @seealso [us_matched()], whose `individual = FALSE` is the ungrouped case
#'   of this function.
#'
#' @examples
#' x <- us_matched(age = c(55, 60, 78, 82), male = c(1, 0, 1, 0),
#'                 other = c(0, 0, 1, 1), times = c(0, 5, 10),
#'                 vintage = "table84")
#'
#' # The cohort curve.
#' us_cohort_curve(x)
#'
#' # The same, broken down by an age band of the study's own choosing. The
#' # grouping is per patient, so it is expanded to x's one-row-per-patient-
#' # per-time shape by id.
#' band <- c("55-79", "55-79", "55-79", "80+")
#' us_cohort_curve(x, by = factor(band[x$id], levels = c("55-79", "80+")))
#'
#' @export
us_cohort_curve <- function(data, by = NULL, x) {
  if (!missing(x)) {
    if (!missing(data)) {
      ## `us_cohort_curve(x = r, grp)` meant `by = grp` before the rename, and
      ## `grp` now lands in `data` by position. Keep that call working, unless
      ## `data` is itself us_matched() output: then both names were given.
      both <- is.data.frame(data) &&
        all(c("id", "time", "smatched", "hmatched") %in% names(data))
      if (!missing(by) || both) {
        stop("us_cohort_curve(): give `data` only; `x` is its deprecated ",
             "name.", call. = FALSE)
      }
      by <- data
    }
    hzl_warn_renamed("us_cohort_curve", "x", "data")
    data <- x
  }
  if (!is.data.frame(data)) {
    stop("us_cohort_curve(): `data` must be the data frame returned by ",
         "us_matched(individual = TRUE); got ", class(data)[[1L]], ".",
         call. = FALSE)
  }
  needed <- c("id", "time", "smatched", "hmatched")
  absent <- setdiff(needed, names(data))
  if (length(absent)) {
    ## A frame missing only `id` is the aggregate shape. Averaging it again
    ## would return a plausible curve computed from the wrong denominator, so
    ## name what happened rather than proceeding.
    if (identical(absent, "id")) {
      stop("us_cohort_curve(): `data` has no `id` column, so it is already a ",
           "cohort curve rather than one row per patient per time. Pass the ",
           "us_matched(individual = TRUE) output.", call. = FALSE)
    }
    stop("us_cohort_curve(): `data` is missing the column(s) ",
         paste(absent, collapse = ", "),
         " that us_matched(individual = TRUE) returns.", call. = FALSE)
  }

  g <- hzl_resolve_by(data, by)

  if (nrow(data) == 0L) {
    ## An empty cohort is a legitimate input -- the same decision
    ## us_matched() makes -- so return the documented columns with zero rows.
    ## The grouping columns keep their own types via `[0, ]`.
    empty <- data.frame(time = numeric(0), smatched = numeric(0),
                        hmatched = numeric(0), stringsAsFactors = FALSE)
    if (is.null(g)) return(empty)
    return(cbind(g[0, , drop = FALSE], empty))
  }

  if (is.null(g)) {
    hzl_check_grid(data)
    return(hzl_mean_curve(data))
  }

  ## "\r" as the key separator rather than "." or "_": it cannot appear in a
  ## grouping label that came from a data column, so two distinct groups
  ## cannot collide into one key.
  key <- do.call(paste, c(lapply(g, as.character), sep = "\r"))
  key <- factor(key, levels = unique(key))

  parts <- lapply(levels(key), function(k) {
    rows <- which(key == k)
    hzl_check_grid(data[rows, , drop = FALSE])
    curve <- hzl_mean_curve(data[rows, , drop = FALSE])
    ## Repeated to the curve's length rather than left to cbind's recycling:
    ## a one-row frame recycles, but carries its row name into the result and
    ## warns that it discarded it. Row names dropped for the same reason.
    labels <- g[rep(rows[[1L]], nrow(curve)), , drop = FALSE]
    rownames(labels) <- NULL
    cbind(labels, curve)
  })

  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}
