version 17.0
set more off

/*******************************************************************************
    Purpose:
        User-friendly workbook for the current elasticity model specifications.

    Inputs:
        Data/Analysis/cmr_census_elasticity_clean.dta
        Data/Analysis/cmr_bdf_elasticity_clean.dta
        Data/Analysis/wbes_elasticity_clean.dta

    Outputs:
        None. This file intentionally does not save datasets, export tables, or
        export figures. Production outputs remain in their source do-files.

    Notes:
        This workbook is designed for checking and adjusting model
        specifications after the data have already been cleaned and prepared.
*******************************************************************************/

* Use the project setup so all dataset paths are available from any working
* directory. The setup file also confirms the local repo structure.
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

local zcrit = invnormal(.975)
local wbes_controls ///
    c.ln_firm_age c.foreign_own_share c.gov_own_share i.isic4_section_fe

/*******************************************************************************
    Helper: display sector-specific slopes after interaction regressions.

    The interaction models estimate one slope for the base category plus
    adjustments for each other category. The helper prints each implied slope
    so the coefficient can be read as the elasticity for that sector.
*******************************************************************************/
capture program drop print_sector_slopes
program define print_sector_slopes
    version 17.0
    syntax, Regressor(name) Sectorvar(name) Sampleif(string)

    levelsof `sectorvar' if `sampleif', local(codes)
    local base_code : word 1 of `codes'

    foreach code of local codes {
        if `code' == `base_code' {
            lincom _b[`regressor']
        }
        else {
            lincom _b[`regressor'] + _b[`code'.`sectorvar'#c.`regressor']
        }
    }
end

/*******************************************************************************
    Part A. Census data
*******************************************************************************/

use "${DATADIR}/Analysis/cmr_census_elasticity_clean.dta", clear

* A.1 Common Census turnover-employment elasticity
* Clean dataset: Data/Analysis/cmr_census_elasticity_clean.dta
* Unit of observation: Census/RGE headquarters firm.
* Outcome/regressor: log employment on log annual turnover.
* Controls/fixed effects: NACAM sector fixed effects, robust standard errors.
* Affected outputs: output/figures/cmr_census_turnover_employment_elasticity_coefficients.pdf;
*   output/figures/cmr_census_turnover_employment_elasticity_scatter.pdf;
*   output/tables/cmr_census_turnover_employment_elasticity.tex.
* Production source: code/elasticity_cameroun/13_cmr_census_turnover_employment_elasticity.do.
regress ln_emp c.ln_annual_turnover i.nacam ///
    if sample_elasticity == 1 & include_census_sector == 1, vce(robust)

* A.2 Sector-specific Census turnover-employment elasticities
* The interaction lets each NACAM sector have its own turnover-employment slope.
* The lincom calls below print the implied elasticity sector by sector.
regress ln_emp c.ln_annual_turnover##i.nacam ///
    if sample_elasticity == 1 & include_census_sector == 1, vce(robust)
print_sector_slopes, regressor(ln_annual_turnover) sectorvar(nacam) ///
    sampleif("sample_elasticity == 1 & include_census_sector == 1")

* A.3 Census exporter and non-exporter turnover-employment elasticities
* Clean dataset: Data/Analysis/cmr_census_elasticity_clean.dta
* Unit of observation: Census/RGE headquarters firm.
* Outcome/regressor: log employment on log annual turnover by exporter status.
* Controls/fixed effects: estimated separately within each eligible NACAM sector.
* Affected outputs: output/figures/cmr_census_exporter_turnover_elasticity_coefficients.pdf;
*   output/tables/cmr_census_exporter_turnover_elasticity.tex.
* Production source: code/elasticity_cameroun/16_cmr_census_exporter_turnover_elasticity.do.
levelsof nacam if sample_exporter_elasticity == 1 ///
    & include_census_exporter_sector == 1, local(census_exporter_codes)

