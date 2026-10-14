# Reference Documents

This folder stores official reference materials used to build reproducible
classification and methodology inputs for the project.

## INSEE-based English division labels

`isic4_division_short_labels_insee.csv` records all 88 division codes, INSEE's
full French titles and 65- and 40-character short titles, and the project's
English display labels. Source: [INSEE NAF Rev.2 short titles](https://www.insee.fr/fr/statistiques/fichier/2120875/int_courts_naf_rev_2.xls),
accessed 29 September 2026. INSEE documents that NAF Rev.2 and ISIC Rev.4 have
the same 88 divisions on its [classification page](https://www.insee.fr/fr/information/3281579).

The English labels are project adaptations, not official INSEE translations.
They retain distinctions useful to readers, including motorcycles in divisions
45–47, while shortening titles for figures. The division code accompanies each
display label. Full official ISIC labels and classification decisions are retained
in prepared data. Section display wording also follows INSEE where applicable;
the agreed combined tax groups remain project groupings.

## Tax source classification: NACAM Rev.1

The raw tax `CODEBRANCHE` / BDF `nacam` uses **NACAM Rev.1**. The official
ECOFIN report and matching count/employment profiles establish this project
decision; see [evidence and period coverage](../cmr_tax_ecofin2019_comparison.md).
Read the Rev.1 column of the NACAM manual for these source codes. The older
NACAM column does not describe their tax meanings.

- `tax_isic4/Rapport-ECOFIN-2019-Final.pdf`: methodology p.79, branch counts
  pp.80–81, employment shares p.43.
- `cmr_ecofin2019_branch_counts.csv`: verified extraction of 185 branch-year counts.
- `cmr_tax_nacam_rev1_isic4_decisions.csv`: current division correspondence.
- `cmr_tax_nacam_rev1_isic4_sections.csv`: current tax section grouping.
- `isic4_broad_groups.csv`: shared ten broad-sector labels, colors and symbols
  for all 21 ISIC Rev.4 sections and their detailed codes. Replaces the former
  tax-only style lookup; see [usage](../isic4_broad_display_groups.md).
- `cmr_tax_isic4_decisions.csv`: superseded legacy interpretation, retained for audit.

The older census/WBES-to-administrative-NACAM bridges listed below describe
existing code, not newly validated equivalence with the corrected tax meanings.
Their use in cross-source comparisons needs review. No census or WBES outputs
were changed by this documentation correction.

Current reference file:

- `nacam-rev1-ins-cameroon.pdf`
  - Official INS Cameroon publication:
    `Nomenclature des activites et des produits du Cameroun (NACAM rev.1)`
  - Source URL:
    `https://ins-cameroun.cm/wp-content/uploads/2025/06/NOMENCLATURE_DES-ACTIVITES-AU-CAMEROUN.pdf`
  - Use in this repo:
    authoritative source for NACAM-to-ISIC harmonization from
    `Data/Cameroon/Clean/CMR_BDF.dta`

Derived reference files:

- `nacam_rev1_citi_bridge_extracted.xlsx`
  - Extracted from the official INS NACAM Rev.1 PDF.
  - Contains Table III.2 rows and a normalized Table III.1 section summary.
  - Use as a reviewable structured source for CITI/ISIC-to-NACAM merges.
- `cmr_census_activity_nacam_crosswalk.xlsx`
  - Project crosswalk from observed 2024 RGE census activity labels to the
    administrative NACAM sectors used in the elasticity analysis.
  - Points back to `nacam_rev1_citi_bridge_extracted.xlsx` and keeps review
    flags for ambiguous or non-observed administrative sectors.
- `cmr_wbes_isic4_nacam_crosswalk.xlsx`
  - Project crosswalk for the 112 four-digit main-product ISIC Rev.4 codes
    observed among 615 latest-wave Cameroon WBES firms.
  - Maps 102 codes uniquely to the administrative NACAM vocabulary and retains
    10 review-excluded codes rather than assigning ambiguous sectors.
  - Generated reproducibly by
    `code/BREADY_wbes/00_build_wbes_nacam_crosswalk.mjs`.
