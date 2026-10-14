version 17.0
set more off
args decision_file
if `"`decision_file'"' == "" local decision_file "${CAMEROONDIR}/Reference/cmr_census_firm_isic4_decisions.csv"
confirm file "`decision_file'"
tempfile divisions decisions
import delimited using "${PROJECT_ROOT}/docs/reference/isic_rev4_english_structure.csv", ///
    varnames(1) stringcols(_all) encoding(utf8) clear
levelsof code if strlen(code) == 2, local(valid_divisions) clean
levelsof code if strlen(code) == 4, local(valid_classes) clean
keep if strlen(code) == 2
rename code firm_division
rename description firm_division_label
isid firm_division
save "`divisions'"

* Keep identifiers as strings: census IDs exceed exact numeric precision.
import delimited using "`decision_file'", varnames(1) stringcols(_all) ///
    encoding(utf8) bindquote(strict) clear
isid firmid_census
assert firmid_census == ustrtrim(firmid_census)
assert inlist(firm_status, "assigned_census_evidence", "assigned_reviewed_assumption", "unknown_unclassified")
generate byte firm_assigned = inlist(firm_status, "assigned_census_evidence", "assigned_reviewed_assumption")
assert !missing(firm_reason, firm_evidence_fields, firm_reviewer, firm_review_date)
assert inlist(firm_branch_conflict, "yes", "no")
assert !missing(firm_division, firm_official_class, firm_official_reference) ///
    if firm_assigned
assert firm_division == "" if !firm_assigned
assert firm_proposed_division == firm_division if firm_assigned
forvalues i = 1/`=_N' {
    local proposal = firm_proposed_division[`i']
    local division = firm_division[`i']
    if "`proposal'" != "" assert `: list proposal in valid_divisions'
    if "`division'" != "" {
        assert `: list division in valid_divisions'
        local classes = firm_official_class[`i']
        foreach code of local classes {
            assert `: list code in valid_classes'
            assert substr("`code'", 1, 2) == "`division'"
        }
    }
}
merge m:1 firm_division using "`divisions'", generate(label_merge)
drop if label_merge == 2
assert label_merge == 3 if firm_assigned
drop label_merge
save "`decisions'"

* Exactly one decision per unresolved unit; compare recorded evidence to the census.
use "${DATADIR}/Intermediate/cmr_census_isic4_firm_inventory.dta", clear
local inventory_n = _N
merge 1:1 firmid_census using "`decisions'", generate(firm_decision_merge)
tab firm_decision_merge, missing
assert firm_decision_merge == 3
assert _N == `inventory_n'
assert review_activity == activity_detail
assert review_branch == citi_branch
assert review_business_name == business_name
assert review_trade_name == trade_name
keep firmid_census firm_* review_activity review_branch review_business_name review_trade_name
sort firmid_census
save "${DATADIR}/Intermediate/cmr_census_firm_isic4_decisions.dta", replace
