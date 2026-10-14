# Cameroon census: ISIC Rev. 4 division crosswalk

**Tax context, 2026-09-29:** raw tax/BDF codes use NACAM Rev.1; see
[the ECOFIN verification](cmr_tax_ecofin2019_comparison.md). This does not change
the census classification below, which uses original census activity text.
Older legacy/admin-NACAM bridges must not be treated as verified equivalence
with the corrected tax sectors.

## Scope and inputs

This classification covers all 273 observed branch/activity pairs, followed by a separate census-only review of unresolved units. Census cleaning attaches the resulting ISIC fields while preserving the existing NACAM classification. The [slide workflow](isic4_slides_workflow.md) uses these divisions for Census results and separately estimates section-level slopes for comparison with Ecofin. A first-pass assignment means the supplied category wording supports one division under the interpretation recorded in the crosswalk. It does not independently verify every firm's actual activity; reviewed assumptions are explicitly identified.

The required input is `Data/Cameroon/Raw/CENSUS 2024 with exports BASE RGE 3 BANQUE MONDIALE exp.xlsx`, sheet `BASE`, supplied by Roldan on 2026-09-28. The input has 438,893 unique `S0Q01` units, 430,011 headquarters and 273 branch/activity pairs. There is no fallback to the older workbook.

Input SHA-256: `1CA6131EFEC7F368E4DC916DDCDC5C348C9E36E458142DBDCB6187C268C7273F`.

The editable decisions are in `docs/reference/cmr_census_activity_isic4_crosswalk.csv`. All assignments use the original branch/activity text as the key; only leading/trailing whitespace is removed for matching. Original source columns, including descriptions, branches and identifiers, remain unchanged in the assessment dataset. Neither the older NACAM mapping nor fuzzy text similarity determines the new assignments.

## Raw information inspected

The `DICTIONNAIRE DES VARIABLE` sheet identifies `BRANCHD_S1Q14` as ISIC Rev. 4, but its values are 17 broad labels, not official division codes. `SACTIV_S1Q14` supplies three macro sectors; `S1Q14B` supplies the activity descriptions. The dictionary contains no numerical four-digit activity field and does not expand the truncated activity descriptions.

All 29 BASE fields were inspected by their headers, dictionary meaning, and relevant values. The generated `census_raw_fields.csv` records the Stata field names and storage types.

| Source fields | Information available for this assessment |
|---|---|
| `S0Q01` | Unit identifier |
| `S1Q05A`, `S1Q05B`, `S1Q05C`, `GEOGRAPHIE` | Location; not an activity code |
| `S1Q13` | Headquarters/other unit status |
| `S1Q14B`, `SACTIV_S1Q14`, `BRANCHD_S1Q14` | Detailed activity text, macro sector and branch |
| `S3Q01` | Establishment year according to the dictionary |
| `S4Q01AA`, `S4Q01AB`, `S4Q01BA` | Ownership information |
| `S4Q03`, `S4Q06`, `FJ`, `FORMEL` | Accounting/tax reporting, legal form and formality |
| `S5Q00`, `S5Q01A`, `S5Q01B`, `S5Q02A`, `S5Q02B`, `S5Q03A`, `S5Q03B` | Promoter/manager characteristics; dictionary partly reuses promoter codes for manager fields |
| `S6Q01A` | Annual turnover; dictionary specifies headquarters only |
| `S6Q05AA`, `S6Q05AB`, `S6Q05AC` | Employment fields; dictionary identifies female and total employment, with headquarters-only reporting |
| `chiffre d'affaire exportation` | Added export turnover; imported by Stata as `chiffredaffaireexportation` |

The other workbook sheets were also inspected. `Sheet3` contains export-linkage fields (`NIU`, enterprise names, `EXPV2023`, matching information). `Feuil2` contains unit ID, name fields, unit status, `S1Q16`, formality and size (`TPE`, `PE`, `ME`, `GE`, undeclared). The existing customs-linkage script identifies `S1Q16` as the taxpayer identifier. `Feuil3` contains names and taxpayer numbers. None provides an explicit detailed activity code or an expanded activity field. Names and taxpayer numbers are not treated as evidence that every unit in an ambiguous activity pair has the same activity.

