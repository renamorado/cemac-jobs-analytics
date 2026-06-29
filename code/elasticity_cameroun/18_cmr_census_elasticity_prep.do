version 17.0
set more off

/*******************************************************************************
    Purpose:
        Prepare the Census/RGE cross-sectional dataset used by the elasticity
        models.

    Inputs:
        Data/Analysis/CMR_census_cleaned.dta

    Outputs:
        Data/Analysis/cmr_census_elasticity_clean.dta

    Notes:
        This file creates the log variables, sample flags, and sector support
        fields used by the Census elasticity specifications. It does not run
        regressions, export tables, or create figures.
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

local input_file "${DATADIR}/Analysis/CMR_census_cleaned.dta"
local output_file "${DATADIR}/Analysis/cmr_census_elasticity_clean.dta"
local min_sector_firms 30
local min_group_firms 10

confirm file "`input_file'"

use "`input_file'", clear

foreach var in firmid_census hq_sample employment annual_turnover nacam ///
    nacam_label_short_display nacam_label_display data_export review_flag ///
    census_exporter {
    confirm variable `var'
}

keep firmid_census hq_sample employment annual_turnover nacam ///
    nacam_label_display nacam_label_short_display data_export review_flag ///
    census_exporter employment_missing employment_zero employment_negative ///
    turnover_missing turnover_zero turnover_negative ///
    census_export_turnover census_export_zero census_export_missing

assert !missing(firmid_census)
isid firmid_census
assert inlist(census_exporter, 0, 1) if !missing(census_exporter)

* Logs are defined only for positive values because the Census elasticities are
* interpreted as log employment responses to log annual turnover.
generate double ln_emp = ln(employment) if employment > 0
generate double ln_annual_turnover = ln(annual_turnover) if annual_turnover > 0

* The elasticity sample is restricted to headquarters with a harmonized NACAM
* sector and positive employment and turnover.
generate byte admin_overlap_hq = hq_sample == 1 & !missing(nacam)
generate byte sample_elasticity = admin_overlap_hq == 1 ///
    & employment > 0 ///
    & annual_turnover > 0 ///
    & !missing(ln_emp, ln_annual_turnover, nacam, ///
        nacam_label_short_display, data_export)
generate byte sample_exporter_elasticity = sample_elasticity == 1 ///
    & inlist(census_exporter, 0, 1)

* Sector support keeps the workbook and production scripts from reporting slopes
* for sectors with too little sample or no within-sector variation.
preserve
keep if admin_overlap_hq == 1

generate byte hq_row = 1
generate byte usable_row = sample_elasticity == 1
generate byte exporter_usable_row = sample_exporter_elasticity == 1 ///
    & census_exporter == 1
generate byte nonexporter_usable_row = sample_exporter_elasticity == 1 ///
    & census_exporter == 0

generate double ln_turnover_supported = ln_annual_turnover if usable_row == 1
generate double ln_emp_supported = ln_emp if usable_row == 1
generate double ln_turnover_exporter = ln_annual_turnover ///
    if exporter_usable_row == 1
generate double ln_turnover_nonexporter = ln_annual_turnover ///
    if nonexporter_usable_row == 1

generate byte employment_missing_hq = missing(employment)
generate byte employment_zero_hq = employment == 0 if !missing(employment)
replace employment_zero_hq = 0 if missing(employment_zero_hq)
generate byte turnover_missing_hq = missing(annual_turnover)
generate byte turnover_zero_hq = annual_turnover == 0 if !missing(annual_turnover)
replace turnover_zero_hq = 0 if missing(turnover_zero_hq)
generate byte review_flag_hq = review_flag == 1 if !missing(review_flag)
replace review_flag_hq = 0 if missing(review_flag_hq)

collapse ///
    (sum) hq_firms = hq_row ///
        usable_firms = usable_row ///
        exporter_firms = exporter_usable_row ///
        nonexporter_firms = nonexporter_usable_row ///
        employment_missing_hq employment_zero_hq ///
        turnover_missing_hq turnover_zero_hq review_flag_hq ///
    (sd) sd_ln_emp = ln_emp_supported ///
        sd_ln_annual_turnover = ln_turnover_supported ///
        sd_ln_turnover_exporter = ln_turnover_exporter ///
        sd_ln_turnover_nonexporter = ln_turnover_nonexporter, ///
    by(nacam nacam_label_display nacam_label_short_display data_export)

replace sd_ln_turnover_exporter = 0 if exporter_firms <= 1
replace sd_ln_turnover_nonexporter = 0 if nonexporter_firms <= 1
replace sd_ln_emp = 0 if usable_firms <= 1
replace sd_ln_annual_turnover = 0 if usable_firms <= 1

generate byte include_census_sector = usable_firms >= `min_sector_firms' ///
    & sd_ln_emp > 0 ///
    & sd_ln_annual_turnover > 0
generate byte include_census_exporter_sector = ///
    usable_firms >= `min_sector_firms' ///
    & exporter_firms >= `min_group_firms' ///
    & nonexporter_firms >= `min_group_firms' ///
    & sd_ln_emp > 0 ///
    & sd_ln_annual_turnover > 0 ///
    & sd_ln_turnover_exporter > 0 ///
    & sd_ln_turnover_nonexporter > 0

generate str96 census_support_reason = "Reported" if include_census_sector == 1
replace census_support_reason = "Fewer than `min_sector_firms' positive employment-turnover firms" ///
    if include_census_sector == 0 & usable_firms < `min_sector_firms'
replace census_support_reason = "No supported log variation" ///
    if include_census_sector == 0 & census_support_reason == ""

generate str96 exporter_support_reason = "Reported" ///
    if include_census_exporter_sector == 1
replace exporter_support_reason = "Fewer than `min_sector_firms' usable firms" ///
    if include_census_exporter_sector == 0 ///
    & usable_firms < `min_sector_firms'
replace exporter_support_reason = "Fewer than `min_group_firms' exporters" ///
    if include_census_exporter_sector == 0 ///
    & exporter_support_reason == "" ///
    & exporter_firms < `min_group_firms'
replace exporter_support_reason = "Fewer than `min_group_firms' non-exporters" ///
    if include_census_exporter_sector == 0 ///
    & exporter_support_reason == "" ///
    & nonexporter_firms < `min_group_firms'
replace exporter_support_reason = "No supported exporter/non-exporter variation" ///
    if include_census_exporter_sector == 0 ///
    & exporter_support_reason == ""

isid nacam
tempfile sector_support
save "`sector_support'"
restore

merge m:1 nacam using "`sector_support'", nogen keep(master match)

label variable ln_emp "Log employment"
label variable ln_annual_turnover "Log annual turnover"
label variable admin_overlap_hq "Headquarters firm with harmonized NACAM sector"
label variable sample_elasticity "Census turnover-employment sample"
label variable sample_exporter_elasticity "Census exporter-turnover sample"
label variable include_census_sector "Sector meets Census elasticity support rule"
label variable include_census_exporter_sector "Sector meets Census exporter support rule"
label variable census_support_reason "Reason sector is reported or suppressed"
label variable exporter_support_reason "Reason exporter sector is reported or suppressed"

order firmid_census hq_sample admin_overlap_hq nacam nacam_label_display ///
    nacam_label_short_display data_export employment annual_turnover ///
    census_exporter ln_emp ln_annual_turnover sample_elasticity ///
    sample_exporter_elasticity include_census_sector ///
    include_census_exporter_sector hq_firms usable_firms exporter_firms ///
    nonexporter_firms

compress
save "`output_file'", replace

display as result "Saved Census elasticity clean dataset to `output_file'."
