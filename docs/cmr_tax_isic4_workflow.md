# Reviewed tax/BDF classification in ISIC Rev. 4

## NACAM Rev.1 tax classification (29 September 2026)

The raw tax codes use **NACAM Rev.1**. The official ECOFIN methodology and our
branch-count and employment comparisons establish this as the project decision
for 2015–2022; see [evidence and period coverage](cmr_tax_ecofin2019_comparison.md).
Uncertainty about partial ISIC correspondences remains separate from the source
revision. Earlier legacy-based tax labels and coverage are superseded.

Use the separate corrected assessment rather than the legacy assignments below:

```stata
do "code/elasticity_cameroun/98_run_cmr_tax_isic4.do" rev1_assessment
```

It applies the NACAM Rev.1 interpretation to 2015-2022 and
saves `Data/Analysis/CMR_BDF_isic4_rev1_assessment.dta`. This assessment command
does not regenerate regressions or slides. The production master now explicitly
runs the reviewed Rev.1 and section steps before tax preparation and estimation;
see the [slide workflow](isic4_slides_workflow.md). Older default legacy commands
below are retained for historical checking.

The reviewed input is `docs/reference/cmr_tax_nacam_rev1_isic4_decisions.csv`;
sources, name-review scope and interpretation rules are documented in
`docs/reference/cmr_tax_nacam_rev1_isic4_sources.md`. Shared scripts19-21 use
separate `_rev1` outputs. Script22 checks the original workbook's code linkage,
name availability, historical transitions and conflicts, and exports the
37-category legacy/Rev.1 comparison.

The dataset retains original variables and NACAM keys. New fields include
`source_revision`, `revision_assumed`, `revision_basis`, `tax_sector_id`,
`tax_sector_label`, `correspondence_status`, `isic4_reference` and `isic4_group`.
Only `single` correspondences populate the strict two-digit `isic4_division`.
Combined groups use a separate plus-separated code. Partial lists are reference
links only; they are not assigned group codes or firm-level industries.
Existing generated files still flag every matched record as having an assumed
revision. That flag and any provisional wording record the earlier assessment
stage; they predate the published ECOFIN verification. The subsequent slide
migration retains this audit trail and explicitly selects the reviewed routing.

### Results and diagnostics

| Correspondence | Categories | Cleaned firm-year records |
|---|---:|---:|
| Single division | 13 | 1,485 |
| Combined divisions | 15 | 6,694 |
| Partial | 9 | 889 |
| Wholly unresolved | 0 | 0 |

All 9,068 cleaned records and 1,637 firms are retained. Single plus combined
correspondences cover 90.20% of records, 87.79% of nonnegative firm-year employment
and 79.31% of nonnegative revenue. Strict single-division coverage is 16.38% of
records. These are descriptive classification measures, not estimates of mapping
accuracy or exhaustive equivalence with another dataset's sector populations.

`output/checks/tax_isic4_rev1/` contains the reviewed categories, comparison,
merge/key/numeric audits, coverage overall and by year/status/category, within-firm
changes, and revision diagnostics overall/by year/by category/by year-category.
`revision_transitions.csv` reports code transitions for unambiguous firm-years,
including nonconsecutive pairs; conflicted firm-years are counted separately.
The private intermediate audit contains identifiers and flags but no names.

Coverage includes distinct categories/firms and employment/revenue for each
status, with valid nonmissing nonnegative denominators and excluded values
reported separately. `covered_*` means single or combined; `mapped_*` means strict
single division. `strict_unassigned_records` includes combined, partial and
unresolved; `pending_*` refers only to wholly unresolved cases. Firms with at least
one covered record count as covered and can appear in several status groups.
The coverage CSV's status column is the correspondence status in this mode.

`preliminary_*` columns are retained for compatibility but, in this mode, refer
to the **superseded reviewed legacy crosswalk**, also identified in
`comparison_basis`. On cleaned data, 622 records gain a strict assignment,713
lose one and 239 change division among records assigned by both versions. These
changes are not measured against verified truth.

Both `cmr_tax_isic4_coverage_rev1.tex` and `cmr_tax_isic4_groups_rev1.tex` are
generated using esttab under `output/tables/`. Successful execution ends with
`TAX REV1 ASSESSMENT COMPLETED SUCCESSFULLY` in `logs/cmr_tax_isic4_rev1.log`.

Validation commands:

