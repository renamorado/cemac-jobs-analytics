version 17.0
set more off
local out "${OUTPUTDIR}/checks/isic4_assessment"
tempfile bridge bdf

* Existing crosswalk assignments are preliminary until source definitions have
* been rechecked. A syntactically valid division is not semantic validation.
use "${DATADIR}/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta", clear
isid nacam
generate str40 assessment_status = "existing_unique_requires_review"
replace assessment_status = "existing_split_requires_review" ///
    if manual_review_flag == 1 | missing(isic_rev4_division)
generate str2 reviewed_isic4_division = ""
export delimited using "`out'/bdf_mapping_review.csv", replace
save "`bridge'"

foreach input in raw cleaned {
    if "`input'" == "raw" local source "${CAMEROONDIR}/Clean/CMR_BDF.dta"
    else local source "${DATADIR}/Analysis/CMR_BDF_cleaned.dta"
    use firmid fin_yr nacam totemp va tot_rev using "`source'", clear
    local source_rows = _N
    if "`input'" == "cleaned" isid firmid fin_yr
    duplicates tag firmid fin_yr, generate(duplicate_key)
    generate byte duplicate_key_row = duplicate_key > 0
    generate byte missing_key = missing(firmid, fin_yr)
    foreach var in totemp va tot_rev {
        capture confirm numeric variable `var'
        if _rc {
            generate byte parse_bad_`var' = !missing(strtrim(`var')) ///
                & missing(real(subinstr(`var', ",", "", .)))
            destring `var', replace ignore(",") force
        }
        else generate byte parse_bad_`var' = 0
    }
    merge m:1 nacam using "`bridge'", keep(master match) generate(bridge_merge)
    tab bridge_merge, missing
    assert _N == `source_rows'
    replace assessment_status = "missing_crosswalk_entry" if bridge_merge == 1
    generate byte one = 1
    generate byte existing_unique = assessment_status == "existing_unique_requires_review"
    generate byte observed_employment = totemp >= 0 & !missing(totemp)
    generate byte observed_revenue = tot_rev >= 0 & !missing(tot_rev)
    generate double employment = totemp if observed_employment
    generate double revenue = tot_rev if observed_revenue
    generate double emp_existing_unique = employment * existing_unique
    generate double rev_existing_unique = revenue * existing_unique
    generate byte sample_va = totemp > 0 & va > 0 ///
        & !missing(totemp, va, firmid, fin_yr, nacam)
    generate byte sample_revenue = totemp > 0 & tot_rev > 0 ///
        & !missing(totemp, tot_rev, firmid, fin_yr, nacam)
    save "`bdf'", replace

    egen byte firm_tag = tag(nacam firmid)
    collapse (sum) records=one firms=firm_tag employment revenue ///
        observed_employment observed_revenue sample_va sample_revenue ///
        duplicate_key_row missing_key parse_bad_totemp parse_bad_va parse_bad_tot_rev, ///
        by(nacam nacam_label_en assessment_status isic_rev4_division)
    isid nacam, missok
    export delimited using "`out'/bdf_`input'_category_coverage.csv", replace

    use "`bdf'", clear
    egen byte firm_tag = tag(fin_yr assessment_status firmid)
    collapse (sum) records=one firms=firm_tag employment revenue ///
        observed_employment observed_revenue, by(fin_yr assessment_status)
    export delimited using "`out'/bdf_`input'_year_coverage.csv", replace

    use "`bdf'", clear
    collapse (sum) records=one existing_unique employment emp_existing_unique ///
        revenue rev_existing_unique observed_employment observed_revenue ///
        duplicate_key_row missing_key
    generate double existing_unique_record_share = existing_unique / records
    generate double existing_unique_emp_share = emp_existing_unique / employment
    generate double existing_unique_rev_share = rev_existing_unique / revenue
    export delimited using "`out'/bdf_`input'_summary.csv", replace

    if "`input'" == "cleaned" {
        use "`bdf'", clear
        * Provisional support only for existing single-division assignments.
        keep if existing_unique
        egen byte va_firm = tag(isic_rev4_division firmid) if sample_va
        egen byte revenue_firm = tag(isic_rev4_division firmid) if sample_revenue
        collapse (sum) va_obs=sample_va revenue_obs=sample_revenue ///
            va_firms=va_firm revenue_firms=revenue_firm, by(isic_rev4_division)
        generate byte meets_baseline_counts = va_obs >= 30 & va_firms >= 10 ///
            & revenue_obs >= 30 & revenue_firms >= 10
        generate str100 limitation = "Existing mapping only; semantic and within-firm variation review pending"
        export delimited using "`out'/bdf_provisional_division_support.csv", replace
    }
}
display as result "BDF existing-crosswalk inventory completed; no mapping certified."
