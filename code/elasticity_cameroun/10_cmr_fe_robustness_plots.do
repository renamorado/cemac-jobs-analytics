version 17.0
set more off

/*******************************************************************************
    Purpose:
        Estimate a compact fixed-effect robustness suite for Cameroon NACAM
        employment elasticities and export check-only plots and LaTeX output.

    Inputs:
        Data/Analysis/CMR_BDF_cleaned.dta

    Outputs:
        Data/Analysis/cmr_nacam_fe_robustness_estimates.dta
        output/tables/cmr_nacam_fe_robustness_spec_summary.tex
        output/figures/cmr_nacam_fe_robustness_va_coefficients.pdf
        output/figures/cmr_nacam_fe_robustness_va_coefficients.png
        output/figures/cmr_nacam_fe_robustness_tot_rev_coefficients.pdf
        output/figures/cmr_nacam_fe_robustness_tot_rev_coefficients.png
        output/robustness/cmr_nacam_fe_robustness_check.tex
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
        display as error "Add this user to the bootstrap block in code/elasticity_cameroun/10_cmr_fe_robustness_plots.do."
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

capture log close cmrferobust
capture log using "${LOGDIR}/10_cmr_fe_robustness_plots_`log_stamp'.log", ///
    text name(cmrferobust)
if _rc {
    sleep `sleep_ms'
    capture log using "${LOGDIR}/10_cmr_fe_robustness_plots_`log_stamp'.log", ///
        text name(cmrferobust)
}
if _rc {
    display as error "Unable to open the FE-robustness log after retry."
    error _rc
}

local min_sector_obs 30
local min_sector_firms 10
local output_stub "cmr_nacam_fe_robustness"

capture mkdir "${OUTPUTDIR}/robustness"

/*******************************************************************************
    1. Prepare the same analysis sample used by the current elasticity script
*******************************************************************************/

use "${DATADIR}/Analysis/CMR_BDF_cleaned.dta", clear

keep firmid fin_yr nacam nacam_label_display nacam_label_short_display ///
    data_export totemp va tot_rev

tempfile sector_labels sector_counts analysis_panel estimates_raw ///
    va_current tot_rev_current spec_summary plot_data

preserve
keep nacam nacam_label_display nacam_label_short_display data_export
drop if missing(nacam)
bysort nacam (nacam_label_display): assert nacam_label_display == nacam_label_display[1]
bysort nacam (nacam_label_short_display): assert nacam_label_short_display == nacam_label_short_display[1]
bysort nacam (data_export): assert data_export == data_export[1]
by nacam: keep if _n == 1
isid nacam
save "`sector_labels'"
restore

encode firmid, generate(firm_fe)
encode data_export, generate(data_export_fe)

capture confirm numeric variable totemp
if !_rc {
    generate double employment = totemp
}
else {
    destring totemp, generate(employment) ignore(",")
}

generate double ln_emp = ln(employment) if employment > 0
generate double ln_va = ln(va) if va > 0
generate double ln_tot_rev = ln(tot_rev) if tot_rev > 0

generate byte sample_va = employment > 0 & va > 0 ///
    & !missing(firm_fe, fin_yr, nacam, data_export_fe)
generate byte sample_tot_rev = employment > 0 & tot_rev > 0 ///
    & !missing(firm_fe, fin_yr, nacam, data_export_fe)

preserve
keep nacam firm_fe sample_va sample_tot_rev

egen tag_va_firm = tag(nacam firm_fe) if sample_va == 1
egen tag_tot_rev_firm = tag(nacam firm_fe) if sample_tot_rev == 1

by nacam, sort: egen va_obs = total(sample_va)
by nacam: egen tot_rev_obs = total(sample_tot_rev)
by nacam: egen va_firms = total(tag_va_firm)
by nacam: egen tot_rev_firms = total(tag_tot_rev_firm)

keep nacam va_obs tot_rev_obs va_firms tot_rev_firms
by nacam: keep if _n == 1

generate byte include_sector = va_obs >= `min_sector_obs' ///
    & va_firms >= `min_sector_firms' ///
    & tot_rev_obs >= `min_sector_obs' ///
    & tot_rev_firms >= `min_sector_firms'

