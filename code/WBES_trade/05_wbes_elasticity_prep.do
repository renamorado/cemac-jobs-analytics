version 17.0
set more off

/*******************************************************************************
    Purpose:
        Prepare the latest-wave WBES dataset used by the trade and revenue
        elasticity specifications.

    Inputs:
        Data/Analysis/wbes_trade_clean.dta

    Outputs:
        Data/Analysis/wbes_elasticity_clean.dta

    Notes:
        This file creates analysis groups, log variables, fixed-effect
        identifiers, and sample flags. It does not estimate models or write
        tables/figures.
*******************************************************************************/

local username = lower("`c(username)'")

if "`username'" == "user" {
    global project_root "C:/Users/User/Documents/Projects/cemac-jobs-analytics"
}
else if "`username'" == "wb648862" {
    global project_root "C:/Users/wb648862/Documents/Projects/CEMAC"
}
else if "`username'" == "wb603585" {
    global project_root "C:/Users/wb603585/OneDrive - WBG/Documents/Projects/CEMAC/FY26/CEMAC jobs analytics"
}
else if fileexists("AGENTS.md") {
    global project_root "`=subinstr(c(pwd), "\", "/", .)'"
}
else {
    display as error "No project_root path is configured for Windows user `c(username)'."
    exit 601
}

capture noisily cd "${project_root}"
if _rc | !fileexists("AGENTS.md") {
    display as error "Configured project_root is not a valid repo root: ${project_root}"
    exit 601
}

do "code/01_setup.do"

local input_file "${DATADIR}/Analysis/wbes_trade_clean.dta"
local output_file "${DATADIR}/Analysis/wbes_elasticity_clean.dta"

confirm file "`input_file'"

use "`input_file'", clear

foreach var in ///
    firm_id country_name cemac_country wb_region wb_income_group weight ///
    employment export_value sales_w export_status isic4_section ///
    ln_firm_age foreign_own_share gov_own_share {
    confirm variable `var'
}

assert !missing(weight)
assert weight > 0
assert inlist(export_status, 0, 1) if !missing(export_status)

* These comparison groups match the current WBES slide workflow: retained
* CEMAC countries, SSA excluding CEMAC, and high-income benchmark economies.
generate byte retained_cemac = cemac_country == 1 & country_name != "Gabon"
generate byte ssa_excl_cemac = ///
    strpos(wb_region, "Sub-Saharan Africa") > 0 & cemac_country != 1
generate byte high_income = strpos(wb_income_group, "High income") > 0
generate byte wbes_display_sample = ///
    retained_cemac == 1 | ssa_excl_cemac == 1 | high_income == 1

generate str40 display_name = country_name
replace display_name = "Central Afr. Rep." ///
    if country_name == "Central African Republic"
replace display_name = "Eq. Guinea" if country_name == "Equatorial Guinea"

* Cameroon activity groups keep the workbook readable and match the production
* WBES figures that aggregate detailed ISIC sections.
generate str36 activity_group = ""
replace activity_group = "Manufacturing" if isic4_section == "C"
replace activity_group = "Construction/utilities" if inlist(isic4_section, "E", "F")
replace activity_group = "Trade/hospitality/transport" ///
    if inlist(isic4_section, "G", "H", "I")
replace activity_group = "Other services" ///
    if inlist(isic4_section, "J", "K", "M", "N", "S")
replace activity_group = "Other/unclear activity" ///
    if missing(activity_group) | activity_group == ""

generate str16 isic4_section_fe_label = isic4_section
replace isic4_section_fe_label = "Unknown" if isic4_section_fe_label == ""
encode isic4_section_fe_label, generate(isic4_section_fe)

* The WBES models are weighted cross-sectional log-log associations, so
* non-positive employment, export values, and sales are excluded as needed.
generate double ln_emp = ln(employment) if employment > 0
generate double ln_export_value = ln(export_value) if export_value > 0
generate double ln_export_value_all = .
replace ln_export_value_all = 0 if export_status == 0
replace ln_export_value_all = ln_export_value ///
    if export_status == 1 & !missing(ln_export_value)
generate double ln_revenue = ln(sales_w) if sales_w > 0

generate byte all_firm_sample = !missing(ln_emp, ln_export_value_all, ///
    export_status, weight, ln_firm_age, foreign_own_share, gov_own_share)
generate byte exporter_only_sample = !missing(ln_emp, ln_export_value, ///
    weight, ln_firm_age, foreign_own_share, gov_own_share) ///
    & export_status == 1
generate byte revenue_interaction_sample = !missing(ln_emp, ln_revenue, ///
    export_status, weight, ln_firm_age, foreign_own_share, gov_own_share)

keep if wbes_display_sample == 1

label variable retained_cemac "Retained CEMAC country"
label variable ssa_excl_cemac "Sub-Saharan Africa excluding CEMAC"
label variable high_income "High-income benchmark economy"
label variable activity_group "Cameroon activity group"
label variable isic4_section_fe "ISIC Rev.4 section fixed effect"
label variable ln_emp "Log employment"
label variable ln_export_value "Log export value among exporters"
label variable ln_export_value_all "Log export value, zero for non-exporters"
label variable ln_revenue "Log winsorized annual sales"
label variable all_firm_sample "WBES all-firm export-value sample"
label variable exporter_only_sample "WBES exporter-only export-value sample"
label variable revenue_interaction_sample "WBES revenue-exporter interaction sample"

compress
save "`output_file'", replace

display as result "Saved WBES elasticity clean dataset to `output_file'."
