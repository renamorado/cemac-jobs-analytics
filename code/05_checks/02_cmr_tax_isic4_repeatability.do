version 17.0
clear all
set more off

* Validate the actual tax-only workflow twice; do not run models or other sources.
do "code/elasticity_cameroun/98_run_cmr_tax_isic4.do"
local snapshot "${SCRATCHDIR}/tax_isic4_repeatability_stata"
capture mkdir "`snapshot'"
log using "${LOGDIR}/cmr_tax_isic4_repeatability.log", text replace name(taxrepeat)
local datasets cmr_tax_isic4_crosswalk cmr_tax_isic4_firm_year cmr_tax_isic4_source_audit
foreach dataset of local datasets {
    copy "${DATADIR}/Intermediate/`dataset'.dta" "`snapshot'/`dataset'.dta", replace
}
copy "${DATADIR}/Analysis/CMR_BDF_isic4.dta" "`snapshot'/CMR_BDF_isic4.dta", replace
local diagnostics reviewed_categories detail_intake_summary merge_audit coverage_summary ///
    key_audit numeric_value_audit within_firm_changes
foreach file of local diagnostics {
    quietly checksum "${OUTPUTDIR}/checks/tax_isic4/`file'.csv"
    local hash_`file' = r(checksum)
    local size_`file' = r(filelen)
}
quietly checksum "${OUTPUTDIR}/tables/cmr_tax_isic4_coverage.tex"
local table_hash = r(checksum)
local table_size = r(filelen)
quietly checksum "${CAMEROONDIR}/Clean/CMR_BDF.dta"
local raw_hash = r(checksum)
quietly checksum "${DATADIR}/Analysis/CMR_BDF_cleaned.dta"
local cleaned_hash = r(checksum)

do "code/elasticity_cameroun/98_run_cmr_tax_isic4.do"
foreach dataset of local datasets {
    use "${DATADIR}/Intermediate/`dataset'.dta", clear
    if _N > 0 cf _all using "`snapshot'/`dataset'.dta"
    else {
        use "`snapshot'/`dataset'.dta", clear
        assert _N == 0
    }
}
use "${DATADIR}/Analysis/CMR_BDF_isic4.dta", clear
cf _all using "`snapshot'/CMR_BDF_isic4.dta"
isid firmid fin_yr
foreach file of local diagnostics {
    quietly checksum "${OUTPUTDIR}/checks/tax_isic4/`file'.csv"
    assert r(checksum) == `hash_`file'' & r(filelen) == `size_`file''
}
quietly checksum "${OUTPUTDIR}/tables/cmr_tax_isic4_coverage.tex"
assert r(checksum) == `table_hash' & r(filelen) == `table_size'
quietly checksum "${CAMEROONDIR}/Clean/CMR_BDF.dta"
assert r(checksum) == `raw_hash'
quietly checksum "${DATADIR}/Analysis/CMR_BDF_cleaned.dta"
assert r(checksum) == `cleaned_hash'
display as result "TAX ISIC4 REPEATABILITY CHECKS COMPLETED SUCCESSFULLY"
log close taxrepeat
