version 17.0
set more off
if "${PROJECT_ROOT}" == "" do "code/01_setup.do"
local checkdir "${OUTPUTDIR}/checks/tax_isic4_rev1"
capture mkdir "`checkdir'"
tempfile workbook counts named_firms named_codes codekeys all_audit
local sheet = "BASE SERIE 2015" + char(36) + "2022"
* Explicit source columns; verify headers before interpreting any values.
import excel firmid=A nacam=B fin_yr=E sigle=FX using ///
    "${CAMEROONDIR}/Raw/TAX PANEL Update - BASE ECOFIN 2015 2022 2024-02-21 18_09_36.xlsx", ///
    sheet("`sheet'") allstring clear
assert firmid[1] == "CODE2" & nacam[1] == "CODEBRANCHE"
assert fin_yr[1] == "exerClos.x" & sigle[1] == "SIGLE.x3"
drop in 1
destring nacam fin_yr, replace
assert !missing(firmid, fin_yr, nacam)
assert inrange(fin_yr, 2015, 2022)
generate long source_row = _n
replace sigle = ustrtrim(sigle)
* import excel reads native Excel error cells as missing; only literal error
* strings remain observable here. Populated counts refer to imported text.
generate byte sigle_imported_populated = !missing(ustrtrim(sigle))
generate byte sigle_literal_error = substr(ustrtrim(sigle), 1, 1) == "#" & sigle_imported_populated
generate byte sigle_valid = sigle_imported_populated & !sigle_literal_error
generate byte statement_text = sigle_valid & ///
    (strpos(ustrlower(sigle), "exercice") > 0 | strpos(ustrlower(sigle), "entit") > 0)
generate byte replacement_character = strpos(sigle, uchar(65533)) > 0
generate byte no_spaces = sigle_valid & strpos(ustrtrim(sigle), " ") == 0
save `workbook'

* Verify the exact workbook/BDF code link including duplicate multiplicity.
contract firmid fin_yr nacam, freq(workbook_records)
isid firmid fin_yr nacam
save `counts'
use firmid fin_yr nacam using "${CAMEROONDIR}/Clean/CMR_BDF.dta", clear
contract firmid fin_yr nacam, freq(bdf_records)
merge 1:1 firmid fin_yr nacam using `counts'
assert _merge == 3 & workbook_records == bdf_records

use `workbook', clear
keep if sigle_valid
keep firmid nacam
duplicates drop
save `named_codes'
keep firmid
duplicates drop
save `named_firms'
use `workbook', clear
merge m:1 firmid using `named_firms', generate(name_link)
assert name_link != 2
generate byte firm_has_name = name_link == 3
drop name_link
merge m:1 firmid nacam using `named_codes', generate(code_link)
assert code_link != 2
generate byte matches_named_code = code_link == 3
drop code_link

* Source conflicts are counted before any cleaning. Never choose a name/code
* arbitrarily from a firm-year that contains more than one branch.
egen byte branch_tag = tag(firmid fin_yr nacam)
bysort firmid fin_yr: egen int branches_in_year = total(branch_tag)
bysort firmid fin_yr: generate int records_in_year = _N
generate byte conflicting_year = branches_in_year > 1
generate byte records = 1
sort source_row
save `all_audit'
drop sigle branch_tag
save "${DATADIR}/Intermediate/cmr_tax_revision_audit_rev1.dta", replace

foreach breakdown in overall year category year_category {
    use `all_audit', clear
    local groups
    if inlist("`breakdown'", "year", "year_category") local groups fin_yr
    if inlist("`breakdown'", "category", "year_category") local groups `groups' nacam
    egen byte firms = tag(`groups' firmid)
    egen byte named_firms = tag(`groups' firmid) if sigle_valid
    egen byte sigle_strings = tag(`groups' sigle) if sigle_valid
    egen byte conflicting_firmyears = tag(`groups' firmid fin_yr) if conflicting_year
    egen byte duplicate_firmyears = tag(`groups' firmid fin_yr) if records_in_year > 1
    local totals records firms named_firms sigle_strings sigle_imported_populated sigle_literal_error ///
        sigle_valid statement_text replacement_character no_spaces firm_has_name ///
        matches_named_code conflicting_year conflicting_firmyears duplicate_firmyears
    if "`groups'" == "" collapse (sum) `totals'
    else collapse (sum) `totals', by(`groups')
    generate str15 breakdown = "`breakdown'"
    if !inlist("`breakdown'", "year", "year_category") generate int fin_yr = .
    if !inlist("`breakdown'", "category", "year_category") generate int nacam = .
    order breakdown fin_yr nacam
    sort fin_yr nacam
    export delimited using "`checkdir'/revision_`breakdown'.csv", replace
}

use `all_audit', clear
keep firmid fin_yr nacam conflicting_year
duplicates drop
drop if conflicting_year
isid firmid fin_yr
sort firmid fin_yr
by firmid: generate int previous_year = fin_yr[_n-1] if _n > 1
by firmid: generate int previous_nacam = nacam[_n-1] if _n > 1
keep if !missing(previous_year)
generate byte consecutive = fin_yr == previous_year + 1
generate byte changed = nacam != previous_nacam
generate byte transition_pairs = 1
collapse (sum) transition_pairs, by(previous_year fin_yr previous_nacam nacam consecutive changed)
sort previous_year fin_yr previous_nacam nacam
export delimited using "`checkdir'/revision_transitions.csv", replace

* An aggregate comparison of interpretations, never firm-name classification.
import delimited using "${PROJECT_ROOT}/docs/reference/cmr_tax_isic4_decisions.csv", ///
    clear varnames(1) stringcols(_all)
destring nacam, replace
keep nacam nacam_original_label isic4_division isic4_status isic4_possible_divisions
rename (nacam_original_label isic4_division isic4_status isic4_possible_divisions) ///
    (legacy_nacam_label legacy_isic4_division legacy_status legacy_references)
isid nacam
save `codekeys'
use "${DATADIR}/Intermediate/cmr_tax_isic4_crosswalk_rev1.dta", clear
merge 1:1 nacam using `codekeys'
assert _merge == 3
drop _merge
sort nacam
export delimited using "`checkdir'/revision_comparison.csv", replace
display as result "TAX REVISION AUDIT CHECKS PASSED"
