version 17.0
set more off

/*******************************************************************************
    Purpose:
        Estimate Census/RGE cross-sectional employment elasticities with
        respect to annual turnover by embedded Census exporter status.

    Inputs:
        Data/Analysis/CMR_census_cleaned.dta

    Outputs:
        Data/Analysis/cmr_census_exporter_turnover_elasticity.dta
        output/tables/cmr_census_exporter_turnover_elasticity.tex
        output/tables/cmr_census_exporter_turnover_elasticity_audit.tex
        output/figures/cmr_census_exporter_turnover_elasticity_coefficients.pdf
        output/figures/cmr_census_exporter_turnover_elasticity_coefficients.png

    Notes:
        Exporter status is defined from the embedded Census export turnover
        field: census_exporter == 1. The Census is a cross-section, so the
        estimates are descriptive associations with robust standard errors.
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
        display as error "Add this user to the bootstrap block in code/elasticity_cameroun/16_cmr_census_exporter_turnover_elasticity.do."
        exit 601
    }

    capture noisily cd "${project_root}"
    if _rc | !fileexists("AGENTS.md") {
        display as error "Configured project_root is not a valid repo root: ${project_root}"
        exit 601
    }

    do "code/01_setup.do"
}

local sleep_ms = real("${SLEEP_MS}")
if missing(`sleep_ms') {
    local sleep_ms 750
}

local log_stamp = subinstr(c(current_time), ":", "", .)
local log_stamp = subinstr("`log_stamp'", " ", "", .)

capture log close cmrcensusexporterelasticity
capture log using "${LOGDIR}/16_cmr_census_exporter_turnover_elasticity_`log_stamp'.log", ///
    text name(cmrcensusexporterelasticity)
if _rc {
    sleep `sleep_ms'
    capture log using "${LOGDIR}/16_cmr_census_exporter_turnover_elasticity_`log_stamp'.log", ///
        text name(cmrcensusexporterelasticity)
}
if _rc {
    display as error "Unable to open the Census exporter elasticity log after retry."
    error _rc
}

local census_clean "${DATADIR}/Analysis/CMR_census_cleaned.dta"
local output_stub "cmr_census_exporter_turnover_elasticity"
local min_sector_firms 30
local min_group_firms 10

confirm file "`census_clean'"

tempfile census_analysis sector_support sector_estimates

/*******************************************************************************
    1. Build the headquarters-level estimation sample
*******************************************************************************/

use "`census_clean'", clear

confirm variable firmid_census
confirm variable hq_sample
confirm variable employment
confirm variable annual_turnover
confirm variable nacam
confirm variable nacam_label_short_display
confirm variable nacam_label_display
confirm variable data_export
confirm variable census_exporter

keep firmid_census hq_sample employment annual_turnover nacam ///
    nacam_label_display nacam_label_short_display data_export census_exporter ///
    employment_missing employment_zero employment_negative ///
    turnover_missing turnover_zero turnover_negative ///
    census_export_turnover census_export_zero census_export_missing

assert !missing(firmid_census)
isid firmid_census
assert inlist(census_exporter, 0, 1) if !missing(census_exporter)

generate double ln_emp = ln(employment) if employment > 0
generate double ln_annual_turnover = ln(annual_turnover) if annual_turnover > 0

generate byte admin_overlap_hq = hq_sample == 1 & !missing(nacam)
generate byte sample_elasticity = admin_overlap_hq == 1 ///
    & employment > 0 ///
    & annual_turnover > 0 ///
    & inlist(census_exporter, 0, 1) ///
    & !missing(ln_emp, ln_annual_turnover, nacam, ///
        nacam_label_short_display, data_export)

label variable ln_emp "Log employment"
label variable ln_annual_turnover "Log annual turnover"
label variable sample_elasticity "Census exporter-turnover estimation sample"

save "`census_analysis'", replace

/*******************************************************************************
    2. Audit sector support for exporter and non-exporter slopes
*******************************************************************************/

preserve
keep if admin_overlap_hq == 1

