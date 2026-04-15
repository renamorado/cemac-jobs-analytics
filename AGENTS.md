# AGENTS.md

## Purpose

This repository is for Stata-first empirical research on job creation and employment multipliers in Cameroon, with room for later expansion if explicitly requested. Future agents should optimize for reproducibility, auditability, and readable empirical workflows that another researcher or research assistant can continue with minimal hand-holding.

This is not a Python-first repository. Do not import Python/R habits when a clear Stata-native solution exists.

## Binding Stata Guidance

Before doing Stata-related work, agents must consult and follow the local Stata skill:

- `C:/Users/wb648862/.codex/skills/stata-dime-repro/SKILL.md`

That skill is binding whenever work involves `.do`, `.ado`, `.dta`, `esttab`, `estout`, `reghdfe`, merges, reshapes, cleaning, analysis pipelines, tables, or reproducible Stata workflows.

Key implications for this repo:

- Write Stata in a Stata-native way.
- Prefer explicit sequential workflows over clever abstractions.
- Prefer readable numbered do-files over over-engineered wrappers.
- Use checks deliberately: `isid`, duplicate checks, merge diagnostics, `assert`, `count if`, and sample audits.
- Use `local` by default and reserve `global` for true project-wide constants such as the root path and agreed output folders.
- Export tables and figures directly from code. No manual post-processing should be required.

## Current Repository Baseline

Observed repository contents at setup:

- `Data/Cameroon/Raw/` contains Cameroon raw Excel inputs.
- `Data/Cameroon/Clean/` contains cleaned Stata datasets:
  - `CMR_BDF.dta`
  - `tax_data.dta`
- `Data/Cameroon/Do files/` exists but is currently empty.
- `Data/World Bank Enterprise Survey/` contains WBES-related materials, including manuals and large data files.
- The repo root contains `Analytics - trade and jobs - Cameroon.docx`, which appears to be narrative/project material rather than generated pipeline output.
- The repo now includes a starter Stata scaffold with `code/00_master.do`, `code/01_setup.do`, `code/`, `output/`, `logs/`, `manuscript/`, `slides/`, `README.md`, and `.gitignore`.
- Git is initialized at the project root.

Agents must preserve useful existing Cameroon work and standardize around it rather than pretending the project starts from zero.

The active working repository is the local clone at `C:/Users/wb648862/Documents/Projects/CEMAC`. Treat the older OneDrive copy as a backup/archive source for ignored data and manual recovery, not as the live execution environment. For now, treat this repo as Cameroon-only and avoid introducing cross-country abstractions unless the user explicitly asks for them.

## Core Working Standard

Reproducibility is the default. The intended workflow should be runnable by updating at most the root path, installing required user-written Stata packages in a controlled setup step, and executing a master script.

Required principles:

- One master script should orchestrate the full pipeline.
- Cleaning, construction, analysis, output production, and checks should be modular and readable.
- Outputs must be generated from code and never edited manually.
- Folder structure must support clean handoff and replication.
- Intermediate and final outputs should be generated systematically and saved intentionally.
- Hidden state should be minimized.
- Do-files should be readable and sequential rather than clever and opaque.
- Comments should explain logic and assumptions, not syntax.
- User-written Stata commands should be installed in a controlled setup/master script rather than ad hoc.

## Local Working Copy and Archive Data

Normal reproducible workflow should run against the local clone and write outputs directly to the repo's `output/`, `logs/`, and data subfolders without extra copy-back helpers.

Archive guidance:

- If required inputs are missing from the local clone, copy them in deliberately from the older OneDrive backup or another documented source.
- Do not treat the OneDrive copy as the default place to run analysis or regenerate outputs.
- Keep write logic simple and explicit; only add retry or `sleep` handling when you have a concrete local file-lock problem to solve.

## Stata-First Workflow Rules

Agents should think in Stata logic:

- the dataset currently in memory
- the unit of observation
- key identifiers
- the required state before each do-file runs
- explicit `use`, `save`, `merge`, `append`, `reshape`, `collapse`, estimation, and export steps

