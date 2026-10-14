# Regenerate slides_cemac using ISIC Rev. 4

Date: 2026-09-29  
Status: Agreed approach saved for later implementation; implementation has not started.

## Objective

Replace NACAM-based sector analysis in `slides/slides_cemac.tex` with the reviewed ISIC Rev. 4 classifications. Keep the existing empirical methods and figure ideas, adapting the grouping and descriptions. Modify the existing numbered Stata scripts and reuse the completed crosswalks; do not create a parallel pipeline or a general-purpose framework.

This plan records the discussion in **Plan ISIC Rev 4 slides update** and the settled classification and figure choices in **Check ISIC 4 tax crosswalk**. Saving this plan does not authorize running the analysis or editing the slides yet.

## Settled decisions

| Dataset or output | Analysis level |
|---|---|
| Census main results | Two-digit ISIC Rev. 4 divisions |
| WBES sector-specific results | Two-digit ISIC Rev. 4 divisions |
| Tax/Ecofin results | The 16 agreed groups in `isic4_section` |
| Census–Ecofin elasticity comparison | Additional Census estimates at the corresponding section grouping |
| WBES/B-READY constraints linked to Ecofin | Weighted WBES constraints at the corresponding section grouping |

The tax crosswalk is settled: 37 NACAM Rev. 1 branches map to 14 section-labelled groups (A, B, C, D, E, F, G, H, I, J, K, L, P, Q) and two combinations (M+N and R+S+T). Six branches use approved analytical assignments, documented in `docs/cmr_tax_isic4_sections.md`. There are no separate X005-type analysis groups. Earlier descriptions of 19 groups are superseded.

Use `isic4_section` for tax analysis, not `isic4_section_strict`. Retain the strict fields, original NACAM code, assignment status and notes for checking. Describe the tax classification as ISIC Rev. 4–based groups and retain the agreed qualifications in figure notes.

**Ecofin regressions remain at the firm-year level.** Section-level analysis means section-specific slopes and section–year fixed effects. Collapse observations only for descriptive sector statistics; do not run the existing firm-level models on section totals or average old NACAM coefficients.

Preserve existing estimators, weights, clustering, transformations, outlier rules and minimum-support thresholds. Recalculate samples, support, estimates and rankings under the new classification. Any further substantive change should be identified separately.

## 1. Prepare the classifications once per dataset

### Tax/Ecofin

- Reuse the reviewed Rev. 1 classification steps and `code/elasticity_cameroun/23_cmr_tax_isic4_sections.do` to build `Data/Analysis/CMR_BDF_isic4_sections_assessment.dta`.
- Update `code/elasticity_cameroun/17_cmr_bdf_elasticity_prep.do` to consume that classified panel and retain `isic4_section`, its labels and qualifications.
- Preserve the cleaned firm-year observations and economic values. The current section assessment contains 9,068 firm-years.
- Construct the numeric sector identifier needed for Stata factor-variable syntax from the agreed classification while retaining readable codes and labels. Use the readable classification as the merge key across separately prepared datasets; do not assume independently encoded numeric IDs coincide.

### Census

- `code/elasticity_cameroun/08_cmr_census_cleaning.do` already applies the activity crosswalk and private firm decisions and attaches `isic4_division` and related fields. Reuse this work.
- Carry these fields through `code/elasticity_cameroun/18_cmr_census_elasticity_prep.do`.
- Replace NACAM grouping in the sector diagnostics and main elasticity samples with the reviewed divisions.
- Remove the old requirement for overlap with administrative NACAM sectors where it no longer defines the intended sample. Retain headquarters and economic-variable restrictions and document the resulting sample changes.
- Construct a separate section comparison grouping, including the agreed combined sections, for the Census–Ecofin figure. Keep the division variable for the main Census results.
- Retain unknown classifications explicitly and report their counts and economic coverage; do not invent assignments.

### WBES

- Reuse the existing division codes and official labels from `code/WBES_trade/01_wbes_trade_clean_prep.do`; carry them through `code/WBES_trade/05_wbes_elasticity_prep.do`.
- Use divisions for sector-specific reporting currently based on broad activity groups. Preserve the purpose, samples and methods of country-level comparisons. Existing section fixed effects need not change solely because reported sectors become divisions.
- Derive a separate section comparison grouping for the WBES/B-READY figures linked to tax results.
- Preserve country/wave selection, survey weights, indicator definitions and benchmark populations.

### Shared display fields

Reuse `code/02_construct/01_isic4_broad_groups.do` and `docs/reference/isic4_broad_groups.csv`. Attach the broad labels, colours and symbols during preparation. These ten categories control figure styling; they do not replace divisions or sections as estimation groups.

## 2. Update sector-dependent analysis

Replace sector references in aggregation, regression interactions, sector–year effects, support checks, merges, rankings and labels. Preserve original NACAM fields for checking rather than overwriting them with ISIC values.

The affected Ecofin scripts include:

- `code/elasticity_cameroun/06_cmr_nacam_elasticity.do`: baseline estimates, rankings and related figures.
- `code/elasticity_cameroun/09_cmr_duplicate_robustness.do`: duplicate-treatment comparison, applying the same agreed classification to both samples.
- `code/elasticity_cameroun/10_cmr_fe_robustness_plots.do`: fixed-effect comparisons and estimates used by the Census comparison.
- `code/elasticity_cameroun/11_cmr_bdf_asset_diagnostics.do` and `12_cmr_bdf_sector_scale_figures.do`: sector descriptive outputs.
- `code/elasticity_cameroun/15_cmr_fixed_asset_elasticity_figures.do`: fixed-asset elasticities.

