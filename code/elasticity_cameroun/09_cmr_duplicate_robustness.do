version 17.0
set more off

/*******************************************************************************
    Purpose:
        Estimate a duplicate-inclusive robustness check for the Cameroon NACAM
        employment elasticities and compare it with the baseline cleaned panel.

    Inputs:
        Data/Cameroon/Clean/CMR_BDF.dta
        Data/Analysis/CMR_BDF_cleaned.dta
        Data/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta
        Data/Intermediate/cmr_nacam_data_export_mapping.dta

    Outputs:
        Data/Analysis/CMR_BDF_duplicate_robustness.dta
        output/tables/cmr_nacam_results_duplicate_robustness_va_elasticity.tex
        output/tables/cmr_nacam_results_duplicate_robustness_tot_rev_elasticity.tex
        output/figures/cmr_nacam_results_duplicate_robustness_comparison.pdf
        output/figures/cmr_nacam_results_duplicate_robustness_comparison.png
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
        display as error "Add this user to the bootstrap block in code/elasticity_cameroun/09_cmr_duplicate_robustness.do."
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

capture log close cmrduprobust
capture log using "${LOGDIR}/09_cmr_duplicate_robustness_`log_stamp'.log", text name(cmrduprobust)
if _rc {
    sleep `sleep_ms'
    capture log using "${LOGDIR}/09_cmr_duplicate_robustness_`log_stamp'.log", text name(cmrduprobust)
}
if _rc {
    display as error "Unable to open the duplicate-robustness log after retry."
    error _rc
}

local min_sector_obs 30
local min_sector_firms 10
local output_stub "cmr_nacam_results_duplicate_robustness"

capture program drop cmr_add_data_export_group
program define cmr_add_data_export_group
    version 17.0

    capture confirm variable data_export
    if !_rc {
        exit
    }

    generate str80 data_export = ""

    replace data_export = "A - Agriculture, Forestry and Fishing" if ///
        inlist(nacam, 1, 2, 3, 5)
    replace data_export = "B - Mining and Quarrying" if inlist(nacam, 6, 7)
    replace data_export = "C - Manufacturing" if ///
        inlist(nacam, 8, 9, 10, 11, 12, 13, 15, 16, 17) | ///
        inlist(nacam, 18, 19, 20, 21, 22, 23, 24, 27) | ///
        nacam == 28
    replace data_export = "Utilities" if nacam == 29
    replace data_export = "F - Construction" if nacam == 30
    replace data_export = "G - Wholesale and Retail Trade; Repair of Motor Vehicles" if ///
        inlist(nacam, 31, 32)
    replace data_export = "H - Transportation and Storage" if nacam == 34
    replace data_export = "J - Information and Communication" if nacam == 35
    replace data_export = "K - Financial and Insurance Activities" if nacam == 36
    replace data_export = "Other services" if ///
        inlist(nacam, 33, 37, 38, 40, 41, 42)

    assert !missing(data_export) if !missing(nacam)
end

/*******************************************************************************
    1. Build duplicate-inclusive robustness panel
*******************************************************************************/

confirm file "${CAMEROONDIR}/Clean/CMR_BDF.dta"
use "${CAMEROONDIR}/Clean/CMR_BDF.dta", clear

ds, has(type string)
local string_vars `r(varlist)'
local id_string_vars firmid
local numeric_string_vars : list string_vars - id_string_vars

foreach var of local numeric_string_vars {
    replace `var' = ustrtrim(`var')
    replace `var' = subinstr(`var', char(13), "", .)
    replace `var' = subinstr(`var', char(10), "", .)
    replace `var' = subinstr(`var', char(9), "", .)
    replace `var' = subinstr(`var', char(160), "", .)
    replace `var' = subinstr(`var', " ", "", .)
    replace `var' = "" if inlist(upper(`var'), "", "NA", "-")
    replace `var' = substr(`var', 1, length(`var') - 1) if regexm(`var', "^[0-9.]+-$")
    destring `var', replace ignore(",") force
}

ds, has(type string)
local remaining_string_vars `r(varlist)'
local unexpected_string_vars : list remaining_string_vars - id_string_vars

if "`unexpected_string_vars'" != "" {
    display as error "Unexpected string variables remain after numeric destringing: `unexpected_string_vars'"
    error 459
}

quietly count
local robustness_observations = r(N)

gen long original_order = _n
clonevar firmid_original = firmid

sort firmid fin_yr original_order
by firmid fin_yr: gen long firmyear_n = _N
by firmid fin_yr: gen int firmyear_dup_seq = _n
egen byte tag_firmyear = tag(firmid fin_yr)

