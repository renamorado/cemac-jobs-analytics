version 17.0
set more off

/*******************************************************************************
    Purpose:
        Prepare the Tax/BDF firm-year dataset used by the elasticity models.

    Inputs:
        Data/Analysis/CMR_BDF_isic4_sections_assessment.dta

    Outputs:
        Data/Analysis/CMR_BDF_isic4_section_prepared.dta
        Data/Analysis/cmr_bdf_isic4_section_elasticity_clean.dta

    Notes:
        This file stops before regressions, tables, or figures. It creates the
        log variables, fixed-effect identifiers, sample flags, and sector support
        fields that are shared across the Tax/BDF elasticity specifications.
*******************************************************************************/

if "${PROJECT_ROOT}" == "" {
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
}

local input_file "${DATADIR}/Analysis/CMR_BDF_isic4_sections_assessment.dta"
local output_file "${DATADIR}/Analysis/cmr_bdf_isic4_section_elasticity_clean.dta"
local min_sector_obs 30
local min_sector_firms 10

confirm file "`input_file'"

use "`input_file'", clear

* Validate that classification has preserved every original field and row.
tempfile original_panel
preserve
use "${DATADIR}/Analysis/CMR_BDF_cleaned.dta", clear
isid firmid fin_yr
sort firmid fin_yr
unab original_variables : _all
save `original_panel'
restore
sort firmid fin_yr
cf `original_variables' using `original_panel'
do "${CODEDIR}/02_construct/02_cmr_tax_section_fields.do"

* Keep the full classified panel for scripts with different accounting inputs.
* Regression preparation below adds convenience fields without changing this file.
save "${DATADIR}/Analysis/CMR_BDF_isic4_section_prepared.dta", replace
bysort firmid isic4_sector_id: generate byte section_tag = _n == 1
bysort firmid: egen byte firm_sections = total(section_tag)
egen byte firm_tag = tag(firmid)
count if firm_tag & firm_sections > 1
display as result "Firms reporting more than one section group: " r(N)
drop section_tag firm_sections firm_tag

isid firmid fin_yr
assert !missing(firmid, fin_yr, isic4_sector_id, isic4_label_display, ///
    isic4_label_short_display, isic4_broad_label)

* The fixed-effect identifiers are encoded once here because all Tax/BDF models
* use firm fixed effects and some robustness checks use broad-sector-year FE.
encode firmid, generate(firm_fe)
encode isic4_broad_label, generate(isic4_broad_label_fe)

* Convert the accounting and employment fields to numeric Stata variables before
* taking logs. Positive-value restrictions define the elasticity samples.
foreach var in totemp va tot_rev fa_net sog sls_prod sls_svcs {
    capture confirm numeric variable `var'
    if _rc {
        destring `var', replace ignore(",") force
    }
    confirm numeric variable `var'
}

generate double employment = totemp
generate double fixed_assets = fa_net
egen double sales_turnover = rowtotal(sog sls_prod sls_svcs), missing

generate double ln_emp = ln(employment) if employment > 0
generate double ln_va = ln(va) if va > 0
generate double ln_tot_rev = ln(tot_rev) if tot_rev > 0
generate double ln_fixed_assets = ln(fixed_assets) if fixed_assets > 0
generate double ln_sales_turnover = ln(sales_turnover) if sales_turnover > 0

* These flags make the production and workbook regressions explicit about which
* firm-years enter each elasticity model.
generate byte sample_va = employment > 0 & va > 0 ///
    & !missing(ln_emp, ln_va, firm_fe, fin_yr, isic4_sector_id)
generate byte sample_tot_rev = employment > 0 & tot_rev > 0 ///
    & !missing(ln_emp, ln_tot_rev, firm_fe, fin_yr, isic4_sector_id)
generate byte sample_fixed_asset_employment = employment > 0 ///
    & fixed_assets > 0 ///
    & !missing(ln_emp, ln_fixed_assets, firm_fe, fin_yr, isic4_sector_id)
generate byte sample_fixed_asset_sales = sales_turnover > 0 ///
    & fixed_assets > 0 ///
    & !missing(ln_sales_turnover, ln_fixed_assets, firm_fe, fin_yr, isic4_sector_id)

* Sector support is calculated once so every Tax/BDF model uses the same
* minimum-observation and minimum-firm rule as the current production scripts.
preserve
keep isic4_sector_id firm_fe sample_va sample_tot_rev ///
    sample_fixed_asset_employment sample_fixed_asset_sales ///
    ln_emp ln_va ln_tot_rev ln_fixed_assets ln_sales_turnover

egen tag_va_firm = tag(isic4_sector_id firm_fe) if sample_va == 1
egen tag_tot_rev_firm = tag(isic4_sector_id firm_fe) if sample_tot_rev == 1
egen tag_fixed_asset_employment_firm = tag(isic4_sector_id firm_fe) ///
    if sample_fixed_asset_employment == 1
egen tag_fixed_asset_sales_firm = tag(isic4_sector_id firm_fe) ///
    if sample_fixed_asset_sales == 1

generate double ln_emp_fixed_asset = ln_emp if sample_fixed_asset_employment == 1
generate double ln_sales_fixed_asset = ln_sales_turnover ///
    if sample_fixed_asset_sales == 1
generate double ln_fixed_assets_employment = ln_fixed_assets ///
    if sample_fixed_asset_employment == 1
generate double ln_fixed_assets_sales = ln_fixed_assets ///
    if sample_fixed_asset_sales == 1

collapse ///
    (sum) va_obs = sample_va ///
          tot_rev_obs = sample_tot_rev ///
          fixed_asset_employment_obs = sample_fixed_asset_employment ///
          fixed_asset_sales_obs = sample_fixed_asset_sales ///
          va_firms = tag_va_firm ///
          tot_rev_firms = tag_tot_rev_firm ///
          fixed_asset_employment_firms = tag_fixed_asset_employment_firm ///
          fixed_asset_sales_firms = tag_fixed_asset_sales_firm ///
    (sd) sd_ln_emp_fixed_asset = ln_emp_fixed_asset ///
         sd_ln_sales_fixed_asset = ln_sales_fixed_asset ///
         sd_ln_fixed_assets_employment = ln_fixed_assets_employment ///
         sd_ln_fixed_assets_sales = ln_fixed_assets_sales, ///
    by(isic4_sector_id)

generate byte include_sector = va_obs >= `min_sector_obs' ///
    & va_firms >= `min_sector_firms' ///
    & tot_rev_obs >= `min_sector_obs' ///
    & tot_rev_firms >= `min_sector_firms'

generate byte include_fixed_asset_sector = ///
    fixed_asset_employment_obs >= `min_sector_obs' ///
    & fixed_asset_employment_firms >= `min_sector_firms' ///
    & fixed_asset_sales_obs >= `min_sector_obs' ///
    & fixed_asset_sales_firms >= `min_sector_firms' ///
    & sd_ln_emp_fixed_asset > 0 ///
    & sd_ln_sales_fixed_asset > 0 ///
    & sd_ln_fixed_assets_employment > 0 ///
    & sd_ln_fixed_assets_sales > 0

isid isic4_sector_id
tempfile sector_support
save "`sector_support'"
restore