The dictionary lists capital `S4Q00`, which is absent from BASE. Missing dictionary entries are not filled using similarly numbered fields.

## Official evidence and decisions

The [UN French ISIC Rev. 4 manual](https://unstats.un.org/unsd/publication/seriesM/seriesm_4rev4f.pdf), *CITI Révision 4*, New York, 2009, is saved as `docs/reference/isic_rev4_official_fr.pdf`. Each row cites the relevant class notes, PDF pages and printed pages. PDF numbering is one-based and includes the front matter; printed pages are 16 lower in the explanatory notes.

Manual SHA-256: `6DBCFBDAC1ED728626FF8DDCACA3D5E22D054C7DF299C62E210ED4B9B43DAAB9`.

English division labels come exclusively from `docs/reference/isic_rev4_english_structure.csv` (88 divisions, 419 classes), with provenance in its adjacent source note. The INS `nacam-rev1-ins-cameroon.pdf` and prior census NACAM references provide supporting context; the old bridge contains broad references that must not be interpreted as a detailed Rev. 4 assignment.

Crosswalk columns:

| Fields | Meaning |
|---|---|
| `citi_branch`, `activity_detail` | Original branch/activity key, with boundary whitespace trimmed |
| `proposed_division` | Preferred interpretation where there is one; never used to classify unresolved records |
| `final_division`, `final_division_label` | Two-digit output and official English label; both blank for unresolved rows |
| `review_status` | `assigned_first_pass`, `assigned_reviewed`, `pending_ambiguity`, `pending_incomplete`, or `pending_conflict` |
| `possible_divisions`, `possibilities_complete` | Space-separated possible divisions; `no` means examples rather than an exhaustive list |
| `supporting_classes` | Space-separated four-digit references used to assess boundaries; these are not firm-level class assignments |
| `official_reference`, `official_pages`, `official_url` | Official definitions to consult |
| `supporting_detail`, `legacy_isic_reference`, `reasoning` | Other evidence, earlier reference and the decision's reasoning |
| `reviewer`, `review_date` | Who made the recorded decision and when |

Several four-digit possibilities can support one division: non-life insurance/reinsurance both map to 65, and data hosting/web portals both map to 63. Cotton ginning belongs to 01 under the explicit post-harvest inclusion. Wood charcoal remains unresolved because traditional forestry production is 02 while wood distillation is 20. Truncated labels can be assigned only where the retained wording settles the division, such as explicitly described retail activities.

Ordinary rental labels are interpreted as the official rental categories without operators/drivers; the row notes disclose this boundary. Generic named categories are interpreted in the context of separately enumerated census categories. These conventions should be revisited if the source agency provides contradictory definitions. The unresolved list preserves actual wording conflicts, missing material/process detail, and descriptions spanning divisions.

## Regeneration

Run from the repository root in Stata 17:

```stata
do "code/isic4_assessment/00_run_census_crosswalk.do"
```

The entrypoint uses the existing `code/01_setup.do`, then calls:

1. `04_validate_census_crosswalk.do`: checks the decision CSV and official codes, and creates the validated intermediate crosswalk.
2. `05_census_isic4_assessment.do`: imports BASE, attaches classifications, checks record preservation, and writes aggregates.
3. `06_census_review_excel.do`: exports and formats the review workbook from those generated CSVs. It is called by step 05 and can also be rerun after setup to rebuild only the Excel copy.
4. `08_census_firm_inventory.do`: selects units unresolved by the category crosswalk, attaches names and reported size from `Feuil2`, and exports their review fields.
5. `09_validate_census_firm_decisions.do`: validates the separately saved firm decision CSV against official divisions and the exact census ID, activity, branch and name fields.
6. `10_apply_census_firm_decisions.do`: applies firm decisions only to unresolved units and creates a separate combined assessment and diagnostics.

The firm stage requires the private input `Data/Cameroon/Reference/cmr_census_firm_isic4_decisions.csv`. It is not recreated by inventory exports. Transfer this file securely with the raw census when replicating the review; it is deliberately excluded from Git. A missing file or a changed set of unresolved IDs stops the run until the decisions have been reviewed against the new inventory.

If the category assessment already exists and its source/category decisions have not changed, run `do "code/isic4_assessment/98_run_census_firm_review.do"` to regenerate just the firm stage. It also checks category codes and statuses against the current crosswalk. If raw data or category decisions changed, use the full census entrypoint. Run `do "code/isic4_assessment/11_test_census_firm_review.do"` after the firm stage for rejection tests and comparisons with the original category assessment.

Successful completion requires `CENSUS ISIC4 ASSESSMENT COMPLETED SUCCESSFULLY` at the end of `logs/census_isic4_assessment.log`, without an uncaptured Stata error. An interrupted run can leave partial outputs; do not treat their presence alone as success.

## Outputs and denominators

`Data/Analysis/cmr_census_isic4_assessment.dta` retains every census unit and all original BASE fields, plus source row/file, classification/status, headquarters flag, parsed measures and measure-quality flags. It is separate from `CMR_census_cleaned.dta`. Supporting class references and long reasoning remain in the small crosswalk rather than being repeated for every unit.

Generated files are under `output/checks/census_isic4/`:

| File | Contents |
|---|---|
| `census_isic4_review.xlsx` | Coverage, exceptions, all activities, and exporter coverage; generated review copy |
| `census_activity_review.csv` | All 273 pairs with decisions, evidence and economic totals |
| `census_unresolved_review.csv` | Exceptions ordered by headquarters employment, then all-unit counts, then branch/activity text |
| `census_mapping_coverage.csv` | Assigned/unresolved counts, totals, denominators and percentages |
| `census_exporter_coverage.csv` | Classification coverage within exporter, non-exporter and unknown export-status groups observed in the source |
| `census_measure_quality.csv` | Missing, nonnumeric, negative, fractional-employment and valid counts by headquarters and assignment status |
| `census_division_totals.csv` | Division totals including an explicit unassigned group |
| `census_merge_reconciliation.csv` | Before/after counts and economic totals, with checked differences |
| `census_raw_fields.csv` | Inventory of the 29 original imported fields |

`units` counts every establishment. `headquarters` uses `S1Q13 == "Siège"` after boundary trimming. `hq_employment`, `hq_turnover` and `hq_exports` sum only valid headquarters values. Non-headquarters values are preserved and audited but are excluded from economic totals to avoid counting enterprise measures twice.

Empty text, `ND`, `Ne sait pas` and `N.D.` are recognized missing values. Numeric parsing follows the existing census convention of removing commas and spaces as thousands separators; negative values are invalid. Fractional employment is also invalid. Raw text is preserved. Missing/invalid amounts contribute nothing to a sum but retain their units in the corresponding counts. Economic coverage percentages use the total **valid observed** amount, including unresolved activities. Unknown amounts cannot enter an amount denominator and are reported separately through valid/missing/invalid counts. A zero total gives an undefined percentage, not zero coverage.

Exporter status means positive, valid export turnover in the supplied file. Zero is labelled `non_exporter`; missing/invalid export turnover is `unknown`. This is a classification of the delivered field, not an independent audit of customs matching or confirmation that every supplied zero represents a true non-exporter. Economic reporting uses headquarters; the file also shows all-unit counts by this reported status. Turnover remains in the raw workbook's monetary units; no deflation or unit conversion is applied.

`hq_positive_emp_sales` counts headquarters with positive valid employment and turnover. It is an estimation-relevant availability count, not a regression sample: no formality, NACAM overlap, outlier, exporter or other model restriction is imposed.

## Completing the human review

Roldan reviews `Needs review` after the complete first pass. Keep a row unresolved when evidence is still insufficient. For a resolved row, record the new evidence, set both division fields to the selected two-digit code, use its exact official English label, change status to `assigned_reviewed`, narrow the possible divisions and supporting classes to the evidence retained for that decision, and record reviewer/date. Preserve the original alternatives in the reasoning or Git history. Rerun the entrypoint. An unresolved row must never acquire a final division by selecting the first listed possibility.

The Stata scripts do not write the decision CSV. Generated inventories and review copies cannot erase reviewed decisions.

## Reviewed decisions, 2026-09-28

Roldan resolved six of the first-pass exceptions: beverage outlets to 56, wooden joinery and miscellaneous wood products to 16, medical imaging/precision/optical/clock-making equipment to 26, heritage institutions/sites to 91, industrial-property licensing to 77, and other extraction to 08. These rows are `assigned_reviewed`; 264 other rows remain `assigned_first_pass`. The classification records the accepted interpretation and the previous alternatives, without claiming independent verification of every firm's activity.

For wooden products, Roldan supplied the full wording "Fabrication d'ouvrages de charpente, de menuiseries et d'articles divers en bois". This is recorded as user-supplied evidence, not as text independently recovered from the workbook. The original truncated key is unchanged. UN classes 1622 and 1629 support division 16 (French manual PDF pages 130-131); no final four-digit code is assigned.

Follow-up inspection linked the 85 units in the three remaining categories to `Feuil2` using `S0Q01`. Business names remain private and are not included in version-controlled documentation. These clues do not resolve the categories:

- Charcoal: all 13 units linked; nine are informal and nine are TPE. Names include charcoal/firewood and wood-waste recovery references. The INS RGE2009 forestry definition includes charcoal, reinforcing the proposed 02, but none of these fields identifies the production method or rules out wood distillation (20).
- Property development: all 64 units linked; 46 are formal and 43 are TPE. Names include property companies, construction and property-management/professional-service wording. Neither names nor legal form distinguishes projects for sale (41), serviced land (42), and own operation (68). NACAM Rev.1 also distinguishes these purposes; it cannot supply a unique Rev.4 code without knowing which activity the unit performs.
- Components: all eight units linked. One formal medium-sized unit accounts for 85 of 102 headquarters jobs and has cable-engineering wording in its name. Other names vary, including welding and retail/service wording. No complete activity label was recovered; firm names cannot justify assigning the entire pair to one division.

Current assignments cover 270 of 273 activity pairs, 438,808 of 438,893 units (99.981%), and 1,177,605 of 1,178,044 valid headquarters jobs (99.963%). Three unresolved pairs retain 85 units and 439 jobs in the denominators. Their final codes remain blank. The first-pass figures below are retained as history. Current coverage is regenerated in `output/checks/census_isic4/census_mapping_coverage.csv` and the review workbook.

## Original first-pass coverage, 2026-09-28

| Measure | Assigned | Unresolved | Total | Assigned share |
|---|---:|---:|---:|---:|
| Branch/activity pairs | 264 | 9 | 273 | 96.70% |
| All units | 418,972 | 19,921 | 438,893 | 95.46% |
| Headquarters | 410,217 | 19,794 | 430,011 | 95.40% |
| Valid headquarters employment | 1,136,695 | 41,349 | 1,178,044 | 96.49% |
| Valid headquarters turnover | 19,734,932,342,207 | 151,174,530,314 | 19,886,106,872,521 | 99.24% |
| Headquarters with reported positive exports | 1,540 | 14 | 1,554 | 99.10% |

Headquarters employment is missing for 139 units and turnover for seven; none of these measures has an invalid value in the supplied workbook. All headquarters have a numeric, nonnegative export value. The 1,710 positive-export units across the complete workbook include 156 non-headquarters, which are excluded from the headquarters exporter count above.

Exceptions, ordered by headquarters employment and units:

| Activity | Units | Headquarters employment | Issue |
|---|---:|---:|---|
| Activités de débits de boissons | 15,348 | 30,980 | Description indicates beverage serving (56), branch says Commerce (possible 47) |
| Fabrication d'ouvrages de charpente, de menuiseries et | 4,450 | 9,803 | Truncated text; no material specified |
| Production de charbon de bois | 13 | 173 | Traditional forestry production (02) versus wood distillation (20) |
| Promotion immobilière | 64 | 164 | Project type and intended sale/operation distinguish 41, 42 and 68 |
| Fabrication de composants, | 8 | 102 | Truncated before component type |
| Fabrication d'équipements d'imagerie médicale, de précision, d'optique et d'horlogerie | 10 | 60 | Broad product wording may span 26 and 32 |
| Conservation et valorisation du patrimoine | 11 | 39 | Operating heritage sites/collections versus restoration work |
| Gestion des droits de propriété industrielle | 8 | 17 | Licensing, patent brokerage or legal administration |
| Autres extractions | 9 | 11 | Mineral/process absent; cannot certify a residual non-metallic division |

These coverage figures describe classification availability, not estimation results. Resolve the exceptions before treating the crosswalk as fully reviewed.

Validation completed in Stata 17: the census-only run and `07_test_census_crosswalk.do` both produced their success markers. All 18 before/after reconciliation differences are exactly zero. Nine deliberately invalid decision files were rejected, including duplicate keys, invalid codes, cross-division class lists, pending rows with final codes, missing references, wrong labels and proposed codes outside the listed possibilities. Generated logs are in `logs/census_isic4_assessment.log` and `logs/census_isic4_tests.log`.

## Census-only firm review, 2026-09-29

Roldan requested a second classification step for units that the activity crosswalk leaves unresolved. This is a review of each census unit, keyed by the full string `firmid_census` (trimmed `S0Q01`). All 85 reviewed units happen to be headquarters. No inference is propagated to other units of a business or to every member of an activity category.

The inventory includes the original branch/activity, both business names, location, establishment year, legal form, formality, reported size, headquarters status, employment, turnover and exports. Firm information comes only from BASE and Feuil2. Official ISIC definitions interpret the census wording; no outside firm information or tax linkage is used. Employment and turnover order the review and quantify coverage; they do not determine the sector. Size, location and legal form provide context but are insufficient assignment rules.

Every row has an individual explanation. Two property records with explicit real-estate appraisal/expertise and management wording are assigned to 68 using the inclusions in class 6820 (UN French PDF p.261). These are `assigned_census_evidence` first-pass interpretations, not verified principal activities or human-approved decisions. Their conflict with the broad Construction branch is recorded. Other property-company names do not establish whether the firm constructs for sale, improves land or operates property. Names indicating other sectors are retained as conflicts, not automatically used to replace the recorded activity.

All charcoal and components records remain unknown: the available characteristics do not resolve charcoal production methods or component types. Unknown records have blank `firm_division`; a nonblank `firm_proposed_division` is a suggestion only and never enters the final classification. The private CSV can be revised after review, then imported again without changing the category crosswalk.

| File | Purpose |
|---|---|
| `output/checks/census_isic4/census_firm_review_inventory.csv` | Generated private review fields; all category-unresolved units |
| `Data/Cameroon/Reference/cmr_census_firm_isic4_decisions.csv` | Editable private decisions, census ID, exact activity/name evidence, proposal, final division, status, reason, conflict flag, reference, reviewer/date |
| `output/checks/census_isic4/census_firm_review_results.csv` | Generated private copy combining firm decisions, names and economic measures |
| `Data/Analysis/cmr_census_isic4_firm_assessment.dta` | Every census record with category decisions plus applied firm decisions |
| `output/checks/census_isic4/census_firm_mapping_coverage.csv` | Final unit/economic coverage by activity crosswalk, firm review and unknown/unclassified |
| `output/checks/census_isic4/census_firm_division_totals.csv` | Final division totals, retaining the unclassified group |
| `output/checks/census_isic4/census_firm_merge_reconciliation.csv` | Before/after counts, valid/missing/invalid measure counts and totals |

Treat IDs as **text** when opening CSVs in Excel; automatic numeric conversion would lose digits. CSVs and DTA files under Data and CSV outputs are ignored by Git. The private decision CSV is a required research input: preserve it in the same secure data backup as the census, rather than expecting Git to restore it.

The combined assessment preserves `category_final_division`, `category_review_status` and `category_assigned`. `mapping_source` is `activity_crosswalk`, `firm_review` or `unknown_unclassified`; `final_division` and `assigned` describe the combined result. Unknown/unclassified is a status, never an invented ISIC code. `firm_branch_conflict` records branch or activity wording conflicts encountered during the firm review. `firm_proposed_division` never fills a blank final division automatically.

The original category workbook and `census_mapping_coverage.csv` continue to report category-only coverage. Use the separate firm-stage outputs for combined coverage; splitting a category across individual decisions does not turn the whole category into a resolved crosswalk row. The cleaned census now carries separate ISIC fields as described below; regressions and slides continue to use their existing classification.

The first firm review assigned two units and four headquarters jobs, leaving 83 units and 435 jobs unknown/unclassified. Combined assignments cover 438,810 units and 1,177,609 headquarters jobs. The category crosswalk remains at 270 assigned pairs and three unresolved pairs. Stata's firm-only entrypoint and tests completed successfully on 2026-09-29: all 18 reconciliation differences are zero, every original assessment variable except the four intended classification updates compares exactly, and ten deliberately invalid decision files were rejected.

## Reviewed property-development assumption, 2026-09-29

Roldan subsequently selected 42 for the 62 remaining property-development units. These decisions are saved in the private firm CSV as `assigned_reviewed_assumption`, with class 4290 as the definition reference and an explicit note that civil-engineering/serviced-land development is assumed rather than observed. The two earlier firm-specific 68 assignments remain. Using the firm CSV preserves this distinction; the activity crosswalk remains unresolved for the heterogeneous property category.

Both `assigned_census_evidence` and `assigned_reviewed_assumption` receive their recorded final division in the combined assessment. `unknown_unclassified` still requires a blank division. Prior census-only explanations are preserved in each updated reason. The human assumption must not be presented as independently established firm activity.

The census branch `Autres industries manufacturières` contains 59 activity labels spanning many ISIC divisions, including paper (17), machinery (28), furniture (31), and other manufacturing (32). Its wording therefore does not identify division 32 for the truncated `Fabrication de composants,` label. All eight components units remain unknown. The proposed charcoal assignment to 02 was discussed but has not been recorded as an accepted final decision in this update.

## Reviewed components and cleaning integration, 2026-09-29

Roldan subsequently accepted two plausible firm-specific assignments within the truncated components category: cable manufacture to 27 and a welding workshop to 25. The private CSV records these as `assigned_reviewed_assumption`. Division 27 assumes ordinary cable manufacture (class references 2731/2732, UN French PDF p.166), rather than installation, trading or application-specific assemblies. Division 25 assumes workshop metalworking (2592, PDF p.154), rather than repairs or construction-site welding. Names are census evidence; neither production detail is independently established. Six components records remain unknown.

These decisions cover 86 headquarters jobs (85 cable manufacture and one welding). The category crosswalk is unchanged; assignments are keyed to the two census IDs and cannot spread to other firms with the same truncated label. The prior 62 property assumptions in 42 and two individual property-service assignments in 68 remain.

`code/elasticity_cameroun/08_cmr_census_cleaning.do` now runs the census classification entrypoint before importing and cleaning the raw workbook. This consumes the current activity and firm CSVs every time, rather than attaching an older saved classification. It then merges the combined results by string census ID, verifies the original branch/activity, and adds five fields to `Data/Analysis/CMR_census_cleaned.dta`:

- `isic4_division` and `isic4_division_label`: final two-digit code and official English label.
- `isic4_mapping_source`: activity crosswalk, firm review, or unknown/unclassified.
- `isic4_review_status`: retains the distinction between first-pass evidence and reviewed assumptions.
- `isic4_assigned`: whether a final code is present.

Run `do "code/elasticity_cameroun/08_cmr_census_cleaning.do"` from the project root to regenerate the cleaned census with current decisions. The existing project master already calls this script. Running the classification entrypoint alone refreshes assessment outputs, but does not resave the production cleaned file. After a cleaning run, `12_test_census_cleaning_isic4.do` checks every merged code, label, source and status against the combined assessment.

Existing NACAM fields, headquarters restrictions and outcome cleaning are retained. The slide migration changes diagnostic and regression groupings to ISIC divisions and removes the obsolete NACAM-overlap restriction; it preserves estimators and support thresholds. Do not edit codes in a generated dataset: update the reviewed CSV and rerun cleaning. The full cleaned dataset and private CSV remain excluded from Git.

Validation completed on 2026-09-29: category and firm checks passed, the cleaned-file test matched all five ISIC fields to the combined assessment, and all records were retained. A same-input control run of the pre-change cleaning code matched every legacy variable exactly. The older saved cleaned file used the previous workbook and differed in provenance, display labels and some pre-existing diagnostic flags; those historical differences must not be attributed to the ISIC merge. The regenerated combined result has 19 unclassified units and 189 headquarters jobs (13 charcoal units and six components units).
