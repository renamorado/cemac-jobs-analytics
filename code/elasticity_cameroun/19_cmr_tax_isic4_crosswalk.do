version 17.0
set more off

* Reviewed decisions are inputs, separate from the preliminary NACAM bridge.
* Optional arguments support reviewing a replacement decision/intake file.
args decisions_file detail_file assessment
assert inlist("`assessment'", "", "rev1")
local suffix
if "`assessment'" == "rev1" local suffix "_rev1"
if "${PROJECT_ROOT}" == "" do "code/01_setup.do"
if `"`decisions_file'"' == "" local decisions_file "${PROJECT_ROOT}/docs/reference/cmr_tax_isic4_decisions.csv"
if `"`detail_file'"' == "" local detail_file "${CAMEROONDIR}/Classification/cmr_tax_isic4_firm_year.csv"
local checkdir "${OUTPUTDIR}/checks/tax_isic4`suffix'"
capture mkdir "${OUTPUTDIR}/checks"
capture mkdir "`checkdir'"
tempfile divisions observed bridge details source_keys

import delimited using "${PROJECT_ROOT}/docs/reference/isic_rev4_english_structure.csv", ///
    clear varnames(1) stringcols(_all) encoding("utf-8")
keep if strlen(code) == 2
rename code isic4_division
rename description official_isic4_label
assert regexm(isic4_division, "^[0-9][0-9]$")
isid isic4_division
levelsof isic4_division, local(valid_divisions) clean
save `divisions'

use nacam firmid fin_yr using "${CAMEROONDIR}/Clean/CMR_BDF.dta", clear
preserve
keep nacam
drop if missing(nacam)
duplicates drop
isid nacam
save `observed'
restore
keep firmid fin_yr nacam
duplicates drop
save `source_keys'

import delimited using `"`decisions_file'"', clear varnames(1) ///
    stringcols(_all) bindquotes(strict) encoding("utf-8")
