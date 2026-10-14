# CEMAC Jobs Analytics

The census ISIC Rev. 4 classification is documented in [the census crosswalk workflow](docs/cmr_census_isic4_workflow.md). The activity crosswalk assigns 270 of 273 pairs; a separate private CSV records individual decisions for unresolved units. Run `do "code/isic4_assessment/00_run_census_crosswalk.do"` for the assessment outputs. Census cleaning (`08_cmr_census_cleaning.do`) regenerates these decisions and attaches `isic4_*` fields while preserving the existing NACAM classification. The private firm decision CSV must accompany the raw data for replication.

Stata-first empirical research repository for job creation and employment multiplier work in Cameroon. The current working assumption is Cameroon-only unless a later task deliberately expands the scope.

## Current Scope

- Cameroon is the active country scope for the current pipeline.
- Existing Cameroon inputs live in `Data/Cameroon/Raw/`.
- Existing cleaned Cameroon datasets live in `Data/Cameroon/Clean/`.
- World Bank Enterprise Survey materials currently live in `Data/World Bank Enterprise Survey/`.

## Repository Setup

- `AGENTS.md`: repo-wide workflow rules for future coding agents.
- `SESSIONS.md`: cumulative project memory across sessions.
- `code/00_master.do`: entry point for the Stata pipeline.
- `code/01_setup.do`: path setup, folder creation, and package installation.
- `code/`: Stata scripts organized by analysis module.
- `code/elasticity_cameroun/`: current Cameroon NACAM crosswalk, checks, cleaning-note exports, elasticity analysis, and related Cameroon trade scaffold.
- `code/WBES_trade/`: WBES trade-analysis branch, starting with a latest-wave
  all-country cleaning/prep stage that includes CEMAC as a filter.
- `code/BREADY_wbes/`: B-READY priority-question mapping and weighted Cameroon
  WBES constraint comparisons by ISIC Rev.4 section group.
- `docs/reference/`: official reference PDFs used for reproducible harmonization work.
- `output/`: generated tables, figures, and slide-ready artifacts.
- `logs/`: generated log files.
- `manuscript/`: LaTeX manuscript source.
- `slides/`: Beamer source.

## Run Order

From the repository root, run:

```stata
do "code/00_master.do"
```

For Marina's OneDrive handoff copy, open Stata from:

```text
C:/Users/wb603585/OneDrive - WBG/Documents/Projects/CEMAC/FY26/CEMAC jobs analytics
```

Then run either:

```stata
do "00_master.do"
```

or:

```stata
do "code/00_master.do"
```

The Stata bootstrap maps `wb603585` to Marina's OneDrive project root and
`wb648862` to the local working copy at
`C:/Users/wb648862/Documents/Projects/CEMAC`.

The current Cameroon master script sets paths, verifies the module structure,
installs core packages, prepares the reviewed classifications, runs the tax,
Census and WBES analyses, and generates the B-READY/WBES constraint extension.
It ends with observation-preservation and cross-dataset checks in
`code/05_checks/07_isic4_slide_checks.do`. Census and Cameroon WBES sector
estimates use two-digit ISIC Rev.4 divisions; tax estimates use the agreed
16 section groups. Separate Census section estimates and weighted WBES
section means support the linked comparisons. See the
[ISIC slide workflow](docs/isic4_slides_workflow.md).
To build the current WBES trade prep dataset, run:

```stata
do "code/WBES_trade/01_wbes_trade_clean_prep.do"
```

To regenerate the Cameroon B-READY/WBES constraint dataset, validation tables,
and all-sector figures with weighted 95% confidence intervals, run:

```stata
do "code/BREADY_wbes/03_bready_wbes_sector_constraints.do"
```

This stage uses the 16 reviewed priority indicators already defined in its code.
When `Data/B-Ready/Raw/2025/bready_enterprise_survey_questions.xlsx` is available,
it also checks the number of rows marked `Priority = yes`. It uses the
official four-digit ISIC Rev.4 classification and shared display lookup, and defines
high-elasticity sectors as total-revenue elasticity deciles 7--10.
Each validated indicator figure uses the overlapping elasticity-eligible section groups,
reports the unweighted sector N, and retains small-sample estimates with an
explicit caution rather than suppressing them. Pooled estimates remain in the
analysis dataset for reference but are not used in the slide deck.

The WBES cleaning stage reads the comprehensive extract, keeps all latest-wave economies, downloads and merges World Bank country metadata plus UNSD ISIC Rev.4 sector labels, and writes `Data/Analysis/wbes_trade_clean.dta` plus audit table fragments.

To export the slide-ready WBES descriptive statistics table, run:

```stata
do "code/WBES_trade/02_wbes_trade_descriptive_stats.do"
```

That stage reads `Data/Analysis/wbes_trade_clean.dta`, merges World Bank WDI
official exchange rates by country and reported fiscal year, converts
winsorized sales to current US dollars, and writes the deck fragment
`output/tables/cemac_wbes_trade_descriptive_stats_deck.tex`.

To export the first CEMAC WBES trade plots, run:

```stata
do "code/WBES_trade/02_wbes_trade_plots.do"
```

That stage reads `Data/Analysis/wbes_trade_clean.dta` and exports weighted country-plus-benchmark dot-and-interval plots for exporter share, export intensity among exporters, import or foreign-input participation, and two-way trader status. Gabon remains coverage-only in these plots.

To prepare and export exploratory WBES employment/trade elasticity outputs, run:

```stata
do "code/WBES_trade/05_wbes_elasticity_prep.do"
do "code/WBES_trade/03_wbes_trade_elasticity.do"
```

The prep stage reads `Data/Analysis/wbes_trade_clean.dta` and writes `Data/Analysis/wbes_elasticity_clean.dta`. The elasticity stage reads that clean file, estimates weighted latest-wave cross-sectional employment/export-value associations, and writes slide-ready country and Cameroon ISIC division tables and figures. These are not panel fixed-effect elasticities; see `docs/wbes_trade_representativeness_note.md` for the methodological caveats.

To estimate the focal revenue-exporter interaction specification, run:

```stata
do "code/WBES_trade/05_wbes_elasticity_prep.do"
do "code/WBES_trade/04_wbes_revenue_exporter_interaction.do"
```

The interaction stage reads `Data/Analysis/wbes_elasticity_clean.dta` and estimates weighted cross-sectional employment-revenue slopes
separately for exporters and non-exporters. It reports the exporter minus
non-exporter slope difference as the focal estimate, retains suppressed groups
in an audit dataset, and requires at least 30 usable firms plus at least 10
exporters and 10 non-exporters for displayed estimates.

The reference metadata steps can also be run separately for audit:

```stata
do "code/WBES_trade/00_download_reference_data.do"
do "code/WBES_trade/00_prepare_reference_merges.do"
```

To compile the seminar deck after generating the required tables and figures, run:

```powershell
pdflatex -interaction=nonstopmode -halt-on-error slides_cemac.tex
```

Run that command from `slides/`. The active deck PDF is `slides/slides_cemac.pdf`;
do not maintain a second review copy under `output/slides/`.

## Data Handling

- Preserve the existing `Data/` tree while the pipeline is being standardized.
- Do not hand-edit generated outputs.
- Keep raw and manually added WBES inputs separate from processed data.
- Keep official classification manuals and methodology PDFs in `docs/reference/`.
- Assume large and proprietary data files should remain outside Git unless explicitly approved.
- Track only curated generated review artifacts from `output/`: LaTeX table
  fragments in `output/tables/`, plus PDF and PNG files used for manuscript or
  slide review. Continue ignoring logs, LaTeX build byproducts, temporary files,
  and generated data.

## Classification Reference

- The raw tax/BDF codes use **NACAM Rev.1**, established from the official ECOFIN
  methodology and matching branch-count/employment profiles. See
  [the evidence and year coverage](docs/cmr_tax_ecofin2019_comparison.md).
  Run `do "code/elasticity_cameroun/98_run_cmr_tax_isic4.do" rev1_assessment`
  to produce `Data/Analysis/CMR_BDF_isic4_rev1_assessment.dta`, preserving the
  cleaned panel and legacy outputs. Its 37 decisions distinguish 13 single,
  15 combined and nine partial correspondences. ISIC boundary uncertainty remains;
  existing generated provisional flags predate the external verification.
  See [the tax classification instructions](docs/cmr_tax_isic4_workflow.md) for
  sources, diagnostics, short labels, coverage and tests. The old
  `CMR_BDF_isic4.dta` assignments and 27-unresolved count are superseded; the
  production master now explicitly runs the reviewed Rev.1 and section steps.

- The first-stage Rev. 4 mapping assessment covers Cameroon Tax/BDF, Cameroon Census/RGE, and WBES for CEMAC countries. Run instructions, input requirements, and diagnostic definitions are in [code/isic4_assessment/README.md](code/isic4_assessment/README.md). This assessment has its own entrypoint and does not run the estimation or slide pipeline.

- `docs/reference/nacam-rev1-ins-cameroon.pdf` is the authoritative local
  reference for NACAM harmonization work in this repository.

## OneDrive Handoff

The authoritative working copy is the local repo at
`C:/Users/wb648862/Documents/Projects/CEMAC`. To refresh the shared OneDrive
handoff copy, run:

```powershell
backup_to_onedrive.bat dryrun
backup_to_onedrive.bat full
```

The backup script is non-destructive: it copies current project files into the
shared OneDrive folder without deleting destination-only files, and it excludes
files named like `*_marina*` so Marina-specific variants are preserved.

The [tax ISIC Rev.4 section assessment](docs/cmr_tax_isic4_sections.md) provides a 37-branch crosswalk, 16 tax analysis groups, and a descriptive employment/revenue preview. Run `do "code/elasticity_cameroun/98_run_cmr_tax_isic4.do" section_assessment`. Six cross-section branches use Roldan's documented analytical groupings (005/006 to B, 009 to A, 021 to C, 029 to D, 037 to L). Strict correspondence fields retain their qualifications. The slide pipeline uses these groups for tax regressions and separate section-level comparisons with Census and WBES.

For tax analysis, use **`isic4_section`** and `isic4_section_label` from
`Data/Analysis/CMR_BDF_isic4_sections_assessment.dta`. This is the adapted
16-group classification, including combined groups. The official-only
correspondence is retained separately in `isic4_section_strict`.

### Shared ISIC Rev.4 display labels

The [shared broad-sector scheme](docs/isic4_broad_display_groups.md) maps every
official Rev.4 section, division, group and class to ten consistent display
labels, colors and symbols. Run `do "code/02_construct/01_isic4_broad_groups.do"`.
Tax and Census figures use this mapping; WBES prepared data carry the same
display fields while retaining their division and section analysis levels.
