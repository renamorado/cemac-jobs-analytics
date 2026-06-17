version 17.0
set more off

/*******************************************************************************
    Purpose:
        Build administrative tax/BDF asset diagnostics by NACAM sector.

    Inputs:
        Data/Analysis/CMR_BDF_cleaned.dta

    Outputs:
        Data/Analysis/CMR_BDF_asset_diagnostics.dta
        output/tables/cmr_bdf_asset_availability_audit.tex
        output/figures/cmr_bdf_net_fixed_assets_by_nacam.pdf
        output/figures/cmr_bdf_net_fixed_assets_by_nacam.png
        output/figures/cmr_bdf_net_total_assets_by_nacam.pdf
        output/figures/cmr_bdf_net_total_assets_by_nacam.png
        output/figures/cmr_bdf_assets_vs_employment_by_nacam.pdf
        output/figures/cmr_bdf_assets_vs_employment_by_nacam.png
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
        display as error "Add this user to the bootstrap block in code/elasticity_cameroun/11_cmr_bdf_asset_diagnostics.do."
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

capture log close cmrbdfassets
capture log using "${LOGDIR}/11_cmr_bdf_asset_diagnostics_`log_stamp'.log", text name(cmrbdfassets)
if _rc {
    sleep `sleep_ms'
    log using "${LOGDIR}/11_cmr_bdf_asset_diagnostics_`log_stamp'.log", text name(cmrbdfassets)
}

local input_file "${DATADIR}/Analysis/CMR_BDF_cleaned.dta"
local diagnostics_out "${DATADIR}/Analysis/CMR_BDF_asset_diagnostics.dta"

confirm file "`input_file'"
use "`input_file'", clear

keep firmid fin_yr nacam nacam_label_display nacam_label_short_display ///
    data_export totemp tot_rev fa_net tot_assets_net ta_net share_k

isid firmid fin_yr
assert !missing(nacam, nacam_label_display, nacam_label_short_display, data_export)

capture confirm numeric variable totemp
if !_rc {
    generate double employment = totemp
}
else {
    destring totemp, generate(employment) ignore(",") force
}

foreach var in fa_net tot_assets_net ta_net share_k employment tot_rev {
    capture confirm numeric variable `var'
    if _rc {
        display as error "`var' must be numeric in `input_file'."
        exit 459
    }
}

/*******************************************************************************
    1. Audit asset-variable availability in the cleaned BDF panel
*******************************************************************************/

foreach var in fa_net tot_assets_net ta_net share_k {
    quietly count if !missing(`var')
    local `var'_nonmissing = r(N)

    quietly count if `var' > 0 & !missing(`var')
    local `var'_positive = r(N)

    quietly count if `var' == 0 & !missing(`var')
    local `var'_zero = r(N)

    quietly count if `var' < 0 & !missing(`var')
    local `var'_negative = r(N)

    preserve
    keep if `var' > 0 & !missing(nacam)
    keep nacam
    duplicates drop
    quietly count
    local `var'_sectors = r(N)
    restore
}

matrix asset_audit = ( ///
    `fa_net_nonmissing', `fa_net_positive', `fa_net_zero', `fa_net_negative', `fa_net_sectors' \ ///
    `tot_assets_net_nonmissing', `tot_assets_net_positive', `tot_assets_net_zero', `tot_assets_net_negative', `tot_assets_net_sectors' \ ///
    `ta_net_nonmissing', `ta_net_positive', `ta_net_zero', `ta_net_negative', `ta_net_sectors' \ ///
    `share_k_nonmissing', `share_k_positive', `share_k_zero', `share_k_negative', `share_k_sectors' ///
)
matrix colnames asset_audit = Nonmissing Positive Zero Negative SectorsPositive
matrix rownames asset_audit = fa_net tot_assets_net ta_net share_k