generate byte hq_row = 1
generate byte usable_row = sample_elasticity == 1
generate byte exporter_row = sample_elasticity == 1 & census_exporter == 1
generate byte nonexporter_row = sample_elasticity == 1 & census_exporter == 0

generate double ln_turnover_supported = ln_annual_turnover if usable_row == 1
generate double ln_turnover_exporter = ln_annual_turnover if exporter_row == 1
generate double ln_turnover_nonexporter = ln_annual_turnover if nonexporter_row == 1
generate double ln_emp_supported = ln_emp if usable_row == 1

collapse ///
    (sum) hq_firms = hq_row ///
        usable_firms = usable_row ///
        exporter_firms = exporter_row ///
        nonexporter_firms = nonexporter_row ///
    (sd) sd_ln_emp = ln_emp_supported ///
        sd_ln_turnover = ln_turnover_supported ///
        sd_ln_turnover_exporter = ln_turnover_exporter ///
        sd_ln_turnover_nonexporter = ln_turnover_nonexporter, ///
    by(nacam nacam_label_display nacam_label_short_display data_export)

replace sd_ln_turnover_exporter = 0 if exporter_firms <= 1
replace sd_ln_turnover_nonexporter = 0 if nonexporter_firms <= 1
replace sd_ln_emp = 0 if usable_firms <= 1
replace sd_ln_turnover = 0 if usable_firms <= 1

generate byte include_sector = usable_firms >= `min_sector_firms' ///
    & exporter_firms >= `min_group_firms' ///
    & nonexporter_firms >= `min_group_firms' ///
    & sd_ln_emp > 0 ///
    & sd_ln_turnover > 0 ///
    & sd_ln_turnover_exporter > 0 ///
    & sd_ln_turnover_nonexporter > 0

generate str96 suppression_reason = ""
replace suppression_reason = "Fewer than `min_sector_firms' usable firms" ///
    if usable_firms < `min_sector_firms'
replace suppression_reason = "Fewer than `min_group_firms' exporters" ///
    if usable_firms >= `min_sector_firms' ///
    & exporter_firms < `min_group_firms'
replace suppression_reason = "Fewer than `min_group_firms' non-exporters" ///
    if usable_firms >= `min_sector_firms' ///
    & exporter_firms >= `min_group_firms' ///
    & nonexporter_firms < `min_group_firms'
replace suppression_reason = "No supported log employment variation" ///
    if usable_firms >= `min_sector_firms' ///
    & exporter_firms >= `min_group_firms' ///
    & nonexporter_firms >= `min_group_firms' ///
    & sd_ln_emp <= 0
replace suppression_reason = "No supported log turnover variation" ///
    if usable_firms >= `min_sector_firms' ///
    & exporter_firms >= `min_group_firms' ///
    & nonexporter_firms >= `min_group_firms' ///
    & sd_ln_emp > 0 ///
    & sd_ln_turnover <= 0
replace suppression_reason = "No exporter log turnover variation" ///
    if usable_firms >= `min_sector_firms' ///
    & exporter_firms >= `min_group_firms' ///
    & nonexporter_firms >= `min_group_firms' ///
    & sd_ln_emp > 0 ///
    & sd_ln_turnover > 0 ///
    & sd_ln_turnover_exporter <= 0
replace suppression_reason = "No non-exporter log turnover variation" ///
    if usable_firms >= `min_sector_firms' ///
    & exporter_firms >= `min_group_firms' ///
    & nonexporter_firms >= `min_group_firms' ///
    & sd_ln_emp > 0 ///
    & sd_ln_turnover > 0 ///
    & sd_ln_turnover_exporter > 0 ///
    & sd_ln_turnover_nonexporter <= 0
replace suppression_reason = "Reported" if include_sector == 1

label variable hq_firms "Headquarters firms with admin-overlap NACAM sector"
label variable usable_firms "Positive employment and annual turnover firms"
label variable exporter_firms "Usable firms with positive embedded Census export turnover"
label variable nonexporter_firms "Usable firms without positive embedded Census export turnover"
label variable include_sector "Reported in exporter-turnover elasticity plot"
label variable suppression_reason "Reason sector is reported or suppressed"

sort nacam
isid nacam
save "`sector_support'", replace

