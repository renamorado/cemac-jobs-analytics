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
display as text "Current stage: Cameroon elasticity module checks, cleaning-note exports, BDF asset diagnostics, census diagnostics, and Census elasticity robustness."

/*******************************************************************************
    Current pipeline order
*******************************************************************************/

* 1. Cameroon elasticity module setup and construction
do "${ELASTICITY_CAMEROUN_CODEDIR}/01_nacam_isic_crosswalk.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/02_nacam_data_export_mapping.do"

* 2. Checks and cleaning
do "${ELASTICITY_CAMEROUN_CODEDIR}/03_repo_checks.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/04_cmr_bdf_cleaning.do"

* 3. Administrative tax/BDF asset diagnostics
do "${ELASTICITY_CAMEROUN_CODEDIR}/11_cmr_bdf_asset_diagnostics.do"

* 4. Census sector diagnostics
do "${ELASTICITY_CAMEROUN_CODEDIR}/08_cmr_census_sector_diagnostics.do"

* 5. Fixed-effect robustness source for tax/BDF comparison
do "${ELASTICITY_CAMEROUN_CODEDIR}/10_cmr_fe_robustness_plots.do"

* 6. Census turnover-employment elasticity robustness
do "${ELASTICITY_CAMEROUN_CODEDIR}/13_cmr_census_turnover_employment_elasticity.do"

display as result "Cameroon checks, BDF cleaning, BDF asset diagnostics, census diagnostics, and Census elasticity robustness completed successfully."

log close