esttab matrix(asset_audit, fmt(%12.0fc)) ///
    using "${OUTPUTDIR}/tables/cmr_bdf_asset_availability_audit.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels( ///
        fa_net "Net fixed assets" ///
        tot_assets_net "Net total assets" ///
        ta_net "Net tangible assets" ///
        share_k "Share capital" ///
    )

tempfile analysis_base sector_fixed sector_total
save "`analysis_base'"

/*******************************************************************************
    2. Build sector diagnostics from each firm's latest positive asset year
*******************************************************************************/

use "`analysis_base'", clear
keep if fa_net > 0 & !missing(firmid, fin_yr, nacam)
gsort firmid -fin_yr
by firmid: keep if _n == 1

generate byte fixed_asset_firm = 1
generate double employment_positive = employment if employment > 0
generate double revenue_positive = tot_rev if tot_rev > 0

collapse ///
    (sum) fixed_asset_firms = fixed_asset_firm ///
        total_fixed_assets = fa_net ///
        total_employment_latest = employment_positive ///
        total_revenue_latest = revenue_positive ///
    (mean) average_fixed_assets = fa_net ///
        average_employment_latest = employment_positive ///
        average_revenue_latest = revenue_positive, ///
    by(nacam nacam_label_display nacam_label_short_display data_export)

generate double total_fixed_assets_bil = total_fixed_assets / 1000000000
generate double average_fixed_assets_mil = average_fixed_assets / 1000000
generate double log_total_fixed_assets = ln(total_fixed_assets) if total_fixed_assets > 0
generate double log_average_fixed_assets = ln(average_fixed_assets) if average_fixed_assets > 0
generate double log_total_employment_latest = ln(total_employment_latest) if total_employment_latest > 0
generate double log_total_revenue_latest = ln(total_revenue_latest) if total_revenue_latest > 0

label variable fixed_asset_firms "Firms with positive net fixed assets"
label variable total_fixed_assets "Total net fixed assets"
label variable average_fixed_assets "Average net fixed assets"
label variable total_fixed_assets_bil "Total net fixed assets, CFAF billions"
label variable average_fixed_assets_mil "Average net fixed assets, CFAF millions"
label variable total_employment_latest "Total employment in firms' latest positive fixed-asset year"
label variable total_revenue_latest "Total revenue in firms' latest positive fixed-asset year"
label variable log_total_fixed_assets "Log total net fixed assets"
label variable log_average_fixed_assets "Log average net fixed assets"
label variable log_total_employment_latest "Log total employment"
label variable log_total_revenue_latest "Log total revenue"

sort nacam
isid nacam
save "`sector_fixed'"

use "`analysis_base'", clear
keep if tot_assets_net > 0 & !missing(firmid, fin_yr, nacam)
gsort firmid -fin_yr
by firmid: keep if _n == 1

generate byte total_asset_firm = 1

collapse ///
    (sum) total_asset_firms = total_asset_firm ///
        total_net_total_assets = tot_assets_net ///
    (mean) average_net_total_assets = tot_assets_net, ///
    by(nacam)

generate double total_net_total_assets_bil = total_net_total_assets / 1000000000
generate double average_net_total_assets_mil = average_net_total_assets / 1000000
generate double log_total_net_total_assets = ln(total_net_total_assets) if total_net_total_assets > 0
generate double log_average_net_total_assets = ln(average_net_total_assets) if average_net_total_assets > 0

label variable total_asset_firms "Firms with positive net total assets"
label variable total_net_total_assets "Total net total assets"
label variable average_net_total_assets "Average net total assets"
label variable total_net_total_assets_bil "Total net total assets, CFAF billions"
label variable average_net_total_assets_mil "Average net total assets, CFAF millions"
label variable log_total_net_total_assets "Log total net total assets"
label variable log_average_net_total_assets "Log average net total assets"

sort nacam
isid nacam
save "`sector_total'"

