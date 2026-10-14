version 17.0
clear all
set more off
do "code/01_setup.do"
local code "${ELASTICITY_CAMEROUN_CODEDIR}"
local real_data "${DATADIR}"
local real_cameroon "${CAMEROONDIR}"
local real_output "${OUTPUTDIR}"
local fixture "${SCRATCHDIR}/tax_isic4_tests"
foreach dir in "`fixture'" "`fixture'/Data" "`fixture'/Data/Clean" ///
    "`fixture'/Data/Intermediate" "`fixture'/Data/Analysis" ///
    "`fixture'/output" "`fixture'/output/checks" {
    capture mkdir "`dir'"
}
global DATADIR "`fixture'/Data"
global CAMEROONDIR "`fixture'/Data"
global OUTPUTDIR "`fixture'/output"
capture log close tax_isic4_tests
log using "${LOGDIR}/cmr_tax_isic4_tests.log", text replace name(tax_isic4_tests)

* Synthetic records exercise the actual builder and merge, never the real panel.
clear
input str4 firmid int fin_yr byte nacam double(totemp tot_rev)
"T001" 2020 1 10 100
"T002" 2020 31 20 200
"T003" 2020 37 . -1
"T004" 2020 . 0 0
end
save "${CAMEROONDIR}/Clean/CMR_BDF.dta", replace
save "${DATADIR}/Analysis/CMR_BDF_cleaned.dta", replace
clear
input byte nacam str20 nacam_original_label str2 isic4_division ///
    str100 isic4_label str30 isic4_status str10 isic4_possible_divisions ///
    str30 isic4_evidence str30 isic4_reason str10 isic4_review_date
1 "Fixture crops" "01" "Crop and animal production, hunting and related service activities" "unique" "01" "Synthetic source p1" "Test unique" "2026-09-28"
31 "Fixture commerce" "" "" "ambiguous" "45 46 47" "Synthetic source p2" "Test split" "2026-09-28"
37 "Fixture unknown" "" "" "insufficient_information" "" "Synthetic source p3" "Test insufficient detail" "2026-09-28"
end
tempfile good_decisions
save `good_decisions'
export delimited using "`fixture'/decisions.csv", replace
do "`code'/19_cmr_tax_isic4_crosswalk.do" "`fixture'/decisions.csv" "`fixture'/absent.csv"
do "`code'/20_cmr_tax_isic4_merge.do"
use "${DATADIR}/Analysis/CMR_BDF_isic4.dta", clear
assert _N == 4
isid firmid fin_yr
assert isic4_division == "01" if nacam == 1
assert missing(isic4_division) if nacam != 1
assert isic4_status == "ambiguous" if nacam == 31
assert isic4_status == "insufficient_information" if nacam == 37
assert isic4_status == "missing_source_code" if missing(nacam)

