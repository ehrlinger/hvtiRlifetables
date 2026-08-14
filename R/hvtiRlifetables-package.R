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
"_PACKAGE"

## `us_lifetable_models` is this package's own lazy-loaded dataset. codetools
## analyses statically and cannot see lazy-load bindings, so R CMD check
## reports every reference to it in R/models.R as an undefined global. It is
## not one.
utils::globalVariables("us_lifetable_models")
