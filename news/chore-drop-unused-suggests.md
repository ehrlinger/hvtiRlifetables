* `withr` and `rmarkdown` are no longer in `Suggests`. Nothing in the package,
  its tests or its vignette called either. The Quarto vignette engine still
  reaches `rmarkdown` through the `quarto` package, which imports it.
