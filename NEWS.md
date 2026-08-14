# hvtiRlifetables 0.1.0

Initial scaffold. No user-facing functions yet.

- Package skeleton created against the design spec
  `docs/specs/2026-08-13-hvtirlifetables-design.md`.
- Vendored inputs under `data-raw/`: the fitted `.sas7bdat` parameter blocks
  for vintages `table84`, `table2008` and `table2023`, and the `%usmatchd`
  macro variants they are read by.
- `data-raw/spike-vintage-confirmation.R` reproduces this study's reference
  output to 6.2e-15 at `table84`, establishing that the macro evaluates a
  stored three-phase hazard fit on the age axis rather than interpolating a
  life table.
