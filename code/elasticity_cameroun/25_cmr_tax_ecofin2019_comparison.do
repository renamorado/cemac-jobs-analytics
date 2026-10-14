version 17.0
clear all
set more off
do "code/01_setup.do"
capture log close ecofin_compare
log using "${LOGDIR}/25_cmr_tax_ecofin2019_comparison.log", text replace name(ecofin_compare)

* Read-only comparison with INS ECOFIN 2019, annex A2, printed pp.80-81.
* The report describes its DSF classification as compatible with NACAM Rev.1
* on p.79. Counts are a dataset-link check, not individual industry assignments.
local out "${OUTPUTDIR}/checks/tax_ecofin2019"
capture mkdir "`out'"
tempfile source_counts cleaned_counts old_labels

use firmid fin_yr nacam using "${CAMEROONDIR}/Clean/CMR_BDF.dta", clear
assert !missing(firmid, fin_yr, nacam)
keep if inrange(fin_yr, 2015, 2019)
generate byte source_records = 1
egen byte source_firms = tag(nacam fin_yr firmid)
collapse (sum) source_records source_firms, by(nacam fin_yr)
isid nacam fin_yr
save `source_counts'

use firmid fin_yr nacam totemp using "${DATADIR}/Analysis/CMR_BDF_cleaned.dta", clear
isid firmid fin_yr
keep if inrange(fin_yr, 2015, 2019)
generate byte cleaned_firms = 1
generate byte employment_excluded = missing(totemp) | totemp < 0
replace totemp = . if employment_excluded
sort nacam fin_yr firmid
collapse (sum) cleaned_firms employment=totemp employment_excluded, by(nacam fin_yr)
isid nacam fin_yr
save `cleaned_counts'

import delimited using "${PROJECT_ROOT}/docs/reference/cmr_tax_isic4_decisions.csv", varnames(1) clear encoding(utf8)
keep nacam nacam_original_label
rename nacam_original_label legacy_label
isid nacam
save `old_labels'

import delimited using "${PROJECT_ROOT}/docs/reference/cmr_ecofin2019_branch_counts.csv", varnames(1) clear encoding(utf8)
isid nacam fin_yr
assert _N == 185
bysort fin_yr: assert _N == 37
bysort fin_yr: egen report_total = total(report_firms)
assert report_total == 1258 if fin_yr == 2015
assert report_total == 1256 if fin_yr == 2016
assert report_total == 1265 if fin_yr == 2017
assert report_total == 1221 if fin_yr == 2018
assert report_total == 1185 if fin_yr == 2019
drop report_total

merge 1:1 nacam fin_yr using `source_counts'
tabulate _merge
assert _merge == 3
drop _merge
merge 1:1 nacam fin_yr using `cleaned_counts'
tabulate _merge
assert _merge == 3
drop _merge
merge m:1 nacam using `old_labels'
tabulate _merge
assert _merge == 3
drop _merge

generate source_record_gap = source_records - report_firms
generate source_firm_gap = source_firms - report_firms
generate cleaned_firm_gap = cleaned_firms - report_firms
generate byte source_record_exact = source_records == report_firms
generate byte source_exact = source_firms == report_firms
generate byte cleaned_exact = cleaned_firms == report_firms
generate source_abs_gap = abs(source_firm_gap)
generate cleaned_abs_gap = abs(cleaned_firm_gap)
* This is permanent employment in the publication; our totemp definition may
* differ. Employment is supplemental evidence, not required count equality.
bysort fin_yr: egen total_employment = total(employment)
generate employment_share = 100 * employment / total_employment
sort nacam fin_yr
order nacam fin_yr report_label legacy_label report_firms source_records source_firms cleaned_firms
export delimited using "`out'/branch_year_comparison.csv", replace
list nacam report_firms source_firms cleaned_firms employment employment_share if fin_yr==2019, noobs sep(0)

collapse (sum) report_firms source_records source_firms cleaned_firms source_record_exact source_exact cleaned_exact source_abs_gap cleaned_abs_gap, by(fin_yr)
* Sums of within-branch firm counts can count a source firm in two branches
* when a conflicting firm-year exists. Cleaned firm-years are unique.
sort fin_yr
export delimited using "`out'/annual_comparison.csv", replace
list, noobs
mkmat report_firms source_records source_firms cleaned_firms source_record_exact source_exact cleaned_exact, matrix(counts) rownames(fin_yr)
esttab matrix(counts, fmt(0)) using "${OUTPUTDIR}/tables/cmr_tax_ecofin2019_comparison.tex", replace booktabs ///
    collabels("Report firms" "Source rows" "Source branch-firms" "Cleaned firms" "Exact row counts" "Exact source firm counts" "Exact cleaned counts") ///
    title("Tax panel versus INS ECOFIN 2019 sample") ///
    addnotes("37 branches per year. Source branch-firms may count conflicting codes twice; cleaned firm-years are unique." "INS ECOFIN 2019, annex A2, pp.80--81; methodology p.79 explicitly uses NACAM Rev.1-compatible DSF branches.")
display as result "ECOFIN 2019 BRANCH COMPARISON COMPLETED SUCCESSFULLY"
log close ecofin_compare
