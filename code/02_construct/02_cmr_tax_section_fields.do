version 17.0
set more off

* Attach the settled tax grouping to the panel currently in memory. The same
* lookup is used for the main and duplicate-inclusive panels; NACAM is retained.
local original_n = _N
capture confirm variable isic4_section
if _rc {
    merge m:1 nacam using "${DATADIR}/Intermediate/cmr_tax_isic4_sections_crosswalk.dta", ///
        keep(master match) assert(match using) nogen
}
assert _N == `original_n'
assert !missing(isic4_section)

* Codes depend on the complete agreed lookup, never on the estimation sample.
preserve
use "${DATADIR}/Intermediate/cmr_tax_isic4_sections_crosswalk.dta", clear
keep isic4_section isic4_section_label section_status
generate byte isic4_qualified = section_status != "single_section"
collapse (max) isic4_qualified, by(isic4_section isic4_section_label)
isid isic4_section
assert _N == 16
sort isic4_section
generate byte isic4_sector_id = _n
generate str180 isic4_label_display = isic4_section_label
generate str80 isic4_label_short_display = ""
* Section wording follows INSEE's short labels; combined groups remain project adaptations.
replace isic4_label_short_display = "Agriculture, forestry & fishing" if isic4_section == "A"
replace isic4_label_short_display = "Mining & quarrying" if isic4_section == "B"
replace isic4_label_short_display = "Manufacturing" if isic4_section == "C"
replace isic4_label_short_display = "Electricity, gas, steam & cooling" if isic4_section == "D"
replace isic4_label_short_display = "Water, waste & remediation" if isic4_section == "E"
replace isic4_label_short_display = "Construction" if isic4_section == "F"
replace isic4_label_short_display = "Trade & motor vehicle repair" if isic4_section == "G"
replace isic4_label_short_display = "Transport & storage" if isic4_section == "H"
replace isic4_label_short_display = "Accommodation/food services" if isic4_section == "I"
replace isic4_label_short_display = "Information & communication" if isic4_section == "J"
replace isic4_label_short_display = "Finance & insurance" if isic4_section == "K"
replace isic4_label_short_display = "Real estate" if isic4_section == "L"
replace isic4_label_short_display = "Professional & admin. support" if isic4_section == "M+N"
replace isic4_label_short_display = "Education" if isic4_section == "P"
replace isic4_label_short_display = "Health & social work" if isic4_section == "Q"
replace isic4_label_short_display = "Arts/other services/households" if isic4_section == "R+S+T"
replace isic4_label_short_display = isic4_label_short_display + "*" if isic4_qualified
replace isic4_label_display = isic4_label_display + "*" if isic4_qualified
assert !missing(isic4_label_short_display)

* Combined groups comprise sections with the same shared display style.
rename isic4_section tax_group
generate str1 isic4_section = substr(tax_group, 1, 1)
merge m:1 isic4_section using "${DATADIR}/Intermediate/isic4_broad_groups_sections.dta", ///
    keep(master match) keepusing(broad_sector broad_sector_label plot_color plot_symbol) ///
    assert(match using) nogen
drop isic4_section
rename tax_group isic4_section
rename broad_sector_label isic4_broad_label
isid isic4_section
save "${DATADIR}/Intermediate/cmr_tax_section_analysis_labels.dta", replace
tempfile section_labels
save `section_labels'
restore
merge m:1 isic4_section using `section_labels', keep(master match) assert(match using) nogen
assert _N == `original_n'
assert !missing(isic4_sector_id, isic4_broad_label)
label variable isic4_sector_id "Agreed ISIC Rev.4-based tax group ID"
