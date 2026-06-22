version 17.0
set more off

/*******************************************************************************
    Purpose:
        Run a standalone Cameroon Phase I employment elasticity analysis using
        the cleaned firm-year panel and native NACAM sectors.

    Inputs:
        Data/Analysis/CMR_BDF_cleaned.dta

    Outputs:
        output/tables/cmr_nacam_results_en_labels_va_elasticity.tex
        output/tables/cmr_nacam_results_en_labels_tot_rev_elasticity.tex
        output/tables/cmr_nacam_results_en_labels_ranking.tex
        output/tables/cmr_nacam_results_en_labels_highlights.tex
        output/figures/cmr_nacam_results_en_labels_ln_emp_density_by_year.pdf
        output/figures/cmr_nacam_results_en_labels_ln_emp_density_by_year.png
        output/figures/cmr_nacam_results_en_labels_va_coefficients.pdf
        output/figures/cmr_nacam_results_en_labels_va_coefficients.png
        output/figures/cmr_nacam_results_en_labels_tot_rev_coefficients.pdf
        output/figures/cmr_nacam_results_en_labels_tot_rev_coefficients.png
        output/figures/cmr_nacam_results_en_labels_scatter.pdf
        output/figures/cmr_nacam_results_en_labels_scatter.png
        output/figures/cmr_nacam_results_en_labels_elasticities_vs_avg_log_employment.pdf
        output/figures/cmr_nacam_results_en_labels_elasticities_vs_avg_log_employment.png
        output/figures/cmr_nacam_results_en_labels_elasticities_vs_avg_log_revenue.pdf
        output/figures/cmr_nacam_results_en_labels_elasticities_vs_avg_log_revenue.png
        Data/Analysis/cmr_nacam_elasticity_performance_scale.dta
        output/figures/cmr_elasticities_va_worker_bubble_total_revenue.pdf
        output/figures/cmr_elasticities_va_worker_bubble_total_revenue.png
        output/figures/cmr_elasticities_va_worker_bubble_total_employment.pdf
        output/figures/cmr_elasticities_va_worker_bubble_total_employment.png
        output/figures/cmr_elasticities_va_worker_bubble_avg_revenue.pdf
        output/figures/cmr_elasticities_va_worker_bubble_avg_revenue.png
        output/figures/cmr_elasticities_va_worker_bubble_avg_employment.pdf
        output/figures/cmr_elasticities_va_worker_bubble_avg_employment.png

    Notes:
        This file is intentionally standalone, but it still bootstraps
        code/01_setup.do so path handling stays local-first.
*******************************************************************************/

* Resolve the repository root from the configured local clone for standalone runs.
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
    display as error "Add this user to the bootstrap block in code/elasticity_cameroun/06_cmr_nacam_elasticity.do."
    exit 601
}

capture noisily cd "${project_root}"
if _rc | !fileexists("AGENTS.md") {
    display as error "Configured project_root is not a valid repo root: ${project_root}"
    exit 601
}

* Import locals from the master setup file to ensure paths and project root are defined.
do "code/01_setup.do"
/*******************************************************************************
    Analysis thresholds and output prefix
    - The thresholds determine which sectors are retained in both models.
    - Keep a shared output stub so tables, figures, and slide references stay in
      sync without duplicating the full prefix throughout the file.
*******************************************************************************/
local min_sector_obs 30
local min_sector_firms 10
local label_elasticity_threshold 0.20
local output_stub "cmr_nacam_results_en_labels"

***# Some descriptive stats
*Table with number of firms and by NACAM sector.



/*******************************************************************************
    Load the cleaned analysis panel
    - The unit of observation is a firm-year.
    - Keep only the variables needed for the elasticity exercise.
*******************************************************************************/
use "${DATADIR}/Analysis/CMR_BDF_cleaned.dta", clear

keep firmid fin_yr nacam nacam_label_display nacam_label_short_display data_export totemp va tot_rev

tempfile sector_labels
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

/*******************************************************************************
    Build analysis variables
    - Encode firm IDs for firm fixed effects.
    - Convert employment to numeric, then create log outcomes and regressors.
    - Define separate estimation samples for the value-added and revenue models.
*******************************************************************************/
encode firmid, generate(firm_fe)

capture confirm numeric variable totemp
if !_rc {
    generate double employment = totemp
}
else {
    destring totemp, generate(employment) ignore(",")
}

*log of employment
gen double ln_emp = .
replace ln_emp = ln(employment) if employment > 0

