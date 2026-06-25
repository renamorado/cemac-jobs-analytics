version 17.0
set more off

/*******************************************************************************
    Purpose:
        Build administrative tax/BDF companion figures for the Census sector
        scale plots: firm counts, employment, revenue, and revenue per worker.

    Input:
        Data/Analysis/CMR_BDF_cleaned.dta

    Outputs:
        output/figures/cmr_bdf_firm_count_by_nacam.pdf
        output/figures/cmr_bdf_firm_count_by_nacam.png
        output/figures/cmr_bdf_total_employment_by_nacam.pdf
        output/figures/cmr_bdf_total_employment_by_nacam.png
        output/figures/cmr_bdf_total_revenue_by_nacam.pdf
        output/figures/cmr_bdf_total_revenue_by_nacam.png
        output/figures/cmr_bdf_revenue_per_worker_by_nacam.pdf
        output/figures/cmr_bdf_revenue_per_worker_by_nacam.png

    Notes:
        The BDF data are a firm-year panel. Sector figures first collapse to
        sector-years, then average across fiscal years so sectors with more
        observed years are not mechanically larger because of panel stacking.
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
        display as error "Add this user to the bootstrap block in code/elasticity_cameroun/12_cmr_bdf_sector_scale_figures.do."
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

capture log close cmrbdfscale
capture log using "${LOGDIR}/12_cmr_bdf_sector_scale_figures_`log_stamp'.log", ///
    text name(cmrbdfscale)
if _rc {
    sleep `sleep_ms'
    log using "${LOGDIR}/12_cmr_bdf_sector_scale_figures_`log_stamp'.log", ///
        text name(cmrbdfscale)
}

local input_file "${DATADIR}/Analysis/CMR_BDF_cleaned.dta"
local figure_dir "${OUTPUTDIR}/figures"

confirm file "`input_file'"
use "`input_file'", clear

keep firmid fin_yr nacam nacam_label_short_display data_export totemp tot_rev

isid firmid fin_yr
assert !missing(firmid, fin_yr, nacam, nacam_label_short_display, data_export)

capture confirm numeric variable totemp
if !_rc {
    generate double employment = totemp
}
else {
    destring totemp, generate(employment) ignore(",") force
}

capture confirm numeric variable tot_rev
if _rc {
    destring tot_rev, replace ignore(",") force
}

confirm numeric variable employment
confirm numeric variable tot_rev

keep if inrange(fin_yr, 2015, 2022)
quietly count
assert r(N) > 0

generate byte firm_year = 1
generate double employment_scale = employment if employment >= 0
generate double revenue_scale = tot_rev if tot_rev >= 0
generate double firm_revenue_per_worker = revenue_scale / employment_scale ///
    if revenue_scale >= 0 & employment_scale > 0

collapse ///
    (sum) sector_year_firms = firm_year ///
          sector_year_total_employment = employment_scale ///
          sector_year_total_revenue = revenue_scale ///
    (mean) sector_year_average_employment = employment_scale ///
           sector_year_average_revenue = revenue_scale ///
           sector_year_avg_rev_worker = firm_revenue_per_worker, ///
    by(nacam fin_yr nacam_label_short_display data_export)

isid nacam fin_yr
assert sector_year_firms > 0
assert sector_year_total_employment >= 0
assert sector_year_total_revenue >= 0

generate double sector_year_revenue_per_worker = ///
    sector_year_total_revenue / sector_year_total_employment ///
    if sector_year_total_employment > 0

collapse ///
    (mean) avg_annual_firms = sector_year_firms ///
           avg_annual_total_employment = sector_year_total_employment ///
           avg_firm_employment = sector_year_average_employment ///
           avg_annual_total_revenue = sector_year_total_revenue ///
           avg_firm_revenue = sector_year_average_revenue ///
           aggregate_revenue_per_worker = sector_year_revenue_per_worker ///
           avg_firm_revenue_per_worker = sector_year_avg_rev_worker ///
    (count) contributing_years = fin_yr, ///
    by(nacam nacam_label_short_display data_export)

isid nacam
assert avg_annual_firms > 0
assert contributing_years > 0
assert !missing(nacam_label_short_display, data_export)

generate double log_avg_annual_total_employment = ///
    ln(avg_annual_total_employment) if avg_annual_total_employment > 0
generate double log_avg_firm_employment = ///
    ln(avg_firm_employment) if avg_firm_employment > 0
generate double log_avg_annual_total_revenue = ///
    ln(avg_annual_total_revenue) if avg_annual_total_revenue > 0
generate double log_avg_firm_revenue = ///
    ln(avg_firm_revenue) if avg_firm_revenue > 0
generate double log_aggregate_revenue_per_worker = ///
    ln(aggregate_revenue_per_worker) if aggregate_revenue_per_worker > 0
generate double log_avg_firm_revenue_per_worker = ///
    ln(avg_firm_revenue_per_worker) if avg_firm_revenue_per_worker > 0

/*******************************************************************************
    Plot helper
*******************************************************************************/

