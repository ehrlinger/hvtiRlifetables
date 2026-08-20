# Claude Code specifics

@AGENTS.md

[`AGENTS.md`](https://ehrlinger.github.io/hvtiRlifetables/AGENTS.md),
imported above, is the operational contract and applies in full. It is
written to be tool neutral so that Codex and other agents read the same
rules. Only the Claude Code affordances live here.

## Before you touch code

`AGENTS.md` says to read `HANDOFF.md` first, and that comes before
anything else here.

For orientation on the code itself, the codemap lives in the Obsidian
vault under `Claude/repomaps/` and is read via the `read-codemap` skill
(`/codemap hvtiRlifetables`). If it looks stale, say so and offer to
refresh it (`/regenerate-codemap`) rather than working from a guess.

If the vault is not available, say so rather than staying quiet about
it, then orient from the repo itself — `NAMESPACE`, `R/models.R` for the
vintage metadata, `R/us_matched.R` for the matching logic.

## Reading the SAS side

The original macros are in `data-raw/sas/` — `uslife.sas`,
`usmatchd.sas`, `usmtch08.sas` and the dated variants. They are the
parity reference and they are in this repository, so a question of the
form “does this match SAS” is answerable here without leaving it. Read
the macro rather than reasoning from the R.

## Strata and what a reader concludes

`AGENTS.md`’s rule about the `"b"` code not meaning Black applies to
anything this session produces, including a table printed into the
transcript or a sentence drafted for a manuscript. If you are about to
name a stratum in prose, take the wording from `nonwhite_meaning` rather
than from the code.

## Prose

`AGENTS.md` points at the house voice. In Claude Code, apply the
`ehrlinger-writing` skill: it carries the same voice, reader persona and
project context, kept in sync from the vault sources. For documentation
*structure*, the `r-package-style` skill is the companion.
