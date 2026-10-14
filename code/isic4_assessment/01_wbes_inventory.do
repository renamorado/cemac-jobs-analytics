version 17.0
set more off

local out "${OUTPUTDIR}/checks/isic4_assessment"
local tables "${OUTPUTDIR}/tables/isic4_assessment"
local source "${DATADIR}/World Bank Enterprise Survey/New_Comprehensive_July_21_2025.dta"
local reference "${PROJECT_ROOT}/docs/reference/isic_rev4_english_structure.csv"
confirm file "`source'"
confirm file "`reference'"
tempfile divisions classes wbes

* Check membership against the complete official structure, not a numeric range.
import delimited using "`reference'", varnames(1) stringcols(_all) clear
rename code isic_code
isid isic_code
preserve
keep if strlen(isic_code) == 2
assert _N == 88
rename isic_code division_code
rename description division_label
save "`divisions'"
restore
keep if strlen(isic_code) == 4
assert _N == 419
rename isic_code class_code
rename description class_label
save "`classes'"

use idstd country sample wt l1 d2 isic_v4 isic_v3_1 d1a2_v4 using "`source'", clear
local extract_rows = _N
generate str80 country_wave = country
generate int survey_year = real(substr(country_wave, strlen(country_wave)-3, 4))
generate str60 country_name = strtrim(substr(country_wave, 1, strlen(country_wave)-4))
replace country_name = "Cote d'Ivoire" if strpos(country_name, "Ivoire") > 0
assert !missing(country_name, survey_year)
generate byte cemac = inlist(country_name, "Cameroon", "Central African Republic", ///
    "Chad", "Congo", "Equatorial Guinea", "Gabon")
count if cemac
display as text "WBES CEMAC records retained = " r(N) " out of `extract_rows' source records."
keep if cemac
local source_rows = _N
generate byte latest_wave = sample == 1
assert inlist(sample, 0, 1)
generate byte one = 1
duplicates tag country_wave idstd, generate(duplicate_id)
generate byte missing_id = missing(idstd)
generate byte duplicate_id_row = duplicate_id > 0

generate str2 division_code = string(isic_v4, "%02.0f") if !missing(isic_v4)
merge m:1 division_code using "`divisions'", keep(master match) generate(division_merge)
tab division_merge, missing
assert _N == `source_rows'
generate byte valid_division = division_merge == 3 & isic_v4 == floor(isic_v4) ///
    & isic_v4 == real(division_code)
generate byte missing_division = missing(isic_v4)
generate byte invalid_division = !missing_division & !valid_division
drop division_merge

generate str4 class_code = string(d1a2_v4, "%04.0f") if !missing(d1a2_v4)
merge m:1 class_code using "`classes'", keep(master match) generate(class_merge)
tab class_merge, missing
assert _N == `source_rows'
generate byte valid_class = class_merge == 3 & d1a2_v4 == floor(d1a2_v4) ///
    & d1a2_v4 == real(class_code)
generate byte missing_class = missing(d1a2_v4)
generate byte invalid_class = !missing_class & !valid_class
generate byte conflict = valid_division & valid_class ///
    & division_code != substr(class_code, 1, 2)

* Do not resolve conflicts silently. A valid native division remains useful
* when a class is absent. Nonmissing invalid fields require separate review.
generate str36 mapping_status = "unresolved"
replace mapping_status = "native_division_and_class_agree" ///
    if valid_division & valid_class & !conflict
replace mapping_status = "native_division_only" if valid_division & missing_class
replace mapping_status = "division_derived_from_class" if missing_division & valid_class
replace mapping_status = "conflicting_valid_codes" if conflict
replace mapping_status = "invalid_code_present" if invalid_division | invalid_class
generate str2 assessed_division = division_code ///
    if inlist(mapping_status, "native_division_and_class_agree", "native_division_only")
replace assessed_division = substr(class_code, 1, 2) ///
    if mapping_status == "division_derived_from_class"
generate byte usable_code = !missing(assessed_division)
generate byte has_isic31 = !missing(isic_v3_1)
assert usable_code == 0 if conflict | invalid_division | invalid_class

merge m:1 country_name using "${DATADIR}/Intermediate/wbes_wb_country_metadata.dta", ///
    keep(master match) keepusing(wb_region wb_income_group) generate(metadata_merge)
tab metadata_merge, missing
assert _N == `source_rows'
generate byte missing_metadata = metadata_merge == 1
generate str24 comparison_group = "retained_CEMAC"
replace comparison_group = "Gabon_excluded" if country_name == "Gabon"
generate byte current_display = latest_wave & country_name != "Gabon"

