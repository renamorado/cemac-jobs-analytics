version 17.0
clear all
set more off

* Default uses the existing cleaned panel. rebuild_clean explicitly regenerates
* that prerequisite with the unchanged BDF cleaning rules, without other sources.
args mode
if "`mode'" == "" local mode "current_clean"
assert inlist("`mode'", "current_clean", "rebuild_clean", "rev1_assessment", "section_assessment")
do "code/01_setup.do"
if inlist("`mode'", "rev1_assessment", "section_assessment") {
    confirm file "${DATADIR}/Analysis/CMR_BDF_cleaned.dta"
    local decisions "${PROJECT_ROOT}/docs/reference/cmr_tax_nacam_rev1_isic4_decisions.csv"
    confirm file "`decisions'"
    capture log close tax_rev1
    log using "${LOGDIR}/cmr_tax_isic4_rev1.log", text replace name(tax_rev1)
    display as text "Provisional NACAM Rev.1 assessment for 2015-2022; legacy outputs preserved."
    do "${ELASTICITY_CAMEROUN_CODEDIR}/19_cmr_tax_isic4_crosswalk.do" "`decisions'" "" rev1
    do "${ELASTICITY_CAMEROUN_CODEDIR}/22_cmr_tax_revision_audit.do"
    do "${ELASTICITY_CAMEROUN_CODEDIR}/20_cmr_tax_isic4_merge.do" rev1
    do "${ELASTICITY_CAMEROUN_CODEDIR}/21_cmr_tax_isic4_coverage.do" rev1
    display as result "TAX REV1 ASSESSMENT COMPLETED SUCCESSFULLY"
    log close tax_rev1
    if "`mode'" == "section_assessment" do "${ELASTICITY_CAMEROUN_CODEDIR}/23_cmr_tax_isic4_sections.do"
    exit
}
foreach file in ///
    "${CAMEROONDIR}/Clean/CMR_BDF.dta" ///
    "${PROJECT_ROOT}/docs/reference/cmr_tax_isic4_decisions.csv" ///
    "${PROJECT_ROOT}/docs/reference/isic_rev4_english_structure.csv" {
    confirm file "`file'"
}
if "`mode'" == "current_clean" {
    confirm file "${DATADIR}/Analysis/CMR_BDF_cleaned.dta"
    confirm file "${DATADIR}/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta"
}
capture log close tax_isic4
log using "${LOGDIR}/cmr_tax_isic4.log", text replace name(tax_isic4)
display as text "Tax ISIC4 input mode: `mode'"
if "`mode'" == "rebuild_clean" {
    do "${ELASTICITY_CAMEROUN_CODEDIR}/01_nacam_isic_crosswalk.do"
    do "${ELASTICITY_CAMEROUN_CODEDIR}/02_nacam_data_export_mapping.do"
    do "${ELASTICITY_CAMEROUN_CODEDIR}/04_cmr_bdf_cleaning.do"
}
do "${ELASTICITY_CAMEROUN_CODEDIR}/19_cmr_tax_isic4_crosswalk.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/20_cmr_tax_isic4_merge.do"
do "${ELASTICITY_CAMEROUN_CODEDIR}/21_cmr_tax_isic4_coverage.do"
display as result "TAX ISIC4 WORKFLOW COMPLETED SUCCESSFULLY"
log close tax_isic4
