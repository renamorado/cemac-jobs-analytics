version 17.0
set more off

/*******************************************************************************
    Purpose:
        Estimate exploratory WBES employment/trade elasticities for slide use.

    Inputs:
        Data/Analysis/wbes_trade_clean.dta

    Outputs:
        Data/Analysis/cemac_wbes_trade_elasticity_estimates.dta
        output/tables/cemac_wbes_trade_elasticity_country.tex
        output/tables/cemac_wbes_trade_elasticity_cameroon_activity.tex
        output/figures/cemac_wbes_trade_elasticity_country_all_firms.{pdf,png}
        output/figures/cemac_wbes_trade_elasticity_country_exporters_only.{pdf,png}
        output/figures/cemac_wbes_trade_elasticity_cameroon_activity_all_firms.{pdf,png}
        output/figures/cemac_wbes_trade_elasticity_cameroon_activity_exporters_only.{pdf,png}
        logs/03_wbes_trade_elasticity.log

    Notes:
        These are weighted cross-sectional associations from latest-wave WBES
        data. They are not comparable to the Cameroon administrative panel's
        firm fixed-effect employment elasticities.
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
else if fileexists("AGENTS.md") {
    global project_root "`=subinstr(c(pwd), "\", "/", .)'"
}
else {
    display as error "No project_root path is configured for Windows user `c(username)'."
    display as error "Add this user to the bootstrap block in code/WBES_trade/03_wbes_trade_elasticity.do."
    exit 601
}

capture noisily cd "${project_root}"
if _rc | !fileexists("AGENTS.md") {
    display as error "Configured project_root is not a valid repo root: ${project_root}"
    exit 601
}

do "code/01_setup.do"

capture log close wbeselasticity
log using "${LOGDIR}/03_wbes_trade_elasticity.log", replace text name(wbeselasticity)

/*******************************************************************************
    Load cleaned WBES file and verify required variables
*******************************************************************************/
use "${DATADIR}/Analysis/wbes_trade_clean.dta", clear