* Coverage denominators: nonnegative reported employment/sales and positive
* survey weights. Negative WBES special codes are excluded, with counts kept.
generate byte valid_weight = wt > 0 & !missing(wt)
generate double weight_denominator = wt if valid_weight
generate double weight_usable = cond(usable_code, wt, 0) if valid_weight
generate byte observed_employment = l1 >= 0 & !missing(l1)
generate byte observed_revenue = d2 >= 0 & !missing(d2)
generate double employment_denominator = l1 if observed_employment
generate double employment_usable = cond(usable_code, l1, 0) if observed_employment
generate double revenue_denominator = d2 if observed_revenue
generate double revenue_usable = cond(usable_code, d2, 0) if observed_revenue
generate byte positive_emp_sales = l1 > 0 & d2 > 0 & !missing(l1, d2)
save "`wbes'"

preserve
collapse (sum) records=one valid_division valid_class missing_division missing_class ///
    invalid_division invalid_class conflict usable_code has_isic31 valid_weight ///
    missing_id duplicate_id_row missing_metadata observed_employment observed_revenue ///
    weight_denominator weight_usable employment_denominator employment_usable ///
    revenue_denominator revenue_usable positive_emp_sales, ///
    by(country_name country_wave survey_year latest_wave comparison_group current_display)
isid country_wave latest_wave
generate double code_coverage = usable_code / records
generate double weighted_code_coverage = weight_usable / weight_denominator if weight_denominator > 0
generate double employment_coverage = employment_usable / employment_denominator if employment_denominator > 0
generate double revenue_coverage = revenue_usable / revenue_denominator if revenue_denominator > 0
sort country_name survey_year
export delimited using "`out'/wbes_country_wave_coverage.csv", replace
restore

preserve
collapse (sum) records=one, by(country_wave latest_wave mapping_status)
isid country_wave latest_wave mapping_status
export delimited using "`out'/wbes_mapping_status_by_wave.csv", replace
restore

preserve
* This file contains code combinations and counts only, never firm identifiers.
collapse (sum) records=one, by(country_wave latest_wave isic_v4 d1a2_v4 ///
    isic_v3_1 mapping_status assessed_division)
export delimited using "`out'/wbes_code_review.csv", replace
restore

preserve
collapse (sum) records=one positive_emp_sales, ///
    by(country_wave latest_wave current_display assessed_division mapping_status)
export delimited using "`out'/wbes_division_counts.csv", replace
restore

* Counts only across countries: do not sum local-currency sales or raw weights.
collapse (sum) records=one valid_division valid_class usable_code conflict ///
    invalid_division invalid_class has_isic31 missing_id duplicate_id_row, by(latest_wave)
generate str16 rowname = cond(latest_wave, "Latest_waves", "Earlier_waves")
mkmat records valid_division valid_class usable_code conflict invalid_division ///
    invalid_class has_isic31 missing_id duplicate_id_row, matrix(wbes_audit) rownames(rowname)
esttab matrix(wbes_audit, fmt(%12.0fc)) using "`tables'/wbes_code_inventory.tex", ///
    replace booktabs fragment nomtitles nonumbers
export delimited using "`out'/wbes_code_inventory.csv", replace
display as result "WBES classification inventory completed."
