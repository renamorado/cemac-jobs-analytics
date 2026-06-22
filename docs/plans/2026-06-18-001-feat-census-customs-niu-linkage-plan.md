---
title: Simple Census-Customs Exact-NIU Merge
type: feat
status: completed
date: 2026-06-18
origin: tasks/Meeting 06-11-2026.md
---

# Simple Census-Customs Exact-NIU Merge

Create one Stata do-file that imports the Census NIU bridge and customs sheet,
normalizes and validates NIUs, aggregates customs exports, and merges them to
Census headquarters. Use tempfiles for all intermediate data.

Persist only:

- `Data/Analysis/CMR_census_customs_linked.dta`
- `output/tables/cmr_customs_census_merge_audit.tex`

Use exact normalized NIUs only. Preserve unmatched headquarters, Census NIU
multiplicity, customs duplicate flags, and both raw and exact-row-deduplicated
export totals. Defer names, fuzzy matching, BDF linkage, wages, analysis,
figures, and slides.
