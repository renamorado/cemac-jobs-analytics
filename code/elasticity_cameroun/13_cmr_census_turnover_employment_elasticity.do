version 17.0
set more off

/*******************************************************************************
    Purpose:
        Estimate cross-sectional Census/RGE employment elasticities with respect
        to annual turnover, then compare them with administrative tax/BDF
        total-revenue employment elasticities.

    Inputs:
        Data/Analysis/CMR_census_cleaned.dta
        Data/Analysis/cmr_nacam_fe_robustness_estimates.dta

    Outputs:
        Data/Analysis/cmr_census_turnover_employment_elasticity.dta
        Data/Analysis/cmr_census_vs_bdf_turnover_employment_elasticity.dta
        output/tables/cmr_census_turnover_employment_elasticity.tex
        output/tables/cmr_census_turnover_employment_elasticity_audit.tex
        output/tables/cmr_census_vs_bdf_turnover_employment_elasticity.tex
        output/figures/cmr_census_turnover_employment_elasticity_coefficients.pdf
        output/figures/cmr_census_turnover_employment_elasticity_coefficients.png
        output/figures/cmr_census_turnover_employment_elasticity_scatter.pdf
        output/figures/cmr_census_turnover_employment_elasticity_scatter.png
        output/figures/cmr_census_vs_bdf_turnover_employment_elasticity.pdf
        output/figures/cmr_census_vs_bdf_turnover_employment_elasticity.png

    Notes:
        The Census is a cross-section. These estimates do not use firm fixed
        effects, year fixed effects, or NACAM-by-year fixed effects.
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
        display as error "Add this user to the bootstrap block in code/elasticity_cameroun/13_cmr_census_turnover_employment_elasticity.do."
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

capture log close cmrcensuselasticity
capture log using "${LOGDIR}/13_cmr_census_turnover_employment_elasticity_`log_stamp'.log", ///
    text name(cmrcensuselasticity)
if _rc {
    sleep `sleep_ms'
    capture log using "${LOGDIR}/13_cmr_census_turnover_employment_elasticity_`log_stamp'.log", ///
        text name(cmrcensuselasticity)
}
if _rc {
    display as error "Unable to open the Census elasticity log after retry."
    error _rc
}

local census_clean "${DATADIR}/Analysis/CMR_census_cleaned.dta"
local bdf_elasticities "${DATADIR}/Analysis/cmr_nacam_fe_robustness_estimates.dta"
local output_stub "cmr_census_turnover_employment_elasticity"
local min_sector_firms 30

confirm file "`census_clean'"
confirm file "`bdf_elasticities'"

tempfile census_analysis sector_support sector_estimates table_rows ///
    census_estimates_for_compare bdf_baseline comparison_data

/*******************************************************************************
    1. Build the cross-sectional Census analysis sample
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
confirm variable review_flag

keep firmid_census hq_sample employment annual_turnover nacam ///
    nacam_label_display nacam_label_short_display data_export review_flag ///
    employment_missing employment_zero employment_negative ///
    turnover_missing turnover_zero turnover_negative

assert !missing(firmid_census)
isid firmid_census

generate double ln_emp = ln(employment) if employment > 0
generate double ln_annual_turnover = ln(annual_turnover) if annual_turnover > 0

generate byte admin_overlap_hq = hq_sample == 1 & !missing(nacam)
generate byte sample_elasticity = admin_overlap_hq == 1 ///
    & employment > 0 ///
    & annual_turnover > 0 ///
    & !missing(ln_emp, ln_annual_turnover, nacam, ///
        nacam_label_short_display, data_export)

label variable ln_emp "Log employment"
label variable ln_annual_turnover "Log annual turnover"
label variable sample_elasticity "Census turnover-employment estimation sample"

save "`census_analysis'", replace

/*******************************************************************************
    2. Audit sector support and suppression reasons
*******************************************************************************/

preserve
keep if admin_overlap_hq == 1

generate byte hq_row = 1
generate byte employment_missing_hq = missing(employment)
generate byte employment_zero_hq = employment == 0 if !missing(employment)
replace employment_zero_hq = 0 if missing(employment_zero_hq)
generate byte employment_nonpositive_hq = employment <= 0 if !missing(employment)
replace employment_nonpositive_hq = 0 if missing(employment_nonpositive_hq)

generate byte turnover_missing_hq = missing(annual_turnover)
generate byte turnover_zero_hq = annual_turnover == 0 if !missing(annual_turnover)
replace turnover_zero_hq = 0 if missing(turnover_zero_hq)
generate byte turnover_nonpositive_hq = annual_turnover <= 0 if !missing(annual_turnover)
replace turnover_nonpositive_hq = 0 if missing(turnover_nonpositive_hq)

