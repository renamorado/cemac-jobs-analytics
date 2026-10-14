version 17.0
clear all
set more off
do "code/01_setup.do"
local code "${ELASTICITY_CAMEROUN_CODEDIR}"
local fixture "${SCRATCHDIR}/tax_rev1_tests"
foreach dir in "`fixture'" "`fixture'/Data" "`fixture'/Data/Clean" ///
    "`fixture'/Data/Intermediate" "`fixture'/Data/Analysis" "`fixture'/output" ///
    "`fixture'/output/checks" "`fixture'/output/tables" {
    capture mkdir "`dir'"
}
global DATADIR "`fixture'/Data"
global CAMEROONDIR "`fixture'/Data"
global OUTPUTDIR "`fixture'/output"
log using "${LOGDIR}/cmr_tax_rev1_tests.log", text replace name(revtest)
clear
input str4 firmid int fin_yr byte nacam double(totemp tot_rev)
"T001" 2020 40 10 100
"T002" 2020 33 20 200
"T003" 2020 5 -1 .
"T004" 2020 37 . -20
"T005" 2020 . 0 0
end
save "${CAMEROONDIR}/Clean/CMR_BDF.dta", replace
save "${DATADIR}/Analysis/CMR_BDF_cleaned.dta", replace
clear
input byte nacam str20 nacam_original_label str2 isic4_division str50 isic4_label ///
    str30 isic4_status str20 isic4_possible_divisions str15 correspondence_status
40 "Education" "85" "Education" "unique" "85" "single"
33 "Hospitality" "" "" "ambiguous" "55 56" "combined"
5 "Extraction" "" "" "ambiguous" "05 06 09" "partial"
37 "Unknown" "" "" "insufficient_information" "" "unresolved"
end
generate str30 tax_sector_label = nacam_original_label
generate str20 isic4_reference = isic4_possible_divisions
generate str20 isic4_group = "55+56" if correspondence_status == "combined"
generate str50 isic4_evidence = "Synthetic source p1"
generate str50 isic4_reason = "Synthetic classification fixture"
generate str10 isic4_review_date = "2026-09-29"
tempfile good bridge
save `good'
export delimited using "`fixture'/good.csv", replace
do "`code'/19_cmr_tax_isic4_crosswalk.do" "`fixture'/good.csv" "" rev1
use "${DATADIR}/Intermediate/cmr_tax_isic4_crosswalk_rev1.dta", clear
save `bridge'
foreach fault in duplicate invalid_code missing_evidence mixed_strict partial_group wrong_group missing_category {
    use `good', clear
    if "`fault'" == "duplicate" expand 2 in 1
    if "`fault'" == "invalid_code" replace isic4_possible_divisions = "00 06" if nacam == 5
    if "`fault'" == "missing_evidence" replace isic4_evidence = "" in 1
    if "`fault'" == "mixed_strict" replace isic4_division = "55" if nacam == 33
    if "`fault'" == "partial_group" replace isic4_group = "05+06+09" if nacam == 5
    if "`fault'" == "wrong_group" replace isic4_group = "55+57" if nacam == 33
    if "`fault'" == "missing_category" drop if nacam == 37
    export delimited using "`fixture'/bad.csv", replace
    capture noisily do "`code'/19_cmr_tax_isic4_crosswalk.do" "`fixture'/bad.csv" "" rev1
    local result = _rc
    assert `result' != 0
    display as result "EXPECTED REV1 VALIDATION FAILURE: `fault' (`result')"
    use "${DATADIR}/Intermediate/cmr_tax_isic4_crosswalk_rev1.dta", clear
    cf _all using `bridge'
}
do "`code'/20_cmr_tax_isic4_merge.do" rev1
use "${DATADIR}/Analysis/CMR_BDF_isic4_rev1_assessment.dta", clear
assert _N == 5
isid firmid fin_yr
assert isic4_division == "85" if nacam == 40
assert missing(isic4_division) if nacam != 40
assert isic4_group == "55+56" if nacam == 33
assert correspondence_status == "partial" & missing(isic4_group) if nacam == 5
assert correspondence_status == "unresolved" if missing(nacam)
assert revision_assumed == 1 if !missing(nacam)
do "`code'/21_cmr_tax_isic4_coverage.do" rev1
import delimited using "${OUTPUTDIR}/checks/tax_isic4_rev1/coverage_summary.csv", clear
keep if sample == "cleaned" & breakdown == "overall"
assert _N == 1
assert records == 5 & mapped_records == 1 & combined_records == 1
assert partial_records == 1 & pending_records == 2 & covered_records == 2
assert employment == 30 & revenue == 300
assert employment_negative == 1 & revenue_negative == 1
assert covered_employment_share == 1 & covered_revenue_share == 1
display as result "TAX REV1 FIXTURE TESTS COMPLETED SUCCESSFULLY"
log close revtest
