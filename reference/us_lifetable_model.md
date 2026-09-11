# One fitted parameter set

Returns the raw fitted model for a single vintage and stratum, for
inspection. \[us_matched()\] is the function most callers want.

## Usage

``` r
us_lifetable_model(vintage, stratum)
```

## Arguments

- vintage:

  Character scalar. One of the identifiers returned by
  \[us_lifetable_vintages()\]. \*\*There is no default\*\*; omitting it
  is an error.

- stratum:

  Character scalar. One of \`"all"\`, \`"f"\`, \`"m"\`, \`"w"\`,
  \`"wf"\`, \`"wm"\`, or the vintage's non-white codes — \`"o"\`,
  \`"of"\`, \`"om"\` for \`table84\`, \`"b"\`, \`"bf"\`, \`"bm"\`
  otherwise.

## Value

A list with elements \`vintage\` (character), \`stratum\` (character),
\`params\` (named numeric of length 11), \`status\` (named integer of
length 11, the \`\_STATUS\_\` gate), \`flags\` (named numeric of length
6, metadata only), and \`vcov\` (11 by 11 numeric matrix, unused in this
version).

## Examples

``` r
m <- us_lifetable_model("table84", "wm")
m$params[["THALF"]]
#> [1] 0.05188786

# The _STATUS_ gate: table84's non-white male stratum has no constant
# phase. Its C0 is 0 *and absent*, not 0 *and meaning exp(0) = 1*.
om <- us_lifetable_model("table84", "om")
om$params[["C0"]]
#> [1] 0
om$status[["C0"]]
#> [1] 0
```
