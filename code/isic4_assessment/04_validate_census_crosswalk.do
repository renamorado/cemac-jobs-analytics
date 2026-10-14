version 17.0
set more off
* Optional alternate CSV is for validation tests; this script never edits decisions.
args crosswalk_file
if `"`crosswalk_file'"' == "" local crosswalk_file "${PROJECT_ROOT}/docs/reference/cmr_census_activity_isic4_crosswalk.csv"
tempfile divisions
import delimited using "${PROJECT_ROOT}/docs/reference/isic_rev4_english_structure.csv", ///
    varnames(1) stringcols(_all) encoding(utf8) clear
isid code
levelsof code if strlen(code) == 4, local(classes) clean
levelsof code if strlen(code) == 2, local(divisions_list) clean
keep if strlen(code) == 2
assert _N == 88
rename code final_division
rename description official_label
save "`divisions'"

import delimited using "`crosswalk_file'", varnames(1) stringcols(_all) ///
    encoding(utf8) bindquote(strict) clear
compress
isid citi_branch activity_detail
assert _N == 273
assert !missing(official_reference, official_pages, official_url, reasoning, reviewer, review_date)
assert inlist(review_status, "assigned_first_pass", "assigned_reviewed", ///
    "pending_ambiguity", "pending_incomplete", "pending_conflict")
assert inlist(possibilities_complete, "yes", "no")
generate byte assigned = inlist(review_status, "assigned_first_pass", "assigned_reviewed")
assert !missing(final_division) if assigned
assert final_division == "" & final_division_label == "" if !assigned
assert possibilities_complete == "yes" if assigned
assert final_division == proposed_division if assigned

* Check every possibility, not just the first class in the list.
forvalues i = 1/`=_N' {
    local proposed = proposed_division[`i']
    if "`proposed'" != "" {
        assert `: list proposed in divisions_list'
    }
    local possible = possible_divisions[`i']
    assert "`possible'" != ""
    if "`proposed'" != "" assert `: list proposed in possible'
    foreach d of local possible {
        assert `: list d in divisions_list'
    }
    if assigned[`i'] {
        assert `: word count `possible'' == 1
        assert "`possible'" == final_division[`i']
    }
    local detail = supporting_classes[`i']
    assert "`detail'" != ""
    foreach c of local detail {
        assert `: list c in classes'
        local d = substr("`c'", 1, 2)
        assert `: list d in possible'
        if assigned[`i'] assert "`d'" == final_division[`i']
    }
}
merge m:1 final_division using "`divisions'", generate(label_merge)
tab label_merge, missing
* Unused official divisions are lookup rows, never census observations.
drop if label_merge == 2
assert label_merge == 3 if assigned
assert final_division_label == official_label if assigned
assert _N == 273
drop official_label label_merge
sort citi_branch activity_detail
save "${DATADIR}/Intermediate/cmr_census_isic4_crosswalk_validated.dta", replace
