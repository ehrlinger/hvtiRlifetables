# hvtiRlifetables: Age, Sex and Race Matched US Reference Survival

Age, sex and race matched US reference survival, reproducing the
Cleveland Clinic 'SAS' macro \`

## Details

The macro does not interpolate a life table. It evaluates a stored
three-phase parametric hazard fit on the \*\*age\*\* axis, with time
origin at birth, and reads conditional survival off that one smooth
curve twice:

\$\$S\_{matched}(t) = \exp\\-(H(age + t) - H(age))\\\$\$

This package therefore ships the fitted parameter blocks, one set per
vintage per stratum, and evaluates them through TemporalHazard.

\`vintage\` is never defaulted. See the package README for why.

## See also

Useful links:

- <https://github.com/ehrlinger/hvtiRlifetables>

- Report bugs at <https://github.com/ehrlinger/hvtiRlifetables/issues>

## Author

**Maintainer**: John Ehrlinger <john.ehrlinger@gmail.com>
([ORCID](https://orcid.org/0000-0002-5340-5154))

Authors:

- John Ehrlinger <john.ehrlinger@gmail.com>
  ([ORCID](https://orcid.org/0000-0002-5340-5154))

Other contributors:

- The Cleveland Clinic Foundation (fitted US life-table hazard model
  parameters) \[copyright holder\]
