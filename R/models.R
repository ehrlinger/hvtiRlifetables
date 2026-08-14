## Vintages the package knows about, including ones it deliberately refuses.
## table2009 is an empty directory on the share. Whether it was never
## populated or lost is unresolved; either way it cannot be used, and the
## error must say "empty" rather than "not found" so nobody goes looking.
VINTAGE_META <- list(
  table84 = list(
    nonwhite_code    = "o",
    nonwhite_meaning = "Other (all non-white), named honestly by this vintage",
    added            = NA_character_,
    usable           = TRUE
  ),
  table2008 = list(
    nonwhite_code    = "b",
    nonwhite_meaning = "Black, per the macro's documentation; not independently verified",
    added            = NA_character_,
    usable           = TRUE
  ),
  table2009 = list(
    nonwhite_code    = NA_character_,
    nonwhite_meaning = NA_character_,
    added            = NA_character_,
    usable           = FALSE
  ),
  table2023 = list(
    nonwhite_code    = "b",
    nonwhite_meaning = paste(
      "risk-weighted average of Black, Asian, American Indian and Hispanic",
      "death rates, weighted by number at risk. NOT Black, despite the",
      "stratum code and despite the macro's own comment."
    ),
    added            = "2025-12-23",
    usable           = TRUE
  )
)

usable_vintages <- function() {
  names(VINTAGE_META)[vapply(VINTAGE_META, function(x) x$usable, logical(1))]
}

hzl_check_vintage <- function(vintage) {
  if (missing(vintage) || is.null(vintage)) {
    stop("`vintage` has no default and must be given. Available: ",
         paste(usable_vintages(), collapse = ", "),
         ".\nThis package refuses to guess: the SAS macro's default silently ",
         "moved from table84 to table2023, and every job re-run across that ",
         "change got different numbers with no signal.", call. = FALSE)
  }
  if (!is.character(vintage) || length(vintage) != 1L) {
    stop("`vintage` must be a single character string.", call. = FALSE)
  }
  if (identical(vintage, "table2009")) {
    stop("vintage \"table2009\" is empty on disk -- the estimates directory ",
         "exists but was never populated. It is not a missing file; there is ",
         "nothing to load. Available: ",
         paste(usable_vintages(), collapse = ", "), ".", call. = FALSE)
  }
  if (!vintage %in% usable_vintages()) {
    stop("unknown vintage \"", vintage, "\". Available: ",
         paste(usable_vintages(), collapse = ", "), ".", call. = FALSE)
  }
  invisible(TRUE)
}

hzl_nonwhite_code <- function(vintage) {
  hzl_check_vintage(vintage)
  VINTAGE_META[[vintage]]$nonwhite_code
}

#' Available US life-table vintages
#'
#' Reports the fitted-model vintages this package ships, with the provenance
#' and race semantics needed to choose one. Vintages are **not**
#' interchangeable — model structure differs, not only fitted values.
#'
#' @return A data frame with one row per usable vintage and columns:
#'   `vintage` (character identifier), `n_strata` (integer, always 9),
#'   `nonwhite_code` (character, the stratum code this vintage uses for its
#'   non-white category), `nonwhite_meaning` (character, what that category
#'   actually contains), `added` (character date the fits were added, where
#'   known, otherwise `NA`).
#'
#'   There is deliberately no `source` column: `R/` carries no literal share
#'   path. `data-raw/build-models.R` names the location the fits are restored
#'   from.
#'
#' @section Read `nonwhite_meaning` before citing a stratum:
#' The `table2023` non-white category is stored under code `b` but is a
#' risk-weighted average of Black, Asian, American Indian and Hispanic death
#' rates. It is not Black. The macro's own comment says otherwise and is
#' wrong.
#'
#' @examples
#' us_lifetable_vintages()
#'
#' @export
us_lifetable_vintages <- function() {
  v <- usable_vintages()
  data.frame(
    vintage          = v,
    n_strata         = vapply(v, function(x)
                         sum(us_lifetable_models$vintage == x), integer(1)),
    nonwhite_code    = vapply(v, function(x)
                         VINTAGE_META[[x]]$nonwhite_code, character(1)),
    nonwhite_meaning = vapply(v, function(x)
                         VINTAGE_META[[x]]$nonwhite_meaning, character(1)),
    added            = vapply(v, function(x)
                         VINTAGE_META[[x]]$added, character(1)),
    row.names        = NULL,
    stringsAsFactors = FALSE
  )
}

#' One fitted parameter set
#'
#' Returns the raw fitted model for a single vintage and stratum, for
#' inspection. [us_matched()] is the function most callers want.
#'
#' @param vintage Character scalar. One of the identifiers returned by
#'   [us_lifetable_vintages()]. **There is no default**; omitting it is an
#'   error.
#' @param stratum Character scalar. One of `"all"`, `"f"`, `"m"`, `"w"`,
#'   `"wf"`, `"wm"`, or the vintage's non-white codes — `"o"`, `"of"`, `"om"`
#'   for `table84`, `"b"`, `"bf"`, `"bm"` otherwise.
#'
#' @return A list with elements `vintage` (character), `stratum` (character),
#'   `params` (named numeric of length 11), `status` (named integer of length
#'   11, the `_STATUS_` gate), `flags` (named numeric of length 6, metadata
#'   only), and `vcov` (11 by 11 numeric matrix, unused in this version).
#'
#' @examples
#' m <- us_lifetable_model("table84", "wm")
#' m$params[["THALF"]]
#'
#' # The _STATUS_ gate: table84's non-white male stratum has no constant
#' # phase. Its C0 is 0 *and absent*, not 0 *and meaning exp(0) = 1*.
#' om <- us_lifetable_model("table84", "om")
#' om$params[["C0"]]
#' om$status[["C0"]]
#'
#' @export
us_lifetable_model <- function(vintage, stratum) {
  hzl_check_vintage(vintage)
  if (missing(stratum) || !is.character(stratum) || length(stratum) != 1L) {
    stop("`stratum` must be a single character string.", call. = FALSE)
  }

  in_vintage <- us_lifetable_models$vintage == vintage
  i <- which(in_vintage & us_lifetable_models$stratum == stratum)

  if (length(i) != 1L) {
    available <- sort(us_lifetable_models$stratum[in_vintage])
    stop("vintage \"", vintage, "\" has no stratum \"", stratum,
         "\". Available: ", paste(available, collapse = ", "),
         ".\nNote that vintages differ in how they name the non-white ",
         "stratum: table84 uses \"o\", table2008 and table2023 use \"b\".",
         call. = FALSE)
  }

  list(
    vintage = vintage,
    stratum = stratum,
    params  = us_lifetable_models$params[[i]],
    status  = us_lifetable_models$status[[i]],
    flags   = us_lifetable_models$flags[[i]],
    vcov    = us_lifetable_models$vcov[[i]]
  )
}

## The _STATUS_ gate, in one place.
##
## mu = exp(X0) ONLY when status[[X0]] == 1. A status of 0 means the phase is
## absent from the fitted model -- NOT that log(mu) is zero. Reading a
## status-0 C0 as exp(0) = 1 injects a constant hazard of one death per
## person-year. It fails loudly per patient but its cohort signature is a
## plausible near-miss, which is what makes it dangerous.
hzl_mu <- function(params, status, name) {
  if (isTRUE(status[[name]] == 1L)) exp(params[[name]]) else 0
}