Preferred practices:

- Use `version` and `set more off` at the top of do-files.
- Prefer clear locals, tempfiles, and explicit paths.
- Use `preserve` and `restore` only when they genuinely improve safety and clarity.
- Sort explicitly when order matters.
- Document sample construction and variable construction directly in code.
- Use transparent intermediate datasets whenever they help auditing or multi-step construction.
- Separate data prep, variable construction, analysis, output generation, and diagnostics when that improves readability.

Avoid:

- fragile code with hidden side effects
- silent sample loss
- merges that ignore `_merge`
- order-dependent logic without `sort` or `gsort`
- manual GUI steps
- over-abstracted wrappers that make Stata harder to review

## Recommended Project Architecture

The repo should grow from the current Cameroon work into a scalable multi-country structure. Do not force a disruptive reorganization before the pipeline exists, but move toward a structure like:

- `code/00_master.do`
- `code/01_setup.do`
- `code/`
- `code/01_data_prep/`
- `code/02_construct/`
- `code/03_analysis/`
- `code/04_output/`
- `code/05_checks/`
- `Data/`
- `Data/Intermediate/`
- `Data/Analysis/`
- `Data/WBES_manual/`
- `output/`
- `output/tables/`
- `output/figures/`
- `output/slides/`
- `logs/`
- `manuscript/`
- `slides/`
- `AGENTS.md`
- `SESSIONS.md`

Country scaling rule:

- Treat Cameroon as the first country module.
- Additional countries should be added in a way that parallels Cameroon rather than creating one-off exceptions.
- Country-specific raw inputs, cleaning, and construction should remain distinguishable from pooled cross-country analysis outputs.

## Practical Mapping From the Current Cameroon Contents

Until a fuller migration is implemented, use the current folders as the authoritative baseline and standardize around them carefully.

Suggested mapping:

- `Data/Cameroon/Raw/` is the current raw input archive for Cameroon.
- `Data/Cameroon/Clean/` is the current cleaned/intermediate Stata output location for Cameroon.
- `Data/Cameroon/Do files/` should be treated as a legacy placeholder and replaced over time by root-level numbered scripts and/or `code/` subfolders.
- `Data/World Bank Enterprise Survey/` should be treated as a source-material holding area and reviewed carefully before any data are folded into the reproducible pipeline.
- `Analytics - trade and jobs - Cameroon.docx` should be treated as background narrative or drafting material, not as the reproducible output layer.

Migration guidance:

- Do not relocate raw files casually if existing references may depend on them.
- When standardizing, either preserve old paths temporarily or migrate deliberately and update the master pipeline in the same change.
- Prefer creating a clean forward-looking structure and then moving Cameroon code and derived outputs into it once reproducible do-files exist.
- If a folder rename would risk breaking the current workflow, document the transition in `SESSIONS.md` first.

## Master and Setup Scripts

The repository should eventually have:

- `code/00_master.do`: orchestrates the full pipeline in sequence
- `code/01_setup.do`: sets the root, creates expected output/log folders if needed, installs required user-written commands in a controlled way, and defines stable project globals only where justified

The master script should:

- open a master log
- call data prep, construction, analysis, output, and check scripts in a readable order
- fail loudly when required inputs are missing
- save logs and generated outputs systematically

Package installation guidance:

- Install user-written commands centrally, not ad hoc inside multiple scripts.
- Keep package requirements explicit.
- `estout` should be installed and available because `esttab`/`estout` is the default table workflow here.
- Use `reghdfe` or other estimation commands only when substantively appropriate and document them in setup.

## Tables: `esttab` / `estout` Are the Default

This rule is strict.

- Regression tables and summary tables should be exported using `esttab` / `estout`.
- Tables should be written as LaTeX fragments intended for `\input{}`.
- Tables should use `booktabs` style.
- `esttab` is the default table engine for this repository.

Agents must not default to custom `filewrite` solutions when a table is difficult.

Before using manual `filewrite`, agents must exhaust the flexibility of `esttab`/`estout` options for:

