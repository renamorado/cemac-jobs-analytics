version 17.0
clear all
set more off

capture log close _all

local username = lower("`c(username)'")

if "`username'" == "user" {
    global project_root "C:/Users/User/Documents/Projects/cemac-jobs-analytics"
}
else if "`username'" == "wb648862" {
    global project_root "C:/Users/wb648862/Documents/Projects/CEMAC"
}
else if "`username'" == "wb603585" {
    global project_root "C:/Users/wb603585/OneDrive - WBG/Documents/Projects/CEMAC/FY26/CEMAC jobs analytics"
}
else if fileexists("AGENTS.md") {
    global project_root "`=subinstr(c(pwd), "\", "/", .)'"
}
else {
    display as error "No project_root path is configured for Windows user `c(username)'."
    display as error "Add this user to the bootstrap block in code/00_master.do."
    exit 601
}

capture noisily cd "${project_root}"
if _rc | !fileexists("AGENTS.md") {
    display as error "Configured project_root is not a valid repo root: ${project_root}"
    exit 601
}

do "code/01_setup.do"

log using "${LOGDIR}/00_master.log", replace text

display as text "Starting Cameroon pipeline from ${PROJECT_ROOT}"
display as text "Current stage: Cameroon elasticities, fixed-asset diagnostics, and B-READY/WBES sector constraints."

/*******************************************************************************
    Current pipeline order
*******************************************************************************/

* 1. Cameroon elasticity module setup and construction
do "${ELASTICITY_CAMEROUN_CODEDIR}/01_nacam_isic_crosswalk.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/02_nacam_data_export_mapping.do"

* 2. Checks and cleaning
do "${ELASTICITY_CAMEROUN_CODEDIR}/03_repo_checks.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/04_cmr_bdf_cleaning.do"

* 3. Administrative tax/BDF companion scale figures
do "${ELASTICITY_CAMEROUN_CODEDIR}/12_cmr_bdf_sector_scale_figures.do"

* 4. Fixed-asset coefficient figures
do "${ELASTICITY_CAMEROUN_CODEDIR}/15_cmr_fixed_asset_elasticity_figures.do"

* 5. Baseline NACAM elasticity rankings used by downstream extensions
do "${ELASTICITY_CAMEROUN_CODEDIR}/06_cmr_nacam_elasticity.do"

* 6. Administrative tax/BDF asset diagnostics
do "${ELASTICITY_CAMEROUN_CODEDIR}/11_cmr_bdf_asset_diagnostics.do"

* 7. Census cleaning and sector figures
do "${ELASTICITY_CAMEROUN_CODEDIR}/08_cmr_census_cleaning.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/08_cmr_census_sector_figures.do"

* 8. Exact-NIU Census-customs linkage
do "${ELASTICITY_CAMEROUN_CODEDIR}/14_cmr_customs_census_linkage.do"

* 9. Fixed-effect robustness source for tax/BDF comparison
do "${ELASTICITY_CAMEROUN_CODEDIR}/10_cmr_fe_robustness_plots.do"

* 10. Census turnover-employment elasticity robustness
do "${ELASTICITY_CAMEROUN_CODEDIR}/13_cmr_census_turnover_employment_elasticity.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/16_cmr_census_exporter_turnover_elasticity.do"

* 11. B-READY mapped WBES constraints by harmonized NACAM sector
do "${BREADY_WBES_CODEDIR}/03_bready_wbes_sector_constraints.do"

display as result "Cameroon analysis and B-READY/WBES constraint extension completed successfully."

log close
