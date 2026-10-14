version 17.0
clear all
set more off
do "code/01_setup.do"
capture log close firm_tests
log using "${LOGDIR}/census_isic4_firm_tests.log", text replace name(firm_tests)
tempfile original bad
import delimited using "${CAMEROONDIR}/Reference/cmr_census_firm_isic4_decisions.csv", ///
    varnames(1) stringcols(_all) encoding(utf8) bindquote(strict) clear
save "`original'"
foreach test in duplicate absent_id missing_row unknown_with_code invalid_code ///
    missing_evidence wrong_activity changed_name class_mismatch assigned_without_code {
    use "`original'", clear
    if "`test'" == "duplicate" replace firmid_census = firmid_census[1] in 2
    if "`test'" == "absent_id" replace firmid_census = "NOT_A_CENSUS_ID" in 1
    if "`test'" == "missing_row" drop in 1
    if "`test'" == "unknown_with_code" {
        replace firm_status = "unknown_unclassified" in 1
        replace firm_division = "68" in 1
    }
    if inlist("`test'", "invalid_code", "class_mismatch", "assigned_without_code") {
        replace firm_status = "assigned_census_evidence" in 1
        replace firm_division = "68" in 1
        replace firm_proposed_division = "68" in 1
        replace firm_official_class = "6820" in 1
        replace firm_official_reference = "UN French PDF 261" in 1
    }
    if "`test'" == "invalid_code" {
        replace firm_division = "04" in 1
        replace firm_proposed_division = "04" in 1
    }
    if "`test'" == "missing_evidence" replace firm_reason = "" in 1
    if "`test'" == "wrong_activity" replace review_activity = "Different activity" in 1
    if "`test'" == "changed_name" replace review_business_name = "Different name" in 1
    if "`test'" == "class_mismatch" replace firm_official_class = "2610" in 1
    if "`test'" == "assigned_without_code" replace firm_division = "" in 1
    export delimited using "`bad'", replace
    capture noisily do "${CODEDIR}/isic4_assessment/09_validate_census_firm_decisions.do" "`bad'"
    local failure = _rc
    assert inlist(`failure', 9, 459)
    display as result "Expected firm-decision rejection passed: `test'"
}
do "${CODEDIR}/isic4_assessment/09_validate_census_firm_decisions.do"

use "${DATADIR}/Analysis/cmr_census_isic4_firm_assessment.dta", clear
assert _N == 438893
isid firmid_census
isid S0Q01
assert final_division == category_final_division if category_assigned
assert mapping_source == "activity_crosswalk" if category_assigned
assert final_division == "" & assigned == 0 if mapping_source == "unknown_unclassified"
assert final_division == firm_division & !missing(firm_division) if mapping_source == "firm_review"
assert inlist(firm_status, "assigned_census_evidence", "assigned_reviewed_assumption") if mapping_source == "firm_review"
assert firm_assigned == 1 if mapping_source == "firm_review"
assert firm_mapping_merge == 3 if !category_assigned

* Compare all original assessment variables except the four intentional updates.
sort source_row
preserve
    use "${DATADIR}/Analysis/cmr_census_isic4_assessment.dta", clear
    sort source_row
    ds final_division final_division_label assigned review_status, not
    local original_vars `r(varlist)'
    save "`original'", replace
restore
cf `original_vars' using "`original'", all
count if headquarters
assert r(N) == 430011
display as result "CENSUS FIRM REVIEW TESTS COMPLETED SUCCESSFULLY"
log close firm_tests
