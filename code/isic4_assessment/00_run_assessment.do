version 17.0
clear all
set more off

/* First-stage classification inventory. Run from the repository root.
   Argument 1: current (default), or baseline for the older census workbook.
   This run validates WBES codes and inventories existing administrative
   mappings; it does not certify their activity definitions or estimate models.
*/
args census_vintage
if "`census_vintage'" == "" local census_vintage "current"
assert inlist("`census_vintage'", "current", "baseline")
do "code/01_setup.do"
* Fail before replacing assessment outputs if this run's required inputs are absent.
foreach file in ///
    "${DATADIR}/World Bank Enterprise Survey/New_Comprehensive_July_21_2025.dta" ///
    "${DATADIR}/Intermediate/wbes_wb_country_metadata.dta" ///
    "${CAMEROONDIR}/Clean/CMR_BDF.dta" ///
    "${DATADIR}/Analysis/CMR_BDF_cleaned.dta" ///
    "${DATADIR}/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta" ///
    "${PROJECT_ROOT}/docs/reference/cmr_census_activity_nacam_crosswalk.xlsx" ///
    "${PROJECT_ROOT}/docs/reference/isic_rev4_english_structure.csv" {
    confirm file "`file'"
}
if "`census_vintage'" == "baseline" {
    confirm file "${CAMEROONDIR}/Raw/CENSUS 2024 - Copy of BASE RGE 3 BANQUE MONDIALE - Copy.xlsx"
}
else {
    confirm file "${CAMEROONDIR}/Raw/CENSUS 2024 with exports BASE RGE 3 BANQUE MONDIALE exp.xlsx"
}
capture mkdir "${OUTPUTDIR}/checks"
capture mkdir "${OUTPUTDIR}/checks/isic4_assessment"
capture mkdir "${OUTPUTDIR}/tables/isic4_assessment"
capture log close _all
log using "${LOGDIR}/isic4_assessment.log", text replace

local assessment_code "${CODEDIR}/isic4_assessment"
do "`assessment_code'/01_wbes_inventory.do"
do "`assessment_code'/02_bdf_inventory.do"
do "`assessment_code'/03_census_inventory.do" "`census_vintage'"

display as result "ISIC4 initial inventory completed successfully; semantic mapping review remains pending."
log close
