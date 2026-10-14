version 17.0
set more off
args assessment
assert inlist("`assessment'", "", "rev1")
local suffix
local panel_suffix
if "`assessment'" == "rev1" {
    local suffix "_rev1"
    local panel_suffix "_rev1_assessment"
}
if "${PROJECT_ROOT}" == "" do "code/01_setup.do"

local checkdir "${OUTPUTDIR}/checks/tax_isic4`suffix'"
tempfile original merge_audit
tempname audit
use "${DATADIR}/Intermediate/cmr_tax_isic4_crosswalk`suffix'.dta", clear
unab category_vars : _all
local category_key nacam
local category_vars : list category_vars - category_key
use "${DATADIR}/Intermediate/cmr_tax_isic4_firm_year`suffix'.dta", clear
unab detail_vars : detail_*
postfile `audit' str8 input str12 merge_step byte merge_result long records ///
    using `merge_audit'

foreach input in source cleaned {
    if "`input'" == "source" local infile "${CAMEROONDIR}/Clean/CMR_BDF.dta"
    else local infile "${DATADIR}/Analysis/CMR_BDF_cleaned.dta"
    use "`infile'", clear
    if "`input'" == "cleaned" isid firmid fin_yr
    unab original_vars : _all
    local original_n = _N
    * Fail on stale reviewed columns rather than letting merge silently retain them.
    foreach newvar in `category_vars' `detail_vars' tax_source_row ///
        isic4_assignment_source isic4_category_status category_merge detail_merge {
        confirm new variable `newvar'
    }
    generate long tax_source_row = _n
    save `original', replace

    merge m:1 nacam using "${DATADIR}/Intermediate/cmr_tax_isic4_crosswalk`suffix'.dta", ///
        generate(category_merge)
    tab category_merge, missing
    forvalues result = 1/3 {
        quietly count if category_merge == `result'
        post `audit' ("`input'") ("category") (`result') (r(N))
    }
    drop if category_merge == 2
    assert _N == `original_n'
    replace isic4_status = "missing_source_code" if missing(nacam)
    replace isic4_status = "unmatched_source_code" if category_merge == 1 & !missing(nacam)
    generate str24 isic4_assignment_source = "unresolved"
    replace isic4_assignment_source = "category_crosswalk" if isic4_status == "unique"
    generate str32 isic4_category_status = isic4_status
    if "`assessment'" == "rev1" {
        replace correspondence_status = "unresolved" if category_merge != 3
        replace isic4_assignment_source = "category_combination" if correspondence_status == "combined"
        replace isic4_assignment_source = "partial_correspondence" if correspondence_status == "partial"
        assert missing(isic4_division) if correspondence_status != "single"
        assert revision_assumed == 1 if category_merge == 3
    }

    * Include NACAM in the key to prevent applying detail to a conflicting branch.
    merge m:1 firmid fin_yr nacam using "${DATADIR}/Intermediate/cmr_tax_isic4_firm_year`suffix'.dta", ///
        generate(detail_merge)
    tab detail_merge, missing
    forvalues result = 1/3 {
        quietly count if detail_merge == `result'
        post `audit' ("`input'") ("firm_year") (`result') (r(N))
    }
    drop if detail_merge == 2
    assert _N == `original_n'
    assert isic4_category_status == "ambiguous" if detail_merge == 3
    assert strpos(" " + isic4_possible_divisions + " ", " " + detail_isic4_division + " ") > 0 if detail_merge == 3
    replace isic4_division = detail_isic4_division if detail_merge == 3
    replace isic4_label = detail_isic4_label if detail_merge == 3
    replace isic4_status = "unique" if detail_merge == 3
    replace isic4_assignment_source = "firm_year_activity" if detail_merge == 3
    assert !missing(isic4_division) if isic4_status == "unique"
    assert missing(isic4_division) if isic4_status != "unique"
    assert !missing(isic4_status, isic4_assignment_source)

    sort tax_source_row
    cf `original_vars' using `original'
    assert _N == `original_n'
    drop tax_source_row category_merge detail_merge
    if "`input'" == "cleaned" {
        isid firmid fin_yr
        sort firmid fin_yr
        save "${DATADIR}/Analysis/CMR_BDF_isic4`panel_suffix'.dta", replace
    }
    else save "${DATADIR}/Intermediate/cmr_tax_isic4_source_audit`suffix'.dta", replace
}
postclose `audit'
use `merge_audit', clear
label define tax_merge_result 1 "Input only" 2 "Crosswalk only" 3 "Matched"
label values merge_result tax_merge_result
export delimited using "`checkdir'/merge_audit.csv", replace
display as result "Tax ISIC4 merges preserved all input rows and original variable values."
