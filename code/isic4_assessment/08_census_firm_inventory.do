version 17.0
set more off
local out "${OUTPUTDIR}/checks/census_isic4"
tempfile unresolved names current_crosswalk

* Refuse to review an assessment built with different category decisions.
use "${DATADIR}/Intermediate/cmr_census_isic4_crosswalk_validated.dta", clear
keep citi_branch activity_detail final_division review_status
rename final_division current_division
rename review_status current_review_status
save "`current_crosswalk'"
use "${DATADIR}/Analysis/cmr_census_isic4_assessment.dta", clear
merge m:1 citi_branch activity_detail using "`current_crosswalk'", generate(current_merge)
assert current_merge == 3
assert final_division == current_division
assert review_status == current_review_status
keep if !assigned
keep firmid_census S0Q01 citi_branch activity_detail activity_macro possible_divisions ///
    S1Q05A S1Q05B S1Q05C S1Q13 S3Q01 FJ FORMEL headquarters ///
    employment turnover exports exporter_status source_file source_sheet source_row
isid firmid_census
local unresolved_n = _N
save "`unresolved'"

* Names and size are additional census fields, not external firm information.
import excel using "${CAMEROONDIR}/Raw/CENSUS 2024 with exports BASE RGE 3 BANQUE MONDIALE exp.xlsx", ///
    sheet("Feuil2") firstrow allstring clear
assert _N == 438893
isid S0Q01
generate firmid_census = ustrtrim(S0Q01)
isid firmid_census
rename S1Q06 business_name
rename S1Q07 trade_name
rename TYPE reported_size
rename S1Q13 names_unit_status
keep firmid_census business_name trade_name reported_size names_unit_status
compress
save "`names'"
use "`unresolved'", clear
merge 1:1 firmid_census using "`names'", generate(names_merge)
tab names_merge, missing
* Other census units are outside this review, not dropped from the assessment.
drop if names_merge == 2
assert names_merge == 3
assert _N == `unresolved_n'
assert ustrtrim(S1Q13) == ustrtrim(names_unit_status)
drop names_merge names_unit_status
gsort -employment firmid_census
order firmid_census citi_branch activity_detail business_name trade_name ///
    possible_divisions FJ FORMEL reported_size headquarters employment turnover exports
save "${DATADIR}/Intermediate/cmr_census_isic4_firm_inventory.dta", replace
export delimited using "`out'/census_firm_review_inventory.csv", replace
display as result "Firm review inventory exported; saved decisions were not edited."
