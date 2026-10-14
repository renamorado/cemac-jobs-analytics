version 17.0
clear all
set more off
do "code/01_setup.do"
local snapshot "${SCRATCHDIR}/tax_rev1_repeatability"
capture mkdir "`snapshot'"
log using "${LOGDIR}/cmr_tax_rev1_repeatability.log", text replace name(revrep)
* Protect input data, legacy products and the production master across both runs.
local protected_files `""${CAMEROONDIR}/Raw/TAX PANEL Update - BASE ECOFIN 2015 2022 2024-02-21 18_09_36.xlsx" "${CAMEROONDIR}/Clean/CMR_BDF.dta" "${DATADIR}/Analysis/CMR_BDF_cleaned.dta" "${DATADIR}/Analysis/CMR_BDF_isic4.dta" "${DATADIR}/Intermediate/cmr_tax_isic4_crosswalk.dta" "${DATADIR}/Intermediate/cmr_tax_isic4_firm_year.dta" "${DATADIR}/Intermediate/cmr_tax_isic4_source_audit.dta" "${PROJECT_ROOT}/docs/reference/cmr_tax_isic4_decisions.csv" "${PROJECT_ROOT}/code/00_master.do" "${OUTPUTDIR}/tables/cmr_tax_isic4_coverage.tex""'
local legacy_csv : dir "${OUTPUTDIR}/checks/tax_isic4" files "*.csv"
foreach file of local legacy_csv {
    local protected_files `"`protected_files' "${OUTPUTDIR}/checks/tax_isic4/`file'""'
}
local i 0
foreach file of local protected_files {
    local ++i
    quietly checksum "`file'"
    local original_hash`i' = r(checksum)
    local original_size`i' = r(filelen)
}
do "code/elasticity_cameroun/98_run_cmr_tax_isic4.do" rev1_assessment
local datasets cmr_tax_isic4_crosswalk_rev1 cmr_tax_isic4_firm_year_rev1 ///
    cmr_tax_isic4_source_audit_rev1 cmr_tax_revision_audit_rev1
foreach dataset of local datasets {
    copy "${DATADIR}/Intermediate/`dataset'.dta" "`snapshot'/`dataset'.dta", replace
}
copy "${DATADIR}/Analysis/CMR_BDF_isic4_rev1_assessment.dta" "`snapshot'/panel.dta", replace
local diagnostics : dir "${OUTPUTDIR}/checks/tax_isic4_rev1" files "*.csv"
local j 0
foreach file of local diagnostics {
    local ++j
    quietly checksum "${OUTPUTDIR}/checks/tax_isic4_rev1/`file'"
    local csv_hash`j' = r(checksum)
    local csv_size`j' = r(filelen)
}
foreach table in coverage groups {
    quietly checksum "${OUTPUTDIR}/tables/cmr_tax_isic4_`table'_rev1.tex"
    local tex_hash_`table' = r(checksum)
    local tex_size_`table' = r(filelen)
}
do "code/elasticity_cameroun/98_run_cmr_tax_isic4.do" rev1_assessment
foreach dataset of local datasets {
    use "${DATADIR}/Intermediate/`dataset'.dta", clear
    if _N > 0 cf _all using "`snapshot'/`dataset'.dta"
    else {
        use "`snapshot'/`dataset'.dta", clear
        assert _N == 0
    }
}
use "${DATADIR}/Analysis/CMR_BDF_isic4_rev1_assessment.dta", clear
cf _all using "`snapshot'/panel.dta"
isid firmid fin_yr
assert _N == 9068
assert missing(isic4_division) if correspondence_status != "single"
assert revision_assumed == 1
* Source-definition regressions: distinguish Rev.1 from the superseded numbering.
assert isic4_division == "16" if nacam == 17
assert isic4_group == "17+18" if nacam == 18
assert isic4_group == "36+37+38+39" if nacam == 30
assert correspondence_status == "partial" & missing(isic4_division) if nacam == 13
assert isic4_reference == "10 11 20" if nacam == 13
local j 0
foreach file of local diagnostics {
    local ++j
    quietly checksum "${OUTPUTDIR}/checks/tax_isic4_rev1/`file'"
    assert r(checksum) == `csv_hash`j'' & r(filelen) == `csv_size`j''
}
foreach table in coverage groups {
    quietly checksum "${OUTPUTDIR}/tables/cmr_tax_isic4_`table'_rev1.tex"
    assert r(checksum) == `tex_hash_`table'' & r(filelen) == `tex_size_`table''
}
local i 0
foreach file of local protected_files {
    local ++i
    quietly checksum "`file'"
    assert r(checksum) == `original_hash`i'' & r(filelen) == `original_size`i''
}
display as result "TAX REV1 REPEATABILITY AND PRESERVATION CHECKS PASSED"
log close revrep
