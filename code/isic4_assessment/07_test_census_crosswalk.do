version 17.0
clear all
set more off
do "code/01_setup.do"
capture log close census_tests
log using "${LOGDIR}/census_isic4_tests.log", text replace name(census_tests)
tempfile original bad

import delimited using "${PROJECT_ROOT}/docs/reference/cmr_census_activity_isic4_crosswalk.csv", ///
    varnames(1) stringcols(_all) encoding(utf8) bindquote(strict) clear
save "`original'"

* Each deliberate defect must fail before the validated crosswalk is saved.
foreach test in duplicate invalid_division invalid_class cross_division ///
    pending_with_final missing_reference incomplete_assigned wrong_label ///
    proposed_outside_possible {
    use "`original'", clear
    if "`test'" == "duplicate" {
        replace citi_branch = citi_branch[1] in 2
        replace activity_detail = activity_detail[1] in 2
    }
    if "`test'" == "invalid_division" replace final_division = "04" in 1
    if "`test'" == "invalid_class" replace supporting_classes = "9999" in 1
    if "`test'" == "cross_division" replace supporting_classes = supporting_classes + " 0220" in 1
    if "`test'" == "pending_with_final" {
        replace review_status = "pending_ambiguity" in 1
        replace final_division_label = "" in 1
    }
    if "`test'" == "missing_reference" replace official_pages = "" in 1
    if "`test'" == "incomplete_assigned" replace possibilities_complete = "no" in 1
    if "`test'" == "wrong_label" replace final_division_label = "Wrong label" in 1
    if "`test'" == "proposed_outside_possible" {
        * Test a known row even after human review resolves every conflict.
        replace proposed_division = "99" in 1
    }
    export delimited using "`bad'", replace
    capture noisily do "${CODEDIR}/isic4_assessment/04_validate_census_crosswalk.do" "`bad'"
    local failure = _rc
    * A missing input or a syntax error must not count as a successful rejection.
    assert inlist(`failure', 9, 459)
    display as result "Expected rejection passed: `test'"
}
do "${CODEDIR}/isic4_assessment/04_validate_census_crosswalk.do"

* Check the actual unit-level merge and the complete pair set, independently of totals.
use "${DATADIR}/Analysis/cmr_census_isic4_assessment.dta", clear
assert _N == 438893
isid S0Q01
isid source_row
assert classification_merge == 3
count if headquarters
assert r(N) == 430011
assert final_division == "" if !assigned
assert final_division != "" if assigned
foreach v in employment turnover exports {
    assert missing_`v' + parse_bad_`v' + negative_`v' + fractional_`v' + valid_`v' == 1
    assert missing(`v') if !valid_`v'
    assert hq_`v' == 0 if !headquarters | !valid_`v'
    assert hq_`v' == `v' if headquarters & valid_`v'
}
contract citi_branch activity_detail, freq(test_units)
assert _N == 273
merge 1:1 citi_branch activity_detail ///
    using "${DATADIR}/Intermediate/cmr_census_isic4_crosswalk_validated.dta", ///
    generate(check_merge)
assert check_merge == 3
display as result "CENSUS CROSSWALK TESTS COMPLETED SUCCESSFULLY"
log close census_tests