use "`sector_fixed'", clear
merge 1:1 nacam using "`sector_total'", nogen keep(match)
assert !missing(nacam_label_display, nacam_label_short_display, data_export)
assert fixed_asset_firms > 0
assert total_asset_firms > 0

sort nacam
isid nacam
save "`diagnostics_out'", replace

/*******************************************************************************
    3. Figure helpers and exports
*******************************************************************************/

capture program drop bdf_asset_colored_dotplot
program define bdf_asset_colored_dotplot
    version 17.0
    syntax varname(numeric) [if], Title(string asis) XTitle(string asis) ///
        Name(name) [LEGENDOFF LABSZ(string) TITLESZ(string) XDIM(string) YDIM(string)]

    marksample touse

    if "`labsz'" == "" {
        local labsz "tiny"
    }
    if "`titlesz'" == "" {
        local titlesz "small"
    }
    if "`xdim'" == "" {
        local xdim "4.2"
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
                7 "Transport" 8 "ICT" 9 "Finance" 10 "Other services") ///
                cols(1) pos(3) ring(1) size(tiny) ///
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

    capture label drop bdf_asset_sector_axis
    forvalues i = 1/`=_N' {
        local sector_label = subinstr(nacam_label_short_display[`i'], char(34), "'", .)
        if `i' == 1 {
            label define bdf_asset_sector_axis `i' `"`sector_label'"'
        }
        else {
            label define bdf_asset_sector_axis `i' `"`sector_label'"', modify
        }
    }
    label values plot_order bdf_asset_sector_axis

    local last_order = _N

    twoway ///
        (scatter plot_order `varlist' if strpos(data_export, "Agriculture") > 0, ///
            msymbol(circle) mcolor("27 158 119") msize(medlarge)) ///
        (scatter plot_order `varlist' if strpos(data_export, "Mining") > 0, ///
            msymbol(diamond) mcolor("117 112 179") msize(medlarge)) ///
        (scatter plot_order `varlist' if strpos(data_export, "Manufacturing") > 0, ///
            msymbol(square) mcolor("44 123 182") msize(medlarge)) ///
        (scatter plot_order `varlist' if data_export == "Utilities", ///
            msymbol(triangle) mcolor("230 171 2") msize(medlarge)) ///
        (scatter plot_order `varlist' if strpos(data_export, "Construction") > 0, ///
            msymbol(Oh) mcolor("208 28 139") msize(medlarge)) ///
        (scatter plot_order `varlist' if strpos(data_export, "Wholesale") > 0, ///
            msymbol(Th) mcolor("217 95 2") msize(medlarge)) ///
        (scatter plot_order `varlist' if strpos(data_export, "Transportation") > 0, ///
            msymbol(Sh) mcolor("102 166 30") msize(medlarge)) ///
        (scatter plot_order `varlist' if strpos(data_export, "Information") > 0, ///
            msymbol(plus) mcolor("102 166 30") msize(medlarge)) ///
        (scatter plot_order `varlist' if strpos(data_export, "Financial") > 0, ///
            msymbol(x) mcolor("117 112 179") msize(medlarge)) ///
        (scatter plot_order `varlist' if data_export == "Other services", ///
            msymbol(Dh) mcolor("102 102 102") msize(medlarge)), ///
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

bdf_asset_colored_dotplot log_total_fixed_assets if !missing(log_total_fixed_assets), ///
    title("Aggregate sector total") ///
    xtitle("Log total net fixed assets") ///
    name(bdf_fa_total) legendoff

bdf_asset_colored_dotplot log_average_fixed_assets if !missing(log_average_fixed_assets), ///
    title("Sector firm average") ///
    xtitle("Log average net fixed assets") ///
    name(bdf_fa_average) xdim(5.4)

