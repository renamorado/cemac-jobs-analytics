version 17.0
set more off

/*******************************************************************************
    Purpose:
        Export reviewer-friendly Cameroon Census sector figures from the
        prepared ISIC Rev.4 division diagnostics dataset.

    Input:
        Data/Analysis/CMR_census_isic4_division_diagnostics.dta

    Outputs:
        output/figures/cmr_census_*.pdf
        output/figures/cmr_census_*.png

    Reviewer note:
        Plot sizing controls and the short figure recipes are kept together
        below so labels, titles, and dimensions can be adjusted quickly.
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
        display as error "Add this user to the bootstrap block in code/elasticity_cameroun/08_cmr_census_sector_figures.do."
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

capture log close cmrcensusfigures
capture log using "${LOGDIR}/08_cmr_census_sector_figures_`log_stamp'.log", ///
    text name(cmrcensusfigures)
if _rc {
    sleep `sleep_ms'
    log using "${LOGDIR}/08_cmr_census_sector_figures_`log_stamp'.log", ///
        text name(cmrcensusfigures)
}

local diagnostics_file "${DATADIR}/Analysis/CMR_census_isic4_division_diagnostics.dta"
confirm file "`diagnostics_file'"
use "`diagnostics_file'", clear

confirm variable isic4_sector_id
confirm variable isic4_label_short_display
confirm variable broad_sector
foreach var in firms total_employment average_employment total_turnover ///
    total_revenue_bil average_revenue turnover_per_worker ///
    average_turnover_per_worker log_total_employment log_average_employment ///
    log_total_revenue log_average_revenue log_turnover_per_worker ///
    log_average_turnover_per_worker {
    confirm numeric variable `var'
}

isid isic4_sector_id
quietly count
assert r(N) > 0
assert !missing(isic4_sector_id, isic4_label_short_display, broad_sector)

generate double average_revenue_mil = average_revenue / 1000000
generate double turnover_per_worker_mil = turnover_per_worker / 1000000
generate double average_turnover_per_worker_mil = ///
    average_turnover_per_worker / 1000000

/*******************************************************************************
    Reviewer controls

    Edit these locals first when changing the layout. Sector colors and marker
    symbols are listed together inside cmr_census_colored_dotplot below.
*******************************************************************************/

local standalone_label_size "tiny"
local standalone_title_size "medsmall"
local standalone_ysize "6.2"
local standalone_xsize "7.5"

local panel_label_size "tiny"
local panel_title_size "small"
local panel_ysize "6.2"
local panel_xsize "5.2"
local combined_ysize "6.2"
local combined_xsize "11.5"
local figure_dir "${OUTPUTDIR}/figures"

