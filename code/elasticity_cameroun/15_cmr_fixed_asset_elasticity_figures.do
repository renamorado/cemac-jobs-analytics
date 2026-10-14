version 17.0
set more off

/*******************************************************************************
    Purpose:
        Estimate Cameroon tax/BDF sector-specific fixed-asset elasticities and
        export coefficient figures for employment and sales turnover outcomes.

    Inputs:
        Data/Analysis/CMR_BDF_isic4_section_prepared.dta

    Outputs:
        Data/Analysis/cmr_isic4_section_fixed_asset_elasticity_estimates.dta
        output/tables/cmr_isic4_section_fixed_asset_elasticity_support_audit.tex
        output/tables/cmr_isic4_section_fixed_asset_elasticity_employment.tex
        output/tables/cmr_isic4_section_fixed_asset_elasticity_sales.tex
        output/figures/cmr_isic4_section_fixed_asset_elasticity_employment_coefficients.pdf
        output/figures/cmr_isic4_section_fixed_asset_elasticity_employment_coefficients.png
        output/figures/cmr_isic4_section_fixed_asset_elasticity_sales_coefficients.pdf
        output/figures/cmr_isic4_section_fixed_asset_elasticity_sales_coefficients.png

    Notes:
        Sales turnover is constructed as the row total of BDF sales components:
        Sales of goods, sales of manufactured products, and sales services.
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
        display as error "Add this user to the bootstrap block in code/elasticity_cameroun/15_cmr_fixed_asset_elasticity_figures.do."
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

capture log close cmrfixedassets
capture log using "${LOGDIR}/15_cmr_fixed_asset_elasticity_figures_`log_stamp'.log", ///
    text name(cmrfixedassets)
if _rc {
    sleep `sleep_ms'
    capture log using "${LOGDIR}/15_cmr_fixed_asset_elasticity_figures_`log_stamp'.log", ///
        text name(cmrfixedassets)
}
if _rc {
    display as error "Unable to open the fixed-asset elasticity log after retry."
    error _rc
}

local input_file "${DATADIR}/Analysis/CMR_BDF_isic4_section_prepared.dta"
local output_stub "cmr_isic4_section_fixed_asset_elasticity"
local min_sector_obs 30
local min_sector_firms 10

confirm file "`input_file'"

tempfile sector_labels sector_counts analysis_panel estimates_raw plot_data

/*******************************************************************************
    1. Prepare the firm-year analysis panel
*******************************************************************************/

use "`input_file'", clear

keep firmid fin_yr isic4_section isic4_sector_id isic4_label_display isic4_label_short_display ///
    isic4_broad_label totemp fa_net sog sls_prod sls_svcs

isid firmid fin_yr
assert !missing(firmid, fin_yr, isic4_sector_id, isic4_label_display, ///
    isic4_label_short_display, isic4_broad_label)

foreach var in totemp fa_net sog sls_prod sls_svcs {
    capture confirm numeric variable `var'
    if _rc {
        destring `var', replace ignore(",") force
    }
    confirm numeric variable `var'
}

preserve
keep isic4_section isic4_sector_id isic4_label_display isic4_label_short_display isic4_broad_label
drop if missing(isic4_sector_id)
bysort isic4_sector_id (isic4_label_display): assert isic4_label_display == isic4_label_display[1]
bysort isic4_sector_id (isic4_label_short_display): assert isic4_label_short_display == isic4_label_short_display[1]
bysort isic4_sector_id (isic4_broad_label): assert isic4_broad_label == isic4_broad_label[1]
by isic4_sector_id: keep if _n == 1
isid isic4_sector_id
save "`sector_labels'"
restore

encode firmid, generate(firm_fe)

generate double employment = totemp
generate double fixed_assets = fa_net
egen double sales_turnover = rowtotal(sog sls_prod sls_svcs), missing

generate double ln_emp = ln(employment) if employment > 0
generate double ln_sales_turnover = ln(sales_turnover) if sales_turnover > 0
generate double ln_fixed_assets = ln(fixed_assets) if fixed_assets > 0