save "`sector_counts'"
restore

merge m:1 nacam using "`sector_counts'", nogen
assert !missing(include_sector) if !missing(nacam)
save "`analysis_panel'", replace

/*******************************************************************************
    2. Estimate each FE variant and post sector-specific elasticities
*******************************************************************************/

tempname estimates_handle
postfile `estimates_handle' str12 outcome byte spec_id str44 spec_label ///
    int nacam double elasticity se lb ub long observations firms ///
    byte estimated using "`estimates_raw'", replace

capture program drop cmr_fe_robust_estimate
program define cmr_fe_robust_estimate
    version 17.0
    syntax, Outcome(string) Regressor(name) Samplevar(name) Specid(integer) ///
        Speclabel(string) Fixedeffects(string) Handle(name)

    quietly areg ln_emp c.`regressor'##i.nacam `fixedeffects' ///
        if `samplevar' == 1 & include_sector == 1, ///
        absorb(firm_fe) vce(cluster firm_fe)

    local regression_obs = e(N)

    levelsof nacam if e(sample), local(codes)
    local base_code : word 1 of `codes'

    foreach code of local codes {
        if "`outcome'" == "va" {
            quietly summarize va_obs if nacam == `code', meanonly
            local sector_obs = r(mean)
            quietly summarize va_firms if nacam == `code', meanonly
            local sector_firms = r(mean)
        }
        else {
            quietly summarize tot_rev_obs if nacam == `code', meanonly
            local sector_obs = r(mean)
            quietly summarize tot_rev_firms if nacam == `code', meanonly
            local sector_firms = r(mean)
        }

        if `code' == `base_code' {
            capture noisily lincom _b[`regressor']
        }
        else {
            capture noisily lincom _b[`regressor'] + ///
                _b[`code'.nacam#c.`regressor']
        }

        if _rc {
            post `handle' ("`outcome'") (`specid') ("`speclabel'") ///
                (`code') (.) (.) (.) (.) (`sector_obs') (`sector_firms') (0)
        }
        else {
            post `handle' ("`outcome'") (`specid') ("`speclabel'") ///
                (`code') (r(estimate)) (r(se)) (r(lb)) (r(ub)) ///
                (`sector_obs') (`sector_firms') (1)
        }
    }

    display as result "`outcome' | `speclabel': `regression_obs' observations"
end

use "`analysis_panel'", clear