foreach code of local census_exporter_codes {
    display as text "Census exporter specification for NACAM sector `code'"

    regress ln_emp c.ln_annual_turnover ///
        if sample_exporter_elasticity == 1 ///
        & include_census_exporter_sector == 1 ///
        & nacam == `code', vce(robust)

    regress ln_emp c.ln_annual_turnover##ib0.census_exporter ///
        if sample_exporter_elasticity == 1 ///
        & include_census_exporter_sector == 1 ///
        & nacam == `code', vce(robust)

    * Non-exporter slope, exporter slope, and exporter minus non-exporter gap.
    lincom ln_annual_turnover
    lincom ln_annual_turnover + 1.census_exporter#c.ln_annual_turnover
    lincom 1.census_exporter#c.ln_annual_turnover
}

/*******************************************************************************
    Part B. Tax/BDF data
*******************************************************************************/

use "${DATADIR}/Analysis/cmr_bdf_elasticity_clean.dta", clear

* B.1 Baseline value-added employment elasticities by NACAM sector
* Clean dataset: Data/Analysis/cmr_bdf_elasticity_clean.dta
* Unit of observation: firm-year.
* Outcome/regressor: log employment on log value added.
* Controls/fixed effects: firm fixed effects and NACAM-by-year fixed effects;
*   standard errors clustered by firm.
* Affected outputs: output/figures/cmr_nacam_results_en_labels_va_coefficients.pdf;
*   output/tables/cmr_nacam_results_en_labels_va_elasticity.tex.
* Production source: code/elasticity_cameroun/06_cmr_nacam_elasticity.do.
areg ln_emp c.ln_va##i.nacam i.nacam#i.fin_yr ///
    if sample_va == 1 & include_sector == 1, ///
    absorb(firm_fe) vce(cluster firm_fe)
print_sector_slopes, regressor(ln_va) sectorvar(nacam) ///
    sampleif("sample_va == 1 & include_sector == 1")

* B.2 Baseline total-revenue employment elasticities by NACAM sector
* This is the administrative tax/BDF elasticity used in the Census comparison
* and in the downstream B-READY/WBES opportunity plots.
* Affected outputs: output/figures/cmr_nacam_results_en_labels_tot_rev_coefficients.pdf;
*   output/figures/cmr_census_vs_bdf_turnover_employment_elasticity.pdf;
*   output/tables/cmr_nacam_results_en_labels_tot_rev_elasticity.tex.
areg ln_emp c.ln_tot_rev##i.nacam i.nacam#i.fin_yr ///
    if sample_tot_rev == 1 & include_sector == 1, ///
    absorb(firm_fe) vce(cluster firm_fe)
print_sector_slopes, regressor(ln_tot_rev) sectorvar(nacam) ///
    sampleif("sample_tot_rev == 1 & include_sector == 1")

* B.3 Fixed-effect robustness: value added
* These specifications show whether sector elasticities are sensitive to the
* fixed-effect structure.
* Affected output: output/figures/cmr_nacam_fe_robustness_va_coefficients.pdf.
* Production source: code/elasticity_cameroun/10_cmr_fe_robustness_plots.do.
areg ln_emp c.ln_va##i.nacam i.nacam#i.fin_yr ///
    if sample_va == 1 & include_sector == 1, ///
    absorb(firm_fe) vce(cluster firm_fe)
areg ln_emp c.ln_va##i.nacam i.fin_yr ///
    if sample_va == 1 & include_sector == 1, ///
    absorb(firm_fe) vce(cluster firm_fe)
areg ln_emp c.ln_va##i.nacam i.data_export_fe#i.fin_yr ///
    if sample_va == 1 & include_sector == 1, ///
    absorb(firm_fe) vce(cluster firm_fe)

* B.4 Fixed-effect robustness: total revenue
* Affected output: output/figures/cmr_nacam_fe_robustness_tot_rev_coefficients.pdf.
areg ln_emp c.ln_tot_rev##i.nacam i.nacam#i.fin_yr ///
    if sample_tot_rev == 1 & include_sector == 1, ///
    absorb(firm_fe) vce(cluster firm_fe)
