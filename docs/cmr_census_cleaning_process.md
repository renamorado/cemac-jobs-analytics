# Cameroon Census Cleaning Process

Date documented: 2026-05-26

## Purpose

This note documents the cleaning process used for the Cameroon 2024 RGE Census dataset in the current CEMAC project pipeline. The active Stata implementation is `code/elasticity_cameroun/08_cmr_census_sector_diagnostics.do`.

The cleaned Census data are used to produce sector-level diagnostics that align the Census activity information with the NACAM sectors used in the Cameroon administrative-data elasticity analysis.

## Source Data

Raw source workbook:

- `Data/Cameroon/Raw/CENSUS 2024 - Copy of BASE RGE 3 BANQUE MONDIALE - Copy.xlsx`

Source sheet:

- `BASE`

The raw Excel workbook is treated as read-only. All transformations are implemented in Stata.

The workbook dictionary lists `S4Q00` as `Capital social`, but the active
`BASE` sheet in this raw file does not contain an `S4Q00` column. The pipeline
therefore treats Census asset diagnostics as blocked until a fuller RGE/Census
source is supplied.

## Fields Kept

The Stata cleaning step imports the workbook as strings, preserves source provenance, and keeps only the fields needed for the Census diagnostics:

- `S0Q01`: firm or unit identifier, renamed `firmid_census`
- `S1Q13`: unit status, renamed `unit_status`
- `S1Q14B`: detailed activity label, renamed `activity_detail`
- `SACTIV_S1Q14`: broad activity grouping, renamed `activity_macro`
- `BRANCHD_S1Q14`: CITI/ISIC Rev.4 branch label, renamed `citi_branch`
- `S6Q05AC`: employment, renamed `employment_raw`
- `S6Q01A`: annual turnover, renamed `annual_turnover_raw`

The Stata step also audits, but does not import, the dictionary-listed
`S4Q00` / `Capital social` field. As of 2026-06-15, the dictionary names this
field but the current `BASE` sheet does not contain it, so no asset variable is
available in the cleaned Census file.

The script also creates:

- `source_file`
- `source_sheet`
- `source_excel_row`

These provenance fields make it possible to trace cleaned records back to the raw workbook.

## Basic Cleaning Rules

The Census cleaning process applies the following basic rules:

- Trim string variables with `ustrtrim()`.
- Recode `"ND"` and `"Ne sait pas"` to missing.
- Require `firmid_census` to be nonmissing.
- Verify that `firmid_census` uniquely identifies rows with `isid firmid_census`.
- Parse employment and annual turnover from string to numeric values, ignoring commas and spaces.
- Flag nonnumeric employment and turnover entries before destringing.
- Flag missing, zero, and negative values for employment and turnover.
- Set negative employment and negative annual turnover to missing.

The flags remain in the cleaned file so later users can audit data quality rather than silently losing information.

## Headquarters Rule

Employment and annual turnover are used only for headquarters rows. This follows the Census dictionary, which marks the employment and turnover fields as headquarters-only fields.

The script creates `hq_sample` to flag rows where `unit_status` identifies a headquarters unit.

Non-headquarters rows remain in the cleaned Census dataset for traceability, but their employment and annual turnover values are set to missing before sector diagnostics are produced.

## Sector Crosswalk

The sector cleaning and harmonization step treats `BRANCHD_S1Q14` as CITI/ISIC Rev.4 because the Census dictionary labels it as `classification CITI Rev.4`.

The mapping from Census activity labels to administrative NACAM sectors is intentionally reviewable:

- The observed Census activity universe is defined as unique pairs of `citi_branch` and `activity_detail`.
- That observed activity universe must be covered exactly once by `docs/reference/cmr_census_activity_nacam_crosswalk.xlsx`.
- The crosswalk points back to `docs/reference/nacam_rev1_citi_bridge_extracted.xlsx`, which was extracted from the official INS NACAM Rev.1/CITI bridge.
- The Stata script validates each nonmissing NACAM Rev.1 reference against official three-digit NACAM Rev.1 prefixes from the extracted bridge.
- Manual classification logic is kept in the reviewable workbook, not hidden in long Stata `replace` blocks.

The merged `nacam` field follows the legacy/admin NACAM sector codes observed in `Data/Cameroon/Clean/CMR_BDF.dta`, so the Census diagnostics use the same sector vocabulary as the elasticity outputs.

For Census descriptive diagnostics, the script also creates `census_nacam`. This equals the admin/BDF-overlap `nacam` where available and falls back to the official legacy NACAM code from the PDF-derived crosswalk when the sector is absent from the current elasticity panel. This keeps the whole-economy Census descriptive statistics from dropping headquarters firms solely because their sector is outside the BDF elasticity sample.

## Review Flags

The crosswalk includes a `review_flag`.

Cases are flagged when they are ambiguous, absent from the current administrative elasticity sectors, or when the Census branch and detailed activity label point to different classifications.

Flagged observations remain in:

- the cleaned Census file
- the activity crosswalk
- the audit table

The current diagnostic plots use headquarters rows with an official/admin NACAM sector. Rows outside the current elasticity-sector crosswalk remain flagged, but they are included in the Census economy descriptive totals when an official legacy NACAM code is available.

## Output Datasets

The Census cleaning script writes:

