# Tax/BDF activity-information inventory

## 2026-09-29 correction: tax codes use NACAM Rev.1

The raw workbook's `CODEBRANCHE` and BDF's `nacam` use NACAM Rev.1 branch
numbering. This is the project's established classification for 2015–2022,
supported by the official ECOFIN methodology, exact branch-count matches in
2016–2017, and matching top-ten employment rankings in 2018–2019. See
[the evidence and its scope](cmr_tax_ecofin2019_comparison.md). The report covers
2015–2019; code-history and company-name checks support continuity in later years.
Run the tax-only entrypoint with `rev1_assessment`; the default legacy route
remains superseded. Existing generated revision flags predate this evidence.

A direct inspection of `SIGLE.x3` found company names/abbreviations, not a formal
activity-description field. There are 1,931 populated cells, including 14 Excel
`#VALUE!` errors; 1,917 nonempty, non-error records cover 979 firm identifiers.
The field is populated only in 2021 (964 cells) and 2022 (967 cells), with no
populated cells in 2015-2020. Names include spacing/encoding differences and
occasional financial-statement header text, so distinct strings are not firm counts.

The name/code patterns strongly support NACAM Rev.1 numbering for the named
2021-2022 records. Examples by activity wording are beverages under code 13,
wood/sawmills under 17, printing/paper under 18, and water utilities under 30.
These agree with the Rev.1 column of INS Table III.2 (printed pp.10-13), whereas
the legacy meanings are other food products, leather/footwear, wood, and
construction respectively. No firm names or identifiers are reproduced here.

The dictionary explicitly identifies `CODEBRANCHE` as `CODE NACAM` but does not
specify the revision. The external report and data comparisons establish the
revision; the dictionary alone does not. The earlier legacy interpretation and
27-unresolved result are superseded and must not guide tax classification.
Names are evidence for this revision audit, not automatic firm-level ISIC assignments.
This inspection does not change raw data, classification CSVs, or generated datasets.

Originally reviewed 28 September 2026; revision corrected 29 September 2026. This inspection checked whether the local tax inputs contain activity information finer than the 37 observed NACAM Rev.1 branches. Raw files were read without modification. Only aggregate results and variable names are recorded here.

## Files and classification fields

| File, relative to `Data/Cameroon/` | Records | Variables | Activity information |
| --- | ---: | ---: | --- |
| `Raw/TAX PANEL Update - BASE ECOFIN 2015 2022 2024-02-21 18_09_36.xlsx`, sheet `BASE SERIE 2015$2022` | 9,325 | 266 | `CODEBRANCHE`: 37 values, no missing codes |
| Same workbook, sheet `DICTIONNAIRE` | 347 dictionary rows | 3 | Defines `CODEBRANCHE` as `CODE NACAM`; contains accounting-field descriptions, not firm activity descriptions |
| `Clean/CMR_BDF.dta` | 9,325 | 141 | `nacam`: the same 37 values, no missing codes |
| `Clean/tax_data.dta` | 9,195 | 11 | `isic_ag`: 16 observed broad groups; variable label is `RECODE of nacam (NACAM/NAIC code)` |
| `More files/ecofin15_22_clean_panel.dta` | 8,680 | 60 | `sector`: the same 37 values; `sector_12`: 12 broader groups |
| `More files/ecofin15_22_clean_panel_final.dta` | 8,556 | 60 | `sector`: the same 37 values; `sector_12`: 12 broader groups |

All observations cover financial years 2015–2022. The workbook data sheet has a single header row. Its first five columns are `CODE2`, `CODEBRANCHE`, `EFFECTIF`, `INVESTISSEMENT`, and `exerClos.x`. Other columns contain balance-sheet and income-statement fields, with auxiliary headers `SIGLE.x3`, `exerClos.y`, and `dureeMois.y`. No additional industry-code or activity-description column was found. `SIGLE.x3` has 1,931 populated strings; it is not a documented activity field and was not used to infer industry.

The dictionary refers to additional columns beyond the 266 present in the data sheet, so dictionary entries alone do not establish that the corresponding data were supplied. Its descriptions include accounting activities such as cash flow from operating activities; these describe financial-statement lines, not an enterprise's principal activity.

## Verified identifier and classification links

- The workbook's `(CODE2, exerClos.x, CODEBRANCHE)` records exactly equal the BDF file's `(firmid, fin_yr, nacam)` records, including multiplicity. Both contain 1,639 firms, 9,195 distinct firm-years, and 130 records in excess of one per firm-year. Neither identifier nor year is missing. This establishes an exact source-code and year link; it does not establish agreement of every accounting field.
- In the BDF source, 62 firm-year groups have more than one NACAM code. Forty firms have more than one observed NACAM code across their records, including same-year conflicts. Existing BDF duplicate-cleaning rules must determine the analysis sample before the reviewed crosswalk is merged.
- Each ECOFIN file is unique on `CODE2 year`. All 8,680 records in the first file and all 8,556 in the final file link exactly to BDF firm-year records and agree on `sector = nacam`. The files contain 1,561 and 1,541 firms, respectively. Eleven firms change sector across years in each file. In both files, each `sector` determines a single `sector_12`; the latter adds no detail.
- `tax_data.dta` is unique on `uin svyr`. Its `uin` contains four-digit strings. Adding the literal prefix `ECOFIN` reproduces BDF firm identifiers: all 9,195 tax firm-years match, covering all 1,639 firms. The 62 source firm-years with conflicting NACAM codes prevent a unique NACAM comparison for those keys. For the other 9,133 keys, each NACAM category determines exactly one `isic_ag` value. This confirms that `isic_ag` supplies broader groupings, with no finer classification information.

## Decision for the reviewed crosswalk

Create no firm-year refinements from these files. Their usable classification fields repeat or aggregate the NACAM Rev.1 branch. Exact firm-year links are available, but additional activity detail is absent. Broad or conflicting categories should therefore remain unresolved where the official category definitions span more than one ISIC Rev. 4 division.

Future firm-year refinements require a documented finer activity code or principal-activity description linked by a verified identifier and year. Neither firm-name inference, proportional allocation, nor carrying an assignment across years is supported by this inventory. The ECOFIN revisions to employment and other accounting variables do not justify changing the current BDF cleaning or classification rules.

## Inspection method

The exploratory inventory read workbook headers, dictionary definitions, code distributions, and exact identifier/year/code combinations with `openpyxl` and `pyreadstat`. It did not export firm identifiers, firm names, or record-level economic values into this document. Production crosswalk construction, merging, diagnostics, and output generation remain in Stata.
