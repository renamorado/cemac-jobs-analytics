version 17.0
clear all
set more off
do "code/01_setup.do"
capture log close census_clean_isic4_tests
log using "${LOGDIR}/census_cleaning_isic4_tests.log", text replace name(census_clean_isic4_tests)
tempfile expected
use "${DATADIR}/Analysis/cmr_census_isic4_firm_assessment.dta", clear
keep firmid_census final_division final_division_label mapping_source review_status assigned
rename final_division expected_division
rename final_division_label expected_label
rename mapping_source expected_source
rename review_status expected_status
rename assigned expected_assigned
isid firmid_census
save "`expected'"
use "${DATADIR}/Analysis/CMR_census_cleaned.dta", clear
assert _N == 438893
isid firmid_census
merge 1:1 firmid_census using "`expected'", generate(test_merge)
assert test_merge == 3
assert isic4_division == expected_division
assert isic4_division_label == expected_label
assert isic4_mapping_source == expected_source
assert isic4_review_status == expected_status
assert isic4_assigned == expected_assigned
assert isic4_division == "" if !isic4_assigned
count if hq_sample
assert r(N) == 430011
display as result "CENSUS CLEANING ISIC4 TESTS COMPLETED SUCCESSFULLY"
log close census_clean_isic4_tests
