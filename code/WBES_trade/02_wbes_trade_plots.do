version 17.0
set more off

/*******************************************************************************
    Purpose:
        Export slide-ready WBES trade plots from the cleaned latest-wave file.

    Inputs:
        Data/Analysis/wbes_trade_clean.dta

    Outputs:
        Data/Analysis/wbes_trade_plot_estimates.dta
        output/figures/cemac_wbes_trade_exporter_share.{pdf,png}
        output/figures/cemac_wbes_trade_export_intensity.{pdf,png}
        output/figures/cemac_wbes_trade_import_participation.{pdf,png}
        output/figures/cemac_wbes_trade_two_way_trader.{pdf,png}

    Notes:
        This file starts from cleaned scaffold-compatible WBES variables. It does
        not reconstruct raw WBES trade measures. CEMAC plots exclude Gabon from
        the main rows because the latest available Gabon wave is 2009 and has no
        ISIC Rev.4 coverage in the current prep output.
*******************************************************************************/

/*******************************************************************************
    Bootstrap repository paths
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
    display as error "Add this user to the bootstrap block in code/WBES_trade/02_wbes_trade_plots.do."
    exit 601
}

capture noisily cd "${project_root}"
if _rc | !fileexists("AGENTS.md") {
    display as error "Configured project_root is not a valid repo root: ${project_root}"
    exit 601
}

do "code/01_setup.do"

capture log close wbesplots
log using "${LOGDIR}/02_wbes_trade_plots.log", replace text name(wbesplots)

/*******************************************************************************
    Load cleaned WBES file and verify the analysis contract
*******************************************************************************/
use "${DATADIR}/Analysis/wbes_trade_clean.dta", clear

