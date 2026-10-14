# ISIC Rev. 4 assessment: initial findings

> **Tax findings superseded, 2026-09-29.** The raw tax codes use NACAM Rev.1,
> established from official ECOFIN methodology plus branch-count and employment
> checks. The tax mapping/coverage figures below used the older interpretation
> and are historical only. Use [the current tax workflow](cmr_tax_isic4_workflow.md)
> and [revision evidence](cmr_tax_ecofin2019_comparison.md). This correction does
> not reclassify census or WBES records.

Recorded 2026-09-28. This is the initial source/code inventory, not completion of the mapping assessment. Scope: Cameroon Tax/BDF, Cameroon Census/RGE, and WBES for CEMAC countries. No employment elasticity models were estimated.

## WBES: current retained CEMAC samples already have Rev. 4 codes

The raw WBES extract contains 2,975 CEMAC records across 12 country-waves. The five latest-wave samples retained in the current CEMAC analysis contain 1,468 records:

- Cameroon 2024: 615.
- Central African Republic 2023: 151.
- Chad 2023: 164.
- Congo 2024: 365.
- Equatorial Guinea 2024: 173.

All 1,468 have valid four-digit `d1a2_v4` codes in the UN structure and valid two-digit `isic_v4` codes agreeing with the class prefixes. All have positive survey weights, so unweighted and weighted code coverage are both 100%. No missing or duplicate `country_wave idstd` keys were found. These checks establish code validity and consistency, not independent verification of each firm's activity.

Gabon 2009 contributes another 179 latest-wave records, with neither Rev. 4 field nor `isic_v3_1` populated. It remains excluded from the existing CEMAC analysis. Its absence cannot be resolved merely by choosing between those fields. Other raw classification fields and source documentation would need investigation if its inclusion were requested.

Earlier CEMAC waves contain 1,328 records. Of these, 1,176 have a valid Rev. 4 division but no detailed Rev. 4 code. The remaining 152 are Congo 2009 (151) and one Chad 2009 record. These earlier waves are included in the classification inventory only; the estimation sample has not been expanded. The SSA and high-income benchmark groups are outside this assessment.

Evidence: `output/checks/isic4_assessment/wbes_country_wave_coverage.csv`, `wbes_mapping_status_by_wave.csv`, and `wbes_code_review.csv`.

## Tax/BDF: broad categories are the main mapping limitation

The source BDF file has 9,325 records and 37 NACAM categories. The existing cleaned snapshot has 9,068 records with unique firm-year keys. The assessment preserves both files and reports their coverage separately; the raw file has 257 rows involved in duplicate firm-year keys.

The existing crosswalk assigns a single Rev. 4 division to 17 NACAM categories and flags 20 as split/ambiguous. Those 17 categories yield 10 distinct divisions. In the cleaned snapshot, their existing assignments cover:

- 2,613 of 9,068 firm-year records: 28.8%.
- 634,007 of 1,652,372 reported employment units summed across firm-years: 38.4%.
- 27.2% of reported nonnegative total revenue summed across firm-years.

These are coverage figures for existing assignments, not newly validated mappings. Employment summed over firm-years is not a count of distinct workers. The remaining categories should not be discarded automatically: first search for finer activity information and review official definitions.

Nine of the ten provisionally assigned divisions satisfy the current baseline count thresholds for both value-added and revenue samples (30 observations and 10 firms per outcome). Tobacco (12) fails the firm threshold. This does not establish full estimation feasibility: semantic mapping and within-firm variation checks remain pending, and additional mapped firms could alter support.

Evidence: `bdf_mapping_review.csv`, `bdf_cleaned_summary.csv`, and `bdf_provisional_division_support.csv` in the same checks folder. The cleaned input was last modified on 2026-05-22; it is not a new production rerun.

## Census/RGE: activity descriptions require direct review

The assessment reads the available raw workbook `CENSUS 2024 - Copy of BASE RGE 3 BANQUE MONDIALE - Copy.xlsx`, not the cleaned census dataset. It confirms 438,893 units, including 430,011 headquarters, and 273 distinct branch/activity pairs. All pairs match the existing description crosswalk, but its ISIC references are often broad lists; matching that workbook is not equivalent to a reviewed two-digit ISIC assignment.

The review list keeps original descriptions, branch labels, existing reference notes, counts, and headquarters employment/revenue. It leaves reviewed Rev. 4 divisions blank and orders activities by headquarters employment so review can begin with economically important categories. The headquarters sample reports 1,178,044 employees; missing employment is recorded separately.

The exports-enriched census workbook expected by current production scripts is absent. This run explicitly selected `baseline` mode and records that vintage in the census outputs. The activity inventory must be reconciled with the intended workbook when available; exporter support cannot be established from this baseline run.

Evidence: `census_activity_review.csv` and `census_source_inventory.csv`.

## What has been set up and what remains

`code/isic4_assessment/00_run_assessment.do` calls three numbered scripts and uses existing project setup. It writes 15 aggregate CSV diagnostics/review lists and an `esttab` LaTeX WBES summary, and logs the run. No firm-level identifiers are exported in the diagnostics. The official UN structure is retained with a source note and checksum. See `code/isic4_assessment/README.md` for run instructions and denominator definitions.

The baseline run completed with its success marker and no uncaptured Stata error; affected WBES/BDF scripts were rerun successfully after adding exact code-format checks and expanding a note field. Row-count assertions protect merges; reference codes and crosswalk keys are checked for uniqueness.

Next work: review tax definitions and possible finer inputs, map census descriptions directly to Rev. 4 with documented decisions, then recompute coverage/support using reviewed assignments. Full model-specific support, census exporter checks, common sector coverage, and the supporting Rev. 3 comparison remain open. The current findings support retaining Rev. 4 as the preferred target while investigating administrative-data coverage.
