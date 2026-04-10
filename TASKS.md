# TASKS.md

Working list for the current Cameroon-first Phase I agenda from `Analytics - trade and jobs - Cameroon.docx`: estimate sub-sector employment elasticities from firm-level data, starting with the cleaned tax-panel file in `Data/Cameroon/Clean/CMR_BDF.dta`.

## Immediate objective

- [x] Lock the current task scope to Cameroon Phase I: sub-sector employment elasticities.
- [x] Read the narrative framing in `Analytics - trade and jobs - Cameroon.docx` and align the task list with that Phase I objective.
- [ ] Keep later phases on heterogeneity, constraints, and the reform roadmap out of the active implementation queue until the Cameroon Phase I workflow is stable.

## Data understanding and provenance

- [x] Inspect `Data/Cameroon/Clean/CMR_BDF.dta` and document the current baseline: 9,325 observations, 141 variables, likely core fields `firmid`, `nacam`, `totemp`, `fin_yr`, `tot_rev`, `va`, and `ni`.
- [x] Confirm that `CMR_BDF.dta` is likely a cleaned and renamed derivative of `Data/Cameroon/Raw/TAX PANEL Update - BASE ECOFIN 2015 2022 2024-02-21 18_09_36.xlsx`, based on matching row count and aligned sample records.
- [x] Review `Data/Cameroon/Raw/CENSUS 2024 - Copy of BASE RGE 3 BANQUE MONDIALE - Copy.xlsx` and document that it is a much larger registry source, not the first elasticity file.
- [x] Report the unit of observation explicitly and verify whether the intended analysis key is `firmid` x `fin_yr`.
- [ ] Diagnose firm-year duplicates in `CMR_BDF.dta`, separating exact duplicates from conflicting duplicate records before any estimation.
- [x] Produce a missingness and validity audit for `totemp`, `tot_rev`, `va`, `ni`, and other candidate analysis fields.
- [x] Create a short Cameroon data inventory note that records the raw sources, cleaned files, date coverage, and known limitations.
- [ ] Reconcile the exact-duplicate classification in the diagnosis table with the `duplicates report firmid fin_yr nacam totemp tot_rev va ni` benchmark of 5 surplus exact duplicates.

## Sector harmonization

- [ ] Treat `nacam` as the starting sector code for the Cameroon elasticity workflow and document what classification level it represents.
- [ ] Look in the web for nacam to isic rev 4 crosss walk 
- [ ] Write `code/02_construct/01_cmr_sector_crosswalk.do` to create and validate the sector mapping.
- [ ] Report mapping coverage overall and by year, with an explicit list of any unmapped or ambiguous sector codes.
- [ ] Decide how to handle sparse sectors before estimation: aggregate further, flag, or exclude with justification.

## Elasticity-ready file

- [ ] Convert employment and financial fields to clean numeric analysis variables where needed, starting with `totemp`.
- [ ] Decide the preferred firm identifier to carry into the analysis file and whether any cleaned `uin` version should be derived from `firmid`.
- [ ] Build a one-row-per-firm-year Cameroon analysis panel after duplicate resolution and sample checks.
- [ ] Write `code/02_construct/02_cmr_elasticity_panel.do` to generate the regression-ready file with firm ID, year, mapped ISIC sector, employment, output proxy candidates, and sample flags.
- [ ] Produce a transparent sample-flow diagnostic from `CMR_BDF.dta` to the final estimation sample.
- [ ] Decide whether the Phase I analysis file should stay under `Data/Cameroon/Clean/` for now or be saved to a more explicit analysis location.

## Estimation design preparation

- [ ] Compare the leading output candidates for Phase I elasticity work: `tot_rev` versus `va`.
- [ ] Decide how to treat zero and negative values in employment and output measures before log-based estimation.
- [ ] Decide whether the first Cameroon estimates should be pooled with sector fixed effects, estimated sector by sector, or produced both ways for comparison.
- [ ] Write `code/03_analysis/01_cmr_elasticity_specs.do` to compare candidate employment-elasticity specifications without overcommitting too early.
- [ ] Write `code/04_output/01_cmr_elasticity_tables.do` to export the first Cameroon sub-sector elasticity tables through `esttab` or `estout`.
- [ ] Define the first Phase I output package: a regression table, a sector ranking table, and a short diagnostic note on coverage and sample restrictions.

## Future phases

- [ ] Keep a short backlog note for later `.docx` phases: firm heterogeneity, business environment constraints, and the reform roadmap.
- [ ] Revisit cross-country extension to Gabon and Equatorial Guinea only after the Cameroon Phase I workflow is reproducible and interpretable.