generate byte review_flag_hq = review_flag == 1 if !missing(review_flag)
replace review_flag_hq = 0 if missing(review_flag_hq)

collapse ///
    (sum) hq_firms = hq_row ///
        usable_firms = sample_elasticity ///
        employment_missing_hq employment_zero_hq employment_nonpositive_hq ///
        turnover_missing_hq turnover_zero_hq turnover_nonpositive_hq ///
        review_flag_hq ///
    (sd) sd_ln_emp = ln_emp sd_ln_annual_turnover = ln_annual_turnover, ///
    by(nacam nacam_label_display nacam_label_short_display data_export)

generate byte include_sector = usable_firms >= `min_sector_firms' ///
    & sd_ln_emp > 0 ///
    & sd_ln_annual_turnover > 0

generate str80 suppression_reason = ""
replace suppression_reason = "Fewer than `min_sector_firms' positive employment-turnover firms" ///
    if usable_firms < `min_sector_firms'
replace suppression_reason = "No within-sector log employment variation" ///
    if usable_firms >= `min_sector_firms' & sd_ln_emp <= 0
replace suppression_reason = "No within-sector log turnover variation" ///
    if usable_firms >= `min_sector_firms' & sd_ln_emp > 0 ///
    & sd_ln_annual_turnover <= 0
replace suppression_reason = "Reported" if include_sector == 1

label variable hq_firms "Headquarters firms with admin-overlap NACAM sector"
label variable usable_firms "Positive employment and annual turnover firms"
label variable include_sector "Reported in sector-specific elasticity table"
label variable suppression_reason "Reason sector is reported or suppressed"

sort nacam
isid nacam
save "`sector_support'", replace

generate str16 rowname = "nacam_" + string(nacam)
mkmat hq_firms usable_firms employment_zero_hq turnover_zero_hq ///
    include_sector, matrix(audit_table) rownames(rowname)
matrix colnames audit_table = HQFirms UsableFirms EmpZero TurnoverZero Reported

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
    collabels("HQ firms" "Usable firms" "Zero emp." "Zero turnover" "Reported") ///
    varlabels(`audit_rowlabels')
restore

/*******************************************************************************
    3. Estimate common and sector-specific Census elasticities
*******************************************************************************/

use "`census_analysis'", clear
merge m:1 nacam using "`sector_support'", nogen keep(master match) ///
    keepusing(hq_firms usable_firms sd_ln_emp sd_ln_annual_turnover ///
        include_sector suppression_reason)

quietly count if sample_elasticity == 1 & include_sector == 1
local common_sample = r(N)
if `common_sample' == 0 {
    display as error "No Census observations meet the elasticity sample and sector-support rules."
    exit 2000
}

regress ln_emp c.ln_annual_turnover i.nacam ///
    if sample_elasticity == 1 & include_sector == 1, vce(robust)

local common_elasticity = _b[ln_annual_turnover]
local common_se = _se[ln_annual_turnover]
local common_lb = `common_elasticity' - invnormal(0.975) * `common_se'
local common_ub = `common_elasticity' + invnormal(0.975) * `common_se'
local common_obs = e(N)

regress ln_emp c.ln_annual_turnover##i.nacam ///
    if sample_elasticity == 1 & include_sector == 1, vce(robust)

tempname estimates_handle
postfile `estimates_handle' int nacam double census_elasticity ///
    census_se census_lb census_ub long observations firms byte estimated ///
    using "`sector_estimates'", replace

levelsof nacam if e(sample), local(codes)
local base_code : word 1 of `codes'

foreach code of local codes {
    quietly summarize usable_firms if nacam == `code', meanonly
    local sector_firms = r(mean)
    local sector_obs = r(mean)

    if `code' == `base_code' {
        capture noisily lincom _b[ln_annual_turnover]
    }
    else {
        capture noisily lincom _b[ln_annual_turnover] + ///
            _b[`code'.nacam#c.ln_annual_turnover]
    }

    if _rc {
        post `estimates_handle' (`code') (.) (.) (.) (.) ///
            (`sector_obs') (`sector_firms') (0)
    }
    else {
        post `estimates_handle' (`code') (r(estimate)) (r(se)) ///
            (r(lb)) (r(ub)) (`sector_obs') (`sector_firms') (1)
    }
}
postclose `estimates_handle'

use "`sector_support'", clear
merge 1:1 nacam using "`sector_estimates'", nogen

replace estimated = 0 if missing(estimated)
replace observations = usable_firms if missing(observations)
replace firms = usable_firms if missing(firms)

label variable census_elasticity "Census annual-turnover employment elasticity"
label variable census_se "Robust standard error"
label variable census_lb "Lower 95 percent confidence bound"
label variable census_ub "Upper 95 percent confidence bound"
label variable observations "Positive employment and annual turnover observations"
label variable firms "Positive employment and annual turnover firms"
label variable estimated "Sector-specific elasticity estimated"

order nacam nacam_label_short_display data_export census_elasticity ///
    census_se census_lb census_ub observations firms include_sector ///
    estimated suppression_reason
sort nacam
isid nacam

capture save "${DATADIR}/Analysis/`output_stub'.dta", replace
if _rc {
    sleep `sleep_ms'
    capture save "${DATADIR}/Analysis/`output_stub'.dta", replace
}
if _rc {
    display as error "Unable to save Census elasticity estimates after retry."
    error _rc
}

save "`census_estimates_for_compare'", replace

/*******************************************************************************
    4. Export Census elasticity table and coefficient plot
*******************************************************************************/

preserve
clear
set obs 1
generate str16 rowname = "common"
generate byte common_row = 1
generate double census_elasticity = `common_elasticity'
generate double census_se = `common_se'
generate double census_lb = `common_lb'
generate double census_ub = `common_ub'
generate double firms = `common_obs'
generate double observations = `common_obs'
save "`table_rows'", replace
restore

keep if estimated == 1 & include_sector == 1
gsort -census_elasticity nacam
generate str16 rowname = "nacam_" + string(nacam)
generate byte common_row = 0
append using "`table_rows'"
gsort -common_row -census_elasticity nacam

mkmat census_elasticity census_se census_lb census_ub firms observations, ///
    matrix(census_table) rownames(rowname)
matrix colnames census_table = Elasticity StdErr Lower95 Upper95 Firms Obs

local table_rowlabels common "Common slope with sector FE"
quietly count
local table_n = r(N)
forvalues i = 1/`table_n' {
    if rowname[`i'] != "common" {
        local code = nacam[`i']
        local table_label = subinstr(nacam_label_short_display[`i'], "&", "\&", .)
        local table_label = subinstr("`table_label'", char(34), "'", .)
        local table_rowlabels `table_rowlabels' nacam_`code' "`table_label'"
    }
}