generate byte sample_employment = employment > 0 ///
    & fixed_assets > 0 ///
    & !missing(ln_emp, ln_fixed_assets, firm_fe, fin_yr, isic4_sector_id)
generate byte sample_sales = sales_turnover > 0 ///
    & fixed_assets > 0 ///
    & !missing(ln_sales_turnover, ln_fixed_assets, firm_fe, fin_yr, isic4_sector_id)

label variable employment "Employment"
label variable fixed_assets "Net fixed assets"
label variable sales_turnover "Sales turnover"
label variable ln_emp "Log employment"
label variable ln_sales_turnover "Log sales turnover"
label variable ln_fixed_assets "Log net fixed assets"
label variable sample_employment "Employment fixed-asset elasticity sample"
label variable sample_sales "Sales fixed-asset elasticity sample"

/*******************************************************************************
    2. Count support by sector and export the support audit
*******************************************************************************/

preserve
keep isic4_sector_id firm_fe sample_employment sample_sales ///
    ln_emp ln_sales_turnover ln_fixed_assets

egen tag_employment_firm = tag(isic4_sector_id firm_fe) if sample_employment == 1
egen tag_sales_firm = tag(isic4_sector_id firm_fe) if sample_sales == 1

generate double ln_fixed_assets_employment = ln_fixed_assets ///
    if sample_employment == 1
generate double ln_fixed_assets_sales = ln_fixed_assets ///
    if sample_sales == 1
generate double ln_emp_sample = ln_emp if sample_employment == 1
generate double ln_sales_sample = ln_sales_turnover if sample_sales == 1

collapse ///
    (sum) employment_obs = sample_employment ///
          sales_obs = sample_sales ///
          employment_firms = tag_employment_firm ///
          sales_firms = tag_sales_firm ///
    (sd) sd_ln_emp = ln_emp_sample ///
         sd_ln_sales = ln_sales_sample ///
         sd_ln_fixed_assets_employment = ln_fixed_assets_employment ///
         sd_ln_fixed_assets_sales = ln_fixed_assets_sales, ///
    by(isic4_sector_id)

generate byte include_sector = employment_obs >= `min_sector_obs' ///
    & employment_firms >= `min_sector_firms' ///
    & sales_obs >= `min_sector_obs' ///
    & sales_firms >= `min_sector_firms' ///
    & sd_ln_emp > 0 ///
    & sd_ln_sales > 0 ///
    & sd_ln_fixed_assets_employment > 0 ///
    & sd_ln_fixed_assets_sales > 0

