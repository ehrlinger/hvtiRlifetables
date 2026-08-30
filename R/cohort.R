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
## depend on whether `x` happens to have a column called `arm` -- one argument
## with two readings, resolved from the data. Grouping by a column of `x` is
## `by = x$arm`, which needs no rule.
hzl_resolve_by <- function(x, by) {
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

  if (nrow(g) != nrow(x)) {
    stop("`by` has ", nrow(g), " value(s) but `x` has ", nrow(x),
         " row(s). `x` carries one row per patient per time, so a ",
         "patient-level grouping must be expanded to it -- for a grouping ",
         "`g` whose order matches the ids in `x`, that is `g[match(x$id, ids)]`.",
         call. = FALSE)
  }
  clash <- intersect(names(g), c("time", "smatched", "hmatched"))
  if (length(clash)) {
    stop("`by` would name a grouping column ", paste(clash, collapse = ", "),
         ", which the returned curve already uses. Rename it.", call. = FALSE)
  }
  g
}

#' Cohort expected-survival curve, optionally within groups
#'
#' Reduces the per-patient output of \code{\link{us_matched}} to the curve a
#' figure actually carries: the cohort's expected survival at each time, and
#' its hazard. With \code{by}, one such curve per group.
#'
#' @param x A data frame as returned by \code{\link{us_matched}} with
#'   \code{individual = TRUE} -- columns \code{id}, \code{time},
#'   \code{smatched} and \code{hmatched}. An already-aggregated frame is
#'   rejected rather than averaged twice.
#' @param by How to group the result. One of:
#'   \itemize{
#'     \item \code{NULL} (default), for a single cohort-wide curve;
#'     \item a vector or factor with one value per \emph{row} of \code{x},
#'       reported in a column called \code{group};
#'     \item a named list or data frame of such vectors, for a crossed
#'       grouping, reported under its own names.
#'   }
#'   It carries values, not column names: group by a column of \code{x} with
#'   \code{by = x$arm}. Because \code{x} holds one row per patient per time,
#'   a patient-level grouping must be expanded to it -- see the examples.
#'
#' @return A data frame with columns \code{time}, \code{smatched} and
#'   \code{hmatched}, one row per time -- or, with \code{by}, the grouping
#'   columns first and one row per group per time. Groups and times appear in
#'   order of first appearance in \code{x}, so a factor grouping does not
#'   reorder to its levels.
#'
#' @section The averaging, and why it is here:
#' The reduction follows the SAS macro \code{\%usmatchd} (lines 338-350): the
#' hazard is converted to a density (\code{hmatched * smatched}), the
#' \strong{unweighted} cohort means of survival and of the density are taken at
#' each time, and the mean hazard is recovered by division. It is deliberately
#' \strong{not} the mean of the individual hazards; in a heterogeneous cohort
#' the two differ, and the difference is not cosmetic.
#'
#' The mean is over \strong{survival}, not over cumulative hazard, and no
#' patient is weighted by follow-up. Missing values are not dropped: every
#' value \code{\link{us_matched}} returns is finite by construction, so an
#' \code{NA} arriving here is a defect rather than a datum, and averaging
#' around it would hide it.
#'
#' @section Grouping is not stratification:
#' \code{us_matched}'s \code{table} argument chooses which strata the
#' \emph{life table} is built from -- \code{"sexrace"}, \code{"race"},
#' \code{"sex"}, \code{"overall"}. \code{by} chooses how the resulting curves
#' are grouped for \emph{reporting} -- age band, treatment arm, era. The two
#' axes are independent: a report broken down by age band is normally still
#' matched on \code{"sexrace"}.
#'
#' @seealso \code{\link{us_matched}}, whose \code{individual = FALSE} is the
#'   ungrouped case of this function.
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
us_cohort_curve <- function(x, by = NULL) {
  if (!is.data.frame(x)) {
    stop("`x` must be the data frame returned by us_matched(individual = ",
         "TRUE); got ", class(x)[[1L]], ".", call. = FALSE)
  }
  needed <- c("id", "time", "smatched", "hmatched")
  absent <- setdiff(needed, names(x))
  if (length(absent)) {
    ## A frame missing only `id` is the aggregate shape. Averaging it again
    ## would return a plausible curve computed from the wrong denominator, so
    ## name what happened rather than proceeding.
    if (identical(absent, "id")) {
      stop("`x` has no `id` column, so it is already a cohort curve rather ",
           "than one row per patient per time. Pass the ",
           "us_matched(individual = TRUE) output.", call. = FALSE)
    }
    stop("`x` is missing the column(s) ", paste(absent, collapse = ", "),
         " that us_matched(individual = TRUE) returns.", call. = FALSE)
  }

  g <- hzl_resolve_by(x, by)

  if (nrow(x) == 0L) {
    ## An empty cohort is a legitimate input -- the same decision
    ## us_matched() makes -- so return the documented columns with zero rows.
    ## The grouping columns keep their own types via `[0, ]`.
    empty <- data.frame(time = numeric(0), smatched = numeric(0),
                        hmatched = numeric(0), stringsAsFactors = FALSE)
    if (is.null(g)) return(empty)
    return(cbind(g[0, , drop = FALSE], empty))
  }

  if (is.null(g)) {
    return(hzl_mean_curve(x))
  }

  ## "\r" as the key separator rather than "." or "_": it cannot appear in a
  ## grouping label that came from a data column, so two distinct groups
  ## cannot collide into one key.
  key <- do.call(paste, c(lapply(g, as.character), sep = "\r"))
  key <- factor(key, levels = unique(key))

  parts <- lapply(levels(key), function(k) {
    rows <- which(key == k)
    curve <- hzl_mean_curve(x[rows, , drop = FALSE])
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