```stata
do "code/05_checks/03_cmr_tax_rev1_tests.do"
do "code/05_checks/04_cmr_tax_rev1_repeatability.do"
```

Fixtures reject duplicate/missing categories, invalid divisions, missing evidence,
combined codes in strict fields and partial links presented as groups. They check
zero, negative and missing value handling, missing source codes and original-row
preservation. Repeatability compares all generated datasets, diagnostic CSVs and
tables across two runs and checks that the workbook, input panels, legacy outputs,
legacy decisions and master remain unchanged. Existing legacy-mode fixtures also
pass. No firm assignment is inferred from names or carried between years.

## Superseded legacy assessment

> **Historical workflow only; superseded on 2026-09-29.** The following sections
> describe the older legacy-based implementation, not the correct tax code
> interpretation. Do not use its assignments, coverage, or default entrypoint for
> new tax analysis. Use the Rev.1 or section assessment modes above/below.

The superseded crosswalk remains reproducible for the audit trail. Its output
`Data/Analysis/CMR_BDF_isic4.dta` must not be used for new tax ISIC analysis.
Use `CMR_BDF_isic4_rev1_assessment.dta` or the section assessment dataset instead,
and explicitly define the estimation sample.

## Historical legacy workflow: reproduce the superseded panel

From the project root, run:

```stata
do "code/elasticity_cameroun/98_run_cmr_tax_isic4.do"
```

The default, `current_clean`, requires the existing `CMR_BDF_cleaned.dta` and
preliminary NACAM crosswalk. It preserves those files. To regenerate the cleaned
prerequisite with the unchanged cleaning rules, run:

```stata
do "code/elasticity_cameroun/98_run_cmr_tax_isic4.do" rebuild_clean
```

That mode runs only the existing NACAM bridge, display-group mapping, BDF cleaning,
and the new tax classification steps. Neither mode requires census or WBES data.
The project master also runs the new steps immediately after BDF cleaning.
Rebuilding can refresh display labels in an older saved panel to the wording in
the current cleaning code. The September 2026 check found only those label
differences relative to the prior snapshot; firm-year keys and economic values
were identical. The classified output is sorted by firm and year, and coverage
sums use a fixed record order for repeatability.

The numbered scripts build the reviewed crosswalk (19), merge it (20), and
calculate coverage (21). The named run log is `logs/cmr_tax_isic4.log`; successful
completion ends with `TAX ISIC4 WORKFLOW COMPLETED SUCCESSFULLY`. An interrupted
run can leave partial outputs: do not treat their existence as completion.

## Historical legacy decisions and merge rules

- `docs/reference/cmr_tax_isic4_decisions.csv` is the editable, version-controlled
  record of decisions. Each observed NACAM category has one row with the original
  definition label, reviewed code and English label, status, possible divisions,
  source references, reason, and review date. Source documentation is in
  `docs/reference/cmr_tax_isic4_sources.md`.
- Stata validates those decisions and writes
  `Data/Intermediate/cmr_tax_isic4_crosswalk.dta`, unique on numeric `nacam`.
  `isic4_division` is a two-character string; unresolved codes are blank.
  Category statuses are `unique`, `ambiguous`, or `insufficient_information`.
- The cleaned panel receives an `m:1 nacam` merge. Every original row and variable
  value is checked against the input before saving the separate classified file.
  Missing and unmatched source codes receive explicit statuses. Unresolved rows
  remain in the dataset.
- `isic4_category_status` retains the category decision;
  `isic4_assignment_source` distinguishes `category_crosswalk`,
  `firm_year_activity`, and `unresolved`. Future estimation must use these reviewed
  fields, not the preliminary `isic_rev4_division` in the older crosswalk.

The workbook and ECOFIN inputs contain no finer activity classification. The
inventory and verified identifier links are documented in
`docs/cmr_tax_isic4_input_inventory.md`. Consequently, this implementation makes
no firm-year refinements from the currently available files.

## Historical legacy workflow: optional activity evidence

The header-only `docs/reference/cmr_tax_isic4_firm_year_template.csv` documents
the intake columns. Put any populated intake at
`Data/Cameroon/Classification/cmr_tax_isic4_firm_year.csv`, which is ignored by
Git. Do not put firm identifiers or confidential activity evidence in the public
reference CSV. If the intake file is absent, the workflow explicitly records
that fact and creates an empty validated firm-year assignment dataset.

