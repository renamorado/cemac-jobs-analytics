# Reference Documents

This folder stores official reference materials used to build reproducible
classification and methodology inputs for the project.

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