capture program drop cmr_bdf_colored_dotplot
program define cmr_bdf_colored_dotplot
    version 17.0
    syntax varname(numeric) [if], Title(string asis) XTitle(string asis) ///
        Name(name) [LABSZ(string) TITLESZ(string) XDIM(string) ///
        YDIM(string) LEGENDOFF]

    local marker_size "medlarge"
    local legend_size "tiny"

    marksample touse

    if "`labsz'" == "" {
        local labsz "vsmall"
    }
    if "`titlesz'" == "" {
        local titlesz "medsmall"
    }
    if "`xdim'" == "" {
        local xdim "7.5"
    }
    if "`ydim'" == "" {
        local ydim "6.2"
    }

    if "`legendoff'" == "legendoff" {
        local legend_options legend(off)
    }
    else {
        local legend_options ///
            legend(order(1 "Agriculture" 2 "Mining" 3 "Manufacturing" ///
                4 "Utilities" 5 "Construction" 6 "Wholesale/retail + repair" ///
                7 "Transport" 8 "Information" 9 "Finance" ///
                10 "Other services") cols(1) pos(3) ring(1) size(`legend_size') ///
                region(lcolor(none) fcolor(none)))
    }

    preserve
    keep if `touse'
    keep if !missing(`varlist')
    count
    if r(N) == 0 {
        display as error "No nonmissing observations for `varlist'."
        exit 2000
    }

    gsort -`varlist' nacam
    generate int plot_order = _n

    capture label drop bdf_sector_plot
    forvalues i = 1/`=_N' {
        local sector_label = subinstr(nacam_label_short_display[`i'], char(34), "'", .)
        if `i' == 1 {
            label define bdf_sector_plot `i' `"`sector_label'"'
        }
        else {
            label define bdf_sector_plot `i' `"`sector_label'"', modify
        }
    }
    label values plot_order bdf_sector_plot

    local last_order = _N

    twoway ///
        (scatter plot_order `varlist' if strpos(data_export, "Agriculture") > 0, ///
            msymbol(circle) mcolor("27 158 119") msize(`marker_size')) ///
        (scatter plot_order `varlist' if strpos(data_export, "Mining") > 0, ///
            msymbol(diamond) mcolor("117 112 179") msize(`marker_size')) ///
        (scatter plot_order `varlist' if strpos(data_export, "Manufacturing") > 0, ///
            msymbol(square) mcolor("44 123 182") msize(`marker_size')) ///
        (scatter plot_order `varlist' if data_export == "Utilities", ///
            msymbol(triangle) mcolor("230 171 2") msize(`marker_size')) ///
        (scatter plot_order `varlist' if strpos(data_export, "Construction") > 0, ///
            msymbol(Oh) mcolor("208 28 139") msize(`marker_size')) ///
        (scatter plot_order `varlist' if strpos(data_export, "Wholesale") > 0, ///
            msymbol(Th) mcolor("217 95 2") msize(`marker_size')) ///
        (scatter plot_order `varlist' if strpos(data_export, "Transportation") > 0, ///
            msymbol(Sh) mcolor("102 166 30") msize(`marker_size')) ///
        (scatter plot_order `varlist' if strpos(data_export, "Information") > 0, ///
            msymbol(plus) mcolor("102 166 30") msize(`marker_size')) ///
        (scatter plot_order `varlist' if strpos(data_export, "Financial") > 0, ///
            msymbol(x) mcolor("117 112 179") msize(`marker_size')) ///
        (scatter plot_order `varlist' if data_export == "Other services", ///
            msymbol(Dh) mcolor("102 102 102") msize(`marker_size')), ///
        ylabel(1(1)`last_order', valuelabel angle(horizontal) ///
            labsize(`labsz') noticks) ///
        yscale(reverse) ///
        xlabel(, grid glpattern(dash) glcolor(gs13)) ///
        xtitle(`xtitle', size(small)) ///
        ytitle("") ///
        title(`title', size(`titlesz')) ///
        `legend_options' ///
        plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
        ysize(`ydim') xsize(`xdim') name(`name', replace)
    restore
end

local standalone_label_size "tiny"
local standalone_title_size "medsmall"
local standalone_ysize "6.2"
local standalone_xsize "7.5"
local panel_label_size "tiny"
local panel_title_size "small"
local panel_ysize "6.2"
local left_panel_xsize "4.2"
local right_panel_xsize "5.4"
local combined_ysize "6.2"
local combined_xsize "11.5"

cmr_bdf_colored_dotplot avg_annual_firms, ///
    title("Tax/BDF firm counts by NACAM sector") ///
    xtitle("Average annual firms") ///
    name(bdf_firms) labsz(`standalone_label_size') ///
    titlesz(`standalone_title_size') ydim(`standalone_ysize') ///
    xdim(`standalone_xsize')
graph export "`figure_dir'/cmr_bdf_firm_count_by_nacam.pdf", replace
graph export "`figure_dir'/cmr_bdf_firm_count_by_nacam.png", replace

cmr_bdf_colored_dotplot log_avg_annual_total_employment ///
    if !missing(log_avg_annual_total_employment), ///
    title("Aggregate sector total") ///
    xtitle("Log average annual total employment") ///
    name(bdf_emp_total) labsz(`panel_label_size') ///
    titlesz(`panel_title_size') ydim(`panel_ysize') ///
    xdim(`left_panel_xsize') legendoff

cmr_bdf_colored_dotplot log_avg_firm_employment ///
    if !missing(log_avg_firm_employment), ///
    title("Sector firm average") ///
    xtitle("Log average firm employment") ///
    name(bdf_emp_average) labsz(`panel_label_size') ///
    titlesz(`panel_title_size') ydim(`panel_ysize') ///
    xdim(`right_panel_xsize')

graph combine bdf_emp_total bdf_emp_average, ///
    cols(2) title("Tax/BDF log employment by NACAM sector", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(`combined_ysize') xsize(`combined_xsize') name(bdf_emp_combined, replace)
graph display bdf_emp_combined
graph export "`figure_dir'/cmr_bdf_total_employment_by_nacam.pdf", replace
graph export "`figure_dir'/cmr_bdf_total_employment_by_nacam.png", replace

cmr_bdf_colored_dotplot log_avg_annual_total_revenue ///
    if !missing(log_avg_annual_total_revenue), ///
    title("Aggregate sector total") ///
    xtitle("Log average annual total revenue") ///
    name(bdf_rev_total) labsz(`panel_label_size') ///
    titlesz(`panel_title_size') ydim(`panel_ysize') ///
    xdim(`left_panel_xsize') legendoff

cmr_bdf_colored_dotplot log_avg_firm_revenue ///
    if !missing(log_avg_firm_revenue), ///
    title("Sector firm average") ///
    xtitle("Log average firm annual revenue") ///
    name(bdf_rev_average) labsz(`panel_label_size') ///
    titlesz(`panel_title_size') ydim(`panel_ysize') ///
    xdim(`right_panel_xsize')

graph combine bdf_rev_total bdf_rev_average, ///
    cols(2) title("Tax/BDF log annual revenue by NACAM sector", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(`combined_ysize') xsize(`combined_xsize') name(bdf_rev_combined, replace)
graph display bdf_rev_combined
graph export "`figure_dir'/cmr_bdf_total_revenue_by_nacam.pdf", replace
graph export "`figure_dir'/cmr_bdf_total_revenue_by_nacam.png", replace

cmr_bdf_colored_dotplot log_aggregate_revenue_per_worker ///
    if !missing(log_aggregate_revenue_per_worker), ///
    title("Aggregate sector ratio") ///
    xtitle("Log annual revenue per worker") ///
    name(bdf_rpw_total) labsz(`panel_label_size') ///
    titlesz(`panel_title_size') ydim(`panel_ysize') ///
    xdim(`left_panel_xsize') legendoff

cmr_bdf_colored_dotplot log_avg_firm_revenue_per_worker ///
    if !missing(log_avg_firm_revenue_per_worker), ///
    title("Sector firm average") ///
    xtitle("Log average annual revenue per worker") ///
    name(bdf_rpw_average) labsz(`panel_label_size') ///
    titlesz(`panel_title_size') ydim(`panel_ysize') ///
    xdim(`right_panel_xsize')

graph combine bdf_rpw_total bdf_rpw_average, ///
    cols(2) title("Tax/BDF log annual revenue per worker by NACAM sector", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(`combined_ysize') xsize(`combined_xsize') name(bdf_rpw_combined, replace)
graph display bdf_rpw_combined
graph export "`figure_dir'/cmr_bdf_revenue_per_worker_by_nacam.pdf", replace
graph export "`figure_dir'/cmr_bdf_revenue_per_worker_by_nacam.png", replace

display as result "BDF sector scale figures completed successfully."
log close cmrbdfscale
