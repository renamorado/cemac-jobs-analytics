# CEMAC Jobs Analytics

Stata-first empirical research repository for job creation and employment multiplier work in CEMAC and related corridor-country settings.

## Current Scope

- Cameroon is the first active country module.
- Existing Cameroon inputs live in `Data/Cameroon/Raw/`.
- Existing cleaned Cameroon datasets live in `Data/Cameroon/Clean/`.
- World Bank Enterprise Survey materials currently live in `Data/World Bank Enterprise Survey/`.

## Repository Setup

- `AGENTS.md`: repo-wide workflow rules for future coding agents.
- `SESSIONS.md`: cumulative project memory across sessions.
- `00_master.do`: entry point for the Stata pipeline.
- `01_setup.do`: path setup, folder creation, and package installation.
- `code/`: modular Stata scripts by stage.
- `docs/reference/`: official reference PDFs used for reproducible harmonization work.
- `output/`: generated tables, figures, and slide-ready artifacts.
- `logs/`: generated log files.
- `manuscript/`: LaTeX manuscript source.
- `slides/`: Beamer source.

## Run Order

From the repository root, run:

```stata
do "00_master.do"
```

At this stage, the repository is scaffolded but the Cameroon processing do-files still need to be recovered or written. The current master script sets paths, verifies the starter structure, installs core packages, and runs a repository check script.

To compile the seminar deck after generating the required tables and figures, run:

```powershell
pdflatex --output-directory=../output/slides -interaction=nonstopmode -halt-on-error cmr_main_results_beamer.tex
```

Run that command from `slides/`.

## Data Handling

- Preserve the existing `Data/` tree while the pipeline is being standardized.
- Do not hand-edit generated outputs.
- Keep raw and manually added WBES inputs separate from processed data.
- Keep official classification manuals and methodology PDFs in `docs/reference/`.
- Assume large and proprietary data files should remain outside Git unless explicitly approved.

## Classification Reference

- `docs/reference/nacam-rev1-ins-cameroon.pdf` is the authoritative local
  reference for NACAM harmonization work in this repository.