foreach var in ///
    firm_id country_name cemac_country wb_region wb_income_group weight ///
    employment export_value export_status isic4_section {
    confirm variable `var'
}

assert !missing(weight)
assert weight > 0

generate byte retained_cemac = cemac_country == 1 & country_name != "Gabon"
generate byte ssa_excl_cemac = strpos(wb_region, "Sub-Saharan Africa") > 0 & cemac_country != 1
generate byte high_income = strpos(wb_income_group, "High income") > 0

generate str40 display_name = country_name
replace display_name = "Central Afr. Rep." if country_name == "Central African Republic"
replace display_name = "Eq. Guinea" if country_name == "Equatorial Guinea"

generate str36 activity_group = ""
replace activity_group = "Manufacturing" if isic4_section == "C"
replace activity_group = "Construction/utilities" if inlist(isic4_section, "E", "F")
replace activity_group = "Trade/hospitality/transport" if inlist(isic4_section, "G", "H", "I")
replace activity_group = "Other services" if inlist(isic4_section, "J", "K", "M", "N", "S")
replace activity_group = "Other/unclear activity" if missing(activity_group) | activity_group == ""

generate double ln_emp = ln(employment) if employment > 0
generate double ln_export_value = ln(export_value) if export_value > 0
generate double ln_export_value_all = .
replace ln_export_value_all = 0 if export_status == 0
replace ln_export_value_all = ln_export_value if export_status == 1 & !missing(ln_export_value)

generate byte all_firm_sample = !missing(ln_emp, ln_export_value_all, export_status, weight)
generate byte exporter_only_sample = !missing(ln_emp, ln_export_value, weight) & export_status == 1

label variable ln_emp "Log employment"
label variable ln_export_value "Log export value among exporters"
label variable ln_export_value_all "Log export value, zero for non-exporters"
label variable export_status "Exporter dummy"

keep if retained_cemac == 1 | ssa_excl_cemac == 1 | high_income == 1

local min_obs 30
local zcrit = invnormal(.975)

/*******************************************************************************
    Country-level estimates
*******************************************************************************/
tempfile country_estimates
tempname country_handle

postfile `country_handle' ///
    str24 panel str24 spec str80 spec_label str60 group_name str40 display_name ///
    byte retained_cemac byte ssa_excl_cemac byte high_income byte benchmark_row ///
    double elasticity se lb ub exporter_dummy exporter_dummy_se ///
    double n_unweighted n_exporters n_countries ///
    using "`country_estimates'", replace

levelsof country_name, local(country_list)

foreach country of local country_list {
    quietly count if country_name == "`country'" & all_firm_sample == 1
    local n_all = r(N)
    quietly count if country_name == "`country'" & all_firm_sample == 1 & export_status == 1
    local exporters_all = r(N)
    quietly count if country_name == "`country'" & all_firm_sample == 1 & export_status == 0
    local nonexporters_all = r(N)

    if `n_all' >= `min_obs' & `exporters_all' > 0 & `nonexporters_all' > 0 {
        capture quietly regress ln_emp ln_export_value_all export_status ///
            [pweight = weight] if country_name == "`country'" & all_firm_sample == 1, ///
            vce(robust)

        if !_rc {
            capture scalar b_trade = _b[ln_export_value_all]
            if !_rc & !missing(b_trade) {
                scalar se_trade = _se[ln_export_value_all]
                scalar lb_trade = b_trade - `zcrit' * se_trade
                scalar ub_trade = b_trade + `zcrit' * se_trade
                scalar b_exporter = _b[export_status]
                scalar se_exporter = _se[export_status]

                quietly summarize retained_cemac if country_name == "`country'", meanonly
                local retained = r(max)
                quietly summarize ssa_excl_cemac if country_name == "`country'", meanonly
                local ssa = r(max)
                quietly summarize high_income if country_name == "`country'", meanonly
                local hi = r(max)
                quietly levelsof display_name if country_name == "`country'", local(display_local) clean

                post `country_handle' ///
                    ("country") ("all_firms") ("All firms, exporter dummy") ///
                    ("`country'") ("`display_local'") ///
                    (`retained') (`ssa') (`hi') (0) ///
                    (b_trade) (se_trade) (lb_trade) (ub_trade) ///
                    (b_exporter) (se_exporter) ///
                    (`n_all') (`exporters_all') (1)
            }
        }
    }

    quietly count if country_name == "`country'" & exporter_only_sample == 1
    local n_exporter = r(N)

    if `n_exporter' >= `min_obs' {
        capture quietly regress ln_emp ln_export_value ///
            [pweight = weight] if country_name == "`country'" & exporter_only_sample == 1, ///
            vce(robust)

        if !_rc {
            capture scalar b_trade = _b[ln_export_value]
            if !_rc & !missing(b_trade) {
                scalar se_trade = _se[ln_export_value]
                scalar lb_trade = b_trade - `zcrit' * se_trade
                scalar ub_trade = b_trade + `zcrit' * se_trade

                quietly summarize retained_cemac if country_name == "`country'", meanonly
                local retained = r(max)
                quietly summarize ssa_excl_cemac if country_name == "`country'", meanonly
                local ssa = r(max)
                quietly summarize high_income if country_name == "`country'", meanonly
                local hi = r(max)
                quietly levelsof display_name if country_name == "`country'", local(display_local) clean

                post `country_handle' ///
                    ("country") ("exporters_only") ("Exporters only") ///
                    ("`country'") ("`display_local'") ///
                    (`retained') (`ssa') (`hi') (0) ///
                    (b_trade) (se_trade) (lb_trade) (ub_trade) ///
                    (.) (.) (`n_exporter') (`n_exporter') (1)
            }
        }
    }
}

postclose `country_handle'

/*******************************************************************************
    Cameroon activity-group estimates
*******************************************************************************/
tempfile activity_estimates
tempname activity_handle

postfile `activity_handle' ///
    str24 panel str24 spec str80 spec_label str60 group_name str40 display_name ///
    byte retained_cemac byte ssa_excl_cemac byte high_income byte benchmark_row ///
    double elasticity se lb ub exporter_dummy exporter_dummy_se ///
    double n_unweighted n_exporters n_countries ///
    using "`activity_estimates'", replace

levelsof activity_group if country_name == "Cameroon", local(activity_list)

foreach activity of local activity_list {
    quietly count if country_name == "Cameroon" & activity_group == "`activity'" & all_firm_sample == 1
    local n_all = r(N)
    quietly count if country_name == "Cameroon" & activity_group == "`activity'" & all_firm_sample == 1 & export_status == 1
    local exporters_all = r(N)
    quietly count if country_name == "Cameroon" & activity_group == "`activity'" & all_firm_sample == 1 & export_status == 0
    local nonexporters_all = r(N)

    if `n_all' >= `min_obs' & `exporters_all' > 0 & `nonexporters_all' > 0 {
        capture quietly regress ln_emp ln_export_value_all export_status ///
            [pweight = weight] if country_name == "Cameroon" ///
            & activity_group == "`activity'" & all_firm_sample == 1, ///
            vce(robust)

        if !_rc {
            capture scalar b_trade = _b[ln_export_value_all]
            if !_rc & !missing(b_trade) {
                scalar se_trade = _se[ln_export_value_all]
                scalar lb_trade = b_trade - `zcrit' * se_trade
                scalar ub_trade = b_trade + `zcrit' * se_trade
                scalar b_exporter = _b[export_status]
                scalar se_exporter = _se[export_status]

                post `activity_handle' ///
                    ("cameroon_activity") ("all_firms") ("All firms, exporter dummy") ///
                    ("`activity'") ("`activity'") ///
                    (1) (0) (0) (0) ///
                    (b_trade) (se_trade) (lb_trade) (ub_trade) ///
                    (b_exporter) (se_exporter) ///
                    (`n_all') (`exporters_all') (1)
            }
        }
    }

    quietly count if country_name == "Cameroon" & activity_group == "`activity'" & exporter_only_sample == 1
    local n_exporter = r(N)

    if `n_exporter' >= `min_obs' {
        capture quietly regress ln_emp ln_export_value ///
            [pweight = weight] if country_name == "Cameroon" ///
            & activity_group == "`activity'" & exporter_only_sample == 1, ///
            vce(robust)

        if !_rc {
            capture scalar b_trade = _b[ln_export_value]
            if !_rc & !missing(b_trade) {
                scalar se_trade = _se[ln_export_value]
                scalar lb_trade = b_trade - `zcrit' * se_trade
                scalar ub_trade = b_trade + `zcrit' * se_trade

                post `activity_handle' ///
                    ("cameroon_activity") ("exporters_only") ("Exporters only") ///
                    ("`activity'") ("`activity'") ///
                    (1) (0) (0) (0) ///
                    (b_trade) (se_trade) (lb_trade) (ub_trade) ///
                    (.) (.) (`n_exporter') (`n_exporter') (1)
            }
        }
    }
}

postclose `activity_handle'

/*******************************************************************************
    Add equal-country benchmark rows
*******************************************************************************/
use "`country_estimates'", clear
tempfile base_country_estimates benchmark_estimates
save "`base_country_estimates'", replace

tempname benchmark_handle
postfile `benchmark_handle' ///
    str24 panel str24 spec str80 spec_label str60 group_name str40 display_name ///
    byte retained_cemac byte ssa_excl_cemac byte high_income byte benchmark_row ///
    double elasticity se lb ub exporter_dummy exporter_dummy_se ///
    double n_unweighted n_exporters n_countries ///
    using "`benchmark_estimates'", replace

foreach spec in all_firms exporters_only {
    foreach benchmark in cemac ssa_excl_cemac high_income {
        use "`base_country_estimates'", clear

        if "`benchmark'" == "cemac" {
            keep if spec == "`spec'" & retained_cemac == 1
            local benchmark_name "CEMAC average"
        }
        else if "`benchmark'" == "ssa_excl_cemac" {
            keep if spec == "`spec'" & ssa_excl_cemac == 1
            local benchmark_name "SSA excl. CEMAC"
        }
        else if "`benchmark'" == "high_income" {
            keep if spec == "`spec'" & high_income == 1
            local benchmark_name "High income"
        }

        quietly count
        local n_countries = r(N)

        if `n_countries' >= 2 {
            quietly summarize elasticity, meanonly
            local elasticity = r(mean)
            quietly summarize elasticity
            local se = r(sd) / sqrt(`n_countries')
            local lb = `elasticity' - `zcrit' * `se'
            local ub = `elasticity' + `zcrit' * `se'
            quietly summarize n_unweighted, meanonly
            local n_unweighted = r(sum)
            quietly summarize n_exporters, meanonly
            local n_exporters = r(sum)
            quietly levelsof spec_label, local(spec_label_local) clean

            post `benchmark_handle' ///
                ("country") ("`spec'") ("`spec_label_local'") ///
                ("`benchmark_name'") ("`benchmark_name'") ///
                (0) (0) (0) (1) ///
                (`elasticity') (`se') (`lb') (`ub') ///
                (.) (.) (`n_unweighted') (`n_exporters') (`n_countries')
        }
    }
}

postclose `benchmark_handle'

use "`base_country_estimates'", clear
append using "`benchmark_estimates'"
append using "`activity_estimates'"

label variable panel "Estimate panel"
label variable spec "WBES cross-sectional specification"
label variable elasticity "Employment/export-value elasticity"
label variable se "Robust standard error"
label variable lb "Lower 95 percent interval"
label variable ub "Upper 95 percent interval"
label variable exporter_dummy "Exporter dummy coefficient in all-firm model"
label variable exporter_dummy_se "Exporter dummy robust standard error"
label variable n_unweighted "Unweighted observations"
label variable n_exporters "Unweighted exporters"
label variable n_countries "Countries represented"

save "${DATADIR}/Analysis/cemac_wbes_trade_elasticity_estimates.dta", replace

/*******************************************************************************
    Country table
*******************************************************************************/
preserve
    keep if panel == "country" & (retained_cemac == 1 | benchmark_row == 1)
    keep panel spec group_name display_name benchmark_row elasticity se n_unweighted n_exporters n_countries

    tempfile country_table_base all_firms
    save "`country_table_base'", replace

    keep if spec == "all_firms"
    rename elasticity all_elasticity
    rename se all_se
    rename n_unweighted all_n
    rename n_exporters all_exporters
    keep group_name display_name benchmark_row n_countries all_elasticity all_se all_n all_exporters
    save "`all_firms'", replace

    use "`country_table_base'", clear
    keep if spec == "exporters_only"
    rename elasticity exporters_elasticity
    rename se exporters_se
    rename n_unweighted exporters_n
    keep group_name exporters_elasticity exporters_se exporters_n
    merge 1:1 group_name using "`all_firms'", nogen

    gsort benchmark_row display_name
    replace display_name = group_name if missing(display_name)
    generate str16 rowname = "row_" + string(_n)

    mkmat all_elasticity all_se all_n all_exporters exporters_elasticity exporters_se exporters_n n_countries, ///
        matrix(country_table) rownames(rowname)
    matrix colnames country_table = AllElasticity AllSE AllN AllExporters ExporterElasticity ExporterSE ExporterN Countries

    local country_rowlabels
    quietly count
    local country_n = r(N)
    forvalues i = 1/`country_n' {
        local label = subinstr(display_name[`i'], "&", "\&", .)
        local country_rowlabels `country_rowlabels' `=rowname[`i']' "`label'"
    }

    esttab matrix(country_table, fmt(%9.3f %9.3f %9.0fc %9.0fc %9.3f %9.3f %9.0fc %9.0fc)) ///
        using "${OUTPUTDIR}/tables/cemac_wbes_trade_elasticity_country.tex", ///
        replace booktabs fragment nomtitles nonumbers ///
        collabels("All-firm slope" "SE" "N" "Exporters" "Exporter-only slope" "SE" "N" "Countries") ///
        varlabels(`country_rowlabels')
restore

/*******************************************************************************
    Cameroon activity table
*******************************************************************************/
preserve
    keep if panel == "cameroon_activity"
    keep spec group_name display_name elasticity se n_unweighted n_exporters

    tempfile activity_table_base activity_all
    save "`activity_table_base'", replace

    keep if spec == "all_firms"
    rename elasticity all_elasticity
    rename se all_se
    rename n_unweighted all_n
    rename n_exporters all_exporters
    keep group_name display_name all_elasticity all_se all_n all_exporters
    save "`activity_all'", replace

    use "`activity_table_base'", clear
    keep if spec == "exporters_only"
    rename elasticity exporters_elasticity
    rename se exporters_se
    rename n_unweighted exporters_n
    keep group_name exporters_elasticity exporters_se exporters_n
    merge 1:1 group_name using "`activity_all'", nogen

    sort display_name
    replace display_name = group_name if missing(display_name)
    generate str16 rowname = "row_" + string(_n)

    mkmat all_elasticity all_se all_n all_exporters exporters_elasticity exporters_se exporters_n, ///
        matrix(activity_table) rownames(rowname)
    matrix colnames activity_table = AllElasticity AllSE AllN AllExporters ExporterElasticity ExporterSE ExporterN

    local activity_rowlabels
    quietly count
    local activity_n = r(N)
    forvalues i = 1/`activity_n' {
        local label = subinstr(display_name[`i'], "&", "\&", .)
        local activity_rowlabels `activity_rowlabels' `=rowname[`i']' "`label'"
    }

    esttab matrix(activity_table, fmt(%9.3f %9.3f %9.0fc %9.0fc %9.3f %9.3f %9.0fc)) ///
        using "${OUTPUTDIR}/tables/cemac_wbes_trade_elasticity_cameroon_activity.tex", ///
        replace booktabs fragment nomtitles nonumbers ///
        collabels("All-firm slope" "SE" "N" "Exporters" "Exporter-only slope" "SE" "N") ///
        varlabels(`activity_rowlabels')
restore

/*******************************************************************************
    Dot-and-interval plots
*******************************************************************************/
local plot_note "Weighted WBES cross-section. Points show log employment/log export-value associations; rows with N<30 suppressed."

foreach panel in country cameroon_activity {
    foreach spec in all_firms exporters_only {
        preserve
            if "`panel'" == "country" {
                keep if panel == "country" & spec == "`spec'" & (retained_cemac == 1 | benchmark_row == 1)
                local output_panel "country"
                if "`spec'" == "all_firms" {
                    local title "WBES country trade-employment association: all firms"
                }
                else {
                    local title "WBES country trade-employment association: exporters only"
                }
            }
            else {
                keep if panel == "cameroon_activity" & spec == "`spec'"
                local output_panel "cameroon_activity"
                if "`spec'" == "all_firms" {
                    local title "Cameroon WBES activity associations: all firms"
                }
                else {
                    local title "Cameroon WBES activity associations: exporters only"
                }
            }

            drop if missing(elasticity, lb, ub)
            quietly count
            if r(N) == 0 {
                restore
                continue
            }

            gsort elasticity display_name
            generate int plot_order = _n
            quietly count
            local plot_n = r(N)

            capture label drop elasticity_plot_labels
            forvalues i = 1/`plot_n' {
                local label = display_name[`i']
                label define elasticity_plot_labels `i' "`label'", add
            }
            label values plot_order elasticity_plot_labels

            twoway ///
                (rcap lb ub plot_order if benchmark_row == 0, ///
                    horizontal lcolor("86 180 233") lwidth(medthin)) ///
                (scatter plot_order elasticity if benchmark_row == 0, ///
                    msymbol(circle) mcolor("0 114 178") msize(medium)) ///
                (rcap lb ub plot_order if benchmark_row == 1, ///
                    horizontal lcolor("230 159 0") lwidth(medthin)) ///
                (scatter plot_order elasticity if benchmark_row == 1, ///
                    msymbol(diamond) mcolor("213 94 0") msize(medium)), ///
                ylabel(1(1)`plot_n', valuelabel angle(0) labsize(small) nogrid) ///
                xlabel(, grid glpattern(dash) glcolor(gs13)) ///
                xline(0, lpattern(dash) lcolor(black)) ///
                xtitle("Employment/export-value elasticity", size(small)) ///
                ytitle("") ///
                title("`title'", size(medsmall)) ///
                legend(order(2 "Country or activity" 4 "Benchmark") rows(1) pos(6) ///
                    size(small) region(lcolor(none) fcolor(none))) ///
                note("`plot_note'", size(vsmall)) ///
                plotregion(color(white)) graphregion(color(white)) ///
                bgcolor(white) xsize(7.5) ysize(4.8)

            graph export "${OUTPUTDIR}/figures/cemac_wbes_trade_elasticity_`output_panel'_`spec'.pdf", replace
            graph export "${OUTPUTDIR}/figures/cemac_wbes_trade_elasticity_`output_panel'_`spec'.png", replace
        restore
    }
}

display as result "Exported WBES trade elasticity outputs to ${OUTPUTDIR}."

log close wbeselasticity
