# NACAM versus ISIC Rev.4: comparison by dataset

Created: 2026-09-30

## Purpose and delivery

Check whether the economic message survives the classification update and identify the changes that matter for sector priorities. Organize the comparison separately for Ecofin, Census and WBES. Each dataset has its own rankings and interpretation.

Prepare a standalone comparison report, separate from `slides/slides_cemac.tex` and its PDF. Do not edit that deck or overwrite existing results. This document is the plan; the complete numerical comparison remains to be produced.

## Diagnostic tools

This comparison does not need to rely fully on Stata. Use existing tables, CSV audits, saved result datasets and figures as the starting evidence. Python or other suitable tools may read these outputs, reconcile memberships, calculate differences and rankings, and create comparison charts or the standalone report. Keep these diagnostic outputs separate from production outputs and document their inputs and calculations.

Use Stata only when necessary to recover missing estimates, verify model-specific details or estimate a controlled comparison. Do not rerun the full pipeline merely to summarize existing results. Reading saved Stata datasets with another tool is acceptable. Any new estimation must reproduce the relevant sample, transformations, weights, fixed effects and uncertainty calculations, and identify the tool used. Do not manually alter existing exported tables or figures.

## 1. Establish the old and new results

- Inventory retained NACAM tables, figures and result datasets alongside current ISIC outputs. Record dates, inputs, sample restrictions, weights, controls and estimator for each pair. Check that old outputs belong to the same analysis vintage.
- Write down each existing headline claim before comparing results. Record old evidence, new evidence and a verdict: unchanged, qualified, changed or unresolved.
- Match activities using reviewed codes and membership. Old English labels alone are insufficient: some disagree with reviewed NACAM definitions.
- Separate unchanged memberships, pooled branches, split groups, corrected labels and approved cross-section assignments. Do not interpret a pooled coefficient as a weighted average of old coefficients.
- Compare ranks only within the same dataset and outcome. Where group definitions differ, show old component estimates alongside the new pooled estimate rather than report a misleading rank change.

## 2. Ecofin / tax panel

Compare employment and revenue concentration, value-added and revenue employment elasticities, productivity–elasticity maps, and linked constraints. Include fixed-asset and robustness results when they support a headline claim.

Use the retained `cmr_nacam_results_en_labels_*` tables and the current `cmr_isic4_section_results_en_labels_*` tables. Review `output/checks/tax_isic4_sections/slide_comparison.csv` for descriptive comparisons and the reviewed section crosswalk for membership.

Known starting evidence:

- Original economic values and 9,068 cleaned firm-years were preserved; estimation retains firm fixed effects and firm-clustered standard errors.
- Six branches use approved analytical section assignments. Professional/admin. support and arts/other services/households remain combined groups. Explain these qualifications in the report.
- Fifteen of 16 groups meet estimation support rules. Water/waste has 28 usable firm-years and six firms per outcome sample and is suppressed.
- Old value-added highlights include leather/footwear (0.426) and transport equipment (0.359); new section highlights include finance (0.143), agriculture (0.139) and manufacturing (0.125). This reflects different grouping levels and does not establish a decline in the same sector's elasticity.
- Health (-0.209) and electricity (-0.294) retain their displayed value-added estimates.

Determine whether the joint combination of elasticity, employment size, revenue size and productivity changes the sectors emphasized. Check how regrouping changes revenue-elasticity deciles and constraint highlighting. Present standard errors or confidence intervals and sample counts; a large point estimate alone is insufficient evidence for a priority.

## 3. Census

Compare employment/turnover concentration, turnover–employment elasticities and exporter interactions. Show which divisions reveal differences hidden in old groups, and which old conclusions survive.

Use retained NACAM Census outputs alongside current `cmr_census_isic4_division_*` tables and support audits. Use the reviewed Census activity crosswalk to explain splits and combinations.

Known starting evidence:

- All 438,893 source units remain in prepared data.
- Before support checks, eligibility increases from 429,567 to 429,846 firms: 292 enter and 13 leave because their reviewed ISIC classification is unknown.
- Main supported estimates cover 429,719 firms and 76 divisions; exporter estimates cover 30 divisions.

Separate classification changes from removal of the former NACAM-overlap restriction. If retained outputs cannot separate these effects, flag the need for a later controlled comparison on the common eligible sample. Section comparisons with Ecofin use coefficients estimated directly from firms, not averaged division coefficients. Keep the Census cross-sectional interpretation distinct from the Ecofin panel interpretation.

## 4. WBES

Compare Cameroon activity-group and division estimates, revenue–exporter interactions, constraint rankings and estimation support. Review country results only where they underpin the economic message.

Use retained `cemac_wbes_trade_elasticity_cameroon_activity.tex` and `cemac_wbes_revenue_exporter_interaction_cameroon_activity.tex` alongside their ISIC division equivalents, with associated support audits.

Known starting evidence:

- Five divisions support all-firm trade estimates, three support exporter interactions, and none support exporter-only trade estimates under current rules.
- Linked constraint figures cover up to eight Ecofin sections, depending on responses.
- Saved May country outputs predate age, ownership and section controls already present in current scripts. Their differences cannot all be attributed to ISIC regrouping.

Report survey weights, respondent counts and uncertainty. Distinguish a suppressed estimate from zero elasticity. Keep exporter interaction estimates distinct from standalone exporter-only regressions. Check whether changing sector composition changes the constraints emphasized for high-elasticity groups.

## 5. Report structure

1. Brief statement of the overall message and its verification status.
2. Ecofin: unchanged conclusions, largest changes, explanations and implications.
3. Census: the same four headings, with its own rankings.
4. WBES: the same four headings, with its own rankings.
5. Synthesis: which conclusions agree across datasets and which depend on classification, sample or method.
6. Appendix: membership correspondence, complete outcome-specific rankings, estimates with uncertainty, sample/support counts and output dates.

For each dataset, prepare a compact comparison table with old group(s), new group, old/new estimate or share, uncertainty, observation/firm counts, explanation and implication. Use side-by-side figures where group definitions differ. Quantify share changes in percentage points. Describe elasticities as estimated associations; do not call them causal job multipliers.

## Completion criteria and remaining questions

- Every claimed change is supported by a named output and a verified group correspondence.
- Grouping effects, label corrections, sample changes and specification differences are distinguished explicitly.
- The report identifies the most important changes within each dataset without treating unlike ranks as comparable.
- The final message is supported by the comparisons; qualifications and unsupported groups are visible.
- The existing CEMAC slide source and PDF remain untouched.

Remaining questions: Are all retained NACAM estimates available from a consistent vintage? Which exact headline claims should be retained? Do the same sector priorities survive when elasticities, economic size and constraints are considered together? Are controlled common-sample comparisons necessary for Census or WBES?

Evidence reviewed: `docs/isic4_slides_workflow.md`, `SESSIONS.md`, reviewed tax section crosswalk, retained/new Ecofin highlight and ranking tables, and the tax descriptive comparison CSV. No Stata analysis was run for this plan.