merge m:1 isic4_sector_id using "`sector_support'", nogen
assert !missing(include_sector, include_fixed_asset_sector) if !missing(isic4_sector_id)

* Sector scale measures support the opportunity-map figures but are still
* constructed before any regression or plotting step.
preserve
keep if employment > 0 & va > 0 & tot_rev > 0 & include_sector == 1 ///
    & !missing(employment, va, tot_rev, firm_fe, fin_yr, isic4_sector_id, ///
        ln_emp, ln_va, ln_tot_rev)

collapse ///
    (sum) sector_year_total_employment = employment ///
          sector_year_total_va = va ///
          sector_year_total_revenue = tot_rev ///
    (count) sector_year_firms = firm_fe, ///
    by(isic4_sector_id fin_yr)

isid isic4_sector_id fin_yr
assert sector_year_total_employment > 0
assert sector_year_total_va > 0
assert sector_year_total_revenue > 0
assert sector_year_firms > 0

generate double sector_year_va_per_worker = ///
    sector_year_total_va / sector_year_total_employment
generate double sector_year_avg_firm_employment = ///
    sector_year_total_employment / sector_year_firms
generate double sector_year_avg_firm_revenue = ///
    sector_year_total_revenue / sector_year_firms

collapse ///
    (mean) avg_annual_total_employment = sector_year_total_employment ///
           avg_annual_total_revenue = sector_year_total_revenue ///
           avg_firm_employment = sector_year_avg_firm_employment ///
           avg_firm_revenue = sector_year_avg_firm_revenue ///
           sector_va_per_worker = sector_year_va_per_worker ///
           avg_annual_firms = sector_year_firms ///
    (count) contributing_years = fin_yr, ///
    by(isic4_sector_id)

generate double ln_sector_va_per_worker = ln(sector_va_per_worker)
isid isic4_sector_id
tempfile sector_scale
save "`sector_scale'"
restore

merge m:1 isic4_sector_id using "`sector_scale'", nogen keep(master match)

label variable firm_fe "Firm fixed-effect identifier"
label variable isic4_broad_label_fe "Broad sector fixed-effect identifier"
label variable employment "Employment"
label variable fixed_assets "Net fixed assets"
label variable sales_turnover "Sales turnover"
label variable ln_emp "Log employment"
label variable ln_va "Log value added"
label variable ln_tot_rev "Log total revenue"
label variable ln_fixed_assets "Log net fixed assets"
label variable ln_sales_turnover "Log sales turnover"
label variable sample_va "Value-added elasticity sample"
label variable sample_tot_rev "Total-revenue elasticity sample"
label variable sample_fixed_asset_employment "Fixed-asset employment sample"
label variable sample_fixed_asset_sales "Fixed-asset sales sample"
label variable include_sector "Sector meets VA and revenue elasticity support rules"
label variable include_fixed_asset_sector "Sector meets fixed-asset support rules"
label variable ln_sector_va_per_worker "Log sector value added per worker"

order firmid firm_fe fin_yr isic4_sector_id isic4_label_display ///
    isic4_label_short_display isic4_broad_label isic4_broad_label_fe employment va ///
    tot_rev fixed_assets sales_turnover ln_emp ln_va ln_tot_rev ///
    ln_fixed_assets ln_sales_turnover sample_va sample_tot_rev ///
    sample_fixed_asset_employment sample_fixed_asset_sales include_sector ///
    include_fixed_asset_sector

compress
save "`output_file'", replace

display as result "Saved Tax/BDF elasticity clean dataset to `output_file'."
