# Cameroon and WBES employment elasticities: assess ISIC Rev. 4 mapping

**Update, 2026-09-29:** the raw tax `CODEBRANCHE` / BDF `nacam` is **NACAM Rev.1**,
established by official ECOFIN methodology and matching branch-count/employment
profiles. See [the evidence](../docs/cmr_tax_ecofin2019_comparison.md).
Tax reporting now uses the separate ISIC Rev.4 section assessment, with combined
sections and explicit boundary exceptions; other datasets retain their own detail.
The original two-digit target and legacy-based tax diagnostics below are historical
where superseded by this decision. Models and production slides remain later work.

Status: first-stage implementation started for the preferred two-digit ISIC Rev. 4 target. Scope is Cameroon Tax/BDF, Cameroon Census/RGE, and WBES for CEMAC countries. Estimation and slide changes remain later work.

Recorded: 2026-09-28. Source: Marina's Slack request, shared by Roldan in chat; original message date not provided.

## Marina's request

> Could we please run the employment elasticity results at the ISIC Rev. 3 level? We've been using NACAM, but we need to convert them to ISIC Rev. 3 to allow comparison and integration with other work streams.

Follow-up shared by Roldan: Marina would consider converting the Cameroon tax data to Rev. 4 if it provides consistency across the work, or presenting both revisions if the differences are substantial. Roldan agreed to Rev. 4 as the preferred target, requested that the first stage cover all three sources, and authorized setup and the start of the assessment. He clarified that WBES countries beyond Cameroon means the CEMAC sample, not the global extract. The general two-digit comparison and Rev. 3 mapping assessment remain supporting evidence; producing both revisions in slides is not yet decided.

## Objective

First establish a reliable and consistently defined two-digit ISIC Rev. 4 classification across Cameroon Tax/BDF, Cameroon Census/RGE, and WBES for CEMAC countries. Assess existing codes as well as categories requiring conversion, document gaps by source and country-wave, and check sector sample support. Use Rev. 3 comparisons and the other workstreams' requirements to assess limitations and any need for additional Rev. 3 results. After reviewing feasibility and estimation scope, reproduce the agreed sector-dependent results in `slides/slides_cemac.tex` with documented source mappings. Preserve the NACAM results for comparison.

## Questions to resolve

- Preferred target: two-digit ISIC Rev. 4, conditional on mapping coverage and estimation support. Confirm compatibility with Marina's other workstreams and whether Rev. 3 results are also required; Rev. 3.1 is a different revision and must not be substituted silently.
- Agreed first-stage scope: Cameroon Tax/BDF, Cameroon Census/RGE, and WBES for the CEMAC countries: Cameroon, Central African Republic, Chad, Congo, Equatorial Guinea, and Gabon. Inventory their available waves and report the current latest-wave analysis sample separately. Include Gabon in the coverage audit while retaining its existing exclusion from the estimation/display sample. SSA outside CEMAC and high-income benchmarks are outside this first-stage assessment. Do not change model specifications or wave inclusion as part of the inventory.
- Mapping feasibility remains empirical: establish which source categories can be assigned uniquely to a target division before committing to the reported sector coverage.

## Implementation plan

### 0. First stage: assess Rev. 4 mapping across all three data sources

- [x] Agree on two-digit Rev. 4 as the preferred target and include Tax/BDF, Census/RGE, and WBES for CEMAC countries in the first-stage assessment. This preference does not establish that every source or WBES country-wave already has validated Rev. 4 codes.