* Bad inputs must fail before replacing a previously validated crosswalk.
tempfile saved_bridge
use "${DATADIR}/Intermediate/cmr_tax_isic4_crosswalk.dta", clear
save `saved_bridge'
foreach fault in duplicate invalid_division absent_evidence missing_category false_unique {
    use `good_decisions', clear
    if "`fault'" == "duplicate" expand 2 in 1
    if "`fault'" == "invalid_division" replace isic4_division = "00" in 1
    if "`fault'" == "absent_evidence" replace isic4_evidence = "" in 1
    if "`fault'" == "missing_category" drop if nacam == 37
    if "`fault'" == "false_unique" replace isic4_status = "unique" if nacam == 31
    export delimited using "`fixture'/bad_decisions.csv", replace
    capture noisily do "`code'/19_cmr_tax_isic4_crosswalk.do" "`fixture'/bad_decisions.csv" "`fixture'/absent.csv"
    local result = _rc
    assert `result' != 0
    display as result "EXPECTED VALIDATION FAILURE: `fault' (`result')"
    use "${DATADIR}/Intermediate/cmr_tax_isic4_crosswalk.dta", clear
    cf _all using `saved_bridge'
}

* A documented, same-year detail can resolve an ambiguous category only.
use "${DATADIR}/Intermediate/cmr_tax_isic4_firm_year.dta", clear
set obs 1
replace firmid = "T002"
replace fin_yr = 2020
replace nacam = 31
replace detail_isic4_division = "46"
replace detail_evidence = "Synthetic detailed activity"
replace detail_reason = "Wholesale activity"
replace detail_review_date = "2026-09-28"
replace detail_link_evidence = "Exact synthetic identifier and year"
drop detail_isic4_label
tempfile good_detail
save `good_detail'
export delimited using "`fixture'/detail.csv", replace
do "`code'/19_cmr_tax_isic4_crosswalk.do" "`fixture'/decisions.csv" "`fixture'/detail.csv"
do "`code'/20_cmr_tax_isic4_merge.do"
use "${DATADIR}/Analysis/CMR_BDF_isic4.dta", clear
assert isic4_division == "46" & isic4_assignment_source == "firm_year_activity" if firmid == "T002"
assert isic4_category_status == "ambiguous" if firmid == "T002"
foreach fault in duplicate wrong_year wrong_branch conflicting_code no_link {
    use `good_detail', clear
    if "`fault'" == "duplicate" expand 2
    if "`fault'" == "wrong_year" replace fin_yr = 2021
    if "`fault'" == "wrong_branch" replace nacam = 1
    if "`fault'" == "conflicting_code" replace detail_isic4_division = "10"
    if "`fault'" == "no_link" replace detail_link_evidence = ""
    export delimited using "`fixture'/bad_detail.csv", replace
    capture noisily do "`code'/19_cmr_tax_isic4_crosswalk.do" "`fixture'/decisions.csv" "`fixture'/bad_detail.csv"
    local result = _rc
    assert `result' != 0
    display as result "EXPECTED VALIDATION FAILURE: detail `fault' (`result')"
}
* Coverage tests use the same synthetic merged files and old assignments.
capture mkdir "${OUTPUTDIR}/tables"
clear
input byte nacam str2 isic_rev4_division
1 "01"
31 ""
37 "68"
end
save "${DATADIR}/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta", replace
use "${DATADIR}/Intermediate/cmr_tax_isic4_source_audit.dta", clear
tostring totemp, replace force
replace totemp = "not_numeric" if firmid == "T001"
save "${DATADIR}/Intermediate/cmr_tax_isic4_source_audit.dta", replace
do "`code'/21_cmr_tax_isic4_coverage.do"
import delimited using "${OUTPUTDIR}/checks/tax_isic4/coverage_summary.csv", clear
assert records == 4 & firms == 4 & categories == 3 if breakdown == "overall"
assert mapped_records == 2 & gained_records == 1 & lost_records == 1 if breakdown == "overall"
assert employment == 30 & revenue == 300 if breakdown == "overall" & sample == "cleaned"
assert mapped_employment_share == 1 & mapped_revenue_share == 1 if breakdown == "overall"
import delimited using "${OUTPUTDIR}/checks/tax_isic4/numeric_value_audit.csv", clear
assert parse_failed_records == 1 if sample == "source" & variable == "totemp"
assert negative_records == 1 if variable == "tot_rev"

* No assignments and zero/all-missing denominators must not become 100% coverage.
foreach input in source cleaned {
    if "`input'" == "source" local file "${DATADIR}/Intermediate/cmr_tax_isic4_source_audit.dta"
    else local file "${DATADIR}/Analysis/CMR_BDF_isic4.dta"
    use "`file'", clear
    replace isic4_division = ""
    replace isic4_status = "ambiguous" if !missing(nacam)
    drop totemp tot_rev
    generate double totemp = 0
    generate double tot_rev = .
    save "`file'", replace
}
do "`code'/21_cmr_tax_isic4_coverage.do"
import delimited using "${OUTPUTDIR}/checks/tax_isic4/coverage_summary.csv", clear
assert mapped_records == 0
assert mapped_records_share == 0
assert employment == 0 & missing(revenue)
assert missing(mapped_employment_share) & missing(mapped_revenue_share)
global DATADIR "`real_data'"
global CAMEROONDIR "`real_cameroon'"
global OUTPUTDIR "`real_output'"
display as result "TAX ISIC4 FIXTURE TESTS COMPLETED SUCCESSFULLY"
log close tax_isic4_tests