graph combine bdf_fa_total bdf_fa_average, ///
    cols(2) title("BDF log net fixed assets by NACAM sector", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(6.2) xsize(11.5) name(bdf_fa_combined, replace)
graph display bdf_fa_combined
graph export "${OUTPUTDIR}/figures/cmr_bdf_net_fixed_assets_by_nacam.pdf", replace
graph export "${OUTPUTDIR}/figures/cmr_bdf_net_fixed_assets_by_nacam.png", replace

bdf_asset_colored_dotplot log_total_net_total_assets if !missing(log_total_net_total_assets), ///
    title("Aggregate sector total") ///
    xtitle("Log total net total assets") ///
    name(bdf_ta_total) legendoff

bdf_asset_colored_dotplot log_average_net_total_assets if !missing(log_average_net_total_assets), ///
    title("Sector firm average") ///
    xtitle("Log average net total assets") ///
    name(bdf_ta_average) xdim(5.4)

graph combine bdf_ta_total bdf_ta_average, ///
    cols(2) title("BDF log net total assets by NACAM sector", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(6.2) xsize(11.5) name(bdf_ta_combined, replace)
graph display bdf_ta_combined
graph export "${OUTPUTDIR}/figures/cmr_bdf_net_total_assets_by_nacam.pdf", replace
graph export "${OUTPUTDIR}/figures/cmr_bdf_net_total_assets_by_nacam.png", replace

twoway ///
    (scatter log_total_fixed_assets log_total_employment_latest if strpos(data_export, "Agriculture") > 0, ///
        msymbol(circle) mcolor("27 158 119") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter log_total_fixed_assets log_total_employment_latest if strpos(data_export, "Mining") > 0, ///
        msymbol(diamond) mcolor("117 112 179") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter log_total_fixed_assets log_total_employment_latest if strpos(data_export, "Manufacturing") > 0, ///
        msymbol(square) mcolor("44 123 182") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter log_total_fixed_assets log_total_employment_latest if data_export == "Utilities", ///
        msymbol(triangle) mcolor("230 171 2") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter log_total_fixed_assets log_total_employment_latest if strpos(data_export, "Construction") > 0, ///
        msymbol(Oh) mcolor("208 28 139") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter log_total_fixed_assets log_total_employment_latest if strpos(data_export, "Wholesale") > 0, ///
        msymbol(Th) mcolor("217 95 2") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter log_total_fixed_assets log_total_employment_latest if strpos(data_export, "Transportation") > 0, ///
        msymbol(Sh) mcolor("102 166 30") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter log_total_fixed_assets log_total_employment_latest if strpos(data_export, "Information") > 0, ///
        msymbol(plus) mcolor("102 166 30") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter log_total_fixed_assets log_total_employment_latest if strpos(data_export, "Financial") > 0, ///
        msymbol(x) mcolor("117 112 179") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)) ///
    (scatter log_total_fixed_assets log_total_employment_latest if data_export == "Other services", ///
        msymbol(Dh) mcolor("102 102 102") mlabcolor(black) ///
        mlabel(nacam_label_short_display) mlabsize(tiny)), ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    ylabel(, grid glpattern(dash) glcolor(gs13)) ///
    xtitle("Log total employment") ///
    ytitle("Log total net fixed assets") ///
    title("BDF sector assets and employment scale", size(medsmall)) ///
    legend(order(1 "Agriculture" 2 "Mining" 3 "Manufacturing" 4 "Utilities" ///
        5 "Construction" 6 "Wholesale/retail + repair" 7 "Transport" 8 "ICT" ///
        9 "Finance" 10 "Other services") cols(1) pos(3) ring(1) size(tiny) ///
        region(lcolor(none) fcolor(none))) ///
    plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
    xsize(7.5) ysize(5.5)

graph export "${OUTPUTDIR}/figures/cmr_bdf_assets_vs_employment_by_nacam.pdf", replace
graph export "${OUTPUTDIR}/figures/cmr_bdf_assets_vs_employment_by_nacam.png", replace

display as result "Saved BDF asset diagnostics to `diagnostics_out'"

log close cmrbdfassets
