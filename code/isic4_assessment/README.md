# First-stage ISIC Rev. 4 assessment

**Tax update, 2026-09-29:** source `CODEBRANCHE` / `nacam` uses **NACAM Rev.1**,
established from official ECOFIN methodology and matching count/employment
profiles. This folder's initial BDF diagnostics use the superseded legacy
crosswalk and must not guide new tax analysis. Use
[the current tax workflow](../../docs/cmr_tax_isic4_workflow.md); see
[evidence and scope](../../docs/cmr_tax_ecofin2019_comparison.md). Census and WBES
classification remain separate.

This assessment covers Cameroon tax/BDF, Cameroon Census/RGE, and WBES for the six CEMAC countries. It reads source data and existing reference files and writes aggregate diagnostics and review lists. It does not alter the production pipeline, fit regressions, or regenerate slides.

## Run

From the repository root in Stata:

```stata
do "code/isic4_assessment/00_run_assessment.do"
```

The default requires the exports-enriched census workbook used by current production code. For an explicitly labelled assessment of the older available census workbook:

```stata
do "code/isic4_assessment/00_run_assessment.do" baseline
```

The initial inventory used `baseline` because the exports-enriched workbook was then absent. Roldan supplied it on 2026-09-28. No automatic fallback is allowed. Both inventory modes write to the same assessment output folder; read the provenance columns and log to identify the vintage. The completed census crosswalk uses a separate entrypoint and output folder below.

The entrypoint uses the existing `code/01_setup.do` for paths and packages. It calls the WBES, BDF, and census scripts in sequence. Successful completion requires the final message in `logs/isic4_assessment.log`; an interrupted run may leave partial outputs.

## Outputs and interpretation

CSV diagnostics are written to `output/checks/isic4_assessment/`. The WBES LaTeX summary is exported with `esttab` to `output/tables/isic4_assessment/`.

| Files | Interpretation |
|---|---|
| `wbes_country_wave_coverage.csv` | CEMAC source waves, code coverage, valid-weight coverage, employment and sales coverage, ID diagnostics, and current sample flags |
| `wbes_mapping_status_by_wave.csv`, `wbes_code_review.csv` | Native/derived divisions, missing/invalid codes, conflicts, and original code combinations with counts |
| `wbes_division_counts.csv` | Records and positive-employment/sales observations by division and wave; these are not complete model-support tests |
| `wbes_code_inventory.csv`, `wbes_code_inventory.tex` | Aggregate code-availability checks for latest versus earlier CEMAC waves |
| `bdf_mapping_review.csv` | Existing 37-category crosswalk with review status and a blank reviewed-division field |
| `bdf_raw_*`, `bdf_cleaned_*` | Separate coverage checks for the source BDF file and existing cleaned snapshot; source rows are not deduplicated in the assessment |
| `bdf_provisional_division_support.csv` | Baseline observation/firm count thresholds for existing single-division assignments; not a certification of mapping or fixed-effect identification |
| `census_activity_review.csv` | Raw branch/activity pairs, frequencies, headquarters measures, and old reference notes; all reviewed-division fields remain blank |
| `census_source_inventory.csv` | Raw-workbook vintage, headquarters flag, missing/negative/nonnumeric measures, and existing-crosswalk coverage |

WBES code validity means membership in the UN Rev. 4 structure. Where valid class and division fields are present, their prefixes must agree. A valid division can be retained when a class is missing. Nonmissing invalid codes and conflicting valid codes remain unresolved. This does not independently verify each firm's reported activity. Gabon is included for coverage but retains its exclusion from the current analysis sample. Earlier waves are inventory information, not additions to estimation. Other global benchmark samples are outside scope.

The BDF crosswalk and census reference notes are evidence to review, not new verified ISIC assignments. Do not copy a first or convenient code out of a list spanning divisions. The census inventory comes from original descriptions and is not mapped through BDF's broad NACAM categories.

Coverage denominators use nonmissing, nonnegative employment and revenue; parse failures and excluded negative values are audited. WBES weighted coverage uses positive, nonmissing `wt` and is reported separately by country-wave. Do not sum sales in different local currencies. BDF employment totals across years represent sums of firm-year employment, not a count of distinct workers. Firm counts within categories/statuses may overlap when firms change classifications over time. Census headquarters are `S1Q13 == "Siège"`; both all-unit counts and headquarters measures are reported.

## Remaining first-stage work

The initial inventory is a starting result, not completion of the mapping stage. The separate census first pass below now provides divisions and exceptions from the intended workbook. Cross-source comparison, outcome-specific estimation support and a supporting Rev. 3 assessment remain separate work.

## Census-only crosswalk

Run `do "code/isic4_assessment/00_run_census_crosswalk.do"` from the project root. This reads only the intended census workbook and census/official reference files, writes `Data/Analysis/cmr_census_isic4_assessment.dta`, and creates review and coverage files in `output/checks/census_isic4/`.

The editable decisions are `docs/reference/cmr_census_activity_isic4_crosswalk.csv`; neither this run nor the older inventory scripts overwrite that file. Following Roldan's review of six exceptions, 270 pairs are assigned (264 first-pass assignments and six reviewed decisions); three remain unresolved. See [the census workflow](../../docs/cmr_census_isic4_workflow.md) for sources, interpretation, output definitions and review instructions. Run `do "code/isic4_assessment/07_test_census_crosswalk.do"` after the assessment to check deliberate invalid decisions and the resulting unit-level data.

The census entrypoint now also exports the unresolved-unit inventory (08), validates the private firm decision CSV (09), and attaches those decisions (10). The required reviewed input is `Data/Cameroon/Reference/cmr_census_firm_isic4_decisions.csv`; it is excluded from Git because it contains census IDs and names. It must accompany the raw data for replication. Inventory exports never overwrite it. Unknown/unclassified rows retain blank final codes, and firm decisions cannot override a category assignment.

The combined result is `Data/Analysis/cmr_census_isic4_firm_assessment.dta`, with coverage and review CSVs prefixed `census_firm_` in the same output folder. The existing Excel workbook remains a category review. For firm-only updates after a current category assessment, run `do "code/isic4_assessment/98_run_census_firm_review.do"`, then `do "code/isic4_assessment/11_test_census_firm_review.do"`. Preserve census IDs as text when reviewing CSVs.

Firm decisions distinguish `assigned_census_evidence` from `assigned_reviewed_assumption`; both apply the saved division, while `unknown_unclassified` requires a blank final code. Roldan's reviewed assumption assigns the 62 remaining property-development units to 42, preserving the two individually assigned 68 records.

Two further reviewed assumptions assign the cable-manufacturing firm to 27 and the welding workshop to 25. Census cleaning (`code/elasticity_cameroun/08_cmr_census_cleaning.do`) now regenerates the classification and attaches five `isic4_*` fields to `CMR_census_cleaned.dta`. Existing NACAM and outcome variables remain. Run `12_test_census_cleaning_isic4.do` after cleaning to verify the attached fields. Firm-only assessment runs do not themselves resave the production cleaned dataset.