cmr_fe_robust_estimate, outcome("va") regressor(ln_va) ///
    samplevar(sample_va) specid(1) ///
    speclabel("Baseline (firm FE + NACAM-year FE)") ///
    fixedeffects("i.nacam#i.fin_yr") handle(`estimates_handle')

cmr_fe_robust_estimate, outcome("va") regressor(ln_va) ///
    samplevar(sample_va) specid(2) ///
    speclabel("Firm FE + year FE") ///
    fixedeffects("i.fin_yr") handle(`estimates_handle')

cmr_fe_robust_estimate, outcome("va") regressor(ln_va) ///
    samplevar(sample_va) specid(3) ///
    speclabel("Firm FE + broad-sector-year FE") ///
    fixedeffects("i.data_export_fe#i.fin_yr") handle(`estimates_handle')

cmr_fe_robust_estimate, outcome("tot_rev") regressor(ln_tot_rev) ///
    samplevar(sample_tot_rev) specid(1) ///
    speclabel("Baseline (firm FE + NACAM-year FE)") ///
    fixedeffects("i.nacam#i.fin_yr") handle(`estimates_handle')

cmr_fe_robust_estimate, outcome("tot_rev") regressor(ln_tot_rev) ///
    samplevar(sample_tot_rev) specid(2) ///
    speclabel("Firm FE + year FE") ///
    fixedeffects("i.fin_yr") handle(`estimates_handle')

cmr_fe_robust_estimate, outcome("tot_rev") regressor(ln_tot_rev) ///
    samplevar(sample_tot_rev) specid(3) ///
    speclabel("Firm FE + broad-sector-year FE") ///
    fixedeffects("i.data_export_fe#i.fin_yr") handle(`estimates_handle')

postclose `estimates_handle'

use "`estimates_raw'", clear
merge m:1 nacam using "`sector_labels'", nogen keep(match)
merge m:1 nacam using "`sector_counts'", nogen keep(match)
keep if include_sector == 1
assert estimated == 1

label define spec_id 1 "Baseline" 2 "Firm + year FE" ///
    3 "Firm + broad-sector-year FE", replace
label values spec_id spec_id

label variable outcome "Output proxy"
label variable spec_id "FE specification"
label variable spec_label "FE specification label"
label variable elasticity "Employment elasticity"
label variable se "Standard error"
label variable lb "Lower 95 percent confidence bound"
label variable ub "Upper 95 percent confidence bound"
label variable observations "Sector observations in estimation sample"
label variable firms "Sector firms in estimation sample"

order outcome spec_id spec_label nacam nacam_label_short_display ///
    elasticity se lb ub observations firms
sort outcome spec_id nacam

capture save "${DATADIR}/Analysis/`output_stub'_estimates.dta", replace
if _rc {
    sleep `sleep_ms'
    capture save "${DATADIR}/Analysis/`output_stub'_estimates.dta", replace
}
if _rc {
    display as error "Unable to save FE-robustness estimates after retry."
    error _rc
}

save "`plot_data'", replace

/*******************************************************************************
    3. Verify that the current-primary estimates reproduce the baseline tables
*******************************************************************************/

preserve
keep if outcome == "va" & spec_id == 1
keep nacam elasticity se lb ub observations firms
rename elasticity va_elasticity
rename se va_se
rename lb va_lb
rename ub va_ub
rename observations va_obs_check
rename firms va_firms_check
save "`va_current'"
restore

preserve
keep if outcome == "tot_rev" & spec_id == 1
keep nacam elasticity se lb ub observations firms
rename elasticity tot_rev_elasticity
rename se tot_rev_se
rename lb tot_rev_lb
rename ub tot_rev_ub
rename observations tot_rev_obs_check
rename firms tot_rev_firms_check
save "`tot_rev_current'"
restore

use "`va_current'", clear
merge 1:1 nacam using "`tot_rev_current'", nogen
merge m:1 nacam using "`sector_counts'", nogen keep(match)
assert abs(va_obs_check - va_obs) <= 0
assert abs(tot_rev_obs_check - tot_rev_obs) <= 0
assert abs(va_firms_check - va_firms) <= 0
assert abs(tot_rev_firms_check - tot_rev_firms) <= 0

display as result "Current-primary robustness estimates reproduce the active sample counts."

/*******************************************************************************
    4. Export a compact specification summary table
*******************************************************************************/

use "`plot_data'", clear

preserve
collapse ///
    (sum) estimated_sectors = estimated ///
    (min) min_observations = observations min_firms = firms ///
    (max) max_observations = observations max_firms = firms, ///
    by(outcome spec_id spec_label)

generate str24 rowname = outcome + "_spec" + string(spec_id)
mkmat estimated_sectors min_observations max_observations ///
    min_firms max_firms, matrix(spec_summary_table) rownames(rowname)
matrix colnames spec_summary_table = Sectors MinObs MaxObs MinFirms MaxFirms

local spec_rowlabels
quietly count
local spec_rows = r(N)
forvalues i = 1/`spec_rows' {
    local row = rowname[`i']
    local outcome_label = "Value added"
    if outcome[`i'] == "tot_rev" {
        local outcome_label = "Total revenue"
    }
    local label = "`outcome_label': " + spec_label[`i']
    local label = subinstr("`label'", "&", "\&", .)
    local spec_rowlabels `spec_rowlabels' `row' "`label'"
}

esttab matrix(spec_summary_table, fmt(%9.0fc %9.0fc %9.0fc %9.0fc %9.0fc)) ///
    using "${OUTPUTDIR}/tables/`output_stub'_spec_summary.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    collabels("Sectors" "Min obs." "Max obs." "Min firms" "Max firms") ///
    varlabels(`spec_rowlabels')

save "`spec_summary'", replace
restore

/*******************************************************************************
    5. Build overlaid sector coefficient plots
*******************************************************************************/

capture program drop cmr_fe_robustness_plot
program define cmr_fe_robustness_plot
    version 17.0
    syntax, Outcome(string) Elasticitytitle(string) Exportstub(string)

    keep if outcome == "`outcome'"
    assert !missing(elasticity, se, lb, ub)

    tempfile order_file
    preserve
    keep if spec_id == 1
    gsort -elasticity nacam
    generate int plot_order = _n
    keep nacam plot_order nacam_label_short_display
    save "`order_file'"
    restore

    merge m:1 nacam using "`order_file'", nogen keep(match)
    assert !missing(plot_order)

    generate double y_position = plot_order
    replace y_position = plot_order - 0.22 if spec_id == 2
    replace y_position = plot_order + 0.22 if spec_id == 3

    capture label drop nacam_fe_robustness_axis
    quietly summarize plot_order
    local plot_n = r(max)
    forvalues i = 1/`plot_n' {
        quietly levelsof nacam_label_short_display if plot_order == `i', ///
            local(sector_label) clean
        local sector_label = subinstr(`"`sector_label'"', "&", "\&", .)
        if `i' == 1 {
            label define nacam_fe_robustness_axis `i' `"`sector_label'"'
        }
        else {
            label define nacam_fe_robustness_axis `i' `"`sector_label'"', modify
        }
    }
    label values plot_order nacam_fe_robustness_axis
    label values y_position nacam_fe_robustness_axis

    twoway ///
        (rcap lb ub y_position if spec_id == 1, horizontal ///
            lcolor("80 80 80") lwidth(thin)) ///
        (scatter y_position elasticity if spec_id == 1, ///
            msymbol(circle) mcolor("0 0 0") msize(small)) ///
        (rcap lb ub y_position if spec_id == 2, horizontal ///
            lcolor("117 112 179") lwidth(thin)) ///
        (scatter y_position elasticity if spec_id == 2, ///
            msymbol(diamond) mcolor("117 112 179") msize(small)) ///
        (rcap lb ub y_position if spec_id == 3, horizontal ///
            lcolor("27 158 119") lwidth(thin)) ///
        (scatter y_position elasticity if spec_id == 3, ///
            msymbol(square) mcolor("27 158 119") msize(small)), ///
        ylabel(1(1)`plot_n', valuelabel angle(0) labsize(tiny) nogrid) ///
        xlabel(, grid glpattern(dash) glcolor(gs13)) ///
        yscale(reverse) ///
        xline(0, lpattern(dash) lcolor(black)) ///
        legend(order(2 "Baseline (firm FE + NACAM-year FE)" ///
            4 "Firm FE + year FE" ///
            6 "Firm FE + broad-sector-year FE") ///
            cols(1) pos(3) ring(1) size(tiny) ///
            region(lcolor(none) fcolor(none))) ///
        ytitle("") ///
        xtitle("Employment elasticity", size(small)) ///
        title("`elasticitytitle'", size(medsmall)) ///
        plotregion(color(white)) graphregion(color(white)) ///
        bgcolor(white) xsize(8.4) ysize(6.2)

    graph export "${OUTPUTDIR}/figures/`exportstub'.pdf", replace
    graph export "${OUTPUTDIR}/figures/`exportstub'.png", replace
end

use "`plot_data'", clear

cmr_fe_robustness_plot, outcome("va") ///
    elasticitytitle("Value-added elasticity: FE robustness") ///
    exportstub("`output_stub'_va_coefficients")

use "`plot_data'", clear

cmr_fe_robustness_plot, outcome("tot_rev") ///
    elasticitytitle("Total-revenue elasticity: FE robustness") ///
    exportstub("`output_stub'_tot_rev_coefficients")

/*******************************************************************************
    6. Write the check-only LaTeX file
*******************************************************************************/

file open texout using "${OUTPUTDIR}/robustness/`output_stub'_check.tex", ///
    write text replace
file write texout "\documentclass[11pt]{article}" _n
file write texout "\usepackage[margin=0.8in]{geometry}" _n
file write texout "\usepackage{amsmath}" _n
file write texout "\usepackage{booktabs}" _n
file write texout "\usepackage{graphicx}" _n
file write texout "\usepackage{float}" _n
file write texout "\begin{document}" _n
file write texout "\section*{Cameroon NACAM FE Robustness Check}" _n
file write texout "This check-only file compares sector-specific employment elasticities across three fixed-effect specifications. It is not included in the main slide deck." _n
file write texout "\subsection*{Common sector-specific elasticity structure}" _n
file write texout "Following the notation used in the slide deck, let \(E_{it}\) denote employment for firm \(i\) in year \(t\), \(X_{it}\) denote either value added or total revenue, and \(D_{is}\) equal one when firm \(i\) belongs to detailed NACAM sector \(s\). Every specification estimates a separate elasticity \(\beta_s\) for each included NACAM sector:" _n
file write texout "\[" _n
file write texout "\ln(E_{it}) = \sum_{s \in \mathcal{S}} \beta_s \left[\ln(X_{it}) \times D_{is}\right] + \text{fixed effects}_{it} + \varepsilon_{it}." _n
file write texout "\]" _n
file write texout "Standard errors are clustered by firm in all specifications." _n
file write texout "\subsection*{Baseline specification: Firm FE and NACAM-by-year FE}" _n
file write texout "This is the baseline specification used in the slide deck. Firm fixed effects absorb all time-invariant firm characteristics, while detailed NACAM-by-year fixed effects absorb annual shocks shared by firms in the same detailed sector." _n
file write texout "\[" _n
file write texout "\ln(E_{it}) = \alpha_i + \delta_{st} + \sum_{s \in \mathcal{S}} \beta_s \left[\ln(X_{it}) \times D_{is}\right] + \varepsilon_{it}." _n
file write texout "\]" _n
file write texout "\subsection*{Specification 2: Firm FE and year FE}" _n
file write texout "This looser specification absorbs firm-specific constants and economy-wide annual shocks, but it does not separately absorb annual shocks at the detailed NACAM-sector level." _n
file write texout "\[" _n
file write texout "\ln(E_{it}) = \alpha_i + \lambda_t + \sum_{s \in \mathcal{S}} \beta_s \left[\ln(X_{it}) \times D_{is}\right] + \varepsilon_{it}." _n
file write texout "\]" _n
file write texout "\subsection*{Specification 3: Firm FE and broad-sector-by-year FE}" _n
file write texout "This intermediate specification absorbs annual shocks shared within each broad \texttt{data\_export} sector group. It is more flexible than common year effects but less restrictive than detailed NACAM-by-year effects." _n
file write texout "\[" _n
file write texout "\ln(E_{it}) = \alpha_i + \gamma_{G_i,t} + \sum_{s \in \mathcal{S}} \beta_s \left[\ln(X_{it}) \times D_{is}\right] + \varepsilon_{it}," _n
file write texout "\]" _n
file write texout "where \(G_i\) denotes the firm's broad sector group." _n
file write texout "\begin{table}[H]\centering" _n
file write texout "\caption{Specification and sample summary}" _n
file write texout "\begin{tabular}{lrrrrr}" _n
file write texout "\input{../tables/`output_stub'_spec_summary.tex}" _n
file write texout "\end{tabular}" _n
file write texout "\end{table}" _n
file write texout "\begin{figure}[H]\centering" _n
file write texout "\includegraphics[width=\textwidth]{../figures/`output_stub'_va_coefficients.pdf}" _n
file write texout "\caption{Value-added employment elasticity robustness}" _n
file write texout "\end{figure}" _n
file write texout "\begin{figure}[H]\centering" _n
file write texout "\includegraphics[width=\textwidth]{../figures/`output_stub'_tot_rev_coefficients.pdf}" _n
file write texout "\caption{Total-revenue employment elasticity robustness}" _n
file write texout "\end{figure}" _n
file write texout "\paragraph{Notes.} Baseline estimates use the firm fixed effects plus NACAM-by-year fixed effects specification presented in the slide deck. The looser comparison uses firm and year fixed effects. The intermediate comparison uses firm fixed effects and broad-sector-by-year fixed effects. Standard errors are clustered by firm in all specifications. Firm age and ownership controls are not included." _n
file write texout "\end{document}" _n
file close texout

display as result "Saved FE-robustness estimates, plots, table, and check-only LaTeX file."
log close cmrferobust