areg ln_emp c.ln_tot_rev##i.nacam i.fin_yr ///
    if sample_tot_rev == 1 & include_sector == 1, ///
    absorb(firm_fe) vce(cluster firm_fe)
areg ln_emp c.ln_tot_rev##i.nacam i.data_export_fe#i.fin_yr ///
    if sample_tot_rev == 1 & include_sector == 1, ///
    absorb(firm_fe) vce(cluster firm_fe)

* B.5 Fixed-asset elasticities
* These models ask how employment and sales turnover move with net fixed assets.
* Affected outputs: output/figures/cmr_fixed_asset_elasticity_employment_coefficients.pdf;
*   output/figures/cmr_fixed_asset_elasticity_sales_coefficients.pdf.
* Production source: code/elasticity_cameroun/15_cmr_fixed_asset_elasticity_figures.do.
areg ln_emp c.ln_fixed_assets##i.nacam i.nacam#i.fin_yr ///
    if sample_fixed_asset_employment == 1 ///
    & include_fixed_asset_sector == 1, ///
    absorb(firm_fe) vce(cluster firm_fe)
print_sector_slopes, regressor(ln_fixed_assets) sectorvar(nacam) ///
    sampleif("sample_fixed_asset_employment == 1 & include_fixed_asset_sector == 1")

areg ln_sales_turnover c.ln_fixed_assets##i.nacam i.nacam#i.fin_yr ///
    if sample_fixed_asset_sales == 1 ///
    & include_fixed_asset_sector == 1, ///
    absorb(firm_fe) vce(cluster firm_fe)
print_sector_slopes, regressor(ln_fixed_assets) sectorvar(nacam) ///
    sampleif("sample_fixed_asset_sales == 1 & include_fixed_asset_sector == 1")

/*******************************************************************************
    Part C. WBES data
*******************************************************************************/

use "${DATADIR}/Analysis/wbes_elasticity_clean.dta", clear

* C.1 WBES country export-value/employment associations
* Clean dataset: Data/Analysis/wbes_elasticity_clean.dta
* Unit of observation: latest-wave WBES firm.
* Outcome/regressor: log employment on log export value.
* Controls/fixed effects: firm age, ownership shares, ISIC section FE; weighted
*   regressions with robust standard errors.
* Affected outputs: output/figures/cemac_wbes_trade_elasticity_country_all_firms.pdf;
*   output/figures/cemac_wbes_trade_elasticity_country_exporters_only.pdf.
* Production source: code/WBES_trade/03_wbes_trade_elasticity.do.
levelsof country_name, local(wbes_countries)

foreach country of local wbes_countries {
    quietly count if country_name == "`country'" & all_firm_sample == 1
    local n_all = r(N)
    quietly count if country_name == "`country'" & all_firm_sample == 1 ///
        & export_status == 1
    local exporters_all = r(N)
    quietly count if country_name == "`country'" & all_firm_sample == 1 ///
        & export_status == 0
    local nonexporters_all = r(N)

    if `n_all' >= 30 & `exporters_all' > 0 & `nonexporters_all' > 0 {
        display as text "WBES all-firm export-value model: `country'"
        regress ln_emp ln_export_value_all export_status ///
            `wbes_controls' [pweight = weight] ///
            if country_name == "`country'" & all_firm_sample == 1, ///
            vce(robust)
    }

    quietly count if country_name == "`country'" & exporter_only_sample == 1
    local n_exporter = r(N)

    if `n_exporter' >= 30 {
        display as text "WBES exporter-only export-value model: `country'"
        regress ln_emp ln_export_value ///
            `wbes_controls' [pweight = weight] ///
            if country_name == "`country'" & exporter_only_sample == 1, ///
            vce(robust)
    }
}

* C.2 Cameroon WBES activity-group export-value/employment associations
* Affected outputs: output/figures/cemac_wbes_trade_elasticity_cameroon_activity_all_firms.pdf;
*   output/figures/cemac_wbes_trade_elasticity_cameroon_activity_exporters_only.pdf.
levelsof activity_group if country_name == "Cameroon", local(wbes_activities)