/*******************************************************************************
    Plot helper
*******************************************************************************/
* Reusable plotting helper for horizontal dot plots. Each plotted variable is
* sorted descending within the current dataset, and marker color/shape comes
* from the broad broad_sector sector group.
capture program drop cmr_census_colored_dotplot
program define cmr_census_colored_dotplot
    version 17.0
    syntax varname(numeric) [if], Title(string asis) XTitle(string asis) ///
        Name(name) [LABSZ(string) TITLESZ(string) XDIM(string) ///
        YDIM(string) LEGENDOFF RANKFROM(integer 0) RANKTO(integer 0)]

    * Shared palette and legend controls.
    local marker_size "medlarge"
    local legend_size "tiny"
    local agriculture_color "27 158 119"
    local mining_color "117 112 179"
    local manufacturing_color "44 123 182"
    local utilities_color "230 171 2"
    local construction_color "208 28 139"
    local trade_color "217 95 2"
    local transport_information_color "102 166 30"
    local finance_color "117 112 179"
    local services_color "102 102 102"

    marksample touse

    * Defaults are tuned for the slide dimensions used by this project.
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

    * Standalone plots can keep a legend; combined two-panel plots usually
    * suppress legends so the left and right plot areas stay balanced.
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
    * Keep only rows that the caller requested and that have a nonmissing metric.
    keep if `touse'
    keep if !missing(`varlist')
    count
    if r(N) == 0 {
        display as error "No nonmissing observations for `varlist'."
        exit 2000
    }

    * Sort sectors by the plotted metric so each figure is independently ranked.
    gsort -`varlist' isic4_sector_id
    if `rankfrom' > 0 keep if inrange(_n, `rankfrom', `rankto')
    generate int plot_order = _n

    * Build a temporary value label for the y-axis from the short ISIC Rev.4 division labels.
    capture label drop census_sector_plot
    forvalues i = 1/`=_N' {
        local sector_label = subinstr(isic4_label_short_display[`i'], char(34), "'", .)
        if `i' == 1 {
            label define census_sector_plot `i' `"`sector_label'"'
        }
        else {
            label define census_sector_plot `i' `"`sector_label'"', modify
        }
    }
    label values plot_order census_sector_plot

    local last_order = _N

    * Draw one scatter layer per broad sector group so the legend and marker
    * vocabulary match the Cameroon elasticity plots.
    twoway ///
        (scatter plot_order `varlist' if broad_sector == 1, ///
            msymbol(circle) mcolor("`agriculture_color'") msize(`marker_size')) ///
        (scatter plot_order `varlist' if broad_sector == 2, ///
            msymbol(diamond) mcolor("`mining_color'") msize(`marker_size')) ///
        (scatter plot_order `varlist' if broad_sector == 3, ///
            msymbol(square) mcolor("`manufacturing_color'") msize(`marker_size')) ///
        (scatter plot_order `varlist' if broad_sector == 4, ///
            msymbol(triangle) mcolor("`utilities_color'") msize(`marker_size')) ///
        (scatter plot_order `varlist' if broad_sector == 5, ///
            msymbol(Oh) mcolor("`construction_color'") msize(`marker_size')) ///
        (scatter plot_order `varlist' if broad_sector == 6, ///
            msymbol(Th) mcolor("`trade_color'") msize(`marker_size')) ///
        (scatter plot_order `varlist' if broad_sector == 7, ///
            msymbol(Sh) mcolor("`transport_information_color'") msize(`marker_size')) ///
        (scatter plot_order `varlist' if broad_sector == 8, ///
            msymbol(plus) mcolor("`transport_information_color'") msize(`marker_size')) ///
        (scatter plot_order `varlist' if broad_sector == 9, ///
            msymbol(x) mcolor("`finance_color'") msize(`marker_size')) ///
        (scatter plot_order `varlist' if broad_sector == 10, ///
            msymbol(Dh) mcolor("`services_color'") msize(`marker_size')), ///
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

* Preserve full exports for zooming; slide parts contain at most 28 ranked rows.
quietly count
local division_n = r(N)
local pages = ceil(`division_n'/28)
local rows_per_page = ceil(`division_n'/`pages')
forvalues page = 0/`pages' {
    local page_suffix ""
    local rank_options ""
    local page_note ""
    local standalone_label_size "tiny"
    local panel_label_size "tiny"
    if `page' > 0 {
        local first = (`page'-1)*`rows_per_page' + 1
        local last = `page'*`rows_per_page'
        local page_suffix "_part`page'"
        local rank_options "rankfrom(`first') rankto(`last')"
        local page_note note("Ranks `first'-`last'; each panel ranks divisions separately.", size(small))
        local standalone_label_size "vsmall"
        local panel_label_size "small"
    }
* Firm-count plot: a single count panel is enough because counts have no
* meaningful sector-average counterpart.
cmr_census_colored_dotplot firms, ///
    title("Census firm counts by ISIC Rev.4 division") ///
    xtitle("Headquarters firms") ///
    `rank_options' name(census_firms) labsz(`standalone_label_size') titlesz(`standalone_title_size') ///
    ydim(`standalone_ysize') xdim(`standalone_xsize')
graph export "`figure_dir'/cmr_census_firm_count_by_isic4_division`page_suffix'.pdf", name(census_firms) replace
graph export "`figure_dir'/cmr_census_firm_count_by_isic4_division`page_suffix'.png", name(census_firms) replace

* Employment scale plot: combine aggregate sector employment with the average
* firm size in the sector, both on log scales for readability.
cmr_census_colored_dotplot log_total_employment if !missing(log_total_employment), ///
    title("Aggregate sector total") ///
    xtitle("Log total employment") ///
    `rank_options' name(census_emp_total) labsz(`panel_label_size') titlesz(`panel_title_size') ///
    ydim(`panel_ysize') xdim(`panel_xsize') legendoff

cmr_census_colored_dotplot log_average_employment if !missing(log_average_employment), ///
    title("Sector firm average") ///
    xtitle("Log average firm employment") ///
    `rank_options' name(census_emp_average) labsz(`panel_label_size') titlesz(`panel_title_size') ///
    ydim(`panel_ysize') xdim(`panel_xsize') legendoff

graph combine census_emp_total census_emp_average, ///
    cols(2) title("Census log employment by ISIC Rev.4 division", size(medsmall)) ///
    `page_note' ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(`combined_ysize') xsize(`combined_xsize') name(census_emp_combined, replace)
