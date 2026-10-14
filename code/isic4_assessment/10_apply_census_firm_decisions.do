version 17.0
set more off
local out "${OUTPUTDIR}/checks/census_isic4"
tempfile before
use "${DATADIR}/Analysis/cmr_census_isic4_assessment.dta", clear
isid firmid_census
local census_n = _N
preserve
    collapse (sum) units headquarters hq_employment hq_turnover hq_exports ///
        hq_valid_* hq_missing_* hq_invalid_* hq_exporter hq_nonexporter ///
        hq_export_unknown hq_positive_emp_sales
    foreach v of varlist _all {
        rename `v' before_`v'
    }
    generate byte check_id = 1
    save "`before'"
restore
clonevar category_final_division = final_division
clonevar category_review_status = review_status
clonevar category_assigned = assigned
merge 1:1 firmid_census using "${DATADIR}/Intermediate/cmr_census_firm_isic4_decisions.dta", ///
    generate(firm_mapping_merge)
tab firm_mapping_merge, missing
assert firm_mapping_merge == 1 if category_assigned
assert firm_mapping_merge == 3 if !category_assigned
assert _N == `census_n'
assert _N == 438893
isid firmid_census
assert review_activity == activity_detail if !category_assigned
assert review_branch == citi_branch if !category_assigned
generate str22 mapping_source = "activity_crosswalk"
replace mapping_source = "unknown_unclassified" if !category_assigned
replace mapping_source = "firm_review" if firm_assigned == 1
replace final_division = firm_division if mapping_source == "firm_review"
replace final_division_label = firm_division_label if mapping_source == "firm_review"
replace review_status = firm_status if !category_assigned
replace assigned = !missing(final_division)
assert final_division == category_final_division if category_assigned
assert final_division == "" if mapping_source == "unknown_unclassified"
assert assigned == (mapping_source != "unknown_unclassified")
sort source_row
save "${DATADIR}/Analysis/cmr_census_isic4_firm_assessment.dta", replace

preserve
    keep if !category_assigned
    merge 1:1 firmid_census using "${DATADIR}/Intermediate/cmr_census_isic4_firm_inventory.dta", ///
        keepusing(business_name trade_name reported_size) generate(inventory_merge)
    assert inventory_merge == 3
    keep firmid_census citi_branch activity_detail business_name trade_name reported_size ///
        FJ FORMEL employment turnover exports mapping_source final_division ///
        final_division_label firm_proposed_division firm_status firm_reason ///
        firm_evidence_fields firm_branch_conflict firm_official_class ///
        firm_official_reference firm_reviewer firm_review_date
    gsort -employment firmid_census
    export delimited using "`out'/census_firm_review_results.csv", replace
restore
preserve
    collapse (sum) units headquarters hq_employment hq_turnover hq_exports ///
        hq_valid_* hq_missing_* hq_invalid_* hq_exporter hq_nonexporter ///
        hq_export_unknown hq_positive_emp_sales
    unab checks : _all
    generate byte check_id = 1
    merge 1:1 check_id using "`before'", assert(match) nogenerate
    foreach v of local checks {
        generate double delta_`v' = `v' - before_`v'
        assert abs(delta_`v') <= max(0.000001, abs(before_`v') * 1e-12)
    }
    export delimited using "`out'/census_firm_merge_reconciliation.csv", replace
restore
preserve
    collapse (sum) units headquarters hq_employment hq_turnover hq_exports ///
        hq_valid_* hq_missing_* hq_invalid_* hq_exporter hq_nonexporter ///
        hq_export_unknown hq_positive_emp_sales, by(mapping_source assigned)
    foreach v in units headquarters hq_employment hq_turnover hq_exports hq_exporter {
        egen double total_`v' = total(`v')
        generate double pct_`v' = 100 * `v' / total_`v'
    }
    export delimited using "`out'/census_firm_mapping_coverage.csv", replace
restore
preserve
    collapse (sum) units headquarters hq_employment hq_turnover hq_exports, ///
        by(final_division final_division_label assigned)
    export delimited using "`out'/census_firm_division_totals.csv", replace
restore
display as result "FIRM DECISIONS APPLIED; ALL CENSUS RECORDS PRESERVED"