foreach activity of local wbes_activities {
    quietly count if country_name == "Cameroon" ///
        & activity_group == "`activity'" & all_firm_sample == 1
    local n_all = r(N)
    quietly count if country_name == "Cameroon" ///
        & activity_group == "`activity'" & all_firm_sample == 1 ///
        & export_status == 1
    local exporters_all = r(N)
    quietly count if country_name == "Cameroon" ///
        & activity_group == "`activity'" & all_firm_sample == 1 ///
        & export_status == 0
    local nonexporters_all = r(N)

    if `n_all' >= 30 & `exporters_all' > 0 & `nonexporters_all' > 0 {
        display as text "Cameroon WBES all-firm model: `activity'"
        regress ln_emp ln_export_value_all export_status ///
            `wbes_controls' [pweight = weight] ///
            if country_name == "Cameroon" ///
            & activity_group == "`activity'" & all_firm_sample == 1, ///
            vce(robust)
    }

    quietly count if country_name == "Cameroon" ///
        & activity_group == "`activity'" & exporter_only_sample == 1
    local n_exporter = r(N)

    if `n_exporter' >= 30 {
        display as text "Cameroon WBES exporter-only model: `activity'"
        regress ln_emp ln_export_value ///
            `wbes_controls' [pweight = weight] ///
            if country_name == "Cameroon" ///
            & activity_group == "`activity'" & exporter_only_sample == 1, ///
            vce(robust)
    }
}

* C.3 WBES revenue-exporter interaction models
* These models compare the employment-revenue slope for exporters and
* non-exporters. They are cross-sectional associations, not causal effects.
* Affected outputs: output/figures/cemac_wbes_revenue_exporter_interaction_country.pdf;
*   output/figures/cemac_wbes_revenue_exporter_interaction_cameroon_activity.pdf.
* Production source: code/WBES_trade/04_wbes_revenue_exporter_interaction.do.
foreach country of local wbes_countries {
    quietly count if country_name == "`country'" & revenue_interaction_sample == 1
    local n_total = r(N)
    quietly count if country_name == "`country'" ///
        & revenue_interaction_sample == 1 & export_status == 1
    local n_exporters = r(N)
    quietly count if country_name == "`country'" ///
        & revenue_interaction_sample == 1 & export_status == 0
    local n_nonexporters = r(N)

    if `n_total' >= 30 & `n_exporters' >= 10 & `n_nonexporters' >= 10 {
        display as text "WBES revenue-exporter interaction: `country'"
        regress ln_emp c.ln_revenue##ib0.export_status ///
            `wbes_controls' [pweight = weight] ///
            if country_name == "`country'" ///
            & revenue_interaction_sample == 1, vce(robust)

        lincom ln_revenue
        lincom ln_revenue + 1.export_status#c.ln_revenue
        lincom 1.export_status#c.ln_revenue
    }
}

foreach activity of local wbes_activities {
    quietly count if country_name == "Cameroon" ///
        & activity_group == "`activity'" & revenue_interaction_sample == 1
    local n_total = r(N)
    quietly count if country_name == "Cameroon" ///
        & activity_group == "`activity'" & revenue_interaction_sample == 1 ///
        & export_status == 1
    local n_exporters = r(N)
    quietly count if country_name == "Cameroon" ///
        & activity_group == "`activity'" & revenue_interaction_sample == 1 ///
        & export_status == 0
    local n_nonexporters = r(N)

    if `n_total' >= 30 & `n_exporters' >= 10 & `n_nonexporters' >= 10 {
        display as text "Cameroon WBES revenue-exporter interaction: `activity'"
        regress ln_emp c.ln_revenue##ib0.export_status ///
            `wbes_controls' [pweight = weight] ///
            if country_name == "Cameroon" ///
            & activity_group == "`activity'" ///
            & revenue_interaction_sample == 1, vce(robust)

        lincom ln_revenue
        lincom ln_revenue + 1.export_status#c.ln_revenue
        lincom 1.export_status#c.ln_revenue
    }
}

display as result "Elasticity model workbook completed. No outputs were written."
