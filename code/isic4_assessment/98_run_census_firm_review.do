version 17.0
clear all
set more off
* Requires the existing category assessment; run 00 first if source/category data changed.
do "code/01_setup.do"
capture log close census_firms
log using "${LOGDIR}/census_isic4_firm_review.log", text replace name(census_firms)
do "${CODEDIR}/isic4_assessment/04_validate_census_crosswalk.do"
do "${CODEDIR}/isic4_assessment/08_census_firm_inventory.do"
do "${CODEDIR}/isic4_assessment/09_validate_census_firm_decisions.do"
do "${CODEDIR}/isic4_assessment/10_apply_census_firm_decisions.do"
display as result "CENSUS FIRM REVIEW COMPLETED SUCCESSFULLY"
log close census_firms
