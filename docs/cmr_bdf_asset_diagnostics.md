# Cameroon BDF Asset Diagnostics

Date documented: 2026-06-15

## Purpose

This note documents the administrative tax/BDF asset diagnostics added as a
scoped alternative to the blocked Census/RGE asset request in
`tasks/Meeting 06-11-2026.md`.

The RGE/Census workbook currently lacks the dictionary-listed `S4Q00` /
`Capital social` field, so the Census-specific asset distribution remains
blocked. The BDF diagnostics use asset variables already present in
`Data/Analysis/CMR_BDF_cleaned.dta`.

## Source and Unit of Observation

Input dataset:

- `Data/Analysis/CMR_BDF_cleaned.dta`

The input unit is a firm-year. For sector asset totals and averages, each firm
contributes once, using its latest fiscal year with a positive value for the
asset measure being plotted. This avoids adding the same firm's balance sheet
across multiple years.

## Asset Measures

The primary capital proxy is:

- `fa_net`: net fixed assets

The supporting balance-sheet measure is:

- `tot_assets_net`: net total assets

Additional coverage checks are exported for:

- `ta_net`: net tangible assets
- `share_k`: share capital

## Outputs

The Stata stage is:

- `code/elasticity_cameroun/11_cmr_bdf_asset_diagnostics.do`

It exports:

- `Data/Analysis/CMR_BDF_asset_diagnostics.dta`
- `output/tables/cmr_bdf_asset_availability_audit.tex`
- `output/figures/cmr_bdf_net_fixed_assets_by_nacam.pdf`
- `output/figures/cmr_bdf_net_fixed_assets_by_nacam.png`
- `output/figures/cmr_bdf_net_total_assets_by_nacam.pdf`
- `output/figures/cmr_bdf_net_total_assets_by_nacam.png`
- `output/figures/cmr_bdf_assets_vs_employment_by_nacam.pdf`
- `output/figures/cmr_bdf_assets_vs_employment_by_nacam.png`

The current slide deck includes the fixed-asset and total-asset distribution
figures. The assets-versus-employment scatter is generated as a diagnostic
review artifact but is too crowded to be a primary slide.

## Current Coverage

The generated audit reports:

| Measure | Nonmissing | Positive | Zero | Negative | Sectors with positive values |
| --- | ---: | ---: | ---: | ---: | ---: |
| Net fixed assets | 8,342 | 6,395 | 1,939 | 8 | 37 |
| Net total assets | 6,362 | 6,279 | 76 | 7 | 37 |
| Net tangible assets | 8,674 | 8,043 | 623 | 8 | 37 |
| Share capital | 8,417 | 6,611 | 1,786 | 20 | 37 |

These counts come from `output/tables/cmr_bdf_asset_availability_audit.tex`.
