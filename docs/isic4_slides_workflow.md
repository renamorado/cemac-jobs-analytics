# ISIC Rev.4 slide workflow

The existing master, `code/00_master.do`, regenerates the inputs used by
`slides/slides_cemac.tex`. Run it from the repository root. Preparation retains
the original NACAM fields and economic values, and adds reviewed ISIC codes,
labels, assignment notes and shared display fields.

| Dataset/output | Classification | Main scripts |
|---|---|---|
| Census descriptions and elasticities | Two-digit division | `08_cmr_census_cleaning.do`, `18_cmr_census_elasticity_prep.do`, `08_cmr_census_sector_figures.do`, `13_cmr_census_turnover_employment_elasticity.do`, `16_cmr_census_exporter_turnover_elasticity.do` |
| Ecofin descriptions and regressions | 16 agreed `isic4_section` groups | `17_cmr_bdf_elasticity_prep.do`, tax analysis scripts 06, 09–12 and 15 |
| Cameroon WBES regressions | Two-digit division | `WBES_trade/05_wbes_elasticity_prep.do`, 03 and 04 |
| Census–Ecofin comparison | Corresponding section groups | Additional firm-level Census regression in script 13 |
| WBES constraints linked to Ecofin | Corresponding section groups | `BREADY_wbes/03_bready_wbes_sector_constraints.do` |

Cameroon Census and tax scripts are in `code/elasticity_cameroun/`.
The shared lookup is produced by `code/02_construct/01_isic4_broad_groups.do`.
Tax preparation uses `code/02_construct/02_cmr_tax_section_fields.do`.
The existing `code/elasticity_model_specs.do` workbook reads these prepared
datasets and uses the same division/section variables for interactive model checks.

## Preparation and estimation

The master runs the reviewed tax Rev.1 crosswalk and section assignment before
tax preparation. Six analytical assignments remain documented: 005/006 to B,
009 to A, 021 to C, 029 to D, and 037 to L. Strict correspondence fields are
retained separately. M+N and R+S+T are combined groups. Linked Census and WBES
comparisons combine the same sections, with T restricted to division 97.
Their activity coverage remains approximate because the tax assignments are
analytical groupings.

Census cleaning reruns the reviewed activity crosswalk and private firm decisions.
Unknown classifications remain in the prepared data. Census analysis no longer
requires NACAM overlap with tax; `legacy_sample_elasticity` records the former
restriction for comparison. Positive employment/turnover requirements and
minimum support rules remain unchanged. Support counts and suppressed groups
are saved with estimates and preparation diagnostics.

In the September 29 regeneration, the Census sample before division support
checks contains 429,846 firms, compared with 429,567 under the former NACAM
overlap rule. The change adds 292 firms and excludes 13 formerly eligible firms
whose reviewed ISIC classification is unknown. The supported main regression
uses 429,719 firms across 76 divisions. All 438,893 source units remain in the
prepared data, including 19 headquarters with unknown classifications.

Tax regressions retain firm-year observations, firm fixed effects, firm-clustered
standard errors, transformations and support rules. Section membership follows
each reported firm-year, including firms changing group over time. Section
coefficients are estimated from the underlying observations. Census section
coefficients are also estimated directly from firms, independently of its
division coefficients.

WBES country/wave selection, survey weights, controls and national benchmarks
remain unchanged. Cameroon subgroup estimates use divisions. Section controls
are constant within a division and absorbed by its intercept. Unsupported
subgroups remain in support audits. B-READY validates national weighted means
before restricting to sections that overlap with eligible Ecofin estimates;
bubble sizes and decile 7–10 highlighting use regenerated tax estimates.

The current support rules retain 15 of the 16 tax groups; E (water/waste) has
only 28 usable firm-year observations and six firms in each outcome sample.
The Census–Ecofin comparison has 15 matched
groups. Cameroon WBES supports five all-firm trade divisions, three
revenue–exporter interaction divisions, and no exporter-only trade divisions.
The linked constraint figures cover up to eight overlapping sections, depending
on indicator responses. These counts describe this regeneration and may change
if the inputs change.

The original B-READY priority workbook is absent from this local copy. Its
16 reviewed indicator definitions and national benchmarks already exist in the
Stata script and are unchanged. The script validates the workbook priority count
when available and logs its absence otherwise; national indicator validation
still runs on the full Cameroon WBES sample.

The saved May WBES outputs predated the current age, ownership and section
controls. Regeneration updates those country results using the existing source
specifications; the ISIC migration does not change the country estimation code.

## Outputs and checks

Division outputs include `isic4_division` in their names; section outputs include
`isic4_section`. Existing NACAM outputs are retained on disk for comparison but
are no longer loaded by the revised slide deck. Figures and tables are exported
by Stata; do not edit them manually.

Every figure export names its graph explicitly. In a combined run, Stata's
default export can select a previously active graph window even after a new
graph has been drawn. Unnamed graphs use `name(Graph)` at export; named panels
and combined graphs use their own names. Preserve this when adding figures.

Dense Census charts have compact division labels and three `_part1`–`_part3`
exports. Descriptive panels show 28 ranked divisions per page; the main
elasticity chart splits its 76 supported divisions across three pages. The deck
includes every part, and the full-size combined exports remain available for
inspection. Official division labels remain in the prepared datasets.

English display labels follow INSEE NAF Rev.2 short titles, whose 88 divisions
match ISIC Rev.4. They are project adaptations, not official English translations.
The complete review table is `docs/reference/isic4_division_short_labels_insee.csv`.
The Census helper `_cmr_census_isic4_labels.do` carries these labels into prepared
data; WBES scripts 03 and 04 use the same wording for their supported divisions.
Keep those strings consistent with the review table. Codes precede the English
labels. Graph labels use literal ampersands; LaTeX table labels escape them.
Section wording is maintained in `code/02_construct/02_cmr_tax_section_fields.do`,
preserving the tax qualifications and agreed section combinations.

Ecofin slide titles and notes use "ISIC Rev.4 sections" and identify the
NACAM–ISIC Rev.4 crosswalk. Notes name the combined sections as professional
and admin. support, and arts/recreation, other services and household employers
(division 97), rather than listing section letters. Asterisks retain their
classification meaning; the slide appendix records the branches spanning
section boundaries. Cross-dataset notes retain the activity-coverage qualification.

Run affected scripts before the full master. The final master check,
`code/05_checks/07_isic4_slide_checks.do`, verifies identifiers, original-field
preservation, classifications, Census sample flags, section overlap and bubble
inputs. Preparation and figure scripts also check merges and conservation of
employment and revenue totals. Confirm successful process exit, no uncaptured
`r(#);`, the final success marker and refreshed outputs.

Compile `slides/slides_cemac.tex` after regeneration and inspect all pages,
including the appendix. The current exported deck remains
`slides/slides_cemac.pdf`. No second analysis pipeline or alternate deck is needed.

Required private inputs include the Census firm decision CSV and original data.
See [Census classification](cmr_census_isic4_workflow.md),
[tax sections](cmr_tax_isic4_sections.md), and
[display groups](isic4_broad_display_groups.md) for their definitions and provenance.
