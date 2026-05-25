# CEMAC Jobs Analytics

Stata-first empirical research repository for job creation and employment multiplier work in Cameroon. The current working assumption is Cameroon-only unless a later task deliberately expands the scope.

## Current Scope

- Cameroon is the active country scope for the current pipeline.
- Existing Cameroon inputs live in `Data/Cameroon/Raw/`.
- Existing cleaned Cameroon datasets live in `Data/Cameroon/Clean/`.
- World Bank Enterprise Survey materials currently live in `Data/World Bank Enterprise Survey/`.

## Repository Setup

- `AGENTS.md`: repo-wide workflow rules for future coding agents.
- `SESSIONS.md`: cumulative project memory across sessions.
- `code/00_master.do`: canonical entry point for the Stata pipeline.
- `code/01_setup.do`: canonical path setup, folder creation, and package installation.
- `code/`: Stata scripts organized by analysis module.
- `code/elasticity_cameroun/`: current Cameroon NACAM crosswalk, checks, cleaning-note exports, elasticity analysis, and related Cameroon trade scaffold.
- `code/WBES_trade/`: WBES trade-analysis branch, starting with a latest-wave
  all-country cleaning/prep stage that includes CEMAC as a filter.
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

The current Cameroon master script sets paths, verifies the module structure, installs core packages, and runs the upstream crosswalk and cleaning checks in `code/elasticity_cameroun/`. The WBES trade branch is kept separate from the master script while the method is being validated. To build the current WBES trade prep dataset, run:

```stata
do "code/WBES_trade/01_wbes_trade_clean_prep.do"
```

That stage reads the comprehensive WBES extract, keeps all latest-wave economies, downloads and merges World Bank country metadata plus UNSD ISIC Rev.4 sector labels, and writes `Data/Analysis/wbes_trade_clean.dta` plus audit table fragments.

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

To export exploratory WBES employment/trade elasticity outputs, run:

```stata
do "code/WBES_trade/03_wbes_trade_elasticity.do"
```

That stage reads `Data/Analysis/wbes_trade_clean.dta`, estimates weighted latest-wave cross-sectional employment/export-value associations, and writes slide-ready country and Cameroon activity-group tables and figures. These are not panel fixed-effect elasticities; see `docs/wbes_trade_representativeness_note.md` for the methodological caveats.

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

- `docs/reference/nacam-rev1-ins-cameroon.pdf` is the authoritative local
  reference for NACAM harmonization work in this repository.

