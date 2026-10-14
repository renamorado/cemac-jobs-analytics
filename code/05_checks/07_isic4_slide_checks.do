version 17.0
set more off
do "code/01_setup.do"
capture log close isic4slidescheck
log using "${LOGDIR}/07_isic4_slide_checks.log", text replace name(isic4slidescheck)

* Preparation must preserve every original tax field and unique firm-year.
use "${DATADIR}/Analysis/CMR_BDF_cleaned.dta", clear
sort firmid fin_yr
isid firmid fin_yr
unab original_fields : _all
tempfile original_tax
save `original_tax'
local tax_rows = _N
use "${DATADIR}/Analysis/CMR_BDF_isic4_section_prepared.dta", clear
sort firmid fin_yr
isid firmid fin_yr
assert _N == `tax_rows'
cf `original_fields' using `original_tax'
assert !missing(isic4_section, isic4_sector_id)
bysort isic4_section: assert isic4_sector_id == isic4_sector_id[1]
egen byte group_tag = tag(isic4_section)
count if group_tag
assert r(N) == 16
assert isic4_section == "B" if inlist(nacam, 5, 6)
assert isic4_section == "A" if nacam == 9
assert isic4_section == "C" if nacam == 21
assert isic4_section == "D" if nacam == 29
assert isic4_section == "L" if nacam == 37
assert isic4_section == "M+N" if nacam == 38
assert isic4_section == "R+S+T" if nacam == 42

* Census preparation retains all cleaned units, including unknown activities.
use "${DATADIR}/Analysis/CMR_census_cleaned.dta", clear
sort firmid_census
isid firmid_census
unab original_fields : _all
tempfile original_census
save `original_census'
local census_rows = _N
use "${DATADIR}/Analysis/cmr_census_isic4_division_elasticity_clean.dta", clear
sort firmid_census
isid firmid_census
assert _N == `census_rows'
cf `original_fields' using `original_census'
assert isic4_sector_id == real(isic4_division)
assert sample_elasticity == 0 if missing(isic4_division) | hq_sample != 1
assert sample_elasticity == 1 if hq_sample == 1 & !missing(isic4_division) ///
    & !missing(employment, annual_turnover) & employment > 0 & annual_turnover > 0
assert isic4_section_compare == "" if isic4_division == "98"
assert isic4_section_compare == "M+N" if inlist(isic4_section, "M", "N")
assert isic4_section_compare == "R+S+T" ///
    if inlist(isic4_section, "R", "S") | isic4_division == "97"
tab legacy_sample_elasticity sample_elasticity if hq_sample, missing

* Cross-dataset matches use readable section keys, not independently encoded IDs.
use "${DATADIR}/Analysis/cmr_census_vs_bdf_isic4_section_turnover_employment_elasticity.dta", clear
isid isic4_section
assert comparison_sample == 0 if bdf_merge != 3
assert !missing(census_elasticity, bdf_tot_rev_elasticity) if comparison_sample
count if comparison_sample
assert r(N) > 1
display as result "Census-Ecofin comparison groups: " r(N)

* WBES preparation preserves original values within the existing display sample.
use "${DATADIR}/Analysis/wbes_trade_clean.dta", clear
isid firm_id
unab original_fields : _all
keep if (cemac_country == 1 & country_name != "Gabon") ///
    | (strpos(wb_region, "Sub-Saharan Africa") > 0 & cemac_country != 1) ///
    | strpos(wb_income_group, "High income") > 0
sort firm_id
local wbes_rows = _N
tempfile original_wbes
save `original_wbes'
use "${DATADIR}/Analysis/wbes_elasticity_clean.dta", clear
isid firm_id
sort firm_id
assert _N == `wbes_rows'
cf `original_fields' using `original_wbes'

* Each reported B-READY cell links a weighted WBES mean to one tax group.
use "${DATADIR}/Analysis/bready_wbes_isic4_section_cmr_constraints.dta", clear
keep if result_level == "sector"
isid indicator isic4_sector_id
assert high_elasticity == (revenue_decile >= 7)
assert !missing(tot_rev_elasticity, avg_annual_total_employment)
assert inrange(employment_size_tercile, 1, 3)
assert missing(estimate) if sample_n == 0
bysort isic4_sector_id: assert employment_size_tercile == employment_size_tercile[1]

display as result "ISIC REV4 SLIDE CHECKS COMPLETED SUCCESSFULLY"
log close isic4slidescheck