generate str90 support_reason = ""
replace support_reason = "Reported" if include_sector == 1
replace support_reason = "Insufficient employment-model observations or firms" ///
    if include_sector == 0 ///
    & (employment_obs < `min_sector_obs' | employment_firms < `min_sector_firms')
replace support_reason = "Insufficient sales-model observations or firms" ///
    if include_sector == 0 & support_reason == "" ///
    & (sales_obs < `min_sector_obs' | sales_firms < `min_sector_firms')
replace support_reason = "No within-sector employment or asset variation" ///
    if include_sector == 0 & support_reason == "" ///
    & (sd_ln_emp <= 0 | sd_ln_fixed_assets_employment <= 0)
replace support_reason = "No within-sector sales or asset variation" ///
    if include_sector == 0 & support_reason == "" ///
    & (sd_ln_sales <= 0 | sd_ln_fixed_assets_sales <= 0)
replace support_reason = "Not reported" if include_sector == 0 ///
    & support_reason == ""

sort isic4_sector_id
isid isic4_sector_id
save "`sector_counts'"
restore

merge m:1 isic4_sector_id using "`sector_counts'", nogen
assert !missing(include_sector) if !missing(isic4_sector_id)
save "`analysis_panel'", replace

use "`sector_counts'", clear
merge 1:1 isic4_sector_id using "`sector_labels'", nogen keep(match)
sort isic4_sector_id

generate str16 rowname = "section_" + string(isic4_sector_id)
mkmat employment_obs employment_firms sales_obs sales_firms include_sector, ///
    matrix(support_table) rownames(rowname)
matrix colnames support_table = EmpObs EmpFirms SalesObs SalesFirms Reported

local support_rowlabels
quietly count
local support_n = r(N)
forvalues i = 1/`support_n' {
    local code = isic4_sector_id[`i']
    local support_label = subinstr(isic4_label_short_display[`i'], "&", "\&", .)
    local support_label = subinstr("`support_label'", char(34), "'", .)
    local support_rowlabels `support_rowlabels' section_`code' "`support_label'"
}

esttab matrix(support_table, fmt(%9.0fc %9.0fc %9.0fc %9.0fc %9.0f)) ///
    using "${OUTPUTDIR}/tables/`output_stub'_support_audit.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    collabels("Emp. obs." "Emp. firms" "Sales obs." "Sales firms" "Reported") ///
    varlabels(`support_rowlabels')

/*******************************************************************************
    3. Estimate sector-specific fixed-asset elasticities
*******************************************************************************/

tempname estimates_handle
postfile `estimates_handle' str16 model str36 model_label int isic4_sector_id ///
    double elasticity se lb ub long observations firms byte estimated ///
    using "`estimates_raw'", replace

capture program drop cmr_fixed_asset_estimate
program define cmr_fixed_asset_estimate
    version 17.0
    syntax, Model(string) Modellabel(string) Outcomevar(name) ///
        Samplevar(name) Obsvar(name) Firmsvar(name) Handle(name)

    quietly areg `outcomevar' c.ln_fixed_assets##i.isic4_sector_id ///
        i.isic4_sector_id#i.fin_yr ///
        if `samplevar' == 1 & include_sector == 1, ///
        absorb(firm_fe) vce(cluster firm_fe)

    local regression_obs = e(N)
    levelsof isic4_sector_id if e(sample), local(codes)
    local base_code : word 1 of `codes'

    foreach code of local codes {
        quietly summarize `obsvar' if isic4_sector_id == `code', meanonly
        local sector_obs = r(mean)
        quietly summarize `firmsvar' if isic4_sector_id == `code', meanonly
        local sector_firms = r(mean)

        if `code' == `base_code' {
            capture noisily lincom _b[ln_fixed_assets]
        }
        else {
            capture noisily lincom _b[ln_fixed_assets] + ///
                _b[`code'.isic4_sector_id#c.ln_fixed_assets]
        }

        if _rc {
            post `handle' ("`model'") ("`modellabel'") (`code') ///
                (.) (.) (.) (.) (`sector_obs') (`sector_firms') (0)
        }
        else {
            post `handle' ("`model'") ("`modellabel'") (`code') ///
                (r(estimate)) (r(se)) (r(lb)) (r(ub)) ///
                (`sector_obs') (`sector_firms') (1)
        }
    }

    display as result "`modellabel': `regression_obs' observations"
end

use "`analysis_panel'", clear

quietly count if sample_employment == 1 & include_sector == 1
if r(N) == 0 {
    display as error "No observations meet the fixed-asset employment sample and sector-support rules."
    exit 2000
}

quietly count if sample_sales == 1 & include_sector == 1
if r(N) == 0 {
    display as error "No observations meet the fixed-asset sales sample and sector-support rules."
    exit 2000
}

cmr_fixed_asset_estimate, model("employment") ///
    modellabel("Employment") outcomevar(ln_emp) ///
    samplevar(sample_employment) obsvar(employment_obs) ///
    firmsvar(employment_firms) handle(`estimates_handle')

cmr_fixed_asset_estimate, model("sales") ///
    modellabel("Sales turnover") outcomevar(ln_sales_turnover) ///
    samplevar(sample_sales) obsvar(sales_obs) firmsvar(sales_firms) ///
    handle(`estimates_handle')

postclose `estimates_handle'

use "`estimates_raw'", clear
merge m:1 isic4_sector_id using "`sector_labels'", nogen keep(match)
merge m:1 isic4_sector_id using "`sector_counts'", nogen keep(match)
keep if include_sector == 1

assert estimated == 1
isid model isic4_sector_id

label variable model "Fixed-asset elasticity model"
label variable model_label "Model label"
label variable elasticity "Elasticity with respect to net fixed assets"
label variable se "Standard error"
label variable lb "Lower 95 percent confidence bound"
label variable ub "Upper 95 percent confidence bound"
label variable observations "Sector observations in estimation sample"
label variable firms "Sector firms in estimation sample"

order model model_label isic4_sector_id isic4_label_short_display isic4_broad_label ///
    elasticity se lb ub observations firms estimated
sort model isic4_sector_id

capture save "${DATADIR}/Analysis/`output_stub'_estimates.dta", replace
if _rc {
    sleep `sleep_ms'
    capture save "${DATADIR}/Analysis/`output_stub'_estimates.dta", replace
}
if _rc {
    display as error "Unable to save fixed-asset elasticity estimates after retry."
    error _rc
}

save "`plot_data'", replace

/*******************************************************************************
    4. Export esttab tables
*******************************************************************************/

capture program drop cmr_fixed_asset_table
program define cmr_fixed_asset_table
    version 17.0
    syntax, Model(string) Exportstub(string)

    keep if model == "`model'"
    gsort -elasticity isic4_sector_id
    generate str16 rowname = "section_" + string(isic4_sector_id)

    mkmat elasticity se lb ub firms observations, ///
        matrix(fixed_asset_table) rownames(rowname)
    matrix colnames fixed_asset_table = Elasticity StdErr Lower95 Upper95 Firms Obs

    local table_rowlabels
    quietly count
    local table_n = r(N)
    forvalues i = 1/`table_n' {
        local code = isic4_sector_id[`i']
        local table_label = subinstr(isic4_label_short_display[`i'], "&", "\&", .)
        local table_label = subinstr("`table_label'", char(34), "'", .)
        local table_rowlabels `table_rowlabels' section_`code' "`table_label'"
    }

    esttab matrix(fixed_asset_table, fmt(%9.3f %9.3f %9.3f %9.3f %9.0fc %9.0fc)) ///
        using "${OUTPUTDIR}/tables/`exportstub'.tex", ///
        replace booktabs fragment nomtitles nonumbers ///
        varlabels(`table_rowlabels')
end

use "`plot_data'", clear
cmr_fixed_asset_table, model("employment") ///
    exportstub("`output_stub'_employment")

use "`plot_data'", clear
cmr_fixed_asset_table, model("sales") ///
    exportstub("`output_stub'_sales")

/*******************************************************************************
    5. Export coefficient figures
*******************************************************************************/

capture program drop cmr_fixed_asset_plot
program define cmr_fixed_asset_plot
    version 17.0
    syntax, Model(string) Title(string asis) XTitle(string asis) ///
        Exportstub(string)

    keep if model == "`model'"
    assert !missing(elasticity, se, lb, ub)

    gsort -elasticity isic4_sector_id
    generate int plot_order = _n

    capture label drop fixed_asset_axis
    quietly count
    local plot_n = r(N)
    forvalues i = 1/`plot_n' {
        local sector_label = subinstr(isic4_label_short_display[`i'], char(34), "'", .)
        if `i' == 1 {
            label define fixed_asset_axis `i' `"`sector_label'"'
        }
        else {
            label define fixed_asset_axis `i' `"`sector_label'"', modify
        }
    }
    label values plot_order fixed_asset_axis

    twoway ///
        (rcap lb ub plot_order if strpos(isic4_broad_label, "Agriculture") > 0, horizontal lcolor("102 194 165")) ///
        (scatter plot_order elasticity if strpos(isic4_broad_label, "Agriculture") > 0, msymbol(circle) mcolor("27 158 119")) ///
        (rcap lb ub plot_order if strpos(isic4_broad_label, "Mining") > 0, horizontal lcolor("190 174 212")) ///
        (scatter plot_order elasticity if strpos(isic4_broad_label, "Mining") > 0, msymbol(diamond) mcolor("117 112 179")) ///
        (rcap lb ub plot_order if strpos(isic4_broad_label, "Manufacturing") > 0, horizontal lcolor("141 160 203")) ///
        (scatter plot_order elasticity if strpos(isic4_broad_label, "Manufacturing") > 0, msymbol(square) mcolor("44 123 182")) ///
        (rcap lb ub plot_order if isic4_broad_label == "Utilities", horizontal lcolor("252 217 142")) ///
        (scatter plot_order elasticity if isic4_broad_label == "Utilities", msymbol(triangle) mcolor("230 171 2")) ///
        (rcap lb ub plot_order if strpos(isic4_broad_label, "Construction") > 0, horizontal lcolor("231 138 195")) ///
        (scatter plot_order elasticity if strpos(isic4_broad_label, "Construction") > 0, msymbol(Oh) mcolor("208 28 139")) ///
        (rcap lb ub plot_order if strpos(isic4_broad_label, "Trade") > 0, horizontal lcolor("247 194 145")) ///
        (scatter plot_order elasticity if strpos(isic4_broad_label, "Trade") > 0, msymbol(Th) mcolor("217 95 2")) ///
        (rcap lb ub plot_order if strpos(isic4_broad_label, "Transport") > 0, horizontal lcolor("179 222 105")) ///
        (scatter plot_order elasticity if strpos(isic4_broad_label, "Transport") > 0, msymbol(Sh) mcolor("102 166 30")) ///
        (rcap lb ub plot_order if strpos(isic4_broad_label, "Information") > 0, horizontal lcolor("166 216 84")) ///
        (scatter plot_order elasticity if strpos(isic4_broad_label, "Information") > 0, msymbol(plus) mcolor("102 166 30")) ///
        (rcap lb ub plot_order if strpos(isic4_broad_label, "Finance") > 0, horizontal lcolor("188 128 189")) ///
        (scatter plot_order elasticity if strpos(isic4_broad_label, "Finance") > 0, msymbol(x) mcolor("117 112 179")) ///
        (rcap lb ub plot_order if isic4_broad_label == "Other services", horizontal lcolor("190 190 190")) ///
        (scatter plot_order elasticity if isic4_broad_label == "Other services", msymbol(Dh) mcolor("102 102 102")), ///
        ylabel(1(1)`plot_n', valuelabel angle(0) labsize(tiny) nogrid) ///
        xlabel(, grid glpattern(dash) glcolor(gs13)) ///
        yscale(reverse) ///
        xline(0, lpattern(dash) lcolor(black)) ///
        legend(order(2 "Agriculture" 4 "Mining" 6 "Manufacturing" 8 "Utilities" ///
            10 "Construction" 12 "Wholesale/retail + repair" 14 "Transport" ///
            16 "ICT" 18 "Finance" 20 "Other services") cols(1) pos(3) ///
            ring(1) size(tiny) region(lcolor(none) fcolor(none))) ///
        ytitle("") ///
        xtitle(`xtitle', size(small)) ///
        title(`title', size(medsmall)) ///
        plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
        xsize(8.4) ysize(6.2) ///
    note("ISIC Rev.4 sections based on the NACAM-ISIC Rev.4 crosswalk." "Combined: professional & admin. support; arts/recreation, other services & household employers (division 97)." "* Includes branches spanning sections; see classification notes.", size(tiny))

    graph export "${OUTPUTDIR}/figures/`exportstub'.pdf", name(Graph) replace
    graph export "${OUTPUTDIR}/figures/`exportstub'.png", name(Graph) replace
end

use "`plot_data'", clear
cmr_fixed_asset_plot, model("employment") ///
    title("Employment and net fixed assets by ISIC Rev.4 section") ///
    xtitle("Employment elasticity with respect to net fixed assets") ///
    exportstub("`output_stub'_employment_coefficients")

use "`plot_data'", clear
cmr_fixed_asset_plot, model("sales") ///
    title("Sales turnover and net fixed assets by ISIC Rev.4 section") ///
    xtitle("Sales-turnover elasticity with respect to net fixed assets") ///
    exportstub("`output_stub'_sales_coefficients")

display as result "Saved fixed-asset elasticity estimates, tables, and coefficient figures."
log close cmrfixedassets