Update Census figures and models in `08_cmr_census_sector_figures.do`, `13_cmr_census_turnover_employment_elasticity.do` and `16_cmr_census_exporter_turnover_elasticity.do`. Update sector-specific WBES results in `code/WBES_trade/03_wbes_trade_elasticity.do` and `04_wbes_revenue_exporter_interaction.do`.

Several analysis scripts currently read cleaned datasets directly despite the presence of dedicated prep scripts. Redirect affected consumers to the prepared classifications consistently, without refactoring unrelated code. Check all outputs included by the slide source so no old NACAM analysis is missed.

Recalculate sector support and rankings. Do not assume that every division or every tax group will meet the existing reporting rules. Preserve reasons for omitted estimates.

## 3. Preserve figure ideas and apply the agreed design

Use `code/elasticity_cameroun/24_cmr_tax_section_comparison.do` and its `cmr_tax_sections_new_employment` / `cmr_tax_sections_new_revenue` figures as the design reference for production Ecofin figures:

- Paired panels for sector totals and firm averages, with ranked rows.
- Existing broad-sector colours and symbols, including the hollow grey diamond for Other services.
- Short, readable section labels and asterisks with notes for qualified groupings.
- Preserve the original definitions of annual totals, equal-year averages of firm means, ratios, log versions and level versions. Calculate pooled group statistics from firms, not by taking unweighted averages of old branch statistics.

Keep coefficient plots, scatter plots, bubble plots and appendix counterparts in their existing roles. Allow the number of rows or points to change with the classification and reporting support.

### Census–Ecofin comparison

Re-estimate Census employment–turnover slopes using the section comparison groups and merge with newly estimated Ecofin employment–revenue elasticities. Do not average division coefficients. Present this as a descriptive comparison: Census slopes are cross-sectional and Ecofin estimates use panel variation.

### WBES/B-READY–Ecofin figures

Adapt `code/BREADY_wbes/03_bready_wbes_sector_constraints.do`:

- Horizontal axis: survey-weighted constraint calculated from WBES firm responses within each section comparison group.
- Vertical axis: newly estimated Ecofin employment–revenue elasticity for that group.
- Bubble size: recalculate the existing three size categories from average annual total Ecofin employment among overlapping groups.
- Orange highlighting: recalculate revenue-elasticity deciles and retain the deciles 7–10 rule; it does not require exceeding the constraint benchmark.
- Keep the published national B-READY benchmark and indicator definitions.
- Recalculate the overlap and remove hard-coded assumptions about 16 overlapping NACAM sectors. Omit indicator/group cells without usable responses and retain the current small-cell reporting rules.

Match combined sections explicitly. Retain qualifications concerning analytical tax assignments and the scope of R+S+T (T covers division 97 in the tax reference). Section labels do not establish identical populations or exact activity coverage across datasets. Use only definable comparison groups, record unmatched groups, and disclose these limits without reopening the settled tax crosswalk.

## 4. Update run order, output names and slide text

- Update `code/00_master.do` to run the reviewed Rev. 1 tax section sequence and shared display lookup before the affected analyses; its current default tax classification calls do not build the agreed section output.
- Include the WBES and robustness steps required by the deck that currently run separately. Keep the sequence explicit in the existing master rather than adding another orchestration layer.
- Generate filenames that distinguish ISIC division outputs from section outputs and update all consumers together. Do not leave the deck pointing at old NACAM results. Avoid unrelated script renaming or folder reorganization.
- Edit the existing `slides/slides_cemac.tex` in place. Update figure/table references, titles, notes, axes, model descriptions and sector references, including section–year fixed effects.
- Recheck numerical statements, highlighted sectors and conclusions against the new estimates. Correct the outdated slide explanation of orange bubbles.
- Retain NACAM references where they describe the original tax classification or the crosswalk itself; do not apply a blanket text replacement.
- Keep regression/summary tables generated with `esttab`/`estout` as booktabs LaTeX fragments. Keep figures and their embedded notes generated by Stata.

## 5. Verify and deliver

1. Check classification keys, merge outcomes, original values and observation counts. Confirm conservation of economic totals under regrouping using unchanged denominators. Report unclassified records separately.
2. Compare old and new estimation-sample counts, explaining changes caused by classification coverage, removal of NACAM overlap restrictions and support rules. Preserve the current empirical methods.
3. Confirm that model interactions, fixed effects, rankings and cross-dataset merges use the intended grouping. Check the treatment of firms whose reported sector changes across years against the existing model convention.
4. Run affected do-files first from the project root, following `AGENTS.md` guidance for long Stata runs. Check completion, logs, success markers and refreshed outputs. Then run the complete integrated sequence needed for the deck.
5. Verify that every figure and table referenced by the deck is current and uses the intended classification. Compile the existing slide document and visually inspect main and appendix slides for labels, notes, clipping and numerical consistency.
6. Update the relevant workflow documentation and `SESSIONS.md` with completed changes, verification and remaining limitations.

Implementation is complete when the deck is reproducibly generated with Census/WBES division results, Ecofin section-group results, the two agreed section-level comparisons, consistent styling and accurate descriptions. Counts of reportable groups and any resulting layout adjustments will be established during implementation; they are not known from the crosswalk alone.

## References

- `docs/cmr_tax_isic4_sections.md`
- `docs/cmr_tax_isic4_workflow.md`
- `docs/cmr_census_isic4_workflow.md`
- `docs/isic4_broad_display_groups.md`
- `docs/reference/cmr_tax_nacam_rev1_isic4_sections.csv`
- `docs/reference/cmr_census_activity_isic4_crosswalk.csv`
- Private census decisions: `Data/Cameroon/Reference/cmr_census_firm_isic4_decisions.csv` (required for replication; excluded from Git).
- `code/elasticity_cameroun/24_cmr_tax_section_comparison.do`
- `slides/slides_cemac.tex`
