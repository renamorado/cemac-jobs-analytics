# Cameroon Raw Data Notes

This folder holds the live raw Cameroon inputs used by the reproducible Stata
pipeline. Raw files should be treated as read-only inputs; cleaning and
diagnostic outputs are generated under `Data/Intermediate/`, `Data/Analysis/`,
and `output/`.

## RGE/Census Asset Variable Check

Task 1.1 from `tasks/Meeting 06-11-2026.md` requested Census-based asset
diagnostics by sector. The authoritative raw Census workbook,
`CENSUS 2024 with exports BASE RGE 3 BANQUE MONDIALE exp.xlsx`, includes a
dictionary row for `S4Q00` / `Capital social`, but the `BASE` sheet in the live
file does not contain an `S4Q00` column.

The shared OneDrive archive contains the same older Census workbook and does
not provide a fuller source for the asset task. The older
`CENSUS 2024 - Copy of BASE RGE 3 BANQUE MONDIALE - Copy.xlsx` is retained only
as an archive and is not a runnable pipeline dependency. Shared Census fields
match the authoritative workbook by `S0Q01`; the authoritative workbook
additionally supplies embedded export turnover.

Until a fuller RGE/Census source with `S4Q00` or another documented
asset/capital variable is supplied, Census asset plots should remain blocked.
Do not substitute the tax-panel capital variable for this Census-specific task
without an explicit scope change.
