version 17.0
set more off

* Section assessment and descriptive preview only; no regressions are run.
* Standalone prerequisite: 98_run_cmr_tax_isic4.do rev1_assessment.
if "${PROJECT_ROOT}" == "" do "code/01_setup.do"
local reference "${PROJECT_ROOT}/docs/reference"
local checkdir "${OUTPUTDIR}/checks/tax_isic4_sections"
capture mkdir "`checkdir'"
capture log close taxsections
log using "${LOGDIR}/23_cmr_tax_isic4_sections.log", text replace name(taxsections)
tempfile official_divisions official_sections reviewed crosswalk original merged summaries

* Derive the division-to-section hierarchy from the official UN structure.
import delimited using "`reference'/isic_rev4_english_structure.csv", clear stringcols(_all) varnames(1)
generate str1 official_section = code if strlen(code) == 1
replace official_section = official_section[_n-1] if missing(official_section)
preserve
keep if strlen(code) == 1
keep official_section description
rename official_section isic4_section_strict
rename description official_label
isid isic4_section_strict
save `official_sections'
restore
keep if strlen(code) == 2
keep code official_section
rename code section_division_refs
isid section_division_refs
save `official_divisions'

* Reject a section CSV that has drifted from the reviewed division evidence.
import delimited using "`reference'/cmr_tax_nacam_rev1_isic4_decisions.csv", clear stringcols(_all) varnames(1)
destring nacam, replace
keep nacam isic4_reference
isid nacam
save `reviewed'
import delimited using "`reference'/cmr_tax_nacam_rev1_isic4_sections.csv", clear stringcols(_all) varnames(1) bindquote(strict)
destring nacam, replace
isid nacam
assert _N == 37
assert nacam_branch == string(nacam, "%03.0f")
assert !missing(section_note, section_evidence, section_review_date, isic4_section_label)
assert inlist(section_status, "single_section", "combined_sections", "boundary_exception", "analytical_assignment")
merge 1:1 nacam using `reviewed', assert(match) nogen
assert section_division_refs == isic4_reference
drop isic4_reference
preserve
keep nacam section_division_refs section_refs
split section_division_refs, parse(" ") generate(div)
drop section_division_refs
reshape long div, i(nacam) j(position)
drop if missing(div)
rename div section_division_refs
merge m:1 section_division_refs using `official_divisions', keep(master match) assert(match using) nogen
sort nacam official_section position
by nacam: generate str20 derived_refs = official_section if _n == 1
by nacam: replace derived_refs = derived_refs[_n-1] + ///
    cond(official_section == official_section[_n-1], "", "+" + official_section) if _n > 1
by nacam: keep if _n == _N
assert section_refs == derived_refs
restore
assert isic4_section_strict == section_refs & strlen(isic4_section_strict) == 1 if section_status == "single_section"
assert missing(isic4_section_strict) & missing(isic4_section_strict_label) if section_status != "single_section"
assert strlen(section_refs) > 1 if section_status != "single_section"
assert isic4_section == isic4_section_strict if section_status == "single_section"
assert isic4_section == section_refs if section_status == "combined_sections"
assert inlist(nacam, 38, 42) if section_status == "combined_sections"
assert isic4_section == "X" + nacam_branch if section_status == "boundary_exception"
* User-approved analysis groups do not populate the strict section field.
assert inlist(nacam, 5, 6, 9, 21, 29, 37) if section_status == "analytical_assignment"
assert section_status == "analytical_assignment" if inlist(nacam, 5, 6, 9, 21, 29, 37)
assert isic4_section == "B" if inlist(nacam, 5, 6)
assert isic4_section == "A" if nacam == 9
assert isic4_section == "C" if nacam == 21
assert isic4_section == "D" if nacam == 29
assert isic4_section == "L" if nacam == 37
assert strpos(section_note, "Roldan approved analytical grouping") > 0 if section_status == "analytical_assignment"
assert strpos("+" + section_refs + "+", "+" + isic4_section + "+") > 0 if section_status == "analytical_assignment"
merge m:1 isic4_section_strict using `official_sections', keep(master match) nogen
assert isic4_section_strict_label == official_label if section_status == "single_section"
drop official_label
* Requested analysis variable: all 16 agreed categories, including adaptations.
* Keep the strict official correspondence separate and retain old aliases.
assert !missing(isic4_section, isic4_section_label)
egen byte analysis_group_tag = tag(isic4_section)
quietly count if analysis_group_tag
assert r(N) == 16
drop analysis_group_tag
clonevar tax_section_group = isic4_section
clonevar tax_section_label = isic4_section_label
label variable isic4_section "ISIC Rev.4-based tax analysis group (16; includes adaptations)"
label variable isic4_section_label "Label for ISIC Rev.4-based tax analysis group"
label variable isic4_section_strict "Strict official ISIC Rev.4 section; blank for adaptations"
label variable isic4_section_strict_label "Official label for strict ISIC Rev.4 section"
label variable tax_section_group "Compatibility alias of isic4_section"
label variable tax_section_label "Compatibility alias of isic4_section_label"
sort nacam
unab section_vars : _all
local key nacam
local section_vars : list section_vars - key
save `crosswalk'
save "${DATADIR}/Intermediate/cmr_tax_isic4_sections_crosswalk.dta", replace

