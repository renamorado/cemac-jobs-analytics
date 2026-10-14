version 17.0
set more off
local out "${OUTPUTDIR}/checks/census_isic4"
local workbook "${CAMEROONDIR}/Raw/CENSUS 2024 with exports BASE RGE 3 BANQUE MONDIALE exp.xlsx"
tempfile crosswalk census pairs before activity

use "${DATADIR}/Intermediate/cmr_census_isic4_crosswalk_validated.dta", clear
keep citi_branch activity_detail final_division final_division_label ///
    review_status assigned possible_divisions
isid citi_branch activity_detail
save "`crosswalk'"

* Retain all 29 source columns unchanged, including the original identifier.
import excel using "`workbook'", sheet("BASE") firstrow allstring clear
assert c(k) == 29
assert _N == 438893
isid S0Q01
generate long source_row = _n + 1
generate str100 source_file = "CENSUS 2024 with exports BASE RGE 3 BANQUE MONDIALE exp.xlsx"
generate str8 source_sheet = "BASE"
generate firmid_census = ustrtrim(S0Q01)
generate citi_branch = ustrtrim(BRANCHD_S1Q14)
generate activity_detail = ustrtrim(S1Q14B)
generate activity_macro = ustrtrim(SACTIV_S1Q14)
compress firmid_census citi_branch activity_detail activity_macro
isid firmid_census
generate byte headquarters = ustrtrim(S1Q13) == "Siège"
count if headquarters
assert r(N) == 430011
generate byte units = 1

* No undocumented field is treated as a sector code. Save the field inventory.
preserve
    describe S0Q01-chiffredaffaireexportation, replace clear
    export delimited using "`out'/census_raw_fields.csv", replace
restore