ds original_order firmyear_n firmyear_dup_seq tag_firmyear firmid_original, not
local original_vars `r(varlist)'

sort `original_vars'
by `original_vars': gen byte tag_full_record = _n == 1
sort firmid fin_yr original_order
by firmid fin_yr: egen long distinct_record_profiles = total(tag_full_record)

gen byte duplicate_class = 0 if firmyear_n == 1
replace duplicate_class = 1 if firmyear_n > 1 & distinct_record_profiles == 1
replace duplicate_class = 2 if firmyear_n > 1 & distinct_record_profiles > 1
label define duplicate_class 0 "Unique firm-year" 1 "Perfect duplicate" 2 "Conflicting duplicate", replace
label values duplicate_class duplicate_class

egen long firmyear_robust_id = group(firmid_original fin_yr firmyear_dup_seq)
isid firmyear_robust_id

quietly count if tag_firmyear & duplicate_class == 2
local conflicting_dup_groups = r(N)
quietly count if duplicate_class == 2
local conflicting_dup_observations = r(N)

display as text "Duplicate-inclusive robustness panel keeps all source rows."
display as result "Robustness observations: `robustness_observations'"
display as result "Conflicting duplicate firm-years retained: `conflicting_dup_groups'"
display as result "Rows in retained conflicting duplicate groups: `conflicting_dup_observations'"

confirm file "${DATADIR}/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta"
merge m:1 nacam using "${DATADIR}/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta", ///
    keep(master match) keepusing(nacam_label nacam_label_en nacam_label_short_en)
assert _merge == 3 if !missing(nacam)
drop _merge
assert !missing(nacam_label, nacam_label_en, nacam_label_short_en) if !missing(nacam)

cmr_add_data_export_group

generate str180 nacam_label_display = ""
replace nacam_label_display = nacam_label_en if !missing(nacam)
assert !missing(nacam_label_display) if !missing(nacam)

generate str60 nacam_label_short_display = ""
replace nacam_label_short_display = nacam_label_short_en if !missing(nacam)
assert !missing(nacam_label_short_display) if !missing(nacam)

label variable firmid_original "Original firm identifier"
label variable firmyear_dup_seq "Sequence within original firm-year"
label variable firmyear_robust_id "Duplicate-inclusive firm-year identifier"
label variable duplicate_class "Firm-year duplicate class"

drop original_order firmyear_n tag_firmyear tag_full_record distinct_record_profiles