* Preserve all columns and rows from the provisional Rev.1 panel.
use "${DATADIR}/Analysis/CMR_BDF_isic4_rev1_assessment.dta", clear
isid firmid fin_yr
assert revision_assumed == 1
unab original_vars : _all
foreach variable of local section_vars {
    confirm new variable `variable'
}
local original_n = _N
generate long section_input_row = _n
save `original'
merge m:1 nacam using `crosswalk', generate(section_merge)
forvalues result = 1/3 {
    quietly count if section_merge == `result'
    local merge_count`result' = r(N)
}
preserve
clear
set obs 3
generate byte section_merge = _n
generate long records = .
forvalues result = 1/3 {
    replace records = `merge_count`result'' if section_merge == `result'
}
export delimited using "`checkdir'/merge_audit.csv", replace
restore
assert section_merge != 1
drop if section_merge == 2
assert _N == `original_n'
assert isic4_reference == section_division_refs
assert !missing(isic4_section, isic4_section_label)
assert isic4_section == tax_section_group & isic4_section_label == tax_section_label
assert missing(isic4_section_strict) if section_status != "single_section"
sort section_input_row
cf `original_vars' using `original'
drop section_input_row section_merge
isid firmid fin_yr
sort firmid fin_yr
save "${DATADIR}/Analysis/CMR_BDF_isic4_sections_assessment.dta", replace
keep firmid fin_yr nacam section_status isic4_section isic4_section_label section_refs totemp tot_rev

