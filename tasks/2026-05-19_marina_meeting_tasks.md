# Marina Meeting Tasks

Date captured: 2026-05-19

Source: Recent meeting with Marina.

Purpose: Backlog of follow-up tasks for the Cameroon/CEMAC jobs analytics workflow. These are implementation tasks to be handled in future coding sessions, with Stata-first reproducibility standards and generated outputs kept auditable.

## Task List

- [ ] Duplicate robustness ID
  - Generate a new firm-year identifier that separates duplicate records so they can be counted separately instead of being collapsed or ignored.
  - Treat this as a robustness-check specification, not as the default baseline until the duplicate logic is diagnosed and documented.
  - Preserve the original identifier and add clear duplicate diagnostics before estimation.

- [x] Split elasticity plots by outcome proxy
  - Separate the elasticity coefficient plots into total-revenue elasticities and value-added elasticities.
  - Use colors to identify aggregated sectors.
  - Keep table and figure names explicit about whether they refer to `tot_rev` or `va`.

- [ ] Track generated outputs in Git
  - Revise the current ignore policy so Codex/Git does not ignore selected generated outputs needed for review and presentation.
  - Candidate tracked outputs include LaTeX table fragments in `output/tables/`, PDFs, and PNGs in the `output/` tree.
  - Decide whether to track all generated artifacts or only a curated publication/presentation set.

- [ ] Adapt trade analysis scaffold for CEMAC WBES data
  - Extend the current trade-analysis scaffold beyond Cameroon so it can run for CEMAC countries with WBES data.
  - Identify the relevant WBES variables for exports, imports, domestic sales, total sales/revenue, value added, employment, sector, country, and survey year.
  - Document variable harmonization decisions before running pooled or cross-country comparisons.

- [ ] Revenue-elasticity deciles and ordered sector table
  - Create deciles of total-revenue employment elasticities.
  - Build an ordered sector-level table based on these deciles.
  - Replace or complement the current sector ranking table with the decile-based ordering once the construction is validated.

## Implementation Notes

- Keep the baseline Cameroon workflow reproducible before turning robustness checks into headline outputs.
- Use Stata-generated `esttab`/`estout` LaTeX fragments for tables where feasible.
- Any `.gitignore` change should be deliberate, because output files may be generated, bulky, or presentation-critical depending on the artifact.
- Record future implementation decisions in `SESSIONS.md`.
