# Tax classification at ISIC Rev.4 section level

## Purpose and interpretation

This assessment groups the 37 observed tax NACAM branches into 16 tax analysis
groups: 14 section-labelled groups and two section combinations. Six branches enter section-labelled groups through
Roldan's explicit analytical choices of 29 September 2026, not strict official
correspondences. The assessment produces a descriptive preview. The
[slide workflow](isic4_slides_workflow.md) now uses these same groups in the
existing firm-year tax regressions and the linked Census/WBES comparisons.

The source classification is **NACAM Rev.1 for 2015–2022**. The official ECOFIN
report, matching branch counts and employment rankings establish the project
decision; see [the evidence and its scope](cmr_tax_ecofin2019_comparison.md).
The source dictionary names NACAM without its revision. The report covers
2015–2019; later-year continuity is supported by code and name checks. ISIC
boundary exceptions remain even though the source numbering is now established.
The earlier `revision_assumed` field remains in the underlying division panel
for its audit trail. Regenerated section figures now state NACAM Rev.1 and mark
the analytical groupings explicitly.

The editable crosswalk is
`docs/reference/cmr_tax_nacam_rev1_isic4_sections.csv`, one row per numeric NACAM
code, with a zero-padded three-digit display code. It carries the reviewed
division references, official section label where unique, short tax label,
status, source pages, reasoning and review date. The script checks every section
reference against the official UN hierarchy and the existing reviewed division
decisions; it does not infer activities from company names.

## Assignment rules

**Use `isic4_section` for the tax analysis.** It contains all 16 agreed categories,
with labels in `isic4_section_label`, in
`Data/Analysis/CMR_BDF_isic4_sections_assessment.dta`. This field includes the
agreed combined codes M+N and R+S+T and the six analytical choices;
it is an adapted ISIC Rev.4 analysis classification, not exclusively official
single-letter sections. `isic4_section_strict` and `isic4_section_strict_label`
preserve the narrower official correspondence. `section_status` and `section_refs`
record the qualifications. The old `tax_section_group` / `tax_section_label`
remain exact compatibility aliases in the panel; current summaries and figures
read `isic4_section` / `isic4_section_label`.

| Status | Branches | Treatment |
|---|---:|---|
| Single section | 29 | Both analysis `isic4_section` and `isic4_section_strict` contain the section letter. |
| Combined sections | 2 | NACAM 038 becomes M+N; 042 becomes R+S+T. Strict section stays blank. |
| Analytical assignment | 6 | Use the agreed section-labelled analysis group; strict section stays blank and original references remain. |

NACAM 013, 019 and 024 were partial at the division level but all their reviewed
references fall within C, Manufacturing. They can therefore receive C while
their strict two-digit assignments remain missing.

The six cross-section branches are treated as follows:

| NACAM | Branch | Analysis group | Official boundaries retained |
|---|---|---|---|
| 005 | Energy extraction and support | B, Mining and quarrying | B, C, H |
| 006 | Mineral extraction and support | B, Mining and quarrying | B, C |
| 009 | Cocoa, coffee, tea and sugar | A, Agriculture | A, C |
| 021 | Rubber and plastic products | C, Manufacturing | A, C |
| 029 | Electricity, gas and air conditioning | D, Electricity and gas | C, D |
| 037 | Real estate | L, Real estate | F, L |

These six assignments are recorded as `section_status = analytical_assignment`
and in `section_note`, including Roldan's approval date. `isic4_section` drives
analysis; `isic4_section_strict` and the strict division field remain missing for these
branches. No firm-level activity is inferred. Branch 009 includes processing
normally associated with manufacturing: assigning it to Agriculture is the user's
agreed broad grouping, not a finding that its firms grow crops. Figure footnotes
explicitly mention this inclusion. Branches 009 and 021 are pooled with the
existing A and C groups, not plotted as duplicate rows.

On 29 September 2026, Roldan approved moving 005 from the separate X005 group
to B after reviewing available activity evidence. Of its 21 firms (104 cleaned
firm-years), four have names observed under 005 and two can be linked to names
under later, different codes. Public descriptions support extraction and related
services for several identifiable firms, with one fuel-retail exception and one
unverified activity. The 15 unnamed firms account for 93.07% of valid branch
revenue, so this evidence does not establish the economic majority. The decision
is a documented analytical grouping; B/C/H references and missing strict fields
are preserved. No firm is individually reclassified from its name.

These lists describe definition boundaries, not verified firm activities. An
exception is not a full union of its referenced sections. M+N and R+S+T also
describe the sections represented by their branches, not complete reverse
coverage: branch 042 covers divisions 90–97, with T limited to household
employers in 97; division 98 is not evidenced.

Every firm-year belongs to exactly one tax group. Overlap in activity definitions
does not duplicate records. Section-labelled groups include the approved whole
branches above, including 005 and 006 together in B. These analytical choices do
not establish exact comparability with full ISIC sections in other datasets.

## Reproduce

From the repository root in Stata:

```stata
do "code/elasticity_cameroun/98_run_cmr_tax_isic4.do" section_assessment
```