* Parse into new variables; preserve raw text and distinguish missing from invalid.
local raw_employment S6Q05AC
local raw_turnover S6Q01A
local raw_exports chiffredaffaireexportation
foreach measure in employment turnover exports {
    local raw `raw_`measure''
    generate strL number_text = ustrtrim(`raw')
    generate byte missing_`measure' = inlist(ustrlower(number_text), "", "nd", "ne sait pas", "n.d.")
    replace number_text = subinstr(number_text, uchar(160), "", .)
    replace number_text = subinstr(subinstr(number_text, ",", "", .), " ", "", .)
    generate double `measure' = real(number_text)
    generate byte parse_bad_`measure' = missing(`measure') & !missing_`measure'
    generate byte negative_`measure' = `measure' < 0
    generate byte fractional_`measure' = 0
    if "`measure'" == "employment" replace fractional_`measure' = ///
        `measure' != floor(`measure') & `measure' >= 0 & !missing(`measure')
    generate byte valid_`measure' = !missing_`measure' & !parse_bad_`measure' ///
        & !negative_`measure' & !fractional_`measure'
    assert missing_`measure' + parse_bad_`measure' + negative_`measure' ///
        + fractional_`measure' + valid_`measure' == 1
    replace `measure' = . if !valid_`measure'
    generate double hq_`measure' = cond(headquarters & valid_`measure', `measure', 0)
    generate long hq_valid_`measure' = headquarters & valid_`measure'
    generate long hq_missing_`measure' = headquarters & missing_`measure'
    generate long hq_invalid_`measure' = headquarters & ///
        (parse_bad_`measure' | negative_`measure' | fractional_`measure')
    drop number_text
}
generate str12 exporter_status = "unknown"
replace exporter_status = "non_exporter" if valid_exports & exports == 0
replace exporter_status = "exporter" if valid_exports & exports > 0
generate byte hq_exporter = headquarters & exporter_status == "exporter"
generate byte hq_nonexporter = headquarters & exporter_status == "non_exporter"
generate byte hq_export_unknown = headquarters & exporter_status == "unknown"
generate byte hq_positive_emp_sales = headquarters & employment > 0 & turnover > 0 ///
    & !missing(employment, turnover)
label variable hq_positive_emp_sales "HQ with positive observed employment and turnover; no estimation sample imposed"
assert hq_exporter + hq_nonexporter + hq_export_unknown == headquarters

* Record totals before attaching any classifications.
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

* Require exact coverage of the observed pair set, including no unused decisions.
preserve
    contract citi_branch activity_detail, freq(pair_units)
    isid citi_branch activity_detail
    assert _N == 273
    save "`pairs'"
    merge 1:1 citi_branch activity_detail using "`crosswalk'", generate(pair_merge)
    tab pair_merge, missing
    assert pair_merge == 3
restore
merge m:1 citi_branch activity_detail using "`crosswalk'", generate(classification_merge)
tab classification_merge, missing
assert classification_merge == 3
assert _N == 438893
isid S0Q01
isid firmid_census
assert missing(final_division) if !assigned
assert !missing(final_division) if assigned
sort source_row
save "${DATADIR}/Analysis/cmr_census_isic4_assessment.dta", replace
save "`census'"

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
    export delimited using "`out'/census_merge_reconciliation.csv", replace
restore

* Missing and invalid quantities are reported explicitly, including non-HQ units.
preserve
    collapse (sum) units missing_* parse_bad_* negative_* fractional_* valid_*, ///
        by(headquarters assigned)
    export delimited using "`out'/census_measure_quality.csv", replace
restore

* Activity-level totals include all units; economic totals count headquarters only.
collapse (sum) units headquarters hq_employment hq_turnover hq_exports ///
    hq_valid_* hq_missing_* hq_invalid_* hq_exporter hq_nonexporter ///
    hq_export_unknown hq_positive_emp_sales, ///
    by(citi_branch activity_detail activity_macro)
merge 1:1 citi_branch activity_detail ///
    using "${DATADIR}/Intermediate/cmr_census_isic4_crosswalk_validated.dta", ///
    generate(review_merge)
tab review_merge, missing
assert review_merge == 3
drop review_merge
assert _N == 273
generate byte activities = 1
save "`activity'"

preserve
    collapse (sum) activities units headquarters hq_employment hq_turnover hq_exports ///
        hq_valid_* hq_missing_* hq_invalid_* hq_exporter hq_nonexporter ///
        hq_export_unknown hq_positive_emp_sales, by(assigned)
    foreach v in activities units headquarters hq_employment hq_turnover hq_exports ///
        hq_exporter hq_nonexporter hq_export_unknown hq_positive_emp_sales {
        egen double total_`v' = total(`v')
        generate double pct_`v' = 100 * `v' / total_`v'
    }
    generate str18 mapping_status = cond(assigned, "Assigned", "Unresolved")
    order mapping_status activities pct_activities units pct_units headquarters ///
        pct_headquarters hq_employment pct_hq_employment hq_turnover pct_hq_turnover ///
        hq_exporter pct_hq_exporter
    export delimited using "`out'/census_mapping_coverage.csv", replace
restore

* Review copy is generated. Edit decisions in docs/reference, never in this output.
gsort -hq_employment -units citi_branch activity_detail
generate long review_order = _n
order review_order citi_branch activity_detail final_division proposed_division ///
    review_status possible_divisions units headquarters hq_employment hq_turnover ///
    hq_exporter reasoning supporting_classes official_pages official_url
export delimited using "`out'/census_activity_review.csv", replace
preserve
    keep if !assigned
    replace review_order = _n
    export delimited using "`out'/census_unresolved_review.csv", replace
restore

use "`census'", clear
collapse (sum) units headquarters hq_employment hq_turnover hq_exports ///
    hq_valid_* hq_missing_* hq_invalid_* hq_positive_emp_sales, ///
    by(exporter_status assigned)
foreach v in units headquarters hq_employment hq_turnover {
    bysort exporter_status: egen double total_`v' = total(`v')
    generate double pct_`v' = 100 * `v' / total_`v'
}
export delimited using "`out'/census_exporter_coverage.csv", replace

use "`census'", clear
collapse (sum) units headquarters hq_employment hq_turnover hq_exports ///
    hq_exporter hq_nonexporter hq_export_unknown hq_positive_emp_sales, ///
    by(final_division final_division_label assigned)
export delimited using "`out'/census_division_totals.csv", replace
do "${CODEDIR}/isic4_assessment/06_census_review_excel.do"
display as result "All census records preserved; economic coverage uses headquarters only."
