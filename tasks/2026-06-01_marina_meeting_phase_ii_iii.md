# Marina Meeting Tasks - 2026-06-01

Source: Meeting with Marina.

Purpose: Organize the next Cameroon elasticity and Phase III follow-up tasks so they can be implemented in later coding sessions under the repo's Stata-first reproducibility standards.

Status legend: backlog, in progress, complete, blocked.

## 1. Cameroon Elasticity and Presentation Follow-Ups

### 1.1 Rename the Detailed NACAM Activity Currently Labeled "Trade"

Status: complete as of 2026-06-02. The detailed NACAM activity previously displayed as "Trade" now uses the display label "Wholesale/retail" in regenerated Cameroon NACAM tables, figures, and the rebuilt deck.

Motivation: The English label "Trade" may imply international trade or exports, while the underlying NACAM activity may refer more broadly to domestic commerce, wholesale, and retail sales.

Subtasks:

- Check the original French NACAM source before renaming anything.
  - Start with `docs/reference/nacam-rev1-ins-cameroon.pdf`.
  - Cross-check `docs/reference/nacam_rev1_citi_bridge_extracted.xlsx`.
  - Confirm whether the official French label is closer to "commerce" than "trade".
- Locate every generated display label that currently uses "Trade" for the detailed NACAM economic activity.
  - Likely files include `code/elasticity_cameroun/02_nacam_data_export_mapping.do`, `code/elasticity_cameroun/06_cmr_nacam_elasticity.do`, `code/elasticity_cameroun/08_cmr_census_sector_diagnostics.do`, and slide/table outputs.
- If confirmed, standardize the label to a source-backed English translation in figures, tables, and slides.
- Regenerate affected outputs from Stata rather than editing exported figures or LaTeX fragments manually.

Deliverable:

- Updated Stata label logic and regenerated tables/figures/slides using a verified wholesale/retail label.

Open question:

- Resolved on 2026-06-02: use "Wholesale/retail" for displayed labels.

### 1.2 Add Figure Sources

Status: complete as of 2026-06-03. The current deck figures now carry short reproducible source notes from the Beamer layer, while Stata figure exports remain source-note-free. `docs/figure_sources.md` records the citation text and assumptions.

Motivation: Each figure in the deck/report should identify its data source in a consistent citation style.

Subtasks:

- Inventory every current figure in `slides/slides_cemac.tex` and any manuscript/report output.
- For each figure, assign the source dataset and institution.
  - Cameroon Census/RGE figures: identify the full census name and the responsible institution.
  - Cameroon BDF/admin tax panel elasticity figures: identify the administrative data source and institution.
  - WBES figures: cite World Bank Enterprise Surveys with the relevant country/sample scope and wave.
- Look up APA-style formatting rules for datasets and institutional reports before finalizing source text.
- Add source notes in the figure-generating Stata code when feasible, or in the LaTeX slide/report layer when the figure is reused from a generated file.
- Keep source notes short enough for slides while maintaining a fuller reference list in the report or appendix.

Deliverable:

- Complete as of 2026-06-03: all current deck figures have reproducible, consistently formatted source notes in `slides/slides_cemac.tex`.
- Complete as of 2026-06-03: `docs/figure_sources.md` records a short reference list and citation notes for the key datasets.

Tentative citation targets to verify:

- Resolved for current slide notes: INS Cameroon, RGE3 (2023-2024).
- Resolved conservatively for current slide notes: Cameroon administrative tax/BDF panel, with exact institution still to confirm before naming it.
- Resolved for current slide notes: World Bank Enterprise Surveys, latest available CEMAC waves.

### 1.3 Robustness Plots for Cameroon Elasticities With Alternative FE and Controls

Status: backlog.

Motivation: Current sector-level Cameroon elasticity estimates have large standard errors. We need to test whether the sector ranking and interpretation are robust to reasonable changes in fixed effects and controls.

Baseline to replicate:

- Current sector elasticity plots by NACAM sector for value added and total revenue.
- Current outputs produced by `code/elasticity_cameroun/06_cmr_nacam_elasticity.do`.