An intake row requires a unique `firmid fin_yr`, matching source NACAM, a valid
division, dated classification evidence, and an explanation of the verified
identifier/year link. It can resolve only an ambiguous category, and only to a
division listed among that category's possibilities. Mismatches, missing evidence,
duplicate keys, and attempts to override a unique category stop the build. Review
and resolve conflicting evidence before intake; no conflicting assignment is
silently chosen. No firm-name inference, proportional allocation, or assignment
carried across years is supported.

Validated private assignments are saved in
`Data/Intermediate/cmr_tax_isic4_firm_year.dta`. The merge retains both category
evidence and the separate `detail_*` evidence fields. Assignments for records
excluded by existing cleaning appear as unused entries in the merge audit.

## Historical legacy diagnostics and interpretation

Diagnostics are generated under `output/checks/tax_isic4/`:

| File | Contents |
| --- | --- |
| `reviewed_categories.csv` | Validated category decisions |
| `detail_intake_summary.csv` | Intake-file availability and number of verified assignments |
| `merge_audit.csv` | Matched, input-only, and crosswalk-only records for each merge and input |
| `coverage_summary.csv` | Source/cleaned coverage overall and by year, category, and status; gains, losses, and changed assignments versus the preliminary bridge |
| `key_audit.csv` | Missing identifiers/codes and duplicate groups/records |
| `numeric_value_audit.csv` | Valid, zero, negative, missing, unparseable, and trailing-minus-adjusted employment/revenue values |
| `within_firm_changes.csv` | Aggregate changes between successive observed firm-years, with adjacent-year pair counts |

The LaTeX summary is generated by `esttab` at
`output/tables/cmr_tax_isic4_coverage.tex`. The source audit dataset remains private
at `Data/Intermediate/cmr_tax_isic4_source_audit.dta`. Diagnostic CSVs contain no
firm identifiers.

Coverage is unweighted. A firm or category is covered if at least one of its
records is assigned in that reporting group, so counts across groups can overlap.
Record gains/losses reconcile exactly; firm gains and losses need not be disjoint.
Employment and revenue shares use nonmissing, nonnegative values. Missing,
unparseable, and negative values are reported separately; zero denominators give
missing shares. Source parsing follows existing BDF cleaning conventions,
including removal of a trailing minus, which is counted explicitly.

Employment summed across years is a firm-year employment total, not distinct
workers. Revenue remains in the input variable's units. Source coverage includes
duplicate rows and is reported separately from the cleaned panel. Category
changes are observed changes, not proof of a firm's actual change of activity.

## Historical legacy validation

Run `code/05_checks/01_cmr_tax_isic4_tests.do` for isolated synthetic tests of the
actual builder and merge. The tests write under `scratch/tax_isic4_tests/` and
exercise missing codes, ambiguous/insufficient decisions, valid detailed
assignments, and rejection of duplicate keys, invalid divisions, missing evidence,
missing category decisions, wrong years/branches, and contradictory refinements.
Expected rejected cases are labelled in the test log. The final success marker
is `TAX ISIC4 FIXTURE TESTS COMPLETED SUCCESSFULLY`.

Run `code/05_checks/02_cmr_tax_isic4_repeatability.do` to execute the tax-only
workflow twice on real inputs. It compares generated data values in their saved
order, diagnostic/table checksums and sizes, and input-file checksums. Its success
marker is `TAX ISIC4 REPEATABILITY CHECKS COMPLETED SUCCESSFULLY`. Snapshots remain
under the ignored scratch directory. These checks do not run employment models.

## Section-level tax preview

Use `isic4_section` as the grouping variable in
`Data/Analysis/CMR_BDF_isic4_sections_assessment.dta`, with display labels in
`isic4_section_label`. It contains the 16 agreed adapted ISIC Rev.4 groups,
including combinations. Strict official correspondence is preserved
separately in `isic4_section_strict`; the six analytical assignments do not
populate that strict field. Section summaries and figure script24 use
`isic4_section`. Older `tax_section_group` and `tax_section_label` are retained
only as exact compatibility aliases.

Run `do "code/elasticity_cameroun/98_run_cmr_tax_isic4.do" section_assessment` for the tax section crosswalk and descriptive preview. See [section grouping and exceptions](cmr_tax_isic4_sections.md). This keeps all 9,068 cleaned firm-years and produces 16 tax groups. Six branches use explicitly approved analytical groupings while strict section/division fields remain missing; 005 joins 006 in B with its B/C/H boundary qualification. It does not re-estimate elasticities or alter census/WBES.