- `Data/Intermediate/cmr_census_activity_nacam_crosswalk.dta`
- `Data/Analysis/CMR_census_cleaned.dta`
- `Data/Analysis/CMR_census_nacam_diagnostics.dta`
- `Data/Analysis/cmr_census_turnover_employment_elasticity.dta`
- `Data/Analysis/cmr_census_vs_bdf_turnover_employment_elasticity.dta`
- `output/tables/cmr_census_asset_availability_audit.tex`

The cleaned file keeps firm-level Census records with provenance, cleaned numeric fields, crosswalk fields, review flags, and plotting eligibility indicators.

The diagnostics file collapses eligible headquarters observations to Census NACAM-sector level.

The asset availability audit records whether the dictionary lists `S4Q00`,
whether the `BASE` sheet actually contains `S4Q00`, and whether Census asset
figures were generated from the current source.

## Sector Diagnostics

For headquarters rows with official/admin NACAM sectors, the script constructs sector-level diagnostics:

- number of headquarters firms
- total employment
- average employment
- total annual turnover
- average annual turnover
- annual turnover per worker
- average firm-level annual turnover per worker
- log versions of positive totals and averages used in plots

The script exports Census figures to:

- `output/figures/cmr_census_firm_count_by_nacam.pdf`
- `output/figures/cmr_census_firm_count_by_nacam.png`
- `output/figures/cmr_census_total_employment_by_nacam.pdf`
- `output/figures/cmr_census_total_employment_by_nacam.png`
- `output/figures/cmr_census_total_revenue_by_nacam.pdf`
- `output/figures/cmr_census_total_revenue_by_nacam.png`
- `output/figures/cmr_census_average_employment_by_nacam.pdf`
- `output/figures/cmr_census_average_employment_by_nacam.png`
- `output/figures/cmr_census_turnover_per_worker_by_nacam.pdf`
- `output/figures/cmr_census_turnover_per_worker_by_nacam.png`

No Census asset figures are exported from the current source because the active
`BASE` sheet does not contain the dictionary-listed asset/capital variable.
Administrative tax/BDF asset diagnostics are documented separately in
`docs/cmr_bdf_asset_diagnostics.md`.

## Turnover-Employment Elasticity Robustness

Task 1.2 adds a Census/RGE robustness check in
`code/elasticity_cameroun/13_cmr_census_turnover_employment_elasticity.do`.
This stage uses `Data/Analysis/CMR_census_cleaned.dta` as its only Census
input; it does not re-import or edit the raw workbook.

The primary Census specification estimates a cross-sectional employment
elasticity with respect to annual turnover:

- outcome: log employment
- regressor: log annual turnover
- sample: headquarters rows with positive employment, positive annual turnover,
  nonmissing admin-overlap NACAM sector, and nonmissing sector labels
- fixed effects: detailed NACAM sector intercepts only
- inference: heteroskedasticity-robust standard errors

Because the Census is a one-time cross-section, this robustness check does not
use firm fixed effects, year fixed effects, or NACAM-sector-by-year fixed
effects. Those panel fixed effects remain specific to the administrative
tax/BDF elasticity estimates.

The stage exports:

- `output/tables/cmr_census_turnover_employment_elasticity.tex`
- `output/tables/cmr_census_turnover_employment_elasticity_audit.tex`
- `output/tables/cmr_census_vs_bdf_turnover_employment_elasticity.tex`
- `output/figures/cmr_census_turnover_employment_elasticity_coefficients.pdf`
- `output/figures/cmr_census_turnover_employment_elasticity_coefficients.png`
- `output/figures/cmr_census_turnover_employment_elasticity_scatter.pdf`
- `output/figures/cmr_census_turnover_employment_elasticity_scatter.png`
- `output/figures/cmr_census_vs_bdf_turnover_employment_elasticity.pdf`
- `output/figures/cmr_census_vs_bdf_turnover_employment_elasticity.png`

The comparison figure and table merge Census annual-turnover elasticities to
the baseline administrative tax/BDF total-revenue elasticities for overlapping
NACAM sectors only. The comparison is descriptive: it contrasts broad Census
coverage with the panel-based administrative elasticity estimates, but it does
not claim the two designs identify the same parameter.

## Current Audit Counts

The current generated audit table reports:

| Audit item                                                |   Count |
| --------------------------------------------------------- | ------: |
| Raw Census rows                                           | 438,893 |
| Headquarters rows                                         | 430,011 |
| Observed detailed activity labels                         |     273 |
| Detailed labels mapped to admin NACAM                     |     260 |
| Detailed labels flagged for review                        |      31 |
| Crosswalk labels not found in official NACAM Rev.1 bridge |       0 |
| Headquarters rows flagged for review                      |  16,202 |
| Headquarters rows outside elasticity NACAM sectors        |     298 |
| Headquarters rows without official/admin NACAM            |       0 |
| Headquarters rows used in Census NACAM plots              | 430,011 |

These counts come from `output/tables/cmr_census_sector_audit.tex`.

The asset availability audit currently reports:

| Audit item                                      | Value |
| ----------------------------------------------- | ----: |
| Dictionary lists `S4Q00` / `Capital social`     |     1 |
| `BASE` sheet contains `S4Q00`                   |     0 |
| Asset figures generated from Census source      |     0 |

These counts come from `output/tables/cmr_census_asset_availability_audit.tex`.

## Reproducibility Notes

The Census cleaning process is run from the project master script:

- `code/00_master.do`

The relevant Census step is:

- `code/elasticity_cameroun/08_cmr_census_sector_diagnostics.do`

The process should be rerun from Stata whenever the raw Census workbook, crosswalk workbook, official bridge extraction, or administrative NACAM sector mapping changes.