Proposed specification families:

- Baseline:
  - Firm fixed effects and year fixed effects, with sector-specific slope interactions for the output proxy.
- Alternative A: sector-by-year shocks.
  - Firm fixed effects plus sector-by-year fixed effects where feasible.
  - Use this to absorb sector-wide annual shocks that may otherwise affect both revenue/value added and employment.
- Alternative B: region or location controls if available.
  - Firm fixed effects, year fixed effects, and time-varying location controls or location-by-year fixed effects.
  - First verify whether location fields exist and are stable enough in the BDF panel.
- Alternative C: firm size controls.
  - Firm fixed effects, year fixed effects, and lagged or baseline firm-size bins interacted with year where feasible.
  - Avoid bad controls that mechanically absorb the employment outcome; define the control logic before coding.
- Alternative D: outlier and sample robustness.
  - Re-estimate after trimming or winsorizing log changes in employment and revenue/value added.
  - Compare balanced-panel and minimum-observation samples.
- Alternative E: clustered standard error choices.
  - Compare firm-level clustering, sector-level clustering if defensible, and bootstrap options if cell sizes allow.

Implementation notes:

- Think through identification before coding: some FE choices may absorb the sector-level variation needed for sector-specific slopes.
- Record sample sizes, number of firms, and number of sector-year cells for each specification.
- Keep the output naming explicit, for example `cmr_nacam_results_fe_robustness_*`.
- Export both tables and plots from Stata.

Deliverable:

- A new set of elasticity plots mirroring the current sector plots, but faceted or grouped by FE/control specification.
- A compact table summarizing the specification variants, sample size, FE structure, controls, and clustering.

### 1.4 Investigate Why the Wood Sector Elasticity Differs From Another Cameroon Report

Status: backlog.

Motivation: Our current "wood" sector elasticities appear low, while another Cameroon report reports a high elasticity for wood. We need to understand whether the difference is due to sector definitions, data coverage, estimator choice, period, or output proxy.

Subtasks:

- Locate and review the other Cameroon report and its documentation.
- Extract the exact definition of the "wood" sector used in that report.
- Compare against this repo's NACAM mapping and any ISIC/NACAM crosswalk rows tied to wood, forestry, furniture, paper, and related manufacturing.
- Compare:
  - data source and coverage
  - years
  - formal vs informal coverage
  - outcome and output proxy
  - estimator and fixed effects
  - sample restrictions
  - treatment of outliers and small cells
- If the definitions differ, create a short note and, if feasible, a harmonized robustness estimate using the other report's sector boundary.

Deliverable:

- A short markdown diagnostic explaining the likely reason for the discrepancy.
- Optional robustness plot/table if the sector can be reconstructed cleanly.

Open question:

- Which "other Cameroon report" should be treated as the comparator? Add the file path or citation once identified.

### 1.5 Add Exporter-Interaction Elasticity Specification

Status: completed on 2026-06-04.

Motivation: Test whether employment-revenue elasticities differ between exporters and non-exporters.

Proposed model idea:

- Add an interaction between revenue and exporter status.
- Candidate Stata framing:
  - `ln_employment` on `ln_revenue`, `exporter`, and `ln_revenue x exporter`, with appropriate fixed effects and clustered standard errors.
  - If firm fixed effects are included, time-invariant exporter status will be absorbed; use time-varying exporter status if available, or define baseline exporter groups and interact them with revenue slopes.

Subtasks:

- Verify whether exporter status exists in the Cameroon administrative panel, the WBES data, or only in one source.
- Define exporter status carefully:
  - time-varying exporter
  - ever-exporter
  - baseline exporter
  - exporters only vs all firms
- Decide whether this belongs in the Cameroon administrative elasticity module, the WBES trade module, or both.
- Estimate and export results with clear caveats about interpretation.

Deliverable:

- A table and plot showing whether the revenue-employment elasticity differs by exporter status, with sample and data-source caveats.

Implementation note:

- Added `code/WBES_trade/04_wbes_revenue_exporter_interaction.do`.
- The focal WBES model uses `sales_w` as revenue and `export_status` for any
  direct or indirect exports.
- Results report non-exporter and exporter slopes plus the exporter minus
  non-exporter difference.
- Displayed estimates require at least 30 usable firms, 10 exporters, and 10
  non-exporters.
- Country estimates are primary; Cameroon activity estimates are diagnostics.
- The existing export-value specifications remain supporting results.
- Restored the comprehensive WBES source, regenerated
  `Data/Analysis/wbes_trade_clean.dta`, and successfully produced the real
  Task 1.5 tables, figures, audit dataset, and slide deck.
- For Cameroon, the exporter revenue-employment slope exceeds the non-exporter
  slope by 0.164 (p = 0.002). The equal-country CEMAC average difference is
  -0.103 (p = 0.371). These remain weighted cross-sectional associations.

## 2. Phase III for Cameroon

### 2.1 Download and Document B-Ready Data

Status: completed on 2026-06-04.

Motivation: Phase III will use business environment constraints and reform-priority evidence. B-Ready is a candidate source for comparable business-environment indicators.

Subtasks:

- Download the relevant B-Ready data files and metadata.
- Save raw files in a documented source folder, preserving original filenames.
- Create a provenance note with:
  - source URL
  - date downloaded
  - version or release year
  - countries covered
  - indicator definitions
- Decide whether B-Ready should live under a new `Data/B-Ready/Raw/` folder or another documented location.
- Do not overwrite raw files.

Deliverable:

- Raw B-Ready data and metadata saved with provenance.
- A short README documenting source and intended use.

Completion note:

- Saved the complete official B-READY 2025 archive and its unchanged contents
  under `Data/B-Ready/Raw/2025/`.
- Documented official sources, release coverage, indicator definitions,
  intended use, Cameroon coverage, and SHA-256 checksums in
  `Data/B-Ready/README.md`.
- Verified that Cameroon (`CMR`) appears in the overall score sheet, all ten
  topic-score sheets, and all ten economy-answer topic sheets.

### 2.2 Select Priority Sectors From Elasticity Deciles 7-10

Status: backlog.

Motivation: Use high-elasticity sectors as candidate priority sectors for Phase III, then compare reported business obstacles for those sectors against other sectors.

Subtasks:

- Use the existing revenue-elasticity decile ranking to identify sectors in deciles 7-10.
- Define the prioritized sector list reproducibly from the generated elasticity results rather than copying names manually.
- Link prioritized sectors to firm-level obstacle data where possible.
- Compare reported obstacles for prioritized sectors against:
  - all other sectors
  - lower elasticity deciles
  - the national or CEMAC WBES benchmark if relevant
- Candidate obstacles to compare:
  - access to finance
  - electricity
  - taxes and tax administration
  - customs and trade regulations
  - transport
  - labor skills
  - corruption or informal competition
  - licensing and permits
- Report both the share of firms identifying an obstacle and the size/severity of the obstacle where the data support it.

Implementation notes:

- Keep obstacle comparisons descriptive unless a stronger identification strategy is defined later.
- Use WBES weights for WBES-based obstacle summaries.
- Make sure sector mapping between elasticity deciles and WBES activity groups is explicit; do not force a detailed NACAM-to-WBES mapping if the data only support broad activity groups.

Deliverable:

- A Phase III sector-prioritization table.
- A set of obstacle-comparison plots for prioritized sectors versus comparison sectors.
- A short methods note documenting the decile rule, sector mapping, data source, weights, and limitations.

## Cross-Cutting Requirements

- Follow `AGENTS.md` and the Stata DIME reproducibility guidance for any `.do` work.
- Update `SESSIONS.md` whenever implementation work begins or meaningful files change.
- Regenerate outputs from code; do not hand-edit exported tables or figures.
- Keep figure/table filenames explicit about data source, outcome, and specification.
- Separate confirmed results from exploratory robustness checks in slides and report text.