This rebuilds the Rev.1 division assessment, then runs
`23_cmr_tax_isic4_sections.do`. If that prerequisite is already current, the latter
script can run independently. It validates the section CSV, checks the merge,
compares every original panel value, and verifies unique firm-year keys.

Outputs:

- `Data/Intermediate/cmr_tax_isic4_sections_crosswalk.dta`: mergeable crosswalk.
- `Data/Analysis/CMR_BDF_isic4_sections_assessment.dta`: all cleaned firm-years,
  original variables and division fields, plus section and tax-group fields.
- `output/checks/tax_isic4_sections/crosswalk_with_shares.csv`: all 37 decisions,
  evidence and observed employment/revenue shares.
- `boundary_exceptions.csv` in the same folder: no remaining separately retained branches (header only).
- `analytical_assignments.csv` in the same folder: the six approved groupings,
  original reference sections, decision notes and shares.
- `shares.csv`: pooled and annual summaries by group and status, plus pooled
  branch summaries. Distinct firms can occur in several groups or years; their
  group counts must not be added to obtain the unique panel firm count.
- `merge_audit.csv`: input-only, crosswalk-only and matched observation counts.
- `output/tables/cmr_tax_isic4_sections_preview.tex`: `esttab` LaTeX fragment.
- `output/figures/cmr_tax_isic4_sections_preview.png` and `.pdf`: descriptive
  employment/revenue share preview with explicit exception notes.

Shares are unweighted and use nonmissing, nonnegative employment and revenue
separately. All records remain in observation counts. Diagnostics report missing
and negative counts and excluded negative sums. Employment pooled over years is
a **firm-year employment total**, not a count of distinct workers. Revenue uses
the existing `tot_rev` units. Annual shares use that year's denominator.

Verification:

```stata
do "code/05_checks/05_cmr_tax_sections_checks.do"
```

Checks run the integrated entrypoint, repeat the section step, compare generated
datasets and CSV/LaTeX checksums, verify expected boundary examples and aggregate
denominators, and check that the cleaned input, legacy panel, master and existing
tax elasticity code are unchanged. The section script itself compares every
original value against the input Rev.1 panel.

## Current descriptive result

On the current 9,068 cleaned firm-years:

| Classification | Firm-years | Employment share (%) | Revenue share (%) |
|---|---:|---:|---:|
| Single section | 6,835 | 75.94 | 84.51 |
| Combined sections | 1,491 | 15.11 | 3.38 |
| Analytical assignments | 742 | 8.95 | 12.11 |

These figures describe assignment status, not complete harmonization across
datasets. The single-section plus combination groups account for 91.05% of valid
employment and 87.89% of valid revenue. Future elasticity work must re-estimate
models within the new tax groups rather than average the existing coefficients.

## Compare with the existing slides

### Broad-sector colors and symbols

The ten broad labels and marker styles are maintained for all ISIC Rev.4 codes
in `docs/reference/isic4_broad_groups.csv`; see [the shared display scheme](isic4_broad_display_groups.md).
Script24 derives tax styles from this shared mapping, checks every component of
combined sections, and exports its `tax_plot_*` fields in `slide_comparison.csv`.
These are visual groups; they do not change the 16 analysis groups or the strict
classification fields. The older `data_export` raw-code mapping is not reused
because it was based on the superseded legacy interpretation.

| Broad label | New tax groups | Color | Symbol |
|---|---|---|---|
| Agriculture | A | Green | Filled circle |
| Mining | B | Purple | Filled diamond |
| Manufacturing | C | Blue | Filled square |
| Utilities | D, E | Gold | Filled triangle |
| Construction | F | Magenta | Hollow circle |
| Trade | G | Orange | Hollow triangle |
| Transport | H | Green | Hollow square |
| Information | J | Green | Plus |
| Finance | K | Purple | Cross |
| Other services | I, L, M+N, P, Q, R+S+T | Gray | Hollow diamond |

Energy extraction (005) is pooled with mineral extraction (006) in B, using
Mining's purple filled diamond and retaining the B/C/H boundary note. Asterisks retain the analytical grouping caveats;
they no longer change the sector color or symbol. The two-panel previews retain
the original layout without a repeated legend; the table above records the key.

### Reproduction

Run `do "code/elasticity_cameroun/24_cmr_tax_section_comparison.do"` after the
section assessment. It produces side-by-side employment and revenue figures
under `output/figures/cmr_tax_sections_vs_slides_*`, each as PNG and PDF, plus
`output/checks/tax_isic4_sections/slide_comparison.csv`.

These use the definitions in `12_cmr_bdf_sector_scale_figures.do`, matching the
Ecofin figures included in `slides/slides_cemac.tex`: average annual sector
totals and equal-year averages of within-year firm means, on natural-log axes.
The 37-branch slide classification is on the left and the new 16-group
classification on the right. Separate `_firm_average` figures show the means.
Axes match within each comparison; row ranks are independent. The original
slide labels are reproduced, including their superseded legacy interpretation,
so the comparison includes both classification correction and aggregation.
No slide files or original figures are overwritten.