*** Plot the distribution of log employment by year to check for outliers and changes over time.
twoway ///
    (kdensity ln_emp if fin_yr == 2015 & !missing(ln_emp), ///
        lcolor("27 158 119") lwidth(medthick)) ///
    (kdensity ln_emp if fin_yr == 2016 & !missing(ln_emp), ///
        lcolor("217 95 2") lwidth(medthick)) ///
    (kdensity ln_emp if fin_yr == 2017 & !missing(ln_emp), ///
        lcolor("117 112 179") lwidth(medthick)) ///
    (kdensity ln_emp if fin_yr == 2018 & !missing(ln_emp), ///
        lcolor("231 41 138") lwidth(medthick)) ///
    (kdensity ln_emp if fin_yr == 2019 & !missing(ln_emp), ///
        lcolor("102 166 30") lwidth(medthick)) ///
    (kdensity ln_emp if fin_yr == 2020 & !missing(ln_emp), ///
        lcolor("230 171 2") lwidth(medthick)) ///
    (kdensity ln_emp if fin_yr == 2021 & !missing(ln_emp), ///
        lcolor("166 118 29") lwidth(medthick)) ///
    (kdensity ln_emp if fin_yr == 2022 & !missing(ln_emp), ///
        lcolor("102 102 102") lwidth(medthick)), ///
    legend(order(1 "2015" 2 "2016" 3 "2017" 4 "2018" ///
        5 "2019" 6 "2020" 7 "2021" 8 "2022") ///
        rows(2) pos(6) size(small) region(lcolor(none) fcolor(none))) ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    ylabel(, grid glpattern(dash) glcolor(gs13)) ///
    xtitle("Log employment", size(small)) ///
    ytitle("Density", size(small)) ///
    title("Log employment distribution by fiscal year", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    bgcolor(white) xsize(7.5) ysize(4.8)

    graph export "output/figures/`output_stub'_ln_emp_density_by_year.pdf", replace
    graph export "output/figures/`output_stub'_ln_emp_density_by_year.png", replace

*Prepare log regressors and outcomes for both models, ensuring that we only take logs of positive values.
*log of value added
generate double ln_va = .
replace ln_va = ln(va) if va > 0

*log of total revenue
generate double ln_tot_rev = .
replace ln_tot_rev = ln(tot_rev) if tot_rev > 0


generate byte sample_va = employment > 0 & va > 0 & !missing(firm_fe, fin_yr, nacam)
generate byte sample_tot_rev = employment > 0 & tot_rev > 0 & !missing(firm_fe, fin_yr, nacam)



/*******************************************************************************
    Count usable observations and firms by NACAM sector
    - A sector stays in the analysis only if it has enough observations and
      enough distinct firms in both model samples.
*******************************************************************************/
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

tempfile sector_counts
save "`sector_counts'"
restore

* Bring the sector-eligibility counts back to the main firm-year dataset.
merge m:1 nacam using "`sector_counts'", nogen

/*******************************************************************************
    Build sector performance and scale measures for elasticity scatter plots
    - Use one common positive-value sample for all performance measures.
    - Collapse to sector-year first so years, rather than firm-year rows, receive
      equal weight in the final sector averages.
*******************************************************************************/
preserve
keep if employment > 0 & va > 0 & tot_rev > 0 & include_sector == 1 ///
    & !missing(employment, va, tot_rev, firm_fe, fin_yr, nacam, ///
        ln_emp, ln_va, ln_tot_rev)
assert !missing(nacam, firm_fe, ln_emp, ln_va, ln_tot_rev)

collapse ///
    (sum) sector_year_total_employment = employment ///
          sector_year_total_va = va ///
          sector_year_total_revenue = tot_rev ///
    (count) sector_year_firms = firm_fe, ///
    by(nacam fin_yr)

isid nacam fin_yr
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
    by(nacam)

generate double ln_sector_va_per_worker = ln(sector_va_per_worker)

label variable avg_annual_total_employment "Average annual total sector employment"
label variable avg_annual_total_revenue "Average annual total sector revenue"
label variable avg_firm_employment "Average firm employment"
label variable avg_firm_revenue "Average firm revenue"
label variable sector_va_per_worker "Sector value added per worker"
label variable ln_sector_va_per_worker "Log sector value added per worker"
label variable avg_annual_firms "Average firms per contributing sector-year"
label variable contributing_years "Contributing sector-years"

isid nacam
assert avg_annual_total_employment > 0
assert avg_annual_total_revenue > 0
assert avg_firm_employment > 0
assert avg_firm_revenue > 0
assert sector_va_per_worker > 0
assert !missing(ln_sector_va_per_worker)

tempfile sector_performance
save "`sector_performance'"
restore

/*******************************************************************************
    Estimate sector-specific value-added elasticities
    - The interaction c.ln_va##i.nacam allows each NACAM sector to have its own
      elasticity.
    - Firm fixed effects absorb time-invariant firm differences.
    - NACAM-by-year effects absorb sector-specific common shocks over time.
*******************************************************************************/
areg ln_emp c.ln_va##i.nacam i.nacam#i.fin_yr ///
    if sample_va == 1 & include_sector == 1, ///
    absorb(firm_fe) vce(cluster firm_fe)

tempfile va_results
tempname va_handle
postfile `va_handle' int nacam double va_elasticity va_se va_lb va_ub ///
    using "`va_results'", replace

* Identify included sectors and recover each sector's implied elasticity.
levelsof nacam if sample_va == 1 & include_sector == 1, local(va_codes)
local va_base : word 1 of `va_codes'

foreach code of local va_codes {
    * The base sector's elasticity is the main ln_va coefficient.
    if `code' == `va_base' {
        lincom _b[ln_va]
    }
    else {
        * Other sectors add their interaction term to the base coefficient.
        lincom _b[ln_va] + _b[`code'.nacam#c.ln_va]
    }

    post `va_handle' (`code') (r(estimate)) (r(se)) (r(lb)) (r(ub))
}

postclose `va_handle'

/*******************************************************************************
    Estimate sector-specific total-revenue elasticities
    - This repeats the same structure, replacing value added with total revenue.
*******************************************************************************/
areg ln_emp c.ln_tot_rev##i.nacam i.nacam#i.fin_yr ///
    if sample_tot_rev == 1 & include_sector == 1, ///
    absorb(firm_fe) vce(cluster firm_fe)

tempfile tot_rev_results
tempname tot_rev_handle
postfile `tot_rev_handle' int nacam double tot_rev_elasticity tot_rev_se ///
    tot_rev_lb tot_rev_ub using "`tot_rev_results'", replace

levelsof nacam if sample_tot_rev == 1 & include_sector == 1, local(tot_rev_codes)
local tot_rev_base : word 1 of `tot_rev_codes'

foreach code of local tot_rev_codes {
    * Same logic as above: base-sector slope plus sector-specific interaction.
    if `code' == `tot_rev_base' {
        lincom _b[ln_tot_rev]
    }
    else {
        lincom _b[ln_tot_rev] + _b[`code'.nacam#c.ln_tot_rev]
    }

    post `tot_rev_handle' (`code') (r(estimate)) (r(se)) (r(lb)) (r(ub))
}

postclose `tot_rev_handle'

/*******************************************************************************
    Export the value-added elasticity table
    - Re-attach sector counts, build a matrix, and send it to LaTeX with esttab.
*******************************************************************************/
use "`va_results'", clear
merge 1:1 nacam using "`sector_counts'", nogen keep(match)
merge m:1 nacam using "`sector_labels'", nogen keep(match)
keep if include_sector == 1
sort nacam
assert !missing(nacam_label_display)
assert !missing(nacam_label_short_display)

generate str16 rowname = "nacam_" + string(nacam)

* Convert the stored results into a matrix because esttab handles matrix export neatly.
mkmat va_elasticity va_se va_lb va_ub va_firms va_obs, ///
    matrix(va_table) rownames(rowname)
matrix colnames va_table = Elasticity StdErr Lower95 Upper95 Firms Obs

local va_rowlabels
quietly count
local va_n = r(N)
forvalues i = 1/`va_n' {
    local code = nacam[`i']
    local va_label = subinstr(nacam_label_short_display[`i'], "&", "\&", .)
    local va_label = subinstr("`va_label'", char(34), "'", .)
    local va_rowlabels `va_rowlabels' nacam_`code' "`va_label'"
}

esttab matrix(va_table, fmt(%9.3f %9.3f %9.3f %9.3f %9.0fc %9.0fc)) ///
    using "output/tables/`output_stub'_va_elasticity.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels(`va_rowlabels')

* Save a compact copy so it can later be merged with the revenue results.
tempfile va_table_data
keep nacam va_elasticity va_se va_lb va_ub va_firms va_obs
save "`va_table_data'"

/*******************************************************************************
    Export the total-revenue elasticity table
*******************************************************************************/
use "`tot_rev_results'", clear
merge 1:1 nacam using "`sector_counts'", nogen keep(match)
merge m:1 nacam using "`sector_labels'", nogen keep(match)
keep if include_sector == 1
sort nacam
assert !missing(nacam_label_display)
assert !missing(nacam_label_short_display)

generate str16 rowname = "nacam_" + string(nacam)

mkmat tot_rev_elasticity tot_rev_se tot_rev_lb tot_rev_ub tot_rev_firms tot_rev_obs, ///
    matrix(tot_rev_table) rownames(rowname)
matrix colnames tot_rev_table = Elasticity StdErr Lower95 Upper95 Firms Obs

local tot_rev_rowlabels
quietly count
local tot_rev_n = r(N)
forvalues i = 1/`tot_rev_n' {
    local code = nacam[`i']
    local tot_rev_label = subinstr(nacam_label_short_display[`i'], "&", "\&", .)
    local tot_rev_label = subinstr("`tot_rev_label'", char(34), "'", .)
    local tot_rev_rowlabels `tot_rev_rowlabels' nacam_`code' "`tot_rev_label'"
}

esttab matrix(tot_rev_table, fmt(%9.3f %9.3f %9.3f %9.3f %9.0fc %9.0fc)) ///
    using "output/tables/`output_stub'_tot_rev_elasticity.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels(`tot_rev_rowlabels')

/*******************************************************************************
    Combine both models into a ranking table
    - Sectors are sorted by value-added elasticity from highest to lowest.
*******************************************************************************/
merge 1:1 nacam using "`va_table_data'", nogen
merge m:1 nacam using "`sector_labels'", nogen keep(match)
merge 1:1 nacam using "`sector_performance'", nogen keep(match)
assert !missing(nacam_label_display)
assert !missing(nacam_label_short_display)
assert !missing(ln_sector_va_per_worker, avg_annual_total_employment, ///
    avg_annual_total_revenue, avg_firm_employment, avg_firm_revenue)

preserve
keep nacam nacam_label_display nacam_label_short_display data_export ///
    va_elasticity va_se va_lb va_ub va_firms va_obs ///
    tot_rev_elasticity tot_rev_se tot_rev_lb tot_rev_ub ///
    tot_rev_firms tot_rev_obs ///
    sector_va_per_worker ln_sector_va_per_worker ///
    avg_annual_total_employment avg_annual_total_revenue ///
    avg_firm_employment avg_firm_revenue ///
    avg_annual_firms contributing_years
sort nacam
isid nacam
save "${DATADIR}/Analysis/cmr_nacam_elasticity_performance_scale.dta", replace
restore

generate double sort_value = va_elasticity
replace sort_value = -1e10 if missing(sort_value)
gsort -sort_value nacam

generate str16 ranking_rowname = "nacam_" + string(nacam)
generate double average_obs = (va_obs + tot_rev_obs) / 2

mkmat va_elasticity va_se va_obs tot_rev_elasticity tot_rev_se tot_rev_obs, ///
    matrix(ranking_table) rownames(ranking_rowname)
matrix colnames ranking_table = VA_Elasticity VA_SE VA_Obs TotRev_Elasticity TotRev_SE TotRev_Obs

local ranking_rowlabels
quietly count
local ranking_n = r(N)
forvalues i = 1/`ranking_n' {
    local code = nacam[`i']
    local ranking_label = subinstr(nacam_label_short_display[`i'], "&", "\&", .)
    local ranking_label = subinstr("`ranking_label'", char(34), "'", .)
    local ranking_rowlabels `ranking_rowlabels' nacam_`code' "`ranking_label'"
}

esttab matrix(ranking_table, fmt(%9.3f %9.3f %9.0fc %9.3f %9.3f %9.0fc)) ///
    using "output/tables/`output_stub'_ranking.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels(`ranking_rowlabels')

/*******************************************************************************
    Export a total-revenue decile ranking table
    - Deciles are computed across included sectors, with 10 as the highest
      total-revenue employment elasticity group.
*******************************************************************************/
preserve
assert !missing(tot_rev_elasticity)

xtile revenue_decile = tot_rev_elasticity, nq(10)
assert inrange(revenue_decile, 1, 10)
assert !missing(revenue_decile)

display as text "Total-revenue elasticity decile counts:"
tabulate revenue_decile

quietly summarize tot_rev_elasticity if revenue_decile == 10
local decile10_min = r(min)
quietly summarize tot_rev_elasticity if revenue_decile < 10
assert `decile10_min' >= r(max)

quietly summarize tot_rev_elasticity if revenue_decile == 1
local decile1_max = r(max)
quietly summarize tot_rev_elasticity if revenue_decile > 1
assert `decile1_max' <= r(min)

gsort -revenue_decile -tot_rev_elasticity nacam

generate str16 decile_rowname = "nacam_" + string(nacam)

mkmat revenue_decile tot_rev_elasticity va_elasticity tot_rev_obs va_obs, ///
    matrix(decile_table) rownames(decile_rowname)
matrix colnames decile_table = RevDecile TotRevElasticity VAElasticity RevObs VAObs

local decile_rowlabels
quietly count
local decile_n = r(N)
forvalues i = 1/`decile_n' {
    local code = nacam[`i']
    local decile_label = subinstr(nacam_label_short_display[`i'], "&", "\&", .)
    local decile_label = subinstr("`decile_label'", char(34), "'", .)
    local decile_rowlabels `decile_rowlabels' nacam_`code' "`decile_label'"
}

esttab matrix(decile_table, fmt(%9.0fc %9.3f %9.3f %9.0fc %9.0fc)) ///
    using "output/tables/`output_stub'_tot_rev_decile_ranking.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    collabels("Revenue decile" "Total revenue elasticity" ///
        "Value added elasticity" "Revenue observations" "VA observations") ///
    varlabels(`decile_rowlabels')

* Save the ranking as data so downstream extensions never parse LaTeX output.
generate byte high_elasticity = revenue_decile >= 7
label variable revenue_decile "Total-revenue employment-elasticity decile"
label variable high_elasticity "1 if total-revenue elasticity decile is 7-10"
keep nacam nacam_label_display nacam_label_short_display data_export ///
    va_elasticity va_se va_obs tot_rev_elasticity tot_rev_se tot_rev_obs ///
    revenue_decile high_elasticity
sort nacam
isid nacam
save "${DATADIR}/Analysis/cmr_nacam_elasticity_ranking.dta", replace
restore

/*******************************************************************************
    Export a small highlights table
    - Keep the top three and bottom two sectors from the ranking for slides.
*******************************************************************************/
preserve
quietly count
local sector_count = r(N)

generate byte highlight_sector = _n <= 3
replace highlight_sector = 1 if _n > `sector_count' - 2
keep if highlight_sector == 1

generate str16 highlight_rowname = "nacam_" + string(nacam)

mkmat va_elasticity tot_rev_elasticity va_obs tot_rev_obs, ///
    matrix(highlight_table) rownames(highlight_rowname)
matrix colnames highlight_table = VA_Elasticity TotRev_Elasticity VA_Obs TotRev_Obs

local highlight_rowlabels
quietly count
local highlight_n = r(N)
forvalues i = 1/`highlight_n' {
    local code = nacam[`i']
    local highlight_label = subinstr(nacam_label_short_display[`i'], "&", "\&", .)
    local highlight_label = subinstr("`highlight_label'", char(34), "'", .)
    local highlight_rowlabels `highlight_rowlabels' nacam_`code' "`highlight_label'"
}

esttab matrix(highlight_table, fmt(%9.3f %9.3f %9.0fc %9.0fc)) ///
    using "output/tables/`output_stub'_highlights.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels(`highlight_rowlabels')
restore

/*******************************************************************************
    Coefficient plots across sectors
    - Plot point estimates and 95% confidence intervals separately for value
      added and total revenue.
    - Colors identify the label-based data_export aggregate sector group.
*******************************************************************************/
preserve
gsort -va_elasticity nacam
generate int plot_order = _n

capture label drop nacam_sector_plot
quietly count
local plot_n = r(N)

forvalues i = 1/`plot_n' {
    local sector_label = subinstr(nacam_label_short_display[`i'], char(34), "'", .)

    if `i' == 1 {
        label define nacam_sector_plot `i' `"`sector_label'"'
    }
    else {
        label define nacam_sector_plot `i' `"`sector_label'"', modify
    }
}

label values plot_order nacam_sector_plot

twoway ///
    (rcap va_lb va_ub plot_order if data_export == "A – Agriculture, Forestry and Fishing", horizontal lcolor("102 194 165")) ///
    (scatter plot_order va_elasticity if data_export == "A – Agriculture, Forestry and Fishing", msymbol(circle) mcolor("27 158 119")) ///
    (rcap va_lb va_ub plot_order if data_export == "B – Mining and Quarrying", horizontal lcolor("190 174 212")) ///
    (scatter plot_order va_elasticity if data_export == "B – Mining and Quarrying", msymbol(diamond) mcolor("117 112 179")) ///
    (rcap va_lb va_ub plot_order if data_export == "C – Manufacturing", horizontal lcolor("141 160 203")) ///
    (scatter plot_order va_elasticity if data_export == "C – Manufacturing", msymbol(square) mcolor("44 123 182")) ///
    (rcap va_lb va_ub plot_order if data_export == "Utilities", horizontal lcolor("252 217 142")) ///
    (scatter plot_order va_elasticity if data_export == "Utilities", msymbol(triangle) mcolor("230 171 2")) ///
    (rcap va_lb va_ub plot_order if data_export == "F – Construction", horizontal lcolor("231 138 195")) ///
    (scatter plot_order va_elasticity if data_export == "F – Construction", msymbol(Oh) mcolor("208 28 139")) ///
    (rcap va_lb va_ub plot_order if data_export == "G – Wholesale and Retail Trade; Repair of Motor Vehicles", horizontal lcolor("247 194 145")) ///
    (scatter plot_order va_elasticity if data_export == "G – Wholesale and Retail Trade; Repair of Motor Vehicles", msymbol(Th) mcolor("217 95 2")) ///
    (rcap va_lb va_ub plot_order if data_export == "H – Transportation and Storage", horizontal lcolor("179 222 105")) ///
    (scatter plot_order va_elasticity if data_export == "H – Transportation and Storage", msymbol(Sh) mcolor("102 166 30")) ///
    (rcap va_lb va_ub plot_order if data_export == "J – Information and Communication", horizontal lcolor("166 216 84")) ///
    (scatter plot_order va_elasticity if data_export == "J – Information and Communication", msymbol(plus) mcolor("102 166 30")) ///
    (rcap va_lb va_ub plot_order if data_export == "K – Financial and Insurance Activities", horizontal lcolor("188 128 189")) ///
    (scatter plot_order va_elasticity if data_export == "K – Financial and Insurance Activities", msymbol(x) mcolor("117 112 179")) ///
    (rcap va_lb va_ub plot_order if data_export == "Other services", horizontal lcolor("190 190 190")) ///
    (scatter plot_order va_elasticity if data_export == "Other services", msymbol(Dh) mcolor("102 102 102")), ///
    ylabel(1(1)`plot_n', valuelabel angle(0) labsize(tiny) nogrid) ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    yscale(reverse) ///
    xline(0, lpattern(dash) lcolor(black)) ///
    legend(order(2 "Agriculture" 4 "Mining" 6 "Manufacturing" 8 "Utilities" ///
        10 "Construction" 12 "Wholesale/retail + repair" 14 "Transport" 16 "ICT" ///
        18 "Finance" 20 "Other services") cols(1) pos(3) ring(1) size(tiny) ///
        region(lcolor(none) fcolor(none))) ///
    ytitle("") ///
    xtitle("Employment elasticity", size(small)) ///
    title("Employment elasticities with respect to value added", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    bgcolor(white) xsize(7.5) ysize(5.5)

graph export "output/figures/`output_stub'_va_coefficients.pdf", replace
graph export "output/figures/`output_stub'_va_coefficients.png", replace

restore

preserve
gsort -tot_rev_elasticity nacam
generate int plot_order = _n

capture label drop nacam_sector_plot
quietly count
local plot_n = r(N)

forvalues i = 1/`plot_n' {
    local sector_label = subinstr(nacam_label_short_display[`i'], char(34), "'", .)

    if `i' == 1 {
        label define nacam_sector_plot `i' `"`sector_label'"'
    }
    else {
        label define nacam_sector_plot `i' `"`sector_label'"', modify
    }
}

label values plot_order nacam_sector_plot

twoway ///
    (rcap tot_rev_lb tot_rev_ub plot_order if data_export == "A – Agriculture, Forestry and Fishing", horizontal lcolor("102 194 165")) ///
    (scatter plot_order tot_rev_elasticity if data_export == "A – Agriculture, Forestry and Fishing", msymbol(circle) mcolor("27 158 119")) ///
    (rcap tot_rev_lb tot_rev_ub plot_order if data_export == "B – Mining and Quarrying", horizontal lcolor("190 174 212")) ///
    (scatter plot_order tot_rev_elasticity if data_export == "B – Mining and Quarrying", msymbol(diamond) mcolor("117 112 179")) ///
    (rcap tot_rev_lb tot_rev_ub plot_order if data_export == "C – Manufacturing", horizontal lcolor("141 160 203")) ///
    (scatter plot_order tot_rev_elasticity if data_export == "C – Manufacturing", msymbol(square) mcolor("44 123 182")) ///
    (rcap tot_rev_lb tot_rev_ub plot_order if data_export == "Utilities", horizontal lcolor("252 217 142")) ///
    (scatter plot_order tot_rev_elasticity if data_export == "Utilities", msymbol(triangle) mcolor("230 171 2")) ///
    (rcap tot_rev_lb tot_rev_ub plot_order if data_export == "F – Construction", horizontal lcolor("231 138 195")) ///
    (scatter plot_order tot_rev_elasticity if data_export == "F – Construction", msymbol(Oh) mcolor("208 28 139")) ///
    (rcap tot_rev_lb tot_rev_ub plot_order if data_export == "G – Wholesale and Retail Trade; Repair of Motor Vehicles", horizontal lcolor("247 194 145")) ///
    (scatter plot_order tot_rev_elasticity if data_export == "G – Wholesale and Retail Trade; Repair of Motor Vehicles", msymbol(Th) mcolor("217 95 2")) ///
    (rcap tot_rev_lb tot_rev_ub plot_order if data_export == "H – Transportation and Storage", horizontal lcolor("179 222 105")) ///
    (scatter plot_order tot_rev_elasticity if data_export == "H – Transportation and Storage", msymbol(Sh) mcolor("102 166 30")) ///
    (rcap tot_rev_lb tot_rev_ub plot_order if data_export == "J – Information and Communication", horizontal lcolor("166 216 84")) ///
    (scatter plot_order tot_rev_elasticity if data_export == "J – Information and Communication", msymbol(plus) mcolor("102 166 30")) ///
    (rcap tot_rev_lb tot_rev_ub plot_order if data_export == "K – Financial and Insurance Activities", horizontal lcolor("188 128 189")) ///
    (scatter plot_order tot_rev_elasticity if data_export == "K – Financial and Insurance Activities", msymbol(x) mcolor("117 112 179")) ///
    (rcap tot_rev_lb tot_rev_ub plot_order if data_export == "Other services", horizontal lcolor("190 190 190")) ///
    (scatter plot_order tot_rev_elasticity if data_export == "Other services", msymbol(Dh) mcolor("102 102 102")), ///
    ylabel(1(1)`plot_n', valuelabel angle(0) labsize(tiny) nogrid) ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    yscale(reverse) ///
    xline(0, lpattern(dash) lcolor(black)) ///
    legend(order(2 "Agriculture" 4 "Mining" 6 "Manufacturing" 8 "Utilities" ///
        10 "Construction" 12 "Wholesale/retail + repair" 14 "Transport" 16 "ICT" ///
        18 "Finance" 20 "Other services") cols(1) pos(3) ring(1) size(tiny) ///
        region(lcolor(none) fcolor(none))) ///
    ytitle("") ///
    xtitle("Employment elasticity", size(small)) ///
    title("Employment elasticities with respect to total revenue", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    bgcolor(white) xsize(7.5) ysize(5.5)

graph export "output/figures/`output_stub'_tot_rev_coefficients.pdf", replace
graph export "output/figures/`output_stub'_tot_rev_coefficients.png", replace

restore

/*******************************************************************************
    Cross-model scatter plot
    - Compare each sector's value-added elasticity with its revenue elasticity.
    - The 45-degree line helps show where the two measures line up.
*******************************************************************************/
quietly summarize va_elasticity if !missing(va_elasticity, tot_rev_elasticity)
local x_min = r(min)
local x_max = r(max)

quietly summarize tot_rev_elasticity if !missing(va_elasticity, tot_rev_elasticity)
local y_min = r(min)
local y_max = r(max)

local diagonal_min = min(`x_min', `y_min')
local diagonal_max = max(`x_max', `y_max')

twoway ///
    (function y = x, range(`diagonal_min' `diagonal_max') lpattern(dash) lcolor(gs8)) ///
    (scatter tot_rev_elasticity va_elasticity if data_export == "A – Agriculture, Forestry and Fishing", ///
        msymbol(circle) mcolor("27 158 119") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(vsmall)) ///
    (scatter tot_rev_elasticity va_elasticity if data_export == "B – Mining and Quarrying", ///
        msymbol(diamond) mcolor("117 112 179") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(vsmall)) ///
    (scatter tot_rev_elasticity va_elasticity if data_export == "C – Manufacturing", ///
        msymbol(square) mcolor("44 123 182") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(vsmall)) ///
    (scatter tot_rev_elasticity va_elasticity if data_export == "Utilities", ///
        msymbol(triangle) mcolor("230 171 2") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(vsmall)) ///
    (scatter tot_rev_elasticity va_elasticity if data_export == "F – Construction", ///
        msymbol(Oh) mcolor("208 28 139") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(vsmall)) ///
    (scatter tot_rev_elasticity va_elasticity if data_export == "G – Wholesale and Retail Trade; Repair of Motor Vehicles", ///
        msymbol(Th) mcolor("217 95 2") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(vsmall)) ///
    (scatter tot_rev_elasticity va_elasticity if data_export == "H – Transportation and Storage", ///
        msymbol(Sh) mcolor("102 166 30") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(vsmall)) ///
    (scatter tot_rev_elasticity va_elasticity if data_export == "J – Information and Communication", ///
        msymbol(plus) mcolor("102 166 30") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(vsmall)) ///
    (scatter tot_rev_elasticity va_elasticity if data_export == "K – Financial and Insurance Activities", ///
        msymbol(x) mcolor("117 112 179") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(vsmall)) ///
    (scatter tot_rev_elasticity va_elasticity if data_export == "Other services", ///
        msymbol(Dh) mcolor("102 102 102") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(vsmall)), ///
    xline(0, lpattern(dash) lcolor(black)) ///
    yline(0, lpattern(dash) lcolor(black)) ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    ylabel(, grid glpattern(dash) glcolor(gs13)) ///
    xtitle("Value added elasticity", size(small)) ///
    ytitle("Total revenue elasticity", size(small)) ///
    title("Cross-sector consistency in employment elasticities", size(medsmall)) ///
    legend(order(2 "Agriculture" 3 "Mining" 4 "Manufacturing" 5 "Utilities" ///
        6 "Construction" 7 "Wholesale/retail + repair" 8 "Transport" 9 "ICT" ///
        10 "Finance" 11 "Other services") cols(1) pos(3) ring(1) size(tiny) ///
        region(lcolor(none) fcolor(none))) ///
    plotregion(color(white)) graphregion(color(white)) ///
    bgcolor(white) xsize(7.5) ysize(5.5)

graph export "output/figures/`output_stub'_scatter.pdf", replace
graph export "output/figures/`output_stub'_scatter.png", replace

* Keep the superseded scale-plot code for reference without regenerating it.
if 0 {
/*******************************************************************************
    Elasticities by sector scale
    - Compare sector elasticities with average firm log employment and revenue.
    - Scale is computed from the common valid sample for both elasticity models.
*******************************************************************************/
twoway ///
    (scatter va_elasticity avg_firm_ln_emp if strpos(data_export, "Agriculture") > 0, ///
        msymbol(circle) mcolor("27 158 119") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_emp if strpos(data_export, "Mining") > 0, ///
        msymbol(diamond) mcolor("117 112 179") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_emp if strpos(data_export, "Manufacturing") > 0, ///
        msymbol(square) mcolor("44 123 182") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_emp if data_export == "Utilities", ///
        msymbol(triangle) mcolor("230 171 2") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_emp if strpos(data_export, "Construction") > 0, ///
        msymbol(Oh) mcolor("208 28 139") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_emp if strpos(data_export, "Wholesale") > 0, ///
        msymbol(Th) mcolor("217 95 2") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_emp if strpos(data_export, "Transportation") > 0, ///
        msymbol(Sh) mcolor("102 166 30") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_emp if strpos(data_export, "Information") > 0, ///
        msymbol(plus) mcolor("102 166 30") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_emp if strpos(data_export, "Financial") > 0, ///
        msymbol(x) mcolor("117 112 179") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_emp if data_export == "Other services", ///
        msymbol(Dh) mcolor("102 102 102") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)), ///
    yline(0, lpattern(dash) lcolor(black)) ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    ylabel(, grid glpattern(dash) glcolor(gs13)) ///
    xtitle("Average firm log employment", size(small)) ///
    ytitle("Value-added elasticity", size(small)) ///
    title("Value added", size(medsmall)) ///
    legend(off) ///
    plotregion(color(white)) graphregion(color(white)) ///
    bgcolor(white) name(scale_va_emp, replace)

twoway ///
    (scatter tot_rev_elasticity avg_firm_ln_emp if strpos(data_export, "Agriculture") > 0, ///
        msymbol(circle) mcolor("27 158 119") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_emp if strpos(data_export, "Mining") > 0, ///
        msymbol(diamond) mcolor("117 112 179") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_emp if strpos(data_export, "Manufacturing") > 0, ///
        msymbol(square) mcolor("44 123 182") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_emp if data_export == "Utilities", ///
        msymbol(triangle) mcolor("230 171 2") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_emp if strpos(data_export, "Construction") > 0, ///
        msymbol(Oh) mcolor("208 28 139") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_emp if strpos(data_export, "Wholesale") > 0, ///
        msymbol(Th) mcolor("217 95 2") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_emp if strpos(data_export, "Transportation") > 0, ///
        msymbol(Sh) mcolor("102 166 30") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_emp if strpos(data_export, "Information") > 0, ///
        msymbol(plus) mcolor("102 166 30") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_emp if strpos(data_export, "Financial") > 0, ///
        msymbol(x) mcolor("117 112 179") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_emp if data_export == "Other services", ///
        msymbol(Dh) mcolor("102 102 102") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)), ///
    yline(0, lpattern(dash) lcolor(black)) ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    ylabel(, grid glpattern(dash) glcolor(gs13)) ///
    xtitle("Average firm log employment", size(small)) ///
    ytitle("Total-revenue elasticity", size(small)) ///
    title("Total revenue", size(medsmall)) ///
    legend(order(1 "Agriculture" 2 "Mining" 3 "Manufacturing" 4 "Utilities" ///
        5 "Construction" 6 "Wholesale/retail + repair" 7 "Transport" 8 "ICT" ///
        9 "Finance" 10 "Other services") cols(1) pos(3) ring(1) size(tiny) ///
        region(lcolor(none) fcolor(none))) ///
    plotregion(color(white)) graphregion(color(white)) ///
    bgcolor(white) name(scale_tot_emp, replace)

graph combine scale_va_emp scale_tot_emp, ///
    rows(1) xsize(11.5) ysize(4.8) graphregion(color(white)) ///
    title("Employment elasticities by sector employment scale", size(medsmall)) ///
    name(scale_emp_combined, replace)
graph display scale_emp_combined
graph export "output/figures/`output_stub'_elasticities_vs_avg_log_employment.pdf", replace
graph export "output/figures/`output_stub'_elasticities_vs_avg_log_employment.png", replace

twoway ///
    (scatter va_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Agriculture") > 0, ///
        msymbol(circle) mcolor("27 158 119") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Mining") > 0, ///
        msymbol(diamond) mcolor("117 112 179") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Manufacturing") > 0, ///
        msymbol(square) mcolor("44 123 182") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_tot_rev if data_export == "Utilities", ///
        msymbol(triangle) mcolor("230 171 2") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Construction") > 0, ///
        msymbol(Oh) mcolor("208 28 139") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Wholesale") > 0, ///
        msymbol(Th) mcolor("217 95 2") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Transportation") > 0, ///
        msymbol(Sh) mcolor("102 166 30") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Information") > 0, ///
        msymbol(plus) mcolor("102 166 30") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Financial") > 0, ///
        msymbol(x) mcolor("117 112 179") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter va_elasticity avg_firm_ln_tot_rev if data_export == "Other services", ///
        msymbol(Dh) mcolor("102 102 102") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)), ///
    yline(0, lpattern(dash) lcolor(black)) ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    ylabel(, grid glpattern(dash) glcolor(gs13)) ///
    xtitle("Average firm log total revenue", size(small)) ///
    ytitle("Value-added elasticity", size(small)) ///
    title("Value added", size(medsmall)) ///
    legend(off) ///
    plotregion(color(white)) graphregion(color(white)) ///
    bgcolor(white) name(scale_va_rev, replace)

twoway ///
    (scatter tot_rev_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Agriculture") > 0, ///
        msymbol(circle) mcolor("27 158 119") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Mining") > 0, ///
        msymbol(diamond) mcolor("117 112 179") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Manufacturing") > 0, ///
        msymbol(square) mcolor("44 123 182") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_tot_rev if data_export == "Utilities", ///
        msymbol(triangle) mcolor("230 171 2") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Construction") > 0, ///
        msymbol(Oh) mcolor("208 28 139") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Wholesale") > 0, ///
        msymbol(Th) mcolor("217 95 2") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Transportation") > 0, ///
        msymbol(Sh) mcolor("102 166 30") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Information") > 0, ///
        msymbol(plus) mcolor("102 166 30") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_tot_rev if strpos(data_export, "Financial") > 0, ///
        msymbol(x) mcolor("117 112 179") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter tot_rev_elasticity avg_firm_ln_tot_rev if data_export == "Other services", ///
        msymbol(Dh) mcolor("102 102 102") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)), ///
    yline(0, lpattern(dash) lcolor(black)) ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    ylabel(, grid glpattern(dash) glcolor(gs13)) ///
    xtitle("Average firm log total revenue", size(small)) ///
    ytitle("Total-revenue elasticity", size(small)) ///
    title("Total revenue", size(medsmall)) ///
    legend(order(1 "Agriculture" 2 "Mining" 3 "Manufacturing" 4 "Utilities" ///
        5 "Construction" 6 "Wholesale/retail + repair" 7 "Transport" 8 "ICT" ///
        9 "Finance" 10 "Other services") cols(1) pos(3) ring(1) size(tiny) ///
        region(lcolor(none) fcolor(none))) ///
    plotregion(color(white)) graphregion(color(white)) ///
    bgcolor(white) name(scale_tot_rev, replace)

graph combine scale_va_rev scale_tot_rev, ///
    rows(1) xsize(11.5) ysize(4.8) graphregion(color(white)) ///
    title("Employment elasticities by sector revenue scale", size(medsmall)) ///
    name(scale_rev_combined, replace)
graph display scale_rev_combined
graph export "output/figures/`output_stub'_elasticities_vs_avg_log_revenue.pdf", replace
graph export "output/figures/`output_stub'_elasticities_vs_avg_log_revenue.png", replace
}

/*******************************************************************************
    Sector opportunity maps
    - The x-axis is aggregate sector value added per worker, averaged equally
      across contributing sector-years and shown in logs.
    - Bubble sizes are transparent tercile categories calculated separately for
      each scale measure across the common 29-sector plotting sample.
    - Sectors are labelled when the absolute value of the relevant employment
      elasticity meets the common threshold or they rank among the two most
      productive sectors.
*******************************************************************************/
isid nacam
assert _N == 29
assert !missing(ln_sector_va_per_worker, va_elasticity, tot_rev_elasticity, ///
    avg_annual_total_revenue, avg_annual_total_employment, ///
    avg_firm_revenue, avg_firm_employment)

quietly summarize ln_sector_va_per_worker, detail
local productivity_median = r(p50)

foreach measure in total_revenue total_employment avg_revenue avg_employment {
    if "`measure'" == "total_revenue" {
        local size_source avg_annual_total_revenue
        local size_unit "CFAF bn"
        local size_divisor 1000000000
        local size_format "%9.1fc"
    }
    else if "`measure'" == "total_employment" {
        local size_source avg_annual_total_employment
        local size_unit "workers"
        local size_divisor 1
        local size_format "%12.0fc"
    }
    else if "`measure'" == "avg_revenue" {
        local size_source avg_firm_revenue
        local size_unit "CFAF bn/firm"
        local size_divisor 1000000000
        local size_format "%9.1fc"
    }
    else if "`measure'" == "avg_employment" {
        local size_source avg_firm_employment
        local size_unit "workers/firm"
        local size_divisor 1
        local size_format "%12.0fc"
    }

    xtile tercile_`measure' = `size_source', nq(3)
    assert inrange(tercile_`measure', 1, 3)

    forvalues tercile = 1/3 {
        quietly count if tercile_`measure' == `tercile'
        local tercile_n`tercile' = r(N)
        assert r(N) > 0

        quietly summarize `size_source' if tercile_`measure' == `tercile', ///
            meanonly
        local range_min : display `size_format' (r(min) / `size_divisor')
        local range_max : display `size_format' (r(max) / `size_divisor')
        local range_min = trim("`range_min'")
        local range_max = trim("`range_max'")

        if `tercile' == 1 {
            local tercile_name "Bottom third"
        }
        else if `tercile' == 2 {
            local tercile_name "Middle third"
        }
        else {
            local tercile_name "Top third"
        }

        local legend`tercile'_`measure' ///
            "`tercile_name': `range_min'-`range_max' `size_unit'"
    }

    if abs(`tercile_n1' - `tercile_n2') > 1 ///
            | abs(`tercile_n1' - `tercile_n3') > 1 ///
            | abs(`tercile_n2' - `tercile_n3') > 1 {
        display as error "Uneven tercile allocation for `measure'."
        exit 459
    }
}

* Label economically large elasticities and the two most productive sectors.
gsort -ln_sector_va_per_worker nacam
generate byte top_productivity = _n <= 2
sort nacam
quietly count if top_productivity == 1
assert r(N) == 2

generate byte annotate_va = ///
    abs(va_elasticity) >= `label_elasticity_threshold' | top_productivity == 1
generate byte annotate_totrev = ///
    abs(tot_rev_elasticity) >= `label_elasticity_threshold' ///
    | top_productivity == 1

assert !missing(annotate_va, annotate_totrev)
quietly count if annotate_va == 1
assert r(N) > 0
quietly count if annotate_totrev == 1
assert r(N) > 0

* Default anchors allow the threshold-selected set to change with the estimates.
* Tailored overrides keep the current leader-line layout readable.
generate double label_x_va = ln_sector_va_per_worker if annotate_va == 1
generate double label_y_va = va_elasticity if annotate_va == 1
generate byte label_pos_va = 3 if annotate_va == 1
replace label_x_va = 15.60 if nacam == 17
replace label_y_va =  0.47 if nacam == 17
replace label_pos_va = 3 if nacam == 17
replace label_x_va = 15.55 if nacam == 27
replace label_y_va =  0.34 if nacam == 27
replace label_pos_va = 3 if nacam == 27
replace label_x_va = 17.55 if nacam == 29
replace label_y_va = -0.31 if nacam == 29
replace label_pos_va = 3 if nacam == 29
replace label_x_va = 15.85 if nacam == 41
replace label_y_va = -0.24 if nacam == 41
replace label_pos_va = 3 if nacam == 41
replace label_x_va = 19.20 if nacam == 5
replace label_y_va =  0.01 if nacam == 5
replace label_pos_va = 9 if nacam == 5

generate double label_x_totrev = ln_sector_va_per_worker ///
    if annotate_totrev == 1
generate double label_y_totrev = tot_rev_elasticity if annotate_totrev == 1
generate byte label_pos_totrev = 3 if annotate_totrev == 1
replace label_x_totrev = 15.64 if nacam == 17
replace label_y_totrev =  0.67 if nacam == 17
replace label_pos_totrev = 3 if nacam == 17
replace label_x_totrev = 17.05 if nacam == 9
replace label_y_totrev =  0.66 if nacam == 9
replace label_pos_totrev = 3 if nacam == 9
replace label_x_totrev = 16.20 if nacam == 6
replace label_y_totrev = -0.32 if nacam == 6
replace label_pos_totrev = 3 if nacam == 6
replace label_x_totrev = 15.10 if nacam == 2
replace label_y_totrev = -0.14 if nacam == 2
replace label_pos_totrev = 3 if nacam == 2
replace label_x_totrev = 19.20 if nacam == 5
replace label_y_totrev =  0.21 if nacam == 5
replace label_pos_totrev = 9 if nacam == 5

assert !missing(label_x_va, label_y_va, label_pos_va) if annotate_va == 1
assert !missing(label_x_totrev, label_y_totrev, label_pos_totrev) ///
    if annotate_totrev == 1

capture program drop cmr_elasticity_bubble_panel
program define cmr_elasticity_bubble_panel
    version 17.0
    syntax varname(numeric), TERCILEvar(name) MODEL(string) ///
        Title(string asis) Name(name) XMEDIAN(real) ///
        LEGEND1(string asis) LEGEND2(string asis) LEGEND3(string asis) ///
        [LEGENDOFF]

    if "`model'" == "va" {
        local annotation_flag annotate_va
        local label_x label_x_va
        local label_y label_y_va
        local label_position label_pos_va
        local y_min -0.42
        local y_max 0.54
        local y_ticks "-0.4(0.2)0.4"
        local heading_top 0.50
        local heading_bottom -0.39
    }
    else if "`model'" == "totrev" {
        local annotation_flag annotate_totrev
        local label_x label_x_totrev
        local label_y label_y_totrev
        local label_position label_pos_totrev
        local y_min -0.42
        local y_max 0.78
        local y_ticks "-0.4(0.2)0.8"
        local heading_top 0.74
        local heading_bottom -0.39
    }
    else {
        display as error "model() must be va or totrev."
        exit 198
    }

    if "`legendoff'" != "" {
        local legend_options legend(off)
    }
    else {
        local legend_options ///
            legend(order(1 `legend1' 2 `legend2' 3 `legend3') ///
                title("Bubble-size terciles across 29 sectors", size(tiny)) ///
                cols(1) pos(4) ring(0) size(tiny) ///
                region(lcolor(gs14) fcolor(white%85)))
    }

    twoway ///
        (scatter `varlist' ln_sector_va_per_worker if `tercilevar' == 1, ///
            msymbol(circle) msize(1.45) mcolor("112 128 144%50") ///
            mlcolor(white%80) mlwidth(vthin)) ///
        (scatter `varlist' ln_sector_va_per_worker if `tercilevar' == 2, ///
            msymbol(circle) msize(2.15) mcolor("112 128 144%50") ///
            mlcolor(white%80) mlwidth(vthin)) ///
        (scatter `varlist' ln_sector_va_per_worker if `tercilevar' == 3, ///
            msymbol(circle) msize(3.00) mcolor("112 128 144%50") ///
            mlcolor(white%80) mlwidth(vthin)) ///
        (scatter `varlist' ln_sector_va_per_worker ///
            if `annotation_flag' == 1 & `varlist' >= 0 & `tercilevar' == 1, ///
            msymbol(circle) msize(1.45) mcolor("0 130 125%85") ///
            mlcolor(white) mlwidth(vthin)) ///
        (scatter `varlist' ln_sector_va_per_worker ///
            if `annotation_flag' == 1 & `varlist' >= 0 & `tercilevar' == 2, ///
            msymbol(circle) msize(2.15) mcolor("0 130 125%85") ///
            mlcolor(white) mlwidth(vthin)) ///
        (scatter `varlist' ln_sector_va_per_worker ///
            if `annotation_flag' == 1 & `varlist' >= 0 & `tercilevar' == 3, ///
            msymbol(circle) msize(3.00) mcolor("0 130 125%85") ///
            mlcolor(white) mlwidth(vthin)) ///
        (scatter `varlist' ln_sector_va_per_worker ///
            if `annotation_flag' == 1 & `varlist' < 0 & `tercilevar' == 1, ///
            msymbol(circle) msize(1.45) mcolor("214 111 67%85") ///
            mlcolor(white) mlwidth(vthin)) ///
        (scatter `varlist' ln_sector_va_per_worker ///
            if `annotation_flag' == 1 & `varlist' < 0 & `tercilevar' == 2, ///
            msymbol(circle) msize(2.15) mcolor("214 111 67%85") ///
            mlcolor(white) mlwidth(vthin)) ///
        (scatter `varlist' ln_sector_va_per_worker ///
            if `annotation_flag' == 1 & `varlist' < 0 & `tercilevar' == 3, ///
            msymbol(circle) msize(3.00) mcolor("214 111 67%85") ///
            mlcolor(white) mlwidth(vthin)) ///
        (pcspike `label_y' `label_x' `varlist' ln_sector_va_per_worker ///
            if `annotation_flag' == 1, lcolor(gs7) lwidth(vthin)) ///
        (scatter `label_y' `label_x' if `annotation_flag' == 1, ///
            msymbol(none) mlabel(nacam_label_short_display) ///
            mlabvposition(`label_position') mlabsize(vsmall) mlabcolor(black)), ///
        xline(`xmedian', lpattern(shortdash) lcolor(gs8) lwidth(thin)) ///
        yline(0, lpattern(solid) lcolor(gs6) lwidth(thin)) ///
        xscale(range(14.8 20.0)) yscale(range(`y_min' `y_max')) ///
        xlabel(15(1)20, grid glpattern(shortdash) glcolor(gs14) labsize(small)) ///
        ylabel(`y_ticks', format(%4.1f) grid glpattern(shortdash) ///
            glcolor(gs14) labsize(small)) ///
        xtitle("Log sector value added per worker", size(small)) ///
        ytitle("Employment elasticity", size(small)) ///
        title(`title', size(medsmall)) ///
        text(`heading_top' 14.92 "Lower-productivity" "employment-expanding", ///
            place(e) justification(left) color("0 105 100") size(vsmall)) ///
        text(`heading_top' 19.90 "Higher-productivity" "employment-expanding", ///
            place(w) justification(right) color("0 105 100") size(vsmall)) ///
        text(`heading_bottom' 14.92 "Lower-productivity" "employment-contracting", ///
            place(e) justification(left) color("181 82 45") size(vsmall)) ///
        text(`heading_bottom' 19.90 "Higher-productivity" "employment-contracting", ///
            place(w) justification(right) color("181 82 45") size(vsmall)) ///
        `legend_options' ///
        plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
        name(`name', replace)
end

cmr_elasticity_bubble_panel va_elasticity, ///
    tercilevar(tercile_total_revenue) model(va) ///
    title("Value-added elasticity") xmedian(`productivity_median') ///
    legend1("`legend1_total_revenue'") ///
    legend2("`legend2_total_revenue'") ///
    legend3("`legend3_total_revenue'") ///
    name(bubble_va_total_revenue) legendoff
cmr_elasticity_bubble_panel tot_rev_elasticity, ///
    tercilevar(tercile_total_revenue) model(totrev) ///
    title("Total-revenue elasticity") xmedian(`productivity_median') ///
    legend1("`legend1_total_revenue'") ///
    legend2("`legend2_total_revenue'") ///
    legend3("`legend3_total_revenue'") ///
    name(bubble_totrev_total_revenue)
graph combine bubble_va_total_revenue bubble_totrev_total_revenue, ///
    rows(1) xsize(11.5) ysize(5.2) graphregion(color(white)) ///
    title("Where are Cameroon's employment-expanding sectors?", size(medsmall)) ///
    subtitle("Employment response, productivity, and sector scale", size(small)) ///
    note("Vertical line marks median log sector value added per worker.", size(vsmall)) ///
    name(bubble_total_revenue_combined, replace)
graph export "output/figures/cmr_elasticities_va_worker_bubble_total_revenue.pdf", replace
graph export "output/figures/cmr_elasticities_va_worker_bubble_total_revenue.png", replace

cmr_elasticity_bubble_panel va_elasticity, ///
    tercilevar(tercile_total_employment) model(va) ///
    title("Value-added elasticity") xmedian(`productivity_median') ///
    legend1("`legend1_total_employment'") ///
    legend2("`legend2_total_employment'") ///
    legend3("`legend3_total_employment'") ///
    name(bubble_va_total_employment) legendoff
cmr_elasticity_bubble_panel tot_rev_elasticity, ///
    tercilevar(tercile_total_employment) model(totrev) ///
    title("Total-revenue elasticity") xmedian(`productivity_median') ///
    legend1("`legend1_total_employment'") ///
    legend2("`legend2_total_employment'") ///
    legend3("`legend3_total_employment'") ///
    name(bubble_totrev_total_employment)
graph combine bubble_va_total_employment bubble_totrev_total_employment, ///
    rows(1) xsize(11.5) ysize(5.2) graphregion(color(white)) ///
    title("Where are Cameroon's employment-expanding sectors?", size(medsmall)) ///
    subtitle("Employment response, productivity, and sector scale", size(small)) ///
    note("Vertical line marks median log sector value added per worker.", size(vsmall)) ///
    name(bubble_total_employment_combined, replace)
graph export "output/figures/cmr_elasticities_va_worker_bubble_total_employment.pdf", replace
graph export "output/figures/cmr_elasticities_va_worker_bubble_total_employment.png", replace

cmr_elasticity_bubble_panel va_elasticity, ///
    tercilevar(tercile_avg_revenue) model(va) ///
    title("Value-added elasticity") xmedian(`productivity_median') ///
    legend1("`legend1_avg_revenue'") ///
    legend2("`legend2_avg_revenue'") ///
    legend3("`legend3_avg_revenue'") ///
    name(bubble_va_avg_revenue) legendoff
cmr_elasticity_bubble_panel tot_rev_elasticity, ///
    tercilevar(tercile_avg_revenue) model(totrev) ///
    title("Total-revenue elasticity") xmedian(`productivity_median') ///
    legend1("`legend1_avg_revenue'") ///
    legend2("`legend2_avg_revenue'") ///
    legend3("`legend3_avg_revenue'") ///
    name(bubble_totrev_avg_revenue)
graph combine bubble_va_avg_revenue bubble_totrev_avg_revenue, ///
    rows(1) xsize(11.5) ysize(5.2) graphregion(color(white)) ///
    title("Where are Cameroon's employment-expanding sectors?", size(medsmall)) ///
    subtitle("Employment response, productivity, and sector scale", size(small)) ///
    note("Vertical line marks median log sector value added per worker.", size(vsmall)) ///
    name(bubble_avg_revenue_combined, replace)
graph export "output/figures/cmr_elasticities_va_worker_bubble_avg_revenue.pdf", replace
graph export "output/figures/cmr_elasticities_va_worker_bubble_avg_revenue.png", replace

cmr_elasticity_bubble_panel va_elasticity, ///
    tercilevar(tercile_avg_employment) model(va) ///
    title("Value-added elasticity") xmedian(`productivity_median') ///
    legend1("`legend1_avg_employment'") ///
    legend2("`legend2_avg_employment'") ///
    legend3("`legend3_avg_employment'") ///
    name(bubble_va_avg_employment) legendoff
cmr_elasticity_bubble_panel tot_rev_elasticity, ///
    tercilevar(tercile_avg_employment) model(totrev) ///
    title("Total-revenue elasticity") xmedian(`productivity_median') ///
    legend1("`legend1_avg_employment'") ///
    legend2("`legend2_avg_employment'") ///
    legend3("`legend3_avg_employment'") ///
    name(bubble_totrev_avg_employment)
graph combine bubble_va_avg_employment bubble_totrev_avg_employment, ///
    rows(1) xsize(11.5) ysize(5.2) graphregion(color(white)) ///
    title("Where are Cameroon's employment-expanding sectors?", size(medsmall)) ///
    subtitle("Employment response, productivity, and sector scale", size(small)) ///
    note("Vertical line marks median log sector value added per worker.", size(vsmall)) ///
    name(bubble_avg_employment_combined, replace)
graph export "output/figures/cmr_elasticities_va_worker_bubble_avg_employment.pdf", replace
graph export "output/figures/cmr_elasticities_va_worker_bubble_avg_employment.png", replace