- [ ] Prepare a general two-digit comparison using official structures, explanatory notes, and detailed correspondences. Distinguish renumbering, splits/mergers, and transfers of activities between divisions. Rev. 3 has 60 divisions, Rev. 3.1 has 62, and Rev. 4 has 88; the increase alone does not measure how much activity moved.
- [ ] Identify relatively stable divisions and materially reorganized ones. Include manufacturing, construction, trade, information/business services, and health. Do not describe the entire revision as either simple relabelling or complete incompatibility. A division with one small boundary transfer is not economically equivalent to one that is extensively reorganized.
- [x] Review all 37 tax NACAM Rev.1 branches and finer-information availability. The division assessment has 13 single, 15 combined and nine partial correspondences. Roldan approved analytical section groupings for 005, 006, 009, 021, 029 and 037, yielding 16 tax groups. Strict correspondence fields preserve the official boundaries. Earlier legacy-based counts are superseded. See `docs/cmr_tax_isic4_workflow.md` and `docs/cmr_tax_isic4_sections.md`. Any Rev.3 comparison remains separate later work.
- [x] Complete the Census/RGE first pass using the intended exports-enriched workbook and official Rev. 4 notes: 273 branch/activity pairs reviewed. Roldan subsequently resolved six of the nine exceptions, bringing assignments to 270; charcoal production, property development and truncated components remain unresolved. Full mapping completion remains pending. See `docs/cmr_census_isic4_workflow.md` and `docs/reference/cmr_census_activity_isic4_crosswalk.csv`.
- [x] Review the 85 category-unresolved census units using census information only. Maintain a private CSV of individual decisions separately from the generated review inventory, and import it after the activity crosswalk. Unknown/unclassified is retained when evidence is insufficient. Census cleaning now consumes the CSV and adds separate ISIC fields; regression specifications and slides remain unchanged. See the firm-review section of `docs/cmr_census_isic4_workflow.md`.
- [ ] Inventory WBES classification fields, code levels, revisions, and missing/invalid values by country-wave for CEMAC. Check native Rev. 4 divisions and four-digit activity codes where available, including agreement between them. Use documented correspondences for other revisions only where the source permits a reliable assignment. Do not extrapolate the Cameroon finding of 615 firms with detailed Rev. 4 codes to other CEMAC countries or waves.
- [ ] Record WBES analysis inclusion separately from mapping feasibility. `01_wbes_trade_clean_prep.do` retains `sample == 1` (latest wave) for every economy; `05_wbes_elasticity_prep.do` uses a CEMAC group excluding Gabon as well as other benchmark groups. This assessment covers only CEMAC, shows each available country-wave, and marks the current latest-wave CEMAC sample and Gabon's exclusion explicitly.
- [ ] Report Rev. 4 coverage and unresolved cases for each source by categories, observations, firms, employment, and revenue where available. Show BDF results by year, census results for all units and the headquarters sample, and WBES results by country-wave with raw counts and separately labelled survey-weighted coverage where valid weights exist. Keep monetary coverage within comparable units/country-waves rather than summing local currencies. Distinguish missing original information, invalid codes, ambiguous mapping, and existing analytical exclusions. Retain the supporting tax Rev. 3 comparison and common-mapped-sample coverage.
- [ ] Check observations, distinct firms, and required variation within mapped Rev. 4 divisions using each source's existing outcome-specific sample/support rules. Report census headquarters and exporter-group support where applicable, and WBES counts within the actual country/comparison groups. Do not apply BDF panel thresholds to WBES or create new sector-level models merely for this assessment. Report unsupported groups without estimating elasticities or loosening thresholds.
- [ ] Deliver source-specific Rev. 4 mapping/validation tables, unresolved-category lists, coverage and sample-support tables, and one cross-source summary of comparable divisions and limitations. Include a feasibility recommendation and the supporting Rev. 3 comparison. Distinguish structural differences, source-data limitations, and estimation support. Mapping alone cannot establish the size of changes in elasticities.
- [ ] Obtain the other workstreams' actual sector codes/labels. Review the evidence across all three sources with Roldan before estimation: retain the preferred Rev. 4 target if coverage and support are acceptable, or reconsider it if material losses or comparison requirements justify doing so. Decide which existing models/slide outputs require changes, whether Rev. 3 results are also needed, and whether any second revision belongs in the main slides or appendix. There is no commitment to two complete decks.