foreach v in nacam nacam_original_label isic4_division isic4_label isic4_status ///
    isic4_possible_divisions isic4_evidence isic4_reason isic4_review_date {
    confirm string variable `v'
    assert `v' == strtrim(`v')
}
destring nacam, replace
isid nacam
assert !missing(nacam_original_label, isic4_evidence, isic4_reason, isic4_review_date)
assert !missing(daily(isic4_review_date, "YMD"))
assert inlist(isic4_status, "unique", "ambiguous", "insufficient_information")
assert !missing(isic4_division, isic4_label) if isic4_status == "unique"
assert missing(isic4_division) & missing(isic4_label) if isic4_status != "unique"
assert isic4_possible_divisions == isic4_division if isic4_status == "unique"
assert wordcount(isic4_possible_divisions) >= 2 if isic4_status == "ambiguous"
forvalues row = 1/`=_N' {
    local possible = isic4_possible_divisions[`row']
    local distinct : list uniq possible
    assert "`possible'" == "`distinct'" in `row'
    foreach division of local possible {
        local valid : list division in valid_divisions
        assert `valid' == 1 in `row'
    }
}
merge m:1 isic4_division using `divisions', generate(label_merge)
assert label_merge == 3 if !missing(isic4_division) & label_merge != 2
assert isic4_label == official_isic4_label if label_merge == 3
drop if label_merge == 2
drop label_merge official_isic4_label
merge 1:1 nacam using `observed', generate(observed_merge)
tab observed_merge, missing
assert observed_merge == 3
drop observed_merge
if "`assessment'" == "rev1" {
    foreach v in correspondence_status tax_sector_label isic4_reference isic4_group {
        confirm string variable `v'
        assert `v' == strtrim(`v')
    }
    assert inlist(correspondence_status, "single", "combined", "partial", "unresolved")
    assert correspondence_status == "single" if isic4_status == "unique"
    assert isic4_status == "unique" if correspondence_status == "single"
    assert isic4_reference == isic4_possible_divisions
    assert !missing(tax_sector_label)
    assert wordcount(isic4_reference) >= 2 if inlist(correspondence_status, "combined", "partial")
    assert isic4_group == subinstr(isic4_reference, " ", "+", .) if correspondence_status == "combined"
    assert missing(isic4_group) if correspondence_status != "combined"
    generate str12 source_revision = "NACAM Rev.1"
    generate byte revision_assumed = 1
    generate str40 revision_basis = "Provisional across 2015-2022"
    generate str5 tax_sector_id = "T" + string(nacam, "%02.0f")
    label variable revision_assumed "Revision assumed, not certified by source dictionary"
}
recast str2 isic4_division
label variable isic4_division "Reviewed ISIC Rev.4 division; blank when unresolved"
label variable isic4_status "Reviewed category mapping status"
sort nacam
save `bridge'

* Optional private intake: never infer a firm activity from a name or another year.
capture confirm file `"`detail_file'"'
local detail_intake_present = (_rc == 0)
* Rev.1 assessment uses only category evidence; legacy detail intake is not portable.
if "`assessment'" == "rev1" local detail_intake_present 0
if `detail_intake_present' {
    import delimited using `"`detail_file'"', clear varnames(1) ///
        stringcols(_all) bindquotes(strict) encoding("utf-8")
    foreach v in firmid fin_yr nacam detail_isic4_division detail_evidence ///
        detail_reason detail_review_date detail_link_evidence {
        confirm string variable `v'
        assert `v' == strtrim(`v')
    }
    destring fin_yr nacam, replace
    isid firmid fin_yr
    assert !missing(firmid, fin_yr, nacam)
    assert !missing(detail_evidence, detail_reason, detail_link_evidence)
    assert !missing(daily(detail_review_date, "YMD"))
    assert regexm(detail_isic4_division, "^[0-9][0-9]$")
    rename detail_isic4_division isic4_division
    merge m:1 isic4_division using `divisions', generate(detail_label_merge)
    assert detail_label_merge == 3 if detail_label_merge != 2
    drop if detail_label_merge == 2
    drop detail_label_merge
    rename (isic4_division official_isic4_label) (detail_isic4_division detail_isic4_label)
    merge m:1 nacam using `bridge', generate(detail_branch_merge)
    assert detail_branch_merge == 3 if detail_branch_merge != 2
    drop if detail_branch_merge == 2
    * Unique categories cannot be overridden. Disagreement requires category review.
    assert isic4_status == "ambiguous"
    assert strpos(" " + isic4_possible_divisions + " ", " " + detail_isic4_division + " ") > 0
    keep firmid fin_yr nacam detail_*
    merge 1:1 firmid fin_yr nacam using `source_keys', generate(detail_key_merge)
    assert detail_key_merge == 3 if detail_key_merge != 2
    drop if detail_key_merge == 2
    drop detail_key_merge
    isid firmid fin_yr
}
else {
    clear
    set obs 0
    generate str10 firmid = ""
    generate int fin_yr = .
    generate byte nacam = .
    generate str2 detail_isic4_division = ""
    generate str120 detail_isic4_label = ""
    foreach v in evidence reason review_date link_evidence {
        generate str244 detail_`v' = ""
    }
}
sort firmid fin_yr
save `details'
local detail_rows = _N

* Publish only after both the category and optional firm-year inputs pass checks.
use `bridge', clear
save "${DATADIR}/Intermediate/cmr_tax_isic4_crosswalk`suffix'.dta", replace
export delimited using "`checkdir'/reviewed_categories.csv", replace
use `details', clear
save "${DATADIR}/Intermediate/cmr_tax_isic4_firm_year`suffix'.dta", replace
clear
set obs 1
generate byte intake_file_present = `detail_intake_present'
generate long verified_assignments = `detail_rows'
export delimited using "`checkdir'/detail_intake_summary.csv", replace
display as result "Reviewed tax ISIC4 crosswalk validated successfully."