graph display census_emp_combined
graph export "`figure_dir'/cmr_census_total_employment_by_isic4_division`page_suffix'.pdf", name(census_emp_combined) replace
graph export "`figure_dir'/cmr_census_total_employment_by_isic4_division`page_suffix'.png", name(census_emp_combined) replace

cmr_census_colored_dotplot total_employment if !missing(total_employment), ///
    title("Aggregate sector total") ///
    xtitle("Total employment (workers)") ///
    `rank_options' name(census_emp_total_levels) labsz(`panel_label_size') ///
    titlesz(`panel_title_size') ydim(`panel_ysize') ///
    xdim(`panel_xsize') legendoff

cmr_census_colored_dotplot average_employment if !missing(average_employment), ///
    title("Sector firm average") ///
    xtitle("Average firm employment (workers)") ///
    `rank_options' name(census_emp_average_levels) labsz(`panel_label_size') ///
    titlesz(`panel_title_size') ydim(`panel_ysize') ///
    xdim(`panel_xsize') legendoff

graph combine census_emp_total_levels census_emp_average_levels, ///
    cols(2) title("Census employment by ISIC Rev.4 division, levels", size(medsmall)) ///
    `page_note' ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(`combined_ysize') xsize(`combined_xsize') ///
    name(census_emp_combined_levels, replace)
graph display census_emp_combined_levels
graph export "`figure_dir'/cmr_census_total_employment_by_isic4_division_levels`page_suffix'.pdf", name(census_emp_combined_levels) replace
graph export "`figure_dir'/cmr_census_total_employment_by_isic4_division_levels`page_suffix'.png", name(census_emp_combined_levels) replace

* Revenue scale plot: show the sector total and the mean firm turnover side by
* side so large sectors are not confused with high-average firms.
cmr_census_colored_dotplot log_total_revenue if !missing(log_total_revenue), ///
    title("Aggregate sector total") ///
    xtitle("Log total annual revenue") ///
    `rank_options' name(census_rev_total) labsz(`panel_label_size') titlesz(`panel_title_size') ///
    ydim(`panel_ysize') xdim(`panel_xsize') legendoff

cmr_census_colored_dotplot log_average_revenue if !missing(log_average_revenue), ///
    title("Sector firm average") ///
    xtitle("Log average firm annual revenue") ///
    `rank_options' name(census_rev_average) labsz(`panel_label_size') titlesz(`panel_title_size') ///
    ydim(`panel_ysize') xdim(`panel_xsize') legendoff

graph combine census_rev_total census_rev_average, ///
    cols(2) title("Census log annual revenue by ISIC Rev.4 division", size(medsmall)) ///
    `page_note' ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(`combined_ysize') xsize(`combined_xsize') name(census_rev_combined, replace)
graph display census_rev_combined
graph export "`figure_dir'/cmr_census_total_revenue_by_isic4_division`page_suffix'.pdf", name(census_rev_combined) replace
graph export "`figure_dir'/cmr_census_total_revenue_by_isic4_division`page_suffix'.png", name(census_rev_combined) replace

cmr_census_colored_dotplot total_revenue_bil if !missing(total_revenue_bil), ///
    title("Aggregate sector total") ///
    xtitle("Total annual turnover (CFAF billions)") ///
    `rank_options' name(census_rev_total_levels) labsz(`panel_label_size') ///
    titlesz(`panel_title_size') ydim(`panel_ysize') ///
    xdim(`panel_xsize') legendoff

cmr_census_colored_dotplot average_revenue_mil if !missing(average_revenue_mil), ///
    title("Sector firm average") ///
    xtitle("Average firm annual turnover (CFAF millions)") ///
    `rank_options' name(census_rev_average_levels) labsz(`panel_label_size') ///
    titlesz(`panel_title_size') ydim(`panel_ysize') ///
    xdim(`panel_xsize') legendoff

graph combine census_rev_total_levels census_rev_average_levels, ///
    cols(2) title("Census annual revenue by ISIC Rev.4 division, levels", size(medsmall)) ///
    `page_note' ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(`combined_ysize') xsize(`combined_xsize') ///
    name(census_rev_combined_levels, replace)
graph display census_rev_combined_levels
graph export "`figure_dir'/cmr_census_total_revenue_by_isic4_division_levels`page_suffix'.pdf", name(census_rev_combined_levels) replace
graph export "`figure_dir'/cmr_census_total_revenue_by_isic4_division_levels`page_suffix'.png", name(census_rev_combined_levels) replace

* Keep the older average-employment standalone figure available for slides or
* quick review even though the combined employment figure is now primary.
cmr_census_colored_dotplot average_employment, ///
    title("Census average employment by ISIC Rev.4 division") ///
    xtitle("Average employment") ///
    `rank_options' name(census_avg_emp) labsz(`standalone_label_size') titlesz(`standalone_title_size') ///
    ydim(`standalone_ysize') xdim(`standalone_xsize')
graph export "`figure_dir'/cmr_census_average_employment_by_isic4_division`page_suffix'.pdf", name(census_avg_emp) replace
graph export "`figure_dir'/cmr_census_average_employment_by_isic4_division`page_suffix'.png", name(census_avg_emp) replace

* Revenue-per-worker plot: compare the aggregate ratio with the average of
* firm-level ratios, which answer related but distinct diagnostic questions.
cmr_census_colored_dotplot log_turnover_per_worker ///
    if !missing(log_turnover_per_worker), ///
    title("Aggregate sector ratio") ///
    xtitle("Log annual revenue per worker") ///
    `rank_options' name(census_rpw_total) labsz(`panel_label_size') titlesz(`panel_title_size') ///
    ydim(`panel_ysize') xdim(`panel_xsize') legendoff

cmr_census_colored_dotplot log_average_turnover_per_worker ///
    if !missing(log_average_turnover_per_worker), ///
    title("Sector firm average") ///
    xtitle("Log average annual revenue per worker") ///
    `rank_options' name(census_rpw_average) labsz(`panel_label_size') titlesz(`panel_title_size') ///
    ydim(`panel_ysize') xdim(`panel_xsize') legendoff

graph combine census_rpw_total census_rpw_average, ///
    cols(2) title("Census log annual revenue per worker by ISIC Rev.4 division", size(medsmall)) ///
    `page_note' ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(`combined_ysize') xsize(`combined_xsize') name(census_rpw_combined, replace)
graph display census_rpw_combined
graph export "`figure_dir'/cmr_census_turnover_per_worker_by_isic4_division`page_suffix'.pdf", name(census_rpw_combined) replace
graph export "`figure_dir'/cmr_census_turnover_per_worker_by_isic4_division`page_suffix'.png", name(census_rpw_combined) replace

cmr_census_colored_dotplot turnover_per_worker_mil ///
    if !missing(turnover_per_worker_mil), ///
    title("Aggregate sector ratio") ///
    xtitle("Annual turnover per worker (CFAF millions)") ///
    `rank_options' name(census_rpw_total_levels) labsz(`panel_label_size') ///
    titlesz(`panel_title_size') ydim(`panel_ysize') ///
    xdim(`panel_xsize') legendoff

cmr_census_colored_dotplot average_turnover_per_worker_mil ///
    if !missing(average_turnover_per_worker_mil), ///
    title("Sector firm average") ///
    xtitle("Average annual turnover per worker (CFAF millions)") ///
    `rank_options' name(census_rpw_average_levels) labsz(`panel_label_size') ///
    titlesz(`panel_title_size') ydim(`panel_ysize') ///
    xdim(`panel_xsize') legendoff

graph combine census_rpw_total_levels census_rpw_average_levels, ///
    cols(2) title("Census annual revenue per worker by ISIC Rev.4 division, levels", size(medsmall)) ///
    `page_note' ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(`combined_ysize') xsize(`combined_xsize') ///
    name(census_rpw_combined_levels, replace)
graph display census_rpw_combined_levels
graph export "`figure_dir'/cmr_census_turnover_per_worker_by_isic4_division_levels`page_suffix'.pdf", name(census_rpw_combined_levels) replace
graph export "`figure_dir'/cmr_census_turnover_per_worker_by_isic4_division_levels`page_suffix'.png", name(census_rpw_combined_levels) replace

}

display as result "Cameroon Census sector figures completed successfully."
log close cmrcensusfigures