Initial official checks confirm substantial but uneven changes at two digits. Examples of broad restructuring include Rev. 3 construction (45) versus Rev. 4 divisions 41-43, and health/social work (85) versus Rev. 4 divisions 86-88 with veterinary activities separately in 75. These are illustrations, not exhaustive crosswalks; partial links and activity definitions still require review. See the [Rev. 3 structure](https://unstats.un.org/unsd/classifications/Econ/Download/In%20Text/ISIC_Rev_3_english_structure.txt) and [Rev. 4 manual, part five](https://unstats.un.org/unsd/classifications/Econ/Download/In%20Text/ISIC_Rev_4_publication_English.pdf). The latter describes changes from Rev. 3.1, so use the Rev. 3/3.1 correspondence as well when constructing Rev. 3 mappings.

Steps 1-6 below retain the proposed implementation approach for later review. Reference collection and mapping checks support the first-stage feasibility assessment; production estimation and slide rebuilding follow review of that assessment and confirmation of scope.

### 1. Confirm the chosen target and inventory the current results

- [ ] Record the confirmed revision(s), reporting level, coverage limitations, and comparison workstreams' codes after step 0. Rev. 4 is preferred; the previous provisional Rev. 3 target is superseded.
- [ ] Inventory active frames, figures, tables, and generating scripts in `slides/slides_cemac.tex`, including the appendix. Record each output's dataset, sector variable, estimation/sample rules, and whether it needs regeneration, a revised explanation, or no change. Exclude commented-out frames from the reproduction target.
- [ ] Cover Cameroon sector scale and asset diagnostics, employment elasticities, exporter comparisons, robustness checks, elasticity rankings, opportunity plots, and WBES constraint plots linked to those rankings. Include the CEMAC WBES figures/models in the classification inventory. Identify whether each uses Rev. 4 divisions, sections, or custom activity groups; assessing two-digit mapping does not automatically replace section fixed effects or extend the assessment to other benchmark samples.
- [ ] Record the starting commit and existing output locations. Use revision-specific `isic3` or `isic4` analysis/output names for the agreed results and a separate ISIC slide source/PDF. Decide whether both revisions share a deck after step 0; preserve the NACAM results.

### 2. Secure data and official classification references

- [ ] Check the required inputs on this machine before running the pipeline. Local cleaned snapshots inspected in this session date from May; the newer exports-enriched census workbook and the three newer elasticity-preparation datasets were absent. Locate the documented raw inputs, including customs and B-READY dependencies for affected slides, and regenerate derived files. Do not silently substitute the older census workbook for the exports-enriched source.
- [ ] Resolve the stale Stata-skill path in `AGENTS.md` before coding. The named `C:/Users/wb648862/.../stata-dime-repro/SKILL.md` is unavailable on this machine; the installed guidance is `stata-reproducible-coding`. Confirm the applicable guidance and retain the project's Stata-first workflow.
- [ ] Download and retain official manuals, machine-readable structures, and correspondence tables for ISIC Rev. 3, Rev. 3.1, and Rev. 4. Include French descriptions for reviewing census labels and English labels for slides. Keep download URLs, retrieval dates, versions, checksums, and any explanatory notes alongside the reference files under `docs/reference/`.
- [ ] For any later Rev.3 work, start from the verified tax NACAM Rev.1 branches and official INS/UN correspondences. Do not interpret tax codes through the older NACAM column or assume a direct Rev.1-to-ISIC Rev.3 concordance exists.
- [ ] Use the verified UN Rev. 4-to-Rev. 3.1 correspondence and the Rev. 3/3.1 correspondence where needed. Preserve partial-coverage flags and explanatory text. Verify direction and coverage before reversing or composing a correspondence.
- [ ] Re-extract or correct reference tables against the PDFs where necessary. Our inspection found misplaced cells in the existing INS Excel extraction and a printed `18002` code whose explanatory notes identify `018002`; the current workbook is not sufficient evidence on its own.

Official starting points:

- [UN classification manuals and structures](https://unstats.un.org/unsd/classifications/Econ)
- [UN ISIC Rev. 4 to Rev. 3.1 correspondence](https://unstats.un.org/unsd/classifications/Econ/tables/ISIC/ISIC4_ISIC31/ISIC4_ISIC31.txt)
- [UN Rev. 3/3.1 correspondence notes](https://unstats.un.org/unsd/classifications/Econ/tables/ISIC/ISIC3_ISIC31/ISIC_3_3.1_note.htm)
- [Official INS NACAM publication page](https://ins-cameroun.cm/statistique/nomenclature_des-activites-et-des-produits-au-cameroun-nacam_npc-rev1/)

### 3. Establish common mapping rules before assigning firms

- [ ] Preserve original codes/descriptions and their revision. Keep codes as strings where leading zeros matter. Retain the most detailed supported classification during mapping and derive two-digit divisions separately for each revision being assessed or implemented.
- [ ] Do not require a unique four-digit Rev. 4 code as an intermediate result for Rev. 3. Use verified direct routes where available; otherwise retain all supported detailed possibilities and interpret partial links against the source activity. Assess uniqueness separately under each target revision; ambiguity in one does not imply ambiguity in the other.
- [ ] Assign a target division when all supported interpretations fall in the same division, or when source activity information and official definitions justify narrowing them to one. A range of four-digit possibilities may still yield one reliable two-digit division.
- [ ] If supported interpretations span divisions and the source cannot distinguish them, leave the target unassigned with an explicit reason. Do not duplicate firms, select the first match, use fuzzy-title scores as evidence, or split employment/revenue using invented weights. Exclude unresolved records from classified estimates while retaining them in coverage audits; review material coverage losses with Roldan before final results.
- [ ] Store reviewable mapping decisions with source category, possible target codes, final division/label, mapping status, official source/page, and reasoning. Distinguish original missing data, unknown codes, and unresolved splits. A reviewed status must explain the assignment, not just indicate that a label exists in a manual.

### 4. Construct and validate the classifier dataset by dataset

Assess all three sources in the first stage using the treatments below. After feasibility review, integrate the validated classifications into production datasets before moving to estimation:

| Dataset | Starting information | Planned treatment |
|---|---|---|
| Tax/BDF | NACAM Rev.1 `nacam`; 37 observed branch codes | Use the reviewed Rev.1 crosswalk and tax section assessment. Source revision is established by ECOFIN evidence; no finer activity classification was found. Broad branches can still span ISIC divisions or sections. |
| Census/RGE | `S1Q14B` activity description and `BRANCHD_S1Q14` branch; 273 distinct descriptions in the available snapshot | Rebuild the activity inventory from the actual intended raw workbook. Review every observed branch/description pair against official activity definitions and exclusions. Use NACAM/NAEMA references as supporting evidence where they clarify local wording; avoid first collapsing descriptions to the broad BDF NACAM sectors. Resolve branch-description conflicts using documented evidence and flag incomplete descriptions. |
| WBES, CEMAC countries | Inventory `isic_v4`, `d1a2_v4`, `isic_v3_1`, labels, and available activity information by country-wave. Initial detailed checks covered Cameroon 2024: 112 four-digit Rev. 4 codes across 615 firms; `isic_v3_1` missing for all 615. | Validate existing Rev. 4 codes directly and compare detailed codes with divisions where both are available. Retain valid native divisions when detailed codes are absent. Inspect documented source revisions and correspondences where conversion is needed; leave unresolved splits explicit. The current trade cleaner retains division fields but omits `d1a2_v4` from its selected raw variables, so audit detailed information from the raw extract. Do not force WBES through NACAM. Report the six CEMAC countries by available wave, showing the existing latest-wave sample and Gabon's exclusion separately. |

- [ ] Add `isic3_division` and/or `isic4_division` and English labels for the selected revision(s), together with separate mapping status and provenance. Retain both assessments in the Tax/BDF comparison even if only one revision is selected for production. Preserve the source identifiers and unit of observation: BDF firm-year, census unit with a headquarters flag, and WBES firm.
- [ ] Validate unique crosswalk keys before merging, inspect every merge outcome, and assert that classification merges do not multiply or silently drop records.
- [ ] Audit mapped/unmapped coverage by source category, observations, firms, employment, and revenue, with denominators and missing-value treatment stated. For BDF, show coverage by year so repeated firm-years do not obscure firm coverage. Report both raw and analysis-eligible coverage.
- [ ] Produce a side-by-side NACAM/ISIC sector composition table. Review all unresolved categories, cross-division splits, and apparent contradictions before estimating models.

### 5. Re-estimate and regenerate the agreed outputs

- [ ] Extend the existing numbered Stata prep/analysis workflow and central setup; avoid a new general-purpose classification framework. Add one explicit entrypoint for the ISIC run that invokes the affected steps in order and writes a master log, without requiring a separate hand-run script for each figure.
- [ ] Keep employment/revenue definitions, transformations, weights, clustering, duplicate handling, and substantive sample restrictions consistent with the current models. Replace classification-related eligibility with eligibility under the new mapping; do not keep an observation excluded solely because its old NACAM sector lacked support. Document the resulting sample changes.
- [ ] Recalculate sector support using the existing model-specific rules. Baseline BDF currently requires 30 observations and 10 firms per outcome; census requires 30 usable firms, with additional exporter-group and variation checks. Preserve all applicable checks and report sectors failing them rather than loosening thresholds to fill a plot.
- [ ] Re-estimate slopes from firm-level data using the selected ISIC revision's sector interactions and corresponding sector-year fixed effects where the current specification uses them. If both revisions are selected, estimate each separately and document comparable samples. Preserve firm fixed effects and firm clustering in BDF, and the existing cross-sectional treatment in census/WBES. Never average NACAM coefficients to obtain ISIC coefficients.
- [ ] Keep source-specific sector coverage for standalone results and use explicitly reported overlap for cross-source comparisons. Rerun a common-mapped-sample NACAM comparison where needed to separate reclassification effects from sample loss; note that changing sector-year fixed effects also changes the specification.
- [ ] Recompute sector totals, firm averages, rankings, deciles, high-elasticity selections, bubble sizes, and associated WBES constraint estimates from the new results. Use the existing definitions and report ties or too few supported sectors explicitly.
- [ ] Export tables through `esttab`/`estout` as booktabs LaTeX fragments and figures from Stata as PDF/PNG. Preserve descriptive/correlational interpretation and confidence intervals where applicable.

### 6. Rebuild the slides and verify the complete run

- [ ] Build the parallel ISIC deck from the frame inventory. Update figures, tables, sector names, model equations, sample notes, and substantive takeaways together. Explain ambiguous/unclassified coverage and distinguish retained country-level WBES models from the new Cameroon sector results.
- [ ] Check source-to-target examples covering exact matches, several detailed codes converging to one division, genuine cross-division splits, partial correspondence links, leading zeros, unknown codes, truncated descriptions, and contradictory census branch labels. Use assertions and small documented check cases; no synthetic records should enter empirical outputs.
- [ ] Reconcile record counts and aggregate measures before/after classification; require valid official divisions for each selected revision, one final mapping decision per source key and revision, and unique firm/firm-year keys after merges. Check finite coefficients/standard errors and documented reasons for omitted sectors or estimates.
- [ ] Run affected scripts first, then the complete ISIC entrypoint once inputs are available. Verify process completion, logs without uncaptured Stata errors, completion markers, and expected output files. Compile and visually inspect the full parallel deck, including the appendix.
- [ ] Confirm every affected frame is regenerated or explicitly identified as unresolved. Deliver the source-specific crosswalks, coverage audits, estimates, comparison deck, and a short methodological note; update `README.md`, this task, and `SESSIONS.md` with regeneration instructions and remaining limitations.

The initial assessment is complete when Rev. 4 mapping/validation, coverage, unresolved cases, and sample-support results are reviewable for all three sources, including WBES for CEMAC countries beyond Cameroon, together with a cross-source comparison, the supporting Rev. 3 comparison, and a recommendation on feasibility. Later implementation requires confirmed target definitions and estimation scope, reviewed mappings, transparent exclusions, reproducible estimates and slide outputs, and no silent use of stale input files. A sector that cannot be classified reliably is a documented limitation, not a reason to invent a mapping.

## Current state

First-stage setup and the initial inventory have been run with `code/isic4_assessment/00_run_assessment.do baseline`. WBES scope is CEMAC only, following Roldan's correction. The five retained latest-wave samples have 1,468 firms with valid, consistent class/division Rev. 4 codes; Gabon remains excluded and lacks these codes. Tax existing single-division assignments cover 28.8% of cleaned firm-year records and still require semantic review. The raw baseline census confirms 273 branch/activity pairs across 438,893 units; reviewed ISIC assignments remain pending. See [initial findings](../docs/isic4_assessment_initial_findings.md) and [run instructions](../code/isic4_assessment/README.md).

The full mapping assessment is not complete. Review of tax/census definitions, finer tax inputs, unresolved coverage, full model-specific support, the supporting Rev. 3 comparison, and the missing exports-enriched census input remain outstanding. Production code, source data, estimates, and slides are unchanged; new assessment scripts write separate diagnostics. The existing task filename is retained to preserve links to Marina's original request.