esttab matrix(census_table, fmt(%9.3f %9.3f %9.3f %9.3f %12.0fc %12.0fc)) ///
    using "${OUTPUTDIR}/tables/`output_stub'.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels(`table_rowlabels')

use "`census_estimates_for_compare'", clear
keep if estimated == 1 & include_sector == 1
gsort -census_elasticity nacam
generate int plot_order = _n

capture label drop census_elasticity_axis
quietly count
local plot_n = r(N)
forvalues i = 1/`plot_n' {
    local plot_label = subinstr(nacam_label_short_display[`i'], "&", "\&", .)
    local plot_label = subinstr("`plot_label'", char(34), "'", .)
    if `i' == 1 {
        label define census_elasticity_axis `i' `"`plot_label'"'
    }
    else {
        label define census_elasticity_axis `i' `"`plot_label'"', modify
    }
}
label values plot_order census_elasticity_axis

twoway ///
    (rcap census_lb census_ub plot_order if strpos(data_export, "Agriculture") > 0, horizontal lcolor("102 194 165")) ///
    (scatter plot_order census_elasticity if strpos(data_export, "Agriculture") > 0, msymbol(circle) mcolor("27 158 119")) ///
    (rcap census_lb census_ub plot_order if strpos(data_export, "Mining") > 0, horizontal lcolor("190 174 212")) ///
    (scatter plot_order census_elasticity if strpos(data_export, "Mining") > 0, msymbol(diamond) mcolor("117 112 179")) ///
    (rcap census_lb census_ub plot_order if strpos(data_export, "Manufacturing") > 0, horizontal lcolor("141 160 203")) ///
    (scatter plot_order census_elasticity if strpos(data_export, "Manufacturing") > 0, msymbol(square) mcolor("44 123 182")) ///
    (rcap census_lb census_ub plot_order if data_export == "Utilities", horizontal lcolor("252 217 142")) ///
    (scatter plot_order census_elasticity if data_export == "Utilities", msymbol(triangle) mcolor("230 171 2")) ///
    (rcap census_lb census_ub plot_order if strpos(data_export, "Construction") > 0, horizontal lcolor("231 138 195")) ///
    (scatter plot_order census_elasticity if strpos(data_export, "Construction") > 0, msymbol(Oh) mcolor("208 28 139")) ///
    (rcap census_lb census_ub plot_order if strpos(data_export, "Wholesale") > 0, horizontal lcolor("247 194 145")) ///
    (scatter plot_order census_elasticity if strpos(data_export, "Wholesale") > 0, msymbol(Th) mcolor("217 95 2")) ///
    (rcap census_lb census_ub plot_order if strpos(data_export, "Transportation") > 0, horizontal lcolor("179 222 105")) ///
    (scatter plot_order census_elasticity if strpos(data_export, "Transportation") > 0, msymbol(Sh) mcolor("102 166 30")) ///
    (rcap census_lb census_ub plot_order if strpos(data_export, "Information") > 0, horizontal lcolor("166 216 84")) ///
    (scatter plot_order census_elasticity if strpos(data_export, "Information") > 0, msymbol(plus) mcolor("102 166 30")) ///
    (rcap census_lb census_ub plot_order if strpos(data_export, "Financial") > 0, horizontal lcolor("188 128 189")) ///
    (scatter plot_order census_elasticity if strpos(data_export, "Financial") > 0, msymbol(x) mcolor("117 112 179")) ///
    (rcap census_lb census_ub plot_order if data_export == "Other services", horizontal lcolor("190 190 190")) ///
    (scatter plot_order census_elasticity if data_export == "Other services", msymbol(Dh) mcolor("102 102 102")), ///
    ylabel(1(1)`plot_n', valuelabel angle(0) labsize(tiny) nogrid) ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    yscale(reverse) ///
    xline(0, lpattern(dash) lcolor(black)) ///
    legend(order(2 "Agriculture" 4 "Mining" 6 "Manufacturing" 8 "Utilities" ///
        10 "Construction" 12 "Wholesale/retail + repair" 14 "Transport" 16 "ICT" ///
        18 "Finance" 20 "Other services") cols(1) pos(3) ring(1) size(tiny) ///
        region(lcolor(none) fcolor(none))) ///
    ytitle("") ///
    xtitle("Employment elasticity with respect to annual turnover", size(small)) ///
    title("Census cross-sectional turnover-employment elasticities", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
    xsize(7.5) ysize(5.5)

graph export "${OUTPUTDIR}/figures/`output_stub'_coefficients.pdf", replace
graph export "${OUTPUTDIR}/figures/`output_stub'_coefficients.png", replace

/*******************************************************************************
    5. Export diagnostic log-log scatter plot
*******************************************************************************/

use "`census_analysis'", clear
merge m:1 nacam using "`sector_support'", nogen keep(master match) ///
    keepusing(include_sector)
keep if sample_elasticity == 1 & include_sector == 1

set seed 20260616
quietly count
local scatter_full_n = r(N)
if `scatter_full_n' > 10000 {
    sample 10000, count
}

twoway ///
    (scatter ln_emp ln_annual_turnover, ///
        msymbol(circle) msize(tiny) mcolor(gs12)) ///
    (lfit ln_emp ln_annual_turnover, lcolor("27 158 119") lwidth(medthick)), ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    ylabel(, grid glpattern(dash) glcolor(gs13)) ///
    xtitle("Log annual turnover", size(small)) ///
    ytitle("Log employment", size(small)) ///
    title("Census log employment and log annual turnover", size(medsmall)) ///
    subtitle("Random 10,000-firm diagnostic sample from supported sectors", size(small)) ///
    legend(order(1 "Census firms" 2 "Linear fit") rows(1) pos(6) size(tiny) ///
        region(lcolor(none) fcolor(none))) ///
    plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
    xsize(7.5) ysize(4.8)

graph export "${OUTPUTDIR}/figures/`output_stub'_scatter.pdf", replace
graph export "${OUTPUTDIR}/figures/`output_stub'_scatter.png", replace

/*******************************************************************************
    6. Compare Census and administrative tax/BDF total-revenue elasticities
*******************************************************************************/

use "`bdf_elasticities'", clear
keep if outcome == "tot_rev" & spec_id == 1
keep nacam elasticity se lb ub observations firms
rename elasticity bdf_tot_rev_elasticity
rename se bdf_tot_rev_se
rename lb bdf_tot_rev_lb
rename ub bdf_tot_rev_ub
rename observations bdf_observations
rename firms bdf_firms
sort nacam
isid nacam
save "`bdf_baseline'", replace

use "`census_estimates_for_compare'", clear
merge 1:1 nacam using "`bdf_baseline'", generate(bdf_merge)

generate byte comparison_sample = estimated == 1 & include_sector == 1 ///
    & bdf_merge == 3
label variable comparison_sample "Sector appears in Census and BDF/tax comparison"

capture save "${DATADIR}/Analysis/cmr_census_vs_bdf_turnover_employment_elasticity.dta", replace
if _rc {
    sleep `sleep_ms'
    capture save "${DATADIR}/Analysis/cmr_census_vs_bdf_turnover_employment_elasticity.dta", replace
}
if _rc {
    display as error "Unable to save Census-vs-BDF comparison dataset after retry."
    error _rc
}

save "`comparison_data'", replace

preserve
keep if comparison_sample == 1
gsort -census_elasticity nacam

generate str16 rowname = "nacam_" + string(nacam)
mkmat census_elasticity census_se firms bdf_tot_rev_elasticity ///
    bdf_tot_rev_se bdf_firms bdf_observations, ///
    matrix(comparison_table) rownames(rowname)
matrix colnames comparison_table = CensusElasticity CensusSE CensusFirms ///
    BDFElasticity BDFSE BDFFirms BDFObs

local comparison_rowlabels
quietly count
local comparison_n = r(N)
forvalues i = 1/`comparison_n' {
    local code = nacam[`i']
    local comparison_label = subinstr(nacam_label_short_display[`i'], "&", "\&", .)
    local comparison_label = subinstr("`comparison_label'", char(34), "'", .)
    local comparison_rowlabels `comparison_rowlabels' nacam_`code' "`comparison_label'"
}

esttab matrix(comparison_table, fmt(%9.3f %9.3f %12.0fc %9.3f %9.3f %9.0fc %9.0fc)) ///
    using "${OUTPUTDIR}/tables/cmr_census_vs_bdf_turnover_employment_elasticity.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    collabels("Census elast." "Census SE" "Census firms" ///
        "BDF elast." "BDF SE" "BDF firms" "BDF obs.") ///
    varlabels(`comparison_rowlabels')
restore

use "`comparison_data'", clear
keep if comparison_sample == 1

generate byte label_sector = census_elasticity >= 0.45 ///
    | bdf_tot_rev_elasticity >= 0.45 ///
    | bdf_tot_rev_elasticity < -0.05 ///
    | abs(census_elasticity - bdf_tot_rev_elasticity) > 0.35

quietly summarize census_elasticity
local x_min = r(min)
local x_max = r(max)
quietly summarize bdf_tot_rev_elasticity
local y_min = r(min)
local y_max = r(max)
local diagonal_min = min(`x_min', `y_min')
local diagonal_max = max(`x_max', `y_max')

twoway ///
    (function y = x, range(`diagonal_min' `diagonal_max') ///
        lpattern(solid) lcolor(black) lwidth(medthin)) ///
    (lfit bdf_tot_rev_elasticity census_elasticity, ///
        lpattern(dash) lcolor(gs8) lwidth(medthick)) ///
    (scatter bdf_tot_rev_elasticity census_elasticity, ///
        msymbol(circle) mcolor("44 123 182") msize(medium)) ///
    (scatter bdf_tot_rev_elasticity census_elasticity if label_sector == 1, ///
        msymbol(none) mlabel(nacam_label_short_display) ///
        mlabposition(9) mlabsize(tiny) mlabcolor(black)), ///
    xline(0, lpattern(dash) lcolor(black)) ///
    yline(0, lpattern(dash) lcolor(black)) ///
    xscale(range(-0.25 0.90)) ///
    yscale(range(-0.25 0.85)) ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    ylabel(, grid glpattern(dash) glcolor(gs13)) ///
    xtitle("Census cross-sectional turnover elasticity", size(small)) ///
    ytitle("Administrative tax/BDF panel total-revenue elasticity", size(small)) ///
    title("Census and tax/BDF employment elasticities", size(medsmall)) ///
    subtitle("Overlapping NACAM sectors only", size(small)) ///
    text(0.67 0.62 "45-degree line", size(vsmall) color(black) place(e)) ///
    legend(order(2 "Fitted relationship" 3 "NACAM sectors") rows(1) ///
        pos(6) size(tiny) region(lcolor(none) fcolor(none))) ///
    plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
    xsize(7.5) ysize(5.2)

graph export "${OUTPUTDIR}/figures/cmr_census_vs_bdf_turnover_employment_elasticity.pdf", replace
graph export "${OUTPUTDIR}/figures/cmr_census_vs_bdf_turnover_employment_elasticity.png", replace

display as result "Saved Census turnover-employment elasticity outputs."
display as result "Common Census turnover-employment elasticity: " ///
    %6.3f `common_elasticity' " (SE " %6.3f `common_se' ")"

log close cmrcensuselasticity
