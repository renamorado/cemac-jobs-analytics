version 17.0
clear all
set more off
do "code/01_setup.do"
capture log close broadchecks
log using "${LOGDIR}/isic4_broad_groups_checks.log", text replace name(broadchecks)
tempfile codes sections
do "${CODEDIR}/02_construct/01_isic4_broad_groups.do"
use "${DATADIR}/Intermediate/isic4_broad_groups_codes.dta", clear
assert _N == 766
isid isic4_code
save `codes'
use "${DATADIR}/Intermediate/isic4_broad_groups_sections.dta", clear
isid isic4_section
save `sections'
do "${CODEDIR}/02_construct/01_isic4_broad_groups.do"
use "${DATADIR}/Intermediate/isic4_broad_groups_codes.dta", clear
cf _all using `codes'
use "${DATADIR}/Intermediate/isic4_broad_groups_sections.dta", clear
cf _all using `sections'
display as result "ISIC4 BROAD DISPLAY GROUP REPEATABILITY CHECKS PASSED"
log close broadchecks