foreach var in ///
    firm_id country_name cemac_country wb_region wb_income_group weight ///
    export_status export_share import_status gvc_two_way {
    confirm variable `var'
}

assert !missing(weight)
assert weight > 0

generate byte retained_cemac = cemac_country == 1 & country_name != "Gabon"
generate byte ssa_excl_cemac = strpos(wb_region, "Sub-Saharan Africa") > 0 & cemac_country != 1
generate byte high_income = strpos(wb_income_group, "High income") > 0

label variable retained_cemac "CEMAC country retained in main WBES plots"
label variable ssa_excl_cemac "SSA benchmark source excluding CEMAC countries"
label variable high_income "High-income benchmark source"

generate str40 display_name = country_name
replace display_name = "Central Afr. Rep." if country_name == "Central African Republic"
replace display_name = "Eq. Guinea" if country_name == "Equatorial Guinea"

keep if retained_cemac == 1 | ssa_excl_cemac == 1 | high_income == 1

local min_country_obs 30
local zcrit = invnormal(.975)

/*******************************************************************************
    Estimate weighted country-level outcomes
*******************************************************************************/
tempfile country_estimates
tempname country_handle

postfile `country_handle' ///
    str32 metric str80 metric_label str80 axis_title str60 country_name ///
    str40 display_name byte retained_cemac byte ssa_excl_cemac byte high_income ///
    byte benchmark_row double estimate se ci_low ci_high n_unweighted n_countries ///
    using "`country_estimates'", replace

levelsof country_name, local(country_list)

foreach metric in exporter_share export_intensity import_participation two_way_trader {
    if "`metric'" == "exporter_share" {
        local var export_status
        local metric_label "Exporter share"
        local axis_title "Weighted share of firms exporting (%)"
        local sample_condition !missing(export_status)
    }
    else if "`metric'" == "export_intensity" {
        local var export_share
        local metric_label "Export intensity among exporters"
        local axis_title "Weighted export share of sales among exporters (%)"
        local sample_condition export_status == 1 & !missing(export_share)
    }
    else if "`metric'" == "import_participation" {
        local var import_status
        local metric_label "Import or foreign-input participation"
        local axis_title "Weighted share of firms importing or using foreign inputs (%)"
        local sample_condition !missing(import_status)
    }
    else if "`metric'" == "two_way_trader" {
        local var gvc_two_way
        local metric_label "Two-way trader share"
        local axis_title "Weighted share of firms exporting and importing (%)"
        local sample_condition !missing(gvc_two_way)
    }

    foreach country of local country_list {
        quietly count if country_name == "`country'" & weight > 0 & `sample_condition'
        local n_unweighted = r(N)

        if `n_unweighted' >= `min_country_obs' {
            quietly mean `var' [pweight = weight] ///
                if country_name == "`country'" & weight > 0 & `sample_condition'

            matrix b = e(b)
            matrix V = e(V)
            local estimate = b[1,1]
            local se = sqrt(V[1,1])
            local ci_low = max(0, `estimate' - `zcrit' * `se')
            local ci_high = min(1, `estimate' + `zcrit' * `se')

            quietly summarize retained_cemac if country_name == "`country'", meanonly
            local retained = r(max)
            quietly summarize ssa_excl_cemac if country_name == "`country'", meanonly
            local ssa = r(max)
            quietly summarize high_income if country_name == "`country'", meanonly
            local hi = r(max)
            quietly levelsof display_name if country_name == "`country'", ///
                local(display_local) clean

            post `country_handle' ///
                ("`metric'") ("`metric_label'") ("`axis_title'") ///
                ("`country'") ("`display_local'") ///
                (`retained') (`ssa') (`hi') (0) ///
                (`estimate') (`se') (`ci_low') (`ci_high') ///
                (`n_unweighted') (1)
        }
    }
}

postclose `country_handle'

/*******************************************************************************
    Add equal-country benchmark rows
*******************************************************************************/
use "`country_estimates'", clear
tempfile plot_estimates benchmarks
save "`plot_estimates'", replace

tempname benchmark_handle
postfile `benchmark_handle' ///
    str32 metric str80 metric_label str80 axis_title str60 country_name ///
    str40 display_name byte retained_cemac byte ssa_excl_cemac byte high_income ///
    byte benchmark_row double estimate se ci_low ci_high n_unweighted n_countries ///
    using "`benchmarks'", replace

foreach metric in exporter_share export_intensity import_participation two_way_trader {
    foreach benchmark in ssa_excl_cemac high_income {
        use "`plot_estimates'", clear

        if "`benchmark'" == "ssa_excl_cemac" {
            keep if metric == "`metric'" & ssa_excl_cemac == 1
            local benchmark_name "SSA excl. CEMAC"
        }
        else if "`benchmark'" == "high_income" {
            keep if metric == "`metric'" & high_income == 1
            local benchmark_name "High income"
        }

        quietly count
        local n_countries = r(N)

        if `n_countries' >= 2 {
            quietly summarize estimate, meanonly
            local estimate = r(mean)
            quietly summarize estimate
            local se = r(sd) / sqrt(`n_countries')
            local ci_low = max(0, `estimate' - `zcrit' * `se')
            local ci_high = min(1, `estimate' + `zcrit' * `se')
            quietly summarize n_unweighted, meanonly
            local n_unweighted = r(sum)
            quietly levelsof metric_label, local(metric_label_local) clean
            quietly levelsof axis_title, local(axis_title_local) clean

            post `benchmark_handle' ///
                ("`metric'") ("`metric_label_local'") ("`axis_title_local'") ///
                ("`benchmark_name'") ("`benchmark_name'") ///
                (0) (0) (0) (1) ///
                (`estimate') (`se') (`ci_low') (`ci_high') ///
                (`n_unweighted') (`n_countries')
        }
    }
}

postclose `benchmark_handle'

use "`plot_estimates'", clear
append using "`benchmarks'"

generate double estimate_pct = 100 * estimate
generate double ci_low_pct = 100 * ci_low
generate double ci_high_pct = 100 * ci_high

label variable estimate_pct "Estimate, percent"
label variable ci_low_pct "Lower 95 percent interval, percent"
label variable ci_high_pct "Upper 95 percent interval, percent"
label variable n_unweighted "Unweighted firm count"
label variable n_countries "Country count"

save "${DATADIR}/Analysis/wbes_trade_plot_estimates.dta", replace

/*******************************************************************************
    Export Healy-style dot-and-interval plots
*******************************************************************************/
local plot_note "WBES weights used. Benchmark points are equal-country averages. Gabon is coverage-only; rows with N<30 suppressed."

foreach metric in exporter_share export_intensity import_participation two_way_trader {
    preserve
        keep if metric == "`metric'" & (retained_cemac == 1 | benchmark_row == 1)
        drop if missing(estimate_pct, ci_low_pct, ci_high_pct)

        gsort estimate_pct display_name
        generate int plot_order = _n
        quietly count
        local plot_n = r(N)

        capture label drop plot_labels
        forvalues i = 1/`plot_n' {
            local label = display_name[`i']
            label define plot_labels `i' "`label'", add
        }
        label values plot_order plot_labels

        quietly levelsof metric_label, local(metric_title) clean
        quietly levelsof axis_title, local(axis_title) clean

        twoway ///
            (rcap ci_low_pct ci_high_pct plot_order if benchmark_row == 0, ///
                horizontal lcolor("86 180 233") lwidth(medthin)) ///
            (scatter plot_order estimate_pct if benchmark_row == 0, ///
                msymbol(circle) mcolor("0 114 178") msize(medium)) ///
            (rcap ci_low_pct ci_high_pct plot_order if benchmark_row == 1, ///
                horizontal lcolor("230 159 0") lwidth(medthin)) ///
            (scatter plot_order estimate_pct if benchmark_row == 1, ///
                msymbol(diamond) mcolor("213 94 0") msize(medium)), ///
            ylabel(1(1)`plot_n', valuelabel angle(0) labsize(small) nogrid) ///
            xlabel(0(20)100, grid glpattern(dash) glcolor(gs13)) ///
            xscale(range(0 100)) ///
            xtitle("`axis_title'", size(small)) ///
            ytitle("") ///
            title("`metric_title'", size(medsmall)) ///
            legend(order(2 "CEMAC country" 4 "Benchmark") rows(1) pos(6) ///
                size(small) region(lcolor(none) fcolor(none))) ///
            note("`plot_note'", size(vsmall)) ///
            plotregion(color(white)) graphregion(color(white)) ///
            bgcolor(white) xsize(7.5) ysize(4.8)

        graph export "${OUTPUTDIR}/figures/cemac_wbes_trade_`metric'.pdf", replace
        graph export "${OUTPUTDIR}/figures/cemac_wbes_trade_`metric'.png", replace
    restore
}

display as result "Exported CEMAC WBES trade plots to ${OUTPUTDIR}/figures."

log close wbesplots