generate str16 rowname = "nacam_" + string(nacam)
mkmat hq_firms usable_firms exporter_firms nonexporter_firms include_sector, ///
    matrix(audit_table) rownames(rowname)
matrix colnames audit_table = HQFirms UsableFirms Exporters NonExporters Reported

local audit_rowlabels
quietly count
local audit_n = r(N)
forvalues i = 1/`audit_n' {
    local code = nacam[`i']
    local audit_label = subinstr(nacam_label_short_display[`i'], "&", "\&", .)
    local audit_label = subinstr("`audit_label'", char(34), "'", .)
    local audit_rowlabels `audit_rowlabels' nacam_`code' "`audit_label'"
}

esttab matrix(audit_table, fmt(%12.0fc %12.0fc %12.0fc %12.0fc %9.0f)) ///
    using "${OUTPUTDIR}/tables/`output_stub'_audit.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    collabels("HQ firms" "Usable firms" "Exporters" "Non-exporters" "Reported") ///
    varlabels(`audit_rowlabels')
restore

/*******************************************************************************
    3. Estimate sector-specific total, non-exporter, and exporter slopes
*******************************************************************************/

use "`census_analysis'", clear
merge m:1 nacam using "`sector_support'", nogen keep(master match) ///
    keepusing(hq_firms usable_firms exporter_firms nonexporter_firms ///
        include_sector suppression_reason)

quietly count if sample_elasticity == 1 & include_sector == 1
local supported_sample = r(N)
if `supported_sample' == 0 {
    display as error "No Census observations meet the exporter-turnover sample and sector-support rules."
    exit 2000
}

tempname estimates_handle
postfile `estimates_handle' int nacam ///
    double total_elasticity total_se total_lb total_ub ///
    double nonexporter_elasticity nonexporter_se nonexporter_lb nonexporter_ub ///
    double exporter_elasticity exporter_se exporter_lb exporter_ub ///
    double exporter_difference difference_se difference_lb difference_ub difference_p ///
    long observations exporters nonexporters byte estimated ///
    using "`sector_estimates'", replace

levelsof nacam if sample_elasticity == 1 & include_sector == 1, local(codes)

foreach code of local codes {
    quietly summarize usable_firms if nacam == `code', meanonly
    local sector_obs = r(mean)
    quietly summarize exporter_firms if nacam == `code', meanonly
    local sector_exporters = r(mean)
    quietly summarize nonexporter_firms if nacam == `code', meanonly
    local sector_nonexporters = r(mean)

    scalar total_b = .
    scalar total_se = .
    scalar total_lb = .
    scalar total_ub = .
    scalar nonexporter_b = .
    scalar nonexporter_se = .
    scalar nonexporter_lb = .
    scalar nonexporter_ub = .
    scalar exporter_b = .
    scalar exporter_se = .
    scalar exporter_lb = .
    scalar exporter_ub = .
    scalar difference_b = .
    scalar difference_se = .
    scalar difference_lb = .
    scalar difference_ub = .
    scalar difference_p = .
    local estimated = 0

    capture quietly regress ln_emp c.ln_annual_turnover ///
        if sample_elasticity == 1 & include_sector == 1 ///
        & nacam == `code', vce(robust)

    if !_rc {
        scalar total_b = _b[ln_annual_turnover]
        scalar total_se = _se[ln_annual_turnover]
        scalar total_lb = total_b - invnormal(0.975) * total_se
        scalar total_ub = total_b + invnormal(0.975) * total_se

        capture quietly regress ln_emp ///
            c.ln_annual_turnover##ib0.census_exporter ///
            if sample_elasticity == 1 & include_sector == 1 ///
            & nacam == `code', vce(robust)

        if !_rc {
            capture quietly lincom ln_annual_turnover
            if !_rc {
                scalar nonexporter_b = r(estimate)
                scalar nonexporter_se = r(se)
                scalar nonexporter_lb = r(lb)
                scalar nonexporter_ub = r(ub)

                quietly lincom ln_annual_turnover + ///
                    1.census_exporter#c.ln_annual_turnover
                scalar exporter_b = r(estimate)
                scalar exporter_se = r(se)
                scalar exporter_lb = r(lb)
                scalar exporter_ub = r(ub)

                quietly lincom 1.census_exporter#c.ln_annual_turnover
                scalar difference_b = r(estimate)
                scalar difference_se = r(se)
                scalar difference_lb = r(lb)
                scalar difference_ub = r(ub)
                scalar difference_p = r(p)

                local estimated = 1
            }
        }
    }

    post `estimates_handle' (`code') ///
        (total_b) (total_se) (total_lb) (total_ub) ///
        (nonexporter_b) (nonexporter_se) (nonexporter_lb) (nonexporter_ub) ///
        (exporter_b) (exporter_se) (exporter_lb) (exporter_ub) ///
        (difference_b) (difference_se) (difference_lb) (difference_ub) ///
        (difference_p) ///
        (`sector_obs') (`sector_exporters') (`sector_nonexporters') ///
        (`estimated')
}
postclose `estimates_handle'

use "`sector_support'", clear
merge 1:1 nacam using "`sector_estimates'", nogen

replace estimated = 0 if missing(estimated)
replace observations = usable_firms if missing(observations)
replace exporters = exporter_firms if missing(exporters)
replace nonexporters = nonexporter_firms if missing(nonexporters)
replace suppression_reason = "Regression failed" ///
    if include_sector == 1 & estimated == 0

assert estimated == 0 if include_sector == 0
assert !missing(total_elasticity, total_se, total_lb, total_ub, ///
    nonexporter_elasticity, nonexporter_se, nonexporter_lb, nonexporter_ub, ///
    exporter_elasticity, exporter_se, exporter_lb, exporter_ub, ///
    exporter_difference, difference_se, difference_lb, difference_ub, ///
    difference_p) if estimated == 1
assert abs(exporter_elasticity - nonexporter_elasticity - exporter_difference) < 1e-8 ///
    if estimated == 1

label variable total_elasticity "All-firm Census turnover-employment elasticity"
label variable nonexporter_elasticity "Non-exporter Census turnover-employment elasticity"
label variable exporter_elasticity "Exporter Census turnover-employment elasticity"
label variable exporter_difference "Exporter minus non-exporter elasticity"
label variable difference_p "P-value for exporter slope difference"
label variable observations "Positive employment and annual turnover observations"
label variable exporters "Usable embedded-Census exporters"
label variable nonexporters "Usable embedded-Census non-exporters"
label variable estimated "Exporter-interaction elasticity estimated"

order nacam nacam_label_short_display data_export estimated include_sector ///
    total_elasticity total_se total_lb total_ub ///
    nonexporter_elasticity nonexporter_se nonexporter_lb nonexporter_ub ///
    exporter_elasticity exporter_se exporter_lb exporter_ub ///
    exporter_difference difference_se difference_lb difference_ub difference_p ///
    observations exporters nonexporters hq_firms usable_firms suppression_reason
sort nacam
isid nacam

capture save "${DATADIR}/Analysis/`output_stub'.dta", replace
if _rc {
    sleep `sleep_ms'
    capture save "${DATADIR}/Analysis/`output_stub'.dta", replace
}
if _rc {
    display as error "Unable to save Census exporter elasticity estimates after retry."
    error _rc
}

/*******************************************************************************
    4. Export table and coefficient plot
*******************************************************************************/

preserve
keep if estimated == 1 & include_sector == 1
gsort -total_elasticity nacam
generate str16 rowname = "nacam_" + string(nacam)

mkmat total_elasticity total_se nonexporter_elasticity nonexporter_se ///
    exporter_elasticity exporter_se exporter_difference difference_p ///
    observations exporters nonexporters, ///
    matrix(exporter_table) rownames(rowname)
matrix colnames exporter_table = Total TotalSE NonExporter NonExporterSE ///
    Exporter ExporterSE Difference PValue Obs Exporters NonExporters

local table_rowlabels
quietly count
local table_n = r(N)
forvalues i = 1/`table_n' {
    local code = nacam[`i']
    local table_label = subinstr(nacam_label_short_display[`i'], "&", "\&", .)
    local table_label = subinstr("`table_label'", char(34), "'", .)
    local table_rowlabels `table_rowlabels' nacam_`code' "`table_label'"
}

esttab matrix(exporter_table, ///
    fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f ///
        %12.0fc %12.0fc %12.0fc)) ///
    using "${OUTPUTDIR}/tables/`output_stub'.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    collabels("Total" "SE" "Non-exporter" "SE" "Exporter" "SE" ///
        "Difference" "P-value" "Obs." "Exporters" "Non-exporters") ///
    varlabels(`table_rowlabels')
restore

keep if estimated == 1 & include_sector == 1
gsort -total_elasticity nacam
generate int plot_order = _n
generate double y_total = plot_order - 0.24
generate double y_nonexporter = plot_order
generate double y_exporter = plot_order + 0.24

capture label drop census_exporter_elasticity_axis
quietly count
local plot_n = r(N)
forvalues i = 1/`plot_n' {
    local plot_label = subinstr(nacam_label_short_display[`i'], "&", "\&", .)
    local plot_label = subinstr("`plot_label'", char(34), "'", .)
    if `i' == 1 {
        label define census_exporter_elasticity_axis `i' `"`plot_label'"'
    }
    else {
        label define census_exporter_elasticity_axis `i' `"`plot_label'"', modify
    }
}
label values plot_order census_exporter_elasticity_axis
label values y_total census_exporter_elasticity_axis
label values y_nonexporter census_exporter_elasticity_axis
label values y_exporter census_exporter_elasticity_axis

twoway ///
    (rcap total_lb total_ub y_total, ///
        horizontal lcolor("86 180 233") lwidth(thin)) ///
    (scatter y_total total_elasticity, ///
        msymbol(circle) mcolor("0 114 178") msize(small)) ///
    (rcap nonexporter_lb nonexporter_ub y_nonexporter, ///
        horizontal lcolor("153 153 153") lwidth(thin)) ///
    (scatter y_nonexporter nonexporter_elasticity, ///
        msymbol(square) mcolor("80 80 80") msize(small)) ///
    (rcap exporter_lb exporter_ub y_exporter, ///
        horizontal lcolor("0 158 115") lwidth(thin)) ///
    (scatter y_exporter exporter_elasticity, ///
        msymbol(triangle) mcolor("0 158 115") msize(small)), ///
    ylabel(1(1)`plot_n', valuelabel angle(0) labsize(tiny) nogrid) ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    yscale(reverse) ///
    xline(0, lpattern(dash) lcolor(black)) ///
    legend(order(2 "All firms" 4 "Non-exporters" 6 "Exporters") ///
        rows(1) pos(6) size(small) region(lcolor(none) fcolor(none))) ///
    ytitle("") ///
    xtitle("Employment elasticity with respect to annual turnover", size(small)) ///
    title("Census turnover-employment elasticities by exporter status", size(medsmall)) ///
    subtitle("Exporter status uses positive embedded Census export turnover", size(small)) ///
    note("Cross-sectional Census headquarters firms. Robust 95 percent confidence intervals.", ///
        size(vsmall)) ///
    plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
    xsize(8.5) ysize(5.5)

graph export "${OUTPUTDIR}/figures/`output_stub'_coefficients.pdf", replace
graph export "${OUTPUTDIR}/figures/`output_stub'_coefficients.png", replace

display as result "Saved Census exporter-turnover elasticity outputs."
display as result "Reported sectors: `plot_n'"

log close cmrcensusexporterelasticity
