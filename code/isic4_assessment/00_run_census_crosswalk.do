version 17.0
clear all
set more off

* Census-only assessment; run from the project root. No production data are replaced.
do "code/01_setup.do"
capture mkdir "${OUTPUTDIR}/checks"
capture mkdir "${OUTPUTDIR}/checks/census_isic4"
capture log close census_isic4
log using "${LOGDIR}/census_isic4_assessment.log", text replace name(census_isic4)

do "${CODEDIR}/isic4_assessment/04_validate_census_crosswalk.do"
do "${CODEDIR}/isic4_assessment/05_census_isic4_assessment.do"
do "${CODEDIR}/isic4_assessment/08_census_firm_inventory.do"
do "${CODEDIR}/isic4_assessment/09_validate_census_firm_decisions.do"
do "${CODEDIR}/isic4_assessment/10_apply_census_firm_decisions.do"

display as result "CENSUS ISIC4 ASSESSMENT COMPLETED SUCCESSFULLY"
log close census_isic4