* Descriptive, unweighted shares. Exclude missing/negative values separately
* for each denominator; all firm-years remain in the record count.
confirm numeric variable totemp tot_rev
generate byte records = 1
generate byte qualified_group = section_status != "single_section"
foreach measure in employment revenue {
    local input totemp
    if "`measure'" == "revenue" local input tot_rev
    generate byte `measure'_missing = missing(`input')
    generate byte `measure'_negative = `input' < 0
    generate double `measure' = cond(`input' >= 0 & !missing(`input'), `input', 0)
    generate double `measure'_negative_sum = cond(`input' < 0, `input', 0)
}
save `merged'
local first 1
foreach breakdown in group year_group status year_status category {
    use `merged', clear
    local byvars section_status
    if inlist("`breakdown'", "group", "year_group") ///
        local byvars isic4_section isic4_section_label
    if "`breakdown'" == "category" ///
        local byvars section_status isic4_section isic4_section_label section_refs
    if inlist("`breakdown'", "year_group", "year_status") local byvars fin_yr `byvars'
    if "`breakdown'" == "category" local byvars nacam `byvars'
    egen byte firms = tag(`byvars' firmid)
    local catkeys `byvars' nacam
    local catkeys : list uniq catkeys
    egen byte categories = tag(`catkeys')
    * Fix summation order for byte-identical CSVs across repeated runs.
    sort `byvars' firmid fin_yr
    collapse (sum) records firms categories employment revenue employment_missing ///
        employment_negative revenue_missing revenue_negative ///
        employment_negative_sum revenue_negative_sum (max) qualified_group, by(`byvars')
    if "`breakdown'" == "group" isid isic4_section
    if "`breakdown'" == "year_group" isid fin_yr isic4_section
    local yearkeys
    if inlist("`breakdown'", "year_group", "year_status") local yearkeys fin_yr
    foreach measure in records employment revenue {
        if "`yearkeys'" == "" egen double denominator_`measure' = total(`measure')
        else bysort fin_yr: egen double denominator_`measure' = total(`measure')
        generate double `measure'_pct = 100 * `measure' / denominator_`measure' if denominator_`measure' > 0
    }
    generate str12 breakdown = "`breakdown'"
    if `first' {
        save `summaries'
        local first 0
    }
    else {
        append using `summaries'
        save `summaries', replace
    }
}
use `summaries', clear
sort breakdown fin_yr nacam isic4_section section_status
export delimited using "`checkdir'/shares.csv", replace
preserve
keep if breakdown == "category"
merge 1:1 nacam using `crosswalk', assert(match) nogen
sort nacam
export delimited using "`checkdir'/crosswalk_with_shares.csv", replace
export delimited if section_status == "analytical_assignment" using "`checkdir'/analytical_assignments.csv", replace
keep if section_status == "boundary_exception"
export delimited using "`checkdir'/boundary_exceptions.csv", replace
restore

* Export a code-generated LaTeX table and a preview of how tax group labels look.
keep if breakdown == "group"
quietly summarize records_pct, meanonly
assert abs(r(sum) - 100) < 0.000001
generate str100 plot_label = isic4_section + "  " + isic4_section_label
replace plot_label = isic4_section + "*  " + isic4_section_label if qualified_group
sort isic4_section
tempname table
mkmat records firms employment_pct revenue_pct, matrix(`table')
matrix colnames `table' = Records Firms Employment_pct Revenue_pct
local rownames
local coeflabels
forvalues i = 1/`=_N' {
    local rownames `rownames' group`i'
    local text = plot_label[`i']
    local coeflabels `"`coeflabels' group`i' "`text'""'
}
matrix rownames `table' = `rownames'
esttab matrix(`table', fmt(0 0 2 2)) using "${OUTPUTDIR}/tables/cmr_tax_isic4_sections_preview.tex", ///
    replace booktabs nonumber nomtitle coeflabels(`coeflabels') ///
    collabels("Firm-years" "Firms" "Employment share (\%)" "Revenue share (\%)") ///
    postfoot("\bottomrule" "\multicolumn{5}{p{0.95\linewidth}}{\footnotesize Notes: NACAM Rev.1, 2015--2022. Employment shares use firm-year employment totals. Denominators exclude missing and negative values. Firms can appear in multiple groups. * Analytical assignments: 005/006 to B, 009 to A (including processing), 021 to C, 029 to D, 037 to L; combined M+N and R+S+T (T:97 only); 005 retains B/C/H boundaries. Groups are not exact official section coverage. Descriptive preview; no elasticities estimated.}" "\end{tabular}")
replace plot_label = "M+N*  Professional and business services" if isic4_section == "M+N"
graph hbar employment_pct revenue_pct, ///
    over(plot_label, sort(1) descending label(labsize(vsmall))) ///
    bar(1, color("31 119 180")) bar(2, color("230 159 0")) ///
    legend(order(1 "Employment" 2 "Revenue") rows(1) size(small)) ///
    ytitle("Share of valid total (%)", size(small)) ylabel(0(5)30, labsize(small)) ///
    title("Tax sectors: ISIC Rev. 4 section preview", size(medsmall)) ///
    subtitle("Cleaned panel, 2015-2022 | descriptive shares", size(small)) ///
    note("* Analytical assignments: 005/006 to B; 009 to A (including processing); 021 to C; 029 to D; 037 to L." ///
         "M+N and R+S+T combine sections (T:97 only); 005 in B retains B/C/H boundaries. Groups are not exact ISIC sections." ///
         "Nonmissing, nonnegative denominators. Employment is summed across firm-years." ///
         "NACAM Rev.1. Descriptive preview; no elasticities estimated.", size(vsmall) span) ///
    graphregion(color(white) margin(l=8 r=4)) xsize(12) ysize(9)
graph export "${OUTPUTDIR}/figures/cmr_tax_isic4_sections_preview.png", width(2000) replace
graph export "${OUTPUTDIR}/figures/cmr_tax_isic4_sections_preview.pdf", replace
display as result "TAX SECTION ASSESSMENT COMPLETED SUCCESSFULLY"
log close taxsections
