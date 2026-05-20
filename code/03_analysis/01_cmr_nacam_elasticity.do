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

    Notes:
        This file is intentionally standalone, but it still bootstraps
        code/01_setup.do so path handling stays local-first.
*******************************************************************************/

* Resolve the repository root from the current directory for standalone runs.
local project_root = subinstr(c(pwd), "\", "/", .)
if !fileexists("`project_root'/AGENTS.md") {
    if fileexists("`project_root'/../../AGENTS.md") {
        local project_root "`project_root'/../.."
    }
    else if fileexists("`project_root'/../AGENTS.md") {
        local project_root "`project_root'/.."
    }
}
capture noisily cd "`project_root'"
if _rc | !fileexists("AGENTS.md") {
    display as error "Expected project root not found: `project_root'"
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
assert !missing(nacam_label_display)
assert !missing(nacam_label_short_display)

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
        10 "Construction" 12 "Trade/repair" 14 "Transport" 16 "ICT" ///
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
        10 "Construction" 12 "Trade/repair" 14 "Transport" 16 "ICT" ///
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
        6 "Construction" 7 "Trade/repair" 8 "Transport" 9 "ICT" ///
        10 "Finance" 11 "Other services") cols(1) pos(3) ring(1) size(tiny) ///
        region(lcolor(none) fcolor(none))) ///
    plotregion(color(white)) graphregion(color(white)) ///
    bgcolor(white) xsize(7.5) ysize(5.5)

graph export "output/figures/`output_stub'_scatter.pdf", replace
graph export "output/figures/`output_stub'_scatter.png", replace





