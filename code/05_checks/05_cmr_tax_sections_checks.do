version 17.0
clear all
set more off
do "code/01_setup.do"
capture log close sectionchecks
log using "${LOGDIR}/cmr_tax_sections_checks.log", text replace name(sectionchecks)
tempfile panel bridge

* Preserve the existing cleaned input, legacy panel, master and estimation code.
local protected `""${DATADIR}/Analysis/CMR_BDF_cleaned.dta" "${DATADIR}/Analysis/CMR_BDF_isic4.dta" "${PROJECT_ROOT}/code/00_master.do" "${ELASTICITY_CAMEROUN_CODEDIR}/06_cmr_nacam_elasticity.do""'
local j 0
foreach file of local protected {
    local ++j
    quietly checksum "`file'"
    local before`j' = r(checksum)
    local size`j' = r(filelen)
}
do "code/elasticity_cameroun/98_run_cmr_tax_isic4.do" section_assessment
use "${DATADIR}/Intermediate/cmr_tax_isic4_sections_crosswalk.dta", clear
assert _N == 37
isid nacam
count if section_status == "single_section"
assert r(N) == 29
count if section_status == "combined_sections"
assert r(N) == 2
count if section_status == "boundary_exception"
assert r(N) == 0
count if section_status == "analytical_assignment"
assert r(N) == 6
assert missing(isic4_section_strict) & missing(isic4_section_strict_label) if section_status == "analytical_assignment"
assert isic4_section == "B" & section_refs == "B+C" if nacam == 6
assert isic4_section == "A" & section_refs == "A+C" if nacam == 9
assert isic4_section == "C" & section_refs == "A+C" if nacam == 21
assert isic4_section == "D" & section_refs == "C+D" if nacam == 29
assert isic4_section == "L" & section_refs == "F+L" if nacam == 37
assert isic4_section_strict == "I" if nacam == 33
assert isic4_section_strict == "C" if inlist(nacam, 13, 19, 24)
assert isic4_section == "M+N" & missing(isic4_section_strict) if nacam == 38
assert section_refs == "B+C+H" & isic4_section == "B" & missing(isic4_section_strict) if nacam == 5
assert section_division_refs == "90 91 92 93 94 95 96 97" if nacam == 42
save `bridge'
use "${DATADIR}/Analysis/CMR_BDF_isic4_sections_assessment.dta", clear
isid firmid fin_yr
assert _N == 9068
assert !missing(isic4_section, isic4_section_label)
assert isic4_section == tax_section_group & isic4_section_label == tax_section_label
egen byte analysis_group_tag = tag(isic4_section)
count if analysis_group_tag
assert r(N) == 16
drop analysis_group_tag
assert revision_assumed == 1
assert missing(isic4_division) if inlist(nacam, 13, 19, 24)
assert missing(isic4_division) & missing(isic4_section_strict) if inlist(nacam, 5, 6, 9, 21, 29, 37)
assert isic4_section == "B" if inlist(nacam, 5, 6)
assert inlist(nacam, 5, 6) if isic4_section == "B"
quietly summarize totemp if inlist(nacam, 5, 6) & totemp >= 0, meanonly
local mining_total = r(sum)
quietly summarize totemp if inlist(nacam, 1, 2, 3, 9) & totemp >= 0, meanonly
local agriculture_total = r(sum)
quietly summarize totemp if isic4_section == "C" & totemp >= 0, meanonly
local manufacturing_total = r(sum)
save `panel'
quietly summarize totemp if totemp >= 0, meanonly
local employment_total = r(sum)
quietly summarize tot_rev if tot_rev >= 0, meanonly
local revenue_total = r(sum)
local checks "${OUTPUTDIR}/checks/tax_isic4_sections"
local csvs "shares.csv crosswalk_with_shares.csv boundary_exceptions.csv analytical_assignments.csv merge_audit.csv"
local k 0
foreach csv of local csvs {
    local ++k
    quietly checksum "`checks'/`csv'"
    local csvhash`k' = r(checksum)
}
quietly checksum "${OUTPUTDIR}/tables/cmr_tax_isic4_sections_preview.tex"
local texhash = r(checksum)
do "code/elasticity_cameroun/23_cmr_tax_isic4_sections.do"
use "${DATADIR}/Analysis/CMR_BDF_isic4_sections_assessment.dta", clear
cf _all using `panel'
use "${DATADIR}/Intermediate/cmr_tax_isic4_sections_crosswalk.dta", clear
cf _all using `bridge'
local k 0
foreach csv of local csvs {
    local ++k
    quietly checksum "`checks'/`csv'"
    display as text "Checking repeatability: `csv'"
    assert r(checksum) == `csvhash`k''
}
quietly checksum "${OUTPUTDIR}/tables/cmr_tax_isic4_sections_preview.tex"
assert r(checksum) == `texhash'
local j 0
foreach file of local protected {
    local ++j
    quietly checksum "`file'"
    assert r(checksum) == `before`j'' & r(filelen) == `size`j''
}
import delimited using "`checks'/shares.csv", clear varnames(1)
keep if breakdown == "group"
assert _N == 16
isid isic4_section
assert categories == 2 & qualified_group == 1 if isic4_section == "B"
assert abs(employment - `mining_total') < 0.001 if isic4_section == "B"
assert categories == 4 & qualified_group == 1 if isic4_section == "A"
assert categories == 18 & qualified_group == 1 if isic4_section == "C"
assert abs(employment - `agriculture_total') < 0.001 if isic4_section == "A"
assert abs(employment - `manufacturing_total') < 0.001 if isic4_section == "C"
quietly summarize employment, meanonly
assert abs(r(sum) - `employment_total') < 0.001
quietly summarize revenue, meanonly
assert abs(r(sum) - `revenue_total') < 1
foreach measure in records employment revenue {
    quietly summarize `measure'_pct, meanonly
    assert abs(r(sum) - 100) < 0.00001
}
display as result "TAX SECTION REPEATABILITY AND PRESERVATION CHECKS PASSED"
log close sectionchecks
