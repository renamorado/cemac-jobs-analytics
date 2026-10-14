version 17.0
set more off
args census_vintage
local out "${OUTPUTDIR}/checks/isic4_assessment"
local current "${CAMEROONDIR}/Raw/CENSUS 2024 with exports BASE RGE 3 BANQUE MONDIALE exp.xlsx"
local baseline "${CAMEROONDIR}/Raw/CENSUS 2024 - Copy of BASE RGE 3 BANQUE MONDIALE - Copy.xlsx"
local source "`current'"
if "`census_vintage'" == "baseline" local source "`baseline'"
confirm file "`source'"
display as text "Census assessment source (explicit `census_vintage' mode): `source'"
local current_available = fileexists("`current'")
tempfile crosswalk census

import excel using "${PROJECT_ROOT}/docs/reference/cmr_census_activity_nacam_crosswalk.xlsx", ///
    firstrow allstring clear
isid citi_branch activity_detail
keep citi_branch activity_detail isic_reference nacam_rev1_reference ///
    mapping_note review_flag
save "`crosswalk'"

* Read original activities from raw data, rather than deriving ISIC from NACAM.
import excel using "`source'", sheet("BASE") firstrow allstring clear
keep S0Q01 S1Q13 S1Q14B SACTIV_S1Q14 BRANCHD_S1Q14 S6Q05AC S6Q01A
rename S0Q01 firmid_census
rename S1Q13 unit_status
rename S1Q14B activity_detail
rename SACTIV_S1Q14 activity_macro
rename BRANCHD_S1Q14 citi_branch
rename S6Q05AC employment_raw
rename S6Q01A revenue_raw
foreach var of varlist _all {
    replace `var' = ustrtrim(`var')
}
local source_rows = _N
isid firmid_census
generate byte one = 1
generate byte headquarters = unit_status == "Siège"
foreach var in employment revenue {
    generate byte parse_bad_`var' = !missing(`var'_raw) ///
        & missing(real(subinstr(subinstr(`var'_raw, ",", "", .), " ", "", .)))
    destring `var'_raw, generate(`var') ignore(", ") force
    generate byte negative_`var' = `var' < 0
    replace `var' = . if `var' < 0
    generate byte observed_`var' = !missing(`var')
    generate double hq_`var' = `var' if headquarters
}
generate byte positive_emp_sales = employment > 0 & revenue > 0 ///
    & !missing(employment, revenue) & headquarters
merge m:1 citi_branch activity_detail using "`crosswalk'", ///
    keep(master match) generate(crosswalk_merge)
tab crosswalk_merge, missing
assert _N == `source_rows'
generate byte old_crosswalk_matched = crosswalk_merge == 3
generate byte missing_activity = missing(activity_detail)
generate byte missing_branch = missing(citi_branch)
save "`census'"

collapse (sum) records=one headquarters employment revenue hq_employment hq_revenue ///
    observed_employment observed_revenue positive_emp_sales parse_bad_employment ///
    parse_bad_revenue negative_employment negative_revenue, ///
    by(citi_branch activity_detail activity_macro isic_reference nacam_rev1_reference ///
       mapping_note review_flag crosswalk_merge)
isid citi_branch activity_detail, missok
generate str2 reviewed_isic4_division = ""
generate str40 assessment_status = "activity_definition_review_pending"
generate str12 source_vintage = "`census_vintage'"
generate str180 source_file = "`source'"
gsort -hq_employment citi_branch activity_detail
export delimited using "`out'/census_activity_review.csv", replace

use "`census'", clear
collapse (sum) records=one old_crosswalk_matched missing_activity missing_branch ///
    employment revenue observed_employment observed_revenue positive_emp_sales ///
    parse_bad_employment parse_bad_revenue negative_employment negative_revenue, by(headquarters)
generate str12 source_vintage = "`census_vintage'"
generate byte exports_workbook_available = `current_available'
generate str180 source_file = "`source'"
export delimited using "`out'/census_source_inventory.csv", replace
display as result "Census activity inventory completed; detailed ISIC assignments remain under review."