- titles
- labels
- notes
- significance stars
- column ordering
- column groups
- panels
- formatting
- statistics blocks

Repository rule:

- Hand-editing exported LaTeX regression tables is not allowed.
- Table logic should be controlled from Stata code as much as possible.
- `filewrite` is a last resort, not a first resort.

## Figures and Data Visualization

All figures must be generated from code and exported in a reproducible way for both papers and slides.

Visual standard:

- clarity over decoration
- honest scales
- readable labels
- minimal clutter
- consistent styling across outputs
- direct labeling when sensible
- colorblind-safe palettes when color matters
- clear display of uncertainty when relevant

Concrete Stata guidance:

- Standardize graph formatting as much as possible.
- Centralize reusable graph style choices when feasible.
- Use stable file names tied to the underlying analysis step.
- Export vector graphics such as PDF when appropriate for LaTeX.
- Also export PNG when helpful for slides or quick review.
- Do not rely on manual post-processing in PowerPoint, Word, or Illustrator.
- Keep legends, axes, notes, titles, and spacing clean and consistent.

## Manuscript and Beamer Workflow

LaTeX is the output layer for manuscript and slides.

Preferred workflow:

- Stata generates table fragments in `.tex`.
- Stata exports figures to `output/figures/`.
- Manuscript and Beamer files load those generated outputs rather than recreating them manually.

Beamer guidance:

- Keep the slide workflow lightweight.
- Preliminary presentations should reuse the same tables and figures generated for the main pipeline.
- Slides should rely on exported `.tex` table fragments and figure files.
- Do not maintain separate manual versions of results for slides unless there is a documented reason.

## Manual WBES Additions

The project may later include manually pasted WBES material for additional countries. This must be handled with unusually clear provenance.

Required practice:

- Create a clearly documented intake location for manually added WBES raw files.
- Keep manual raw inputs separate from processed datasets.
- Do not overwrite raw files.
- Document source, date obtained, country, and any manual steps required to create the raw input file.
- Make downstream cleaning scripts fully reproducible from those raw files.

Recommended convention once implemented:

- `Data/WBES_manual/<country>/`
- include a short provenance note or README for each intake batch

## Git and GitHub Hygiene

The repo is not currently initialized as Git, but it should be organized for clean Git/GitHub use.

Guidance:

- Version control code, documentation, lightweight configuration, and lightweight output metadata.
- Do not commit bulky generated files unless there is a deliberate reason.
- Do not commit confidential, proprietary, or sensitive raw data unless explicitly intended and permitted.
- Keep logs, temporary files, caches, and machine-specific artifacts out of version control.
- Prefer documenting how outputs are regenerated rather than storing unnecessary derived files.
- Maintain a clean `.gitignore` aligned with Stata, LaTeX, logs, and temporary outputs.

As a rule:

- commit source do-files, `.md`, `.tex`, and lightweight project configuration
- be selective about committing `.dta`, large `.xlsx`, PDFs, and generated figures
- document data dependencies and regeneration steps clearly

## Empirical Rigor and Diagnostics

Future agents must preserve empirical transparency.

Always make explicit:

- whether a result is descriptive, correlational, or causal
- sample restrictions
- weights
- clustering decisions
- estimator choice
- units and denominators
- transformations
- outlier handling
- merge logic

Required habits:

- verify identifiers before merges
- inspect and document merge results
- avoid silently dropping observations
- produce dedicated diagnostic outputs when useful
- keep construction decisions auditable and reviewable

## Logging and Validation

Where useful, the pipeline should save:

- master and step-specific logs
- intermediate datasets with clear names
- validation outputs or check tables
- sample audit information

Checks should be easy to rerun and easy to inspect.

## Session Memory Requirement

`SESSIONS.md` is the cumulative project memory for future coding sessions.

Whenever an agent makes meaningful changes, update `SESSIONS.md` with:

- date
- task
- files created or modified
- key decisions
- important assumptions
- unresolved issues
- warnings or next steps

Keep entries concise, factual, and safe for version control. Do not store sensitive data or bulky logs there.


