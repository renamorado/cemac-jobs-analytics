# Tax NACAM Rev.1 classification and ISIC correspondence

**Established project classification, 29 September 2026: the raw tax data use
NACAM Rev.1 branch numbering.** INS ECOFIN 2019 explicitly identifies its DSF
branches as compatible with NACAM Rev.1 (p.79). All 37 published branch counts
match our source rows in both 2016 and 2017. The top-ten employment rankings
also match in 2018 and 2019, with shares within 0.34 percentage points. See
[the report comparison](../cmr_tax_ecofin2019_comparison.md) for evidence and
limits. Differences in samples do not justify reverting to the older numbering.

Reviewed 2026-09-29. The editable decisions are in
`cmr_tax_nacam_rev1_isic4_decisions.csv`: 37 observed codes, with 13 single-division,
15 combined-division, and nine partial correspondences. These decisions replace
the superseded legacy interpretation. These ISIC mapping decisions do not
independently certify each firm's principal activity or resolve partial boundaries.

## Evidence and scope

The original workbook dictionary defines CODEBRANCHE as CODE NACAM without a
revision. The published ECOFIN methodology and data comparisons establish the
Rev.1 interpretation for this project. The report covers 2015–2019. Company names
in SIGLE.x3 support continuity in 2021–2022 across several changed branches,
including beverages, wood, paper, water, construction and trade; code-history
checks also support using the same revision across 2015–2022. They do not verify
every firm's actual activity. Code 030 means water/sanitation/waste, 031 means
construction, and 032 means trade/vehicle repair.

Generated datasets still contain `revision_assumed = 1` and earlier provisional
wording. Those fields describe the initial assessment stage and have not been
changed by this documentation update. They should be read with this later
evidence; the source revision is no longer an open choice between legacy and Rev.1.

The qualitative name review inspected up to four frequent raw strings per
populated branch, covering all 37 branches. It was a category-level plausibility
check, not an exhaustive adjudication of firms. `sigle_review` records whether
that sample supports changed numbering or is mixed/not decisive. Names and firm
identifiers are not included in this reference CSV. No external firm lookups or
name-based firm-year assignments are used.

The raw inspection found 1,931 populated SIGLE cells, including 14 native Excel
errors, and 1,917 non-error entries covering 979 firms. Stata `import excel`
imports native error cells as missing. Consequently, generated name diagnostics
count **imported text**, not all populated Excel cells; `sigle_literal_error`
detects only any error strings that survive import. It must not be interpreted
as a count of native Excel error cells. Names are trimmed before counting distinct
strings. The diagnostics also flag statement-heading fragments, strings without
spaces and the Unicode replacement character; those flags are not a complete
encoding-quality test. Counts of distinct strings are not counts of firms.

## Official references

- INS, [NACAM/NPC Rev.1](https://ins-cameroun.cm/wp-content/uploads/2025/06/NOMENCLATURE_DES-ACTIVITES-AU-CAMEROUN.pdf),
  Table III.1 printed p8, Table III.2 pp9-15, explanatory notes pp41-101.
  Use the **NACAM rev1** column, not NACAM Ancien. Saved in
  `docs/reference/nacam-rev1-ins-cameroon.pdf`; searchable text is under
  `docs/reference/tax_isic4/nacam-rev1-ins-cameroon.txt`. PDF page = printed page + 1.
- UN, [ISIC Rev.4](https://unstats.un.org/unsd/publication/seriesm/seriesm_4rev4e.pdf),
  official division/class definitions and exclusions. Saved under
  `docs/reference/tax_isic4/isic_rev4_un.pdf`. PDF page = printed page + 15.
  Strict English labels come from `isic_rev4_english_structure.csv`.
- Source PDF checksums and acquisition details are retained in
  `cmr_tax_isic4_sources.md`; its legacy application is superseded, not its sources.

Each decision row cites printed INS table/notes pages. Material conflicts also
identify the UN classes and relevant pages. French branch labels are shortened
and accents normalized for readability; they are not a new raw-data field.

## Interpretation rules

- **Single:** the documented branch activities fit within one ISIC division.
  The branch may cover only part of that division; several tax branches map to01
  or10. Only these rows populate `isic4_division` and its official English label.
- **Combined:** the explicit branch aggregate supports classification into the
  listed divisions. `isic4_group` stores the plus-separated code and
  `tax_sector_label` the short label. This is an aggregate destination, not proof
  of exhaustive reverse correspondence or equal source populations. For example,
  branch031 fits41-43, but INS assigns some property development to037.
- **Partial:** explicit conflicting inclusions or narrow transfers prevent treating
  the branch as the named standard aggregate. `isic4_reference` lists links;
  both the strict division and combined-group fields stay blank. The original
  branch and short tax label remain usable for tax-only analysis.
- **Unresolved:** retain the record and document insufficient evidence. No current
  category uses this status; the workflow supports it, including missing source codes.

Do not equate short display labels with official full division titles. Do not
aggregate firms from other datasets using a partial reference list. No claim of
exact cross-source harmonization follows from this assessment.

## Main changes and remaining boundaries

The revision corrects several old-code shifts and moves publishing to035,
recycling to030, machinery repair to028 and veterinary activity to038. Whole
rubber/plastic footwear remains in15; slaughterhouse raw hides remain in10;
by-products alone do not create extra industries.

Nine partial cases remain: **5, 6, 9, 13, 19, 21, 24, 29 and 37**. Reasons include
explicit table-versus-note discrepancies for extraction, beverages, nuclear
products and machinery; agricultural preparation in coffee and rubber; biofuel
production; and development for sale within real estate. These are possible
classification boundaries, not evidence that all such activities occur in the tax
sample. Notably, branch005 explicitly excludes off-site gas liquefaction, so52
is not retained from the earlier speculative extraction list.
