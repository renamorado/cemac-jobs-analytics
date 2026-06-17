# B-READY Data

This folder stores unchanged official World Bank Business Ready (B-READY)
releases for future analysis of business-environment constraints and reform
priorities.

## B-READY 2025

Downloaded on: `2026-06-04`

Release: `B-READY 2025`

Official sources:

- Data landing page:
  `https://www.worldbank.org/en/businessready/data`
- Downloaded archive:
  `https://www.worldbank.org/content/dam/sites/b-ready/documents/excel/B-READY_ALL_DATA_2025.zip`
- Covered economies:
  `https://www.worldbank.org/en/businessready/about-us/covered-economies`
- Methodology Handbook, Second Edition:
  `https://thedocs.worldbank.org/en/doc/bc6351803cb0cd5ad4aba96b7e4aed8c-0540012024/original/B-Ready-Methodology-Handbook-Edition-2.pdf`

The release covers 101 economies. Cameroon is included under economy code
`CMR`. Coverage was verified directly in the scores and economy-answer
workbooks.

## Raw Files

The complete archive and its unchanged contents are saved under
`Data/B-Ready/Raw/2025/`:

- `B-READY_ALL_DATA_2025.zip`
  - Complete official archive as downloaded.
- `00_B-READY-2025-DATA-README.pdf`
  - Official overview of the archive and its two workbooks.
- `01_B-READY-2025-PILLAR-TOPIC-SCORES.xlsx`
  - Overall scores for the three B-READY pillars: Regulatory Framework,
    Public Services, and Operational Efficiency.
  - Includes topic, pillar, category, subcategory, and indicator scores for
    ten topics and 101 economies.
  - The overall pillar-score sheet ends with six non-data note and color-
    legend rows; use nonmissing economy codes to identify the 101 economies.
  - Workbook file version: `December 10, 2025`.
- `02_B-READY-2025-EconomyAnswer.xlsx`
  - Economy-level answers to the underlying questions for ten topics and 101
    economies.
  - Includes technical variable names, full survey-question text, economy
    responses, and data-source fields.
  - Workbook file version: `December 23, 2025`.

The ten topics are Business Entry, Business Location, Utility Services,
Labor, Financial Services, International Trade, Taxation, Dispute
Resolution, Market Competition, and Business Insolvency.

Indicator definitions are provided through the score workbook's hierarchical
column labels and the economy-answer workbook's full survey-question text.
Aggregation rules and detailed methodology are documented in the official
Methodology Handbook, Second Edition.

## Cameroon Verification

- `01_B-READY-2025-PILLAR-TOPIC-SCORES.xlsx` contains Cameroon (`CMR`) in
  the overall pillar-score sheet and all ten topic sheets.
- `02_B-READY-2025-EconomyAnswer.xlsx` contains Cameroon observations in all
  ten topic sheets.

## Intended Use

These raw files are retained for later Phase III work comparing Cameroon's
business-environment constraints and potential reform priorities with other
economies. Any cleaning, selection, or analysis should be performed
downstream without modifying these raw files.

Do not overwrite raw releases. Save future releases in a separate
year-specific folder.

## SHA-256 Checksums

| File | SHA-256 |
|---|---|
| `B-READY_ALL_DATA_2025.zip` | `59A8A83B5D91FAF7F8D0ECD979B49AB44477B8DB3B5F4849E93CA1217A95D109` |
| `00_B-READY-2025-DATA-README.pdf` | `D71F86D585EB3EF4F9386E9968918DD33663271E1D3D9743AFD458EB24CB4C61` |
| `01_B-READY-2025-PILLAR-TOPIC-SCORES.xlsx` | `4870F9158578D6C9EB67F9ED0C5ECB49B38C18CF21A0F6588B0CE2BF6EB28EC5` |
| `02_B-READY-2025-EconomyAnswer.xlsx` | `8B2C7035ECE2EE48B5E1094A82A047583F76809E8604722A2DABAAD0DE4DC968` |