capture save "${DATADIR}/Analysis/CMR_BDF_duplicate_robustness.dta", replace
if _rc {
    sleep `sleep_ms'
    capture save "${DATADIR}/Analysis/CMR_BDF_duplicate_robustness.dta", replace
}
if _rc {
    display as error "Unable to save duplicate-robustness panel after retry."
    error _rc
}

/*******************************************************************************
    2. Define reusable elasticity estimator
*******************************************************************************/

capture program drop cmr_dup_robust_estimate
program define cmr_dup_robust_estimate
    version 17.0
    syntax using/, Resultfile(string) [Tableprefix(string)]

    use "`using'", clear

    local idvar firmid
    capture confirm variable firmid_original
    if !_rc {
        local idvar firmid_original
    }

    capture confirm variable data_export
    if _rc {
        cmr_add_data_export_group
    }

    keep `idvar' fin_yr nacam nacam_label_display nacam_label_short_display ///
        data_export totemp va tot_rev

    tempfile sector_labels sector_counts va_results tot_rev_results va_table_data

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

    encode `idvar', generate(firm_fe)

    capture confirm numeric variable totemp
    if !_rc {
        generate double employment = totemp
    }
    else {
        destring totemp, generate(employment) ignore(",")
    }

    generate double ln_emp = .
    replace ln_emp = ln(employment) if employment > 0

    generate double ln_va = .
    replace ln_va = ln(va) if va > 0

    generate double ln_tot_rev = .
    replace ln_tot_rev = ln(tot_rev) if tot_rev > 0

    generate byte sample_va = employment > 0 & va > 0 & !missing(firm_fe, fin_yr, nacam)
    generate byte sample_tot_rev = employment > 0 & tot_rev > 0 & !missing(firm_fe, fin_yr, nacam)

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

    generate byte include_sector = va_obs >= $cmr_dup_min_sector_obs ///
        & va_firms >= $cmr_dup_min_sector_firms ///
        & tot_rev_obs >= $cmr_dup_min_sector_obs ///
        & tot_rev_firms >= $cmr_dup_min_sector_firms

    save "`sector_counts'"
    restore

    merge m:1 nacam using "`sector_counts'", nogen

    areg ln_emp c.ln_va##i.nacam i.nacam#i.fin_yr ///
        if sample_va == 1 & include_sector == 1, ///
        absorb(firm_fe) vce(cluster firm_fe)

    tempname va_handle
    postfile `va_handle' int nacam double va_elasticity va_se va_lb va_ub ///
        using "`va_results'", replace

    levelsof nacam if sample_va == 1 & include_sector == 1, local(va_codes)
    local va_base : word 1 of `va_codes'

    foreach code of local va_codes {
        if `code' == `va_base' {
            lincom _b[ln_va]
        }
        else {
            lincom _b[ln_va] + _b[`code'.nacam#c.ln_va]
        }

        post `va_handle' (`code') (r(estimate)) (r(se)) (r(lb)) (r(ub))
    }

    postclose `va_handle'

    areg ln_emp c.ln_tot_rev##i.nacam i.nacam#i.fin_yr ///
        if sample_tot_rev == 1 & include_sector == 1, ///
        absorb(firm_fe) vce(cluster firm_fe)

    tempname tot_rev_handle
    postfile `tot_rev_handle' int nacam double tot_rev_elasticity ///
        tot_rev_se tot_rev_lb tot_rev_ub using "`tot_rev_results'", replace

    levelsof nacam if sample_tot_rev == 1 & include_sector == 1, local(tot_rev_codes)
    local tot_rev_base : word 1 of `tot_rev_codes'

    foreach code of local tot_rev_codes {
        if `code' == `tot_rev_base' {
            lincom _b[ln_tot_rev]
        }
        else {
            lincom _b[ln_tot_rev] + _b[`code'.nacam#c.ln_tot_rev]
        }

        post `tot_rev_handle' (`code') (r(estimate)) (r(se)) (r(lb)) (r(ub))
    }

    postclose `tot_rev_handle'

    use "`va_results'", clear
    merge 1:1 nacam using "`sector_counts'", nogen keep(match)
    merge m:1 nacam using "`sector_labels'", nogen keep(match)
    keep if include_sector == 1
    sort nacam
    assert !missing(nacam_label_display)
    assert !missing(nacam_label_short_display)

    if "`tableprefix'" != "" {
        generate str16 rowname = "nacam_" + string(nacam)
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
            using "${OUTPUTDIR}/tables/`tableprefix'_va_elasticity.tex", ///
            replace booktabs fragment nomtitles nonumbers ///
            varlabels(`va_rowlabels')
    }

    keep nacam nacam_label_display nacam_label_short_display data_export ///
        va_elasticity va_se va_lb va_ub va_firms va_obs include_sector
    save "`va_table_data'"

    use "`tot_rev_results'", clear
    merge 1:1 nacam using "`sector_counts'", nogen keep(match)
    merge m:1 nacam using "`sector_labels'", nogen keep(match)
    keep if include_sector == 1
    sort nacam
    assert !missing(nacam_label_display)
    assert !missing(nacam_label_short_display)

    if "`tableprefix'" != "" {
        generate str16 rowname = "nacam_" + string(nacam)
        mkmat tot_rev_elasticity tot_rev_se tot_rev_lb tot_rev_ub ///
            tot_rev_firms tot_rev_obs, matrix(tot_rev_table) rownames(rowname)
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
            using "${OUTPUTDIR}/tables/`tableprefix'_tot_rev_elasticity.tex", ///
            replace booktabs fragment nomtitles nonumbers ///
            varlabels(`tot_rev_rowlabels')
    }

    merge 1:1 nacam using "`va_table_data'", nogen
    merge m:1 nacam using "`sector_labels'", nogen keep(match)
    keep nacam nacam_label_display nacam_label_short_display data_export ///
        va_elasticity va_se va_lb va_ub va_firms va_obs ///
        tot_rev_elasticity tot_rev_se tot_rev_lb tot_rev_ub ///
        tot_rev_firms tot_rev_obs

    save "`resultfile'", replace
end

global cmr_dup_min_sector_obs `min_sector_obs'
global cmr_dup_min_sector_firms `min_sector_firms'

tempfile baseline_results robustness_results

cmr_dup_robust_estimate using "${DATADIR}/Analysis/CMR_BDF_cleaned.dta", ///
    resultfile("`baseline_results'")

cmr_dup_robust_estimate using "${DATADIR}/Analysis/CMR_BDF_duplicate_robustness.dta", ///
    resultfile("`robustness_results'") tableprefix("`output_stub'")

/*******************************************************************************
    3. Build paired baseline-vs-robustness comparison plot
*******************************************************************************/

use "`baseline_results'", clear
rename va_elasticity baseline_va_elasticity
rename va_se baseline_va_se
rename va_lb baseline_va_lb
rename va_ub baseline_va_ub
rename va_firms baseline_va_firms
rename va_obs baseline_va_obs
rename tot_rev_elasticity baseline_tot_rev_elasticity
rename tot_rev_se baseline_tot_rev_se
rename tot_rev_lb baseline_tot_rev_lb
rename tot_rev_ub baseline_tot_rev_ub
rename tot_rev_firms baseline_tot_rev_firms
rename tot_rev_obs baseline_tot_rev_obs

merge 1:1 nacam using "`robustness_results'", keep(match) nogen
rename va_elasticity robustness_va_elasticity
rename va_se robustness_va_se
rename va_lb robustness_va_lb
rename va_ub robustness_va_ub
rename va_firms robustness_va_firms
rename va_obs robustness_va_obs
rename tot_rev_elasticity robustness_tot_rev_elasticity
rename tot_rev_se robustness_tot_rev_se
rename tot_rev_lb robustness_tot_rev_lb
rename tot_rev_ub robustness_tot_rev_ub
rename tot_rev_firms robustness_tot_rev_firms
rename tot_rev_obs robustness_tot_rev_obs

assert !missing(baseline_va_elasticity, robustness_va_elasticity)
assert !missing(baseline_tot_rev_elasticity, robustness_tot_rev_elasticity)

gsort -baseline_tot_rev_elasticity nacam
generate int plot_order = _n

capture label drop nacam_duplicate_robustness_plot
quietly count
local plot_n = r(N)

forvalues i = 1/`plot_n' {
    local sector_label = subinstr(nacam_label_short_display[`i'], char(34), "'", .)

    if `i' == 1 {
        label define nacam_duplicate_robustness_plot `i' `"`sector_label'"'
    }
    else {
        label define nacam_duplicate_robustness_plot `i' `"`sector_label'"', modify
    }
}

label values plot_order nacam_duplicate_robustness_plot

twoway ///
    (pcspike plot_order baseline_va_elasticity plot_order robustness_va_elasticity, ///
        lcolor(gs12) lwidth(thin)) ///
    (scatter plot_order baseline_va_elasticity, ///
        msymbol(Oh) mcolor(gs8) msize(small)) ///
    (scatter plot_order robustness_va_elasticity, ///
        msymbol(O) mcolor("44 123 182") msize(small)), ///
    ylabel(1(1)`plot_n', valuelabel angle(0) labsize(tiny) nogrid) ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    yscale(reverse) ///
    xline(0, lpattern(dash) lcolor(black)) ///
    legend(order(2 "Baseline" 3 "Duplicate-inclusive") rows(1) pos(6) ///
        size(vsmall) region(lcolor(none) fcolor(none))) ///
    ytitle("") ///
    xtitle("Employment elasticity", size(small)) ///
    title("Value added", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    bgcolor(white) name(dup_robust_va, replace)

twoway ///
    (pcspike plot_order baseline_tot_rev_elasticity plot_order robustness_tot_rev_elasticity, ///
        lcolor(gs12) lwidth(thin)) ///
    (scatter plot_order baseline_tot_rev_elasticity, ///
        msymbol(Oh) mcolor(gs8) msize(small)) ///
    (scatter plot_order robustness_tot_rev_elasticity, ///
        msymbol(O) mcolor("44 123 182") msize(small)), ///
    ylabel(1(1)`plot_n', valuelabel angle(0) labsize(tiny) nogrid) ///
    xlabel(, grid glpattern(dash) glcolor(gs13)) ///
    yscale(reverse) ///
    xline(0, lpattern(dash) lcolor(black)) ///
    legend(order(2 "Baseline" 3 "Duplicate-inclusive") rows(1) pos(6) ///
        size(vsmall) region(lcolor(none) fcolor(none))) ///
    ytitle("") ///
    xtitle("Employment elasticity", size(small)) ///
    title("Total revenue", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    bgcolor(white) name(dup_robust_tot_rev, replace)

graph combine dup_robust_va dup_robust_tot_rev, ///
    rows(1) xsize(11) ysize(5.8) graphregion(color(white)) ///
    title("Baseline vs duplicate-inclusive employment elasticities", size(medsmall)) ///
    name(dup_robust_comparison, replace)
graph display dup_robust_comparison

graph export "${OUTPUTDIR}/figures/`output_stub'_comparison.pdf", replace
graph export "${OUTPUTDIR}/figures/`output_stub'_comparison.png", replace

display as result "Duplicate robustness comparison exported to ${OUTPUTDIR}/figures/`output_stub'_comparison.*"

log close cmrduprobust
