version 17.0
set more off

* Shared display groups for every official ISIC Rev.4 code; no firm data changed.
if "${PROJECT_ROOT}" == "" do "code/01_setup.do"
capture log close isicbroad
log using "${LOGDIR}/01_isic4_broad_groups.log", text replace name(isicbroad)
tempfile styles
import delimited using "${PROJECT_ROOT}/docs/reference/isic4_broad_groups.csv", clear varnames(1)
isid isic4_section
assert _N == 21
assert inrange(broad_sector, 1, 10)
assert !missing(broad_sector_label, plot_color, plot_symbol)
bysort broad_sector (isic4_section): assert broad_sector_label == broad_sector_label[1] & ///
    plot_color == plot_color[1] & plot_symbol == plot_symbol[1]
egen byte broad_tag = tag(broad_sector)
count if broad_tag
assert r(N) == 10
drop broad_tag
save `styles'

* The official file is ordered by section and its constituent codes.
import delimited using "${PROJECT_ROOT}/docs/reference/isic_rev4_english_structure.csv", ///
    clear varnames(1) stringcols(_all)
rename code isic4_code
rename description isic4_label
isid isic4_code
generate byte isic4_level = strlen(isic4_code)
assert inrange(isic4_level, 1, 4)
generate str1 isic4_section = isic4_code if isic4_level == 1
replace isic4_section = isic4_section[_n-1] if missing(isic4_section)
assert !missing(isic4_section)
assert substr(isic4_code, 1, 1) == isic4_section if isic4_level == 1
assert !missing(real(isic4_code)) if isic4_level > 1
count if isic4_level == 1
assert r(N) == 21
count if isic4_level == 2
assert r(N) == 88
count if isic4_level == 3
assert r(N) == 238
count if isic4_level == 4
assert r(N) == 419
merge m:1 isic4_section using `styles', assert(match) nogen
label variable broad_sector "Project broad display sector (10 groups; not an official ISIC level)"
label variable isic4_level "ISIC level: 1 section, 2 division, 3 group, 4 class"
assert isic4_section == "A" & broad_sector == 1 if inlist(isic4_code, "01", "011", "0111")
assert isic4_section == "C" & broad_sector == 3 if isic4_code == "1920"
assert broad_sector == 4 if inlist(isic4_section, "D", "E")
assert broad_sector == 10 if inlist(isic4_section, "O", "T", "U")
sort isic4_code
save "${DATADIR}/Intermediate/isic4_broad_groups_codes.dta", replace
keep if isic4_level == 1
drop isic4_code isic4_level
rename isic4_label official_section_label
isid isic4_section
sort isic4_section
save "${DATADIR}/Intermediate/isic4_broad_groups_sections.dta", replace
display as result "ISIC4 BROAD DISPLAY GROUP CHECKS PASSED"
log close isicbroad
