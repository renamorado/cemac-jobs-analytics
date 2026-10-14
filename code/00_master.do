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

log using "${LOGDIR}/00_master.log", replace text name(cemac_master)

display as text "Starting ISIC Rev.4 slide pipeline from ${PROJECT_ROOT}"

* Preserve existing accounting cleaning and original NACAM source fields.
do "${ELASTICITY_CAMEROUN_CODEDIR}/01_nacam_isic_crosswalk.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/02_nacam_data_export_mapping.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/03_repo_checks.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/04_cmr_bdf_cleaning.do"

* Build the reviewed Rev.1 tax crosswalk and the agreed 16 section groups.
do "${CODEDIR}/02_construct/01_isic4_broad_groups.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/19_cmr_tax_isic4_crosswalk.do" "${PROJECT_ROOT}/docs/reference/cmr_tax_nacam_rev1_isic4_decisions.csv" "" rev1
do "${ELASTICITY_CAMEROUN_CODEDIR}/22_cmr_tax_revision_audit.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/20_cmr_tax_isic4_merge.do" rev1
do "${ELASTICITY_CAMEROUN_CODEDIR}/21_cmr_tax_isic4_coverage.do" rev1
do "${ELASTICITY_CAMEROUN_CODEDIR}/23_cmr_tax_isic4_sections.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/17_cmr_bdf_elasticity_prep.do"

* Tax firm-year models, section summaries and robustness outputs.
do "${ELASTICITY_CAMEROUN_CODEDIR}/12_cmr_bdf_sector_scale_figures.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/15_cmr_fixed_asset_elasticity_figures.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/06_cmr_nacam_elasticity.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/11_cmr_bdf_asset_diagnostics.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/09_cmr_duplicate_robustness.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/10_cmr_fe_robustness_plots.do"

* Census division results plus the additional section comparison with tax.
do "${ELASTICITY_CAMEROUN_CODEDIR}/08_cmr_census_cleaning.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/18_cmr_census_elasticity_prep.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/08_cmr_census_sector_figures.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/14_cmr_customs_census_linkage.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/13_cmr_census_turnover_employment_elasticity.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/16_cmr_census_exporter_turnover_elasticity.do"

* WBES country comparisons and division-specific Cameroon estimates.
do "${WBES_TRADE_CODEDIR}/01_wbes_trade_clean_prep.do"
do "${WBES_TRADE_CODEDIR}/02_wbes_trade_descriptive_stats.do"
do "${WBES_TRADE_CODEDIR}/02_wbes_trade_plots.do"
do "${WBES_TRADE_CODEDIR}/05_wbes_elasticity_prep.do"
do "${WBES_TRADE_CODEDIR}/03_wbes_trade_elasticity.do"
do "${WBES_TRADE_CODEDIR}/04_wbes_revenue_exporter_interaction.do"

* Link WBES constraints to the corresponding tax section groups.
do "${BREADY_WBES_CODEDIR}/03_bready_wbes_sector_constraints.do"
do "${CODEDIR}/05_checks/07_isic4_slide_checks.do"

display as result "ISIC REV4 SLIDE PIPELINE COMPLETED SUCCESSFULLY"
log close cemac_master
