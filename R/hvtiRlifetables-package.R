#' @keywords internal
#' @description
#' Age, sex and race matched US reference survival, reproducing the Cleveland
#' Clinic 'SAS' macro `%usmatchd`.
#'
#' @details
#' The macro does not interpolate a life table. It evaluates a stored
#' three-phase parametric hazard fit on the **age** axis, with time origin at
#' birth, and reads conditional survival off that one smooth curve twice:
#'
#' \deqn{S_{matched}(t) = \exp\{-(H(age + t) - H(age))\}}
#'
#' This package therefore ships the fitted parameter blocks, one set per
#' vintage per stratum, and evaluates them through \pkg{TemporalHazard}.
#'
#' `vintage` is never defaulted. See the package README for why.
#'
#' @importFrom utils data
"_PACKAGE"

## `us_lifetable_models` is lazy-loaded, so package code cannot see it by bare
## name -- see the note in R/data.R, where hzl_models() reads it explicitly.
## There is therefore no undefined-global to declare here any more; the
## globalVariables("us_lifetable_models") call that stood in this place has
## gone with the bare references it covered.
##
## The `@importFrom utils data` above replaces the `@importFrom utils
## globalVariables` it displaced, and keeps `utils` demonstrably imported from
## rather than merely declared -- `data()` in R/data.R is called unqualified
## against it, as `globalVariables()` was.
