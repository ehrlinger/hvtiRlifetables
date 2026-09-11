# Available US life-table vintages

Reports the fitted-model vintages this package ships, with the
provenance and race semantics needed to choose one. Vintages are
\*\*not\*\* interchangeable — model structure differs, not only fitted
values.

## Usage

``` r
us_lifetable_vintages()
```

## Value

A data frame with one row per usable vintage and columns: \`vintage\`
(character identifier), \`n_strata\` (integer, always 9),
\`nonwhite_code\` (character, the stratum code this vintage uses for its
non-white category), \`nonwhite_meaning\` (character, what that category
actually contains), \`added\` (character date the fits were added, where
known, otherwise \`NA\`).

There is deliberately no \`source\` column: \`R/\` carries no literal
share path. \`data-raw/build-models.R\` names the location the fits are
restored from.

## Read \`nonwhite_meaning\` before citing a stratum

The \`table2023\` non-white category is stored under code \`b\` but is a
risk-weighted average of Black, Asian, American Indian and Hispanic
death rates. It is not Black. The macro's own comment says otherwise and
is wrong.

## Examples

``` r
us_lifetable_vintages()
#>     vintage n_strata nonwhite_code
#> 1   table84        9             o
#> 2 table2008        9             b
#> 3 table2023        9             b
#>                                                                                                                                                                        nonwhite_meaning
#> 1                                                                                                                                 Other (all non-white), named honestly by this vintage
#> 2                                                                                                                      Black, per the macro's documentation; not independently verified
#> 3 risk-weighted average of Black, Asian, American Indian and Hispanic death rates, weighted by number at risk. NOT Black, despite the stratum code and despite the macro's own comment.
#>        added
#> 1       <NA>
#> 2       <NA>
#> 3 2025-12-23
```
