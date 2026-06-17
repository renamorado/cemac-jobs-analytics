version 17.0
set more off

/*******************************************************************************
    Purpose:
        Estimate whether weighted WBES employment-revenue associations differ
        between exporters and non-exporters.

    Inputs:
        Data/Analysis/wbes_trade_clean.dta

    Outputs:
        Data/Analysis/cemac_wbes_revenue_exporter_interaction_estimates.dta
        output/tables/cemac_wbes_revenue_exporter_interaction_country.tex
        output/tables/cemac_wbes_revenue_exporter_interaction_cameroon_activity.tex
        output/tables/cemac_wbes_revenue_exporter_interaction_sample_audit.tex
        output/figures/cemac_wbes_revenue_exporter_interaction_country.{pdf,png}
        output/figures/cemac_wbes_revenue_exporter_interaction_cameroon_activity.{pdf,png}
        logs/04_wbes_revenue_exporter_interaction.log

    Notes:
        The unit of observation is a latest-wave WBES firm. Results are
        weighted cross-sectional associations, not causal effects or panel
        fixed-effect elasticities. The focal estimate is the exporter minus
        non-exporter difference in the log revenue slope. Specifications
        control for log firm age, foreign ownership share, and government/state
        ownership share, and include ISIC Rev.4 section fixed effects.
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
    display as error "Add this user to the bootstrap block in code/WBES_trade/04_wbes_revenue_exporter_interaction.do."
    exit 601
}

capture noisily cd "${project_root}"
if _rc | !fileexists("AGENTS.md") {
    display as error "Configured project_root is not a valid repo root: ${project_root}"
    exit 601
}

do "code/01_setup.do"

capture log close wbesrevenueinteraction
log using "${LOGDIR}/04_wbes_revenue_exporter_interaction.log", ///
    replace text name(wbesrevenueinteraction)

/*******************************************************************************
    Load cleaned WBES file and define the common sample
*******************************************************************************/
confirm file "${DATADIR}/Analysis/wbes_trade_clean.dta"
use "${DATADIR}/Analysis/wbes_trade_clean.dta", clear

foreach var in ///
    firm_id country_name cemac_country wb_region wb_income_group weight ///
    employment sales_w export_status isic4_section ///
    ln_firm_age foreign_own_share gov_own_share {
    confirm variable `var'
}

assert !missing(weight)
assert weight > 0
assert inlist(export_status, 0, 1) if !missing(export_status)

generate byte retained_cemac = cemac_country == 1 & country_name != "Gabon"
generate byte ssa_excl_cemac = ///
    strpos(wb_region, "Sub-Saharan Africa") > 0 & cemac_country != 1
generate byte high_income = strpos(wb_income_group, "High income") > 0

generate str40 display_name = country_name
replace display_name = "Central Afr. Rep." ///
    if country_name == "Central African Republic"
replace display_name = "Eq. Guinea" if country_name == "Equatorial Guinea"

generate str36 activity_group = ""
replace activity_group = "Manufacturing" if isic4_section == "C"
replace activity_group = "Construction/utilities" ///
    if inlist(isic4_section, "E", "F")
replace activity_group = "Trade/hospitality/transport" ///
    if inlist(isic4_section, "G", "H", "I")
replace activity_group = "Other services" ///
    if inlist(isic4_section, "J", "K", "M", "N", "S")
replace activity_group = "Other/unclear activity" ///
    if missing(activity_group) | activity_group == ""

generate str16 isic4_section_fe_label = isic4_section
replace isic4_section_fe_label = "Unknown" if isic4_section_fe_label == ""
encode isic4_section_fe_label, generate(isic4_section_fe)
label variable isic4_section_fe "ISIC Rev.4 section fixed effect"

generate double ln_emp = ln(employment) if employment > 0
generate double ln_revenue = ln(sales_w) if sales_w > 0
generate byte interaction_sample = ///
    !missing(ln_emp, ln_revenue, export_status, weight, ln_firm_age, ///
        foreign_own_share, gov_own_share)

label variable ln_emp "Log employment"
label variable ln_revenue "Log winsorized annual sales"
label variable export_status "Firm exports directly or indirectly"
label variable interaction_sample "Usable controlled revenue-exporter interaction sample"

keep if retained_cemac == 1 | ssa_excl_cemac == 1 | high_income == 1

local min_total 30
local min_group 10
local zcrit = invnormal(.975)
local firm_controls ///
    c.ln_firm_age c.foreign_own_share c.gov_own_share i.isic4_section_fe

/*******************************************************************************
    Estimate country-level models and retain every attempted country
*******************************************************************************/
tempfile country_estimates
tempname country_handle

postfile `country_handle' ///
    str24 panel str60 group_name str40 display_name ///
    byte retained_cemac byte ssa_excl_cemac byte high_income ///
    byte benchmark_row byte eligible_support byte estimated ///
    str48 suppression_reason ///
    double nonexporter_slope nonexporter_se nonexporter_lb nonexporter_ub ///
    double exporter_slope exporter_se exporter_lb exporter_ub ///
    double slope_difference difference_se difference_lb difference_ub difference_p ///
    double n_total n_exporters n_nonexporters n_countries ///
    using "`country_estimates'", replace

levelsof country_name, local(country_list)

foreach country of local country_list {
    quietly count if country_name == "`country'" & interaction_sample == 1
    local n_total = r(N)
    quietly count if country_name == "`country'" & interaction_sample == 1 ///
        & export_status == 1
    local n_exporters = r(N)
    quietly count if country_name == "`country'" & interaction_sample == 1 ///
        & export_status == 0
    local n_nonexporters = r(N)

    quietly summarize retained_cemac if country_name == "`country'", meanonly
    local retained = r(max)
    quietly summarize ssa_excl_cemac if country_name == "`country'", meanonly
    local ssa = r(max)
    quietly summarize high_income if country_name == "`country'", meanonly
    local hi = r(max)
    quietly levelsof display_name if country_name == "`country'", ///
        local(display_local) clean

    local eligible_support = ///
        `n_total' >= `min_total' & `n_exporters' >= `min_group' ///
        & `n_nonexporters' >= `min_group'
    local estimated = 0
    local reason "Below support rule"

    scalar nonexporter_b = .
    scalar nonexporter_se = .
    scalar nonexporter_lb = .
    scalar nonexporter_ub = .
    scalar exporter_b = .
    scalar exporter_se = .
    scalar exporter_lb = .
    scalar exporter_ub = .
    scalar difference_b = .
    scalar difference_se = .
    scalar difference_lb = .
    scalar difference_ub = .
    scalar difference_p = .

    if `eligible_support' {
        local reason "Regression failed"
        capture quietly regress ln_emp c.ln_revenue##ib0.export_status ///
            `firm_controls' ///
            [pweight = weight] if country_name == "`country'" ///
            & interaction_sample == 1, vce(robust)

        if !_rc {
            capture quietly lincom ln_revenue
            if !_rc {
                scalar nonexporter_b = r(estimate)
                scalar nonexporter_se = r(se)
                scalar nonexporter_lb = r(lb)
                scalar nonexporter_ub = r(ub)

                quietly lincom ln_revenue + ///
                    1.export_status#c.ln_revenue
                scalar exporter_b = r(estimate)
                scalar exporter_se = r(se)
                scalar exporter_lb = r(lb)
                scalar exporter_ub = r(ub)

                quietly lincom 1.export_status#c.ln_revenue
                scalar difference_b = r(estimate)
                scalar difference_se = r(se)
                scalar difference_lb = r(lb)
                scalar difference_ub = r(ub)
                scalar difference_p = r(p)

                local estimated = 1
                local reason ""
            }
        }
    }

    post `country_handle' ///
        ("country") ("`country'") ("`display_local'") ///
        (`retained') (`ssa') (`hi') (0) ///
        (`eligible_support') (`estimated') ("`reason'") ///
        (nonexporter_b) (nonexporter_se) (nonexporter_lb) (nonexporter_ub) ///
        (exporter_b) (exporter_se) (exporter_lb) (exporter_ub) ///
        (difference_b) (difference_se) (difference_lb) (difference_ub) ///
        (difference_p) ///
        (`n_total') (`n_exporters') (`n_nonexporters') (1)
}

postclose `country_handle'

/*******************************************************************************
    Estimate Cameroon activity-group models and retain every attempted group
*******************************************************************************/
tempfile activity_estimates
tempname activity_handle

postfile `activity_handle' ///
    str24 panel str60 group_name str40 display_name ///
    byte retained_cemac byte ssa_excl_cemac byte high_income ///
    byte benchmark_row byte eligible_support byte estimated ///
    str48 suppression_reason ///
    double nonexporter_slope nonexporter_se nonexporter_lb nonexporter_ub ///
    double exporter_slope exporter_se exporter_lb exporter_ub ///
    double slope_difference difference_se difference_lb difference_ub difference_p ///
    double n_total n_exporters n_nonexporters n_countries ///
    using "`activity_estimates'", replace

levelsof activity_group if country_name == "Cameroon", local(activity_list)

foreach activity of local activity_list {
    quietly count if country_name == "Cameroon" ///
        & activity_group == "`activity'" & interaction_sample == 1
    local n_total = r(N)
    quietly count if country_name == "Cameroon" ///
        & activity_group == "`activity'" & interaction_sample == 1 ///
        & export_status == 1
    local n_exporters = r(N)
    quietly count if country_name == "Cameroon" ///
        & activity_group == "`activity'" & interaction_sample == 1 ///
        & export_status == 0
    local n_nonexporters = r(N)

    local eligible_support = ///
        `n_total' >= `min_total' & `n_exporters' >= `min_group' ///
        & `n_nonexporters' >= `min_group'
    local estimated = 0
    local reason "Below support rule"

    scalar nonexporter_b = .
    scalar nonexporter_se = .
    scalar nonexporter_lb = .
    scalar nonexporter_ub = .
    scalar exporter_b = .
    scalar exporter_se = .
    scalar exporter_lb = .
    scalar exporter_ub = .
    scalar difference_b = .
    scalar difference_se = .
    scalar difference_lb = .
    scalar difference_ub = .
    scalar difference_p = .

    if `eligible_support' {
        local reason "Regression failed"
        capture quietly regress ln_emp c.ln_revenue##ib0.export_status ///
            `firm_controls' ///
            [pweight = weight] if country_name == "Cameroon" ///
            & activity_group == "`activity'" & interaction_sample == 1, ///
            vce(robust)

        if !_rc {
            capture quietly lincom ln_revenue
            if !_rc {
                scalar nonexporter_b = r(estimate)
                scalar nonexporter_se = r(se)
                scalar nonexporter_lb = r(lb)
                scalar nonexporter_ub = r(ub)

                quietly lincom ln_revenue + ///
                    1.export_status#c.ln_revenue
                scalar exporter_b = r(estimate)
                scalar exporter_se = r(se)
                scalar exporter_lb = r(lb)
                scalar exporter_ub = r(ub)

                quietly lincom 1.export_status#c.ln_revenue
                scalar difference_b = r(estimate)
                scalar difference_se = r(se)
                scalar difference_lb = r(lb)
                scalar difference_ub = r(ub)
                scalar difference_p = r(p)

                local estimated = 1
                local reason ""
            }
        }
    }

    post `activity_handle' ///
        ("cameroon_activity") ("`activity'") ("`activity'") ///
        (1) (0) (0) (0) ///
        (`eligible_support') (`estimated') ("`reason'") ///
        (nonexporter_b) (nonexporter_se) (nonexporter_lb) (nonexporter_ub) ///
        (exporter_b) (exporter_se) (exporter_lb) (exporter_ub) ///
        (difference_b) (difference_se) (difference_lb) (difference_ub) ///
        (difference_p) ///
        (`n_total') (`n_exporters') (`n_nonexporters') (1)
}

postclose `activity_handle'

/*******************************************************************************
    Construct equal-country benchmark rows from eligible country estimates
*******************************************************************************/
use "`country_estimates'", clear
tempfile benchmark_estimates
tempname benchmark_handle

postfile `benchmark_handle' ///
    str24 panel str60 group_name str40 display_name ///
    byte retained_cemac byte ssa_excl_cemac byte high_income ///
    byte benchmark_row byte eligible_support byte estimated ///
    str48 suppression_reason ///
    double nonexporter_slope nonexporter_se nonexporter_lb nonexporter_ub ///
    double exporter_slope exporter_se exporter_lb exporter_ub ///
    double slope_difference difference_se difference_lb difference_ub difference_p ///
    double n_total n_exporters n_nonexporters n_countries ///
    using "`benchmark_estimates'", replace

foreach benchmark in cemac ssa_excl_cemac high_income {
    use "`country_estimates'", clear

    if "`benchmark'" == "cemac" {
        keep if retained_cemac == 1 & estimated == 1
        local benchmark_name "CEMAC average"
    }
    else if "`benchmark'" == "ssa_excl_cemac" {
        keep if ssa_excl_cemac == 1 & estimated == 1
        local benchmark_name "SSA excl. CEMAC"
    }
    else if "`benchmark'" == "high_income" {
        keep if high_income == 1 & estimated == 1
        local benchmark_name "High income"
    }

    quietly count
    local n_countries = r(N)
    local benchmark_eligible = `n_countries' >= 2
    local benchmark_estimated = 0
    local reason "Fewer than two eligible countries"

    scalar bench_nonexporter_b = .
    scalar bench_nonexporter_se = .
    scalar bench_nonexporter_lb = .
    scalar bench_nonexporter_ub = .
    scalar bench_exporter_b = .
    scalar bench_exporter_se = .
    scalar bench_exporter_lb = .
    scalar bench_exporter_ub = .
    scalar bench_difference_b = .
    scalar bench_difference_se = .
    scalar bench_difference_lb = .
    scalar bench_difference_ub = .
    scalar bench_difference_p = .
    local n_total = 0
    local n_exporters = 0
    local n_nonexporters = 0

    if `benchmark_eligible' {
        quietly summarize nonexporter_slope
        scalar bench_nonexporter_b = r(mean)
        scalar bench_nonexporter_se = r(sd) / sqrt(`n_countries')
        scalar bench_nonexporter_lb = ///
            bench_nonexporter_b - `zcrit' * bench_nonexporter_se
        scalar bench_nonexporter_ub = ///
            bench_nonexporter_b + `zcrit' * bench_nonexporter_se

        quietly summarize exporter_slope
        scalar bench_exporter_b = r(mean)
        scalar bench_exporter_se = r(sd) / sqrt(`n_countries')
        scalar bench_exporter_lb = ///
            bench_exporter_b - `zcrit' * bench_exporter_se
        scalar bench_exporter_ub = ///
            bench_exporter_b + `zcrit' * bench_exporter_se

        quietly summarize slope_difference
        scalar bench_difference_b = r(mean)
        scalar bench_difference_se = r(sd) / sqrt(`n_countries')
        scalar bench_difference_lb = ///
            bench_difference_b - `zcrit' * bench_difference_se
        scalar bench_difference_ub = ///
            bench_difference_b + `zcrit' * bench_difference_se
        if bench_difference_se > 0 {
            scalar bench_difference_p = ///
                2 * normal(-abs(bench_difference_b / bench_difference_se))
        }
        else if bench_difference_se == 0 & bench_difference_b != 0 {
            scalar bench_difference_p = 0
        }
        else if bench_difference_se == 0 & bench_difference_b == 0 {
            scalar bench_difference_p = 1
        }

        quietly summarize n_total, meanonly
        local n_total = r(sum)
        quietly summarize n_exporters, meanonly
        local n_exporters = r(sum)
        quietly summarize n_nonexporters, meanonly
        local n_nonexporters = r(sum)

        local benchmark_estimated = 1
        local reason ""
    }

    post `benchmark_handle' ///
        ("country") ("`benchmark_name'") ("`benchmark_name'") ///
        (0) (0) (0) (1) ///
        (`benchmark_eligible') (`benchmark_estimated') ("`reason'") ///
        (bench_nonexporter_b) (bench_nonexporter_se) ///
        (bench_nonexporter_lb) (bench_nonexporter_ub) ///
        (bench_exporter_b) (bench_exporter_se) ///
        (bench_exporter_lb) (bench_exporter_ub) ///
        (bench_difference_b) (bench_difference_se) ///
        (bench_difference_lb) (bench_difference_ub) ///
        (bench_difference_p) ///
        (`n_total') (`n_exporters') (`n_nonexporters') (`n_countries')
}

postclose `benchmark_handle'

/*******************************************************************************
    Combine results, validate estimates, and save the analysis dataset
*******************************************************************************/
use "`country_estimates'", clear
append using "`benchmark_estimates'"
append using "`activity_estimates'"

generate byte displayed_candidate = ///
    (panel == "country" & (retained_cemac == 1 | benchmark_row == 1)) ///
    | panel == "cameroon_activity"

assert estimated == 0 if eligible_support == 0
assert n_total == n_exporters + n_nonexporters if benchmark_row == 0
assert n_total >= `min_total' & n_exporters >= `min_group' ///
    & n_nonexporters >= `min_group' if estimated == 1 & benchmark_row == 0
assert !missing(nonexporter_slope, nonexporter_se, nonexporter_lb, ///
    nonexporter_ub, exporter_slope, exporter_se, exporter_lb, exporter_ub, ///
    slope_difference, difference_se, difference_lb, difference_ub, ///
    difference_p, n_total, n_exporters, n_nonexporters) if estimated == 1
assert abs(exporter_slope - nonexporter_slope - slope_difference) < 1e-8 ///
    if estimated == 1
assert inrange(difference_p, 0, 1) if estimated == 1

label variable panel "Estimate panel"
label variable group_name "Country or Cameroon activity group"
label variable eligible_support "Meets minimum sample support rule"
label variable estimated "Regression estimated successfully"
label variable suppression_reason "Reason estimate was not produced"
label variable nonexporter_slope "Non-exporter employment-revenue elasticity"
label variable exporter_slope "Exporter employment-revenue elasticity"
label variable slope_difference "Exporter minus non-exporter elasticity"
label variable difference_p "P-value for exporter slope difference"
label variable n_total "Unweighted usable observations"
label variable n_exporters "Unweighted exporters"
label variable n_nonexporters "Unweighted non-exporters"
label variable n_countries "Countries represented"

sort panel benchmark_row group_name
save "${DATADIR}/Analysis/cemac_wbes_revenue_exporter_interaction_estimates.dta", ///
    replace

/*******************************************************************************
    Export country and Cameroon activity result tables
*******************************************************************************/
foreach table_panel in country cameroon_activity {
    preserve
        if "`table_panel'" == "country" {
            keep if panel == "country" & displayed_candidate == 1 & estimated == 1
            local table_file "cemac_wbes_revenue_exporter_interaction_country.tex"
        }
        else {
            keep if panel == "cameroon_activity" & estimated == 1
            local table_file "cemac_wbes_revenue_exporter_interaction_cameroon_activity.tex"
        }

        gsort benchmark_row display_name
        generate str16 rowname = "row_" + string(_n)

        mkmat nonexporter_slope exporter_slope slope_difference difference_se ///
            difference_lb difference_ub difference_p ///
            n_total n_exporters n_nonexporters, ///
            matrix(interaction_table) rownames(rowname)
        matrix colnames interaction_table = NonExporter Exporter Difference ///
            DifferenceSE Lower95 Upper95 PValue N Exporters NonExporters

        local table_rowlabels
        quietly count
        local table_n = r(N)
        forvalues i = 1/`table_n' {
            local label = subinstr(display_name[`i'], "&", "\&", .)
            local table_rowlabels `table_rowlabels' `=rowname[`i']' "`label'"
        }

        esttab matrix(interaction_table, ///
            fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %9.3f %9.3f ///
                %9.0fc %9.0fc %9.0fc)) ///
            using "${OUTPUTDIR}/tables/`table_file'", ///
            replace booktabs fragment nomtitles nonumbers ///
            collabels("Non-exporter" "Exporter" "Difference" "SE" ///
                "Lower 95" "Upper 95" "P-value" "N" "Exporters" ///
                "Non-exporters") ///
            varlabels(`table_rowlabels')
    restore
}

/*******************************************************************************
    Export sample-support audit for every candidate display row
*******************************************************************************/
preserve
    keep if displayed_candidate == 1
    gsort panel benchmark_row display_name

    generate double support_rule = eligible_support
    generate double estimated_result = estimated
    generate str16 rowname = "row_" + string(_n)

    mkmat n_total n_exporters n_nonexporters support_rule estimated_result, ///
        matrix(audit_table) rownames(rowname)
    matrix colnames audit_table = Total Exporters NonExporters SupportRule Estimated

    local audit_rowlabels
    quietly count
    local audit_n = r(N)
    forvalues i = 1/`audit_n' {
        local prefix "Country: "
        if panel[`i'] == "cameroon_activity" {
            local prefix "Cameroon activity: "
        }
        if benchmark_row[`i'] == 1 {
            local prefix "Benchmark: "
        }
        local label = "`prefix'" + display_name[`i']
        local label = subinstr("`label'", "&", "\&", .)
        local audit_rowlabels `audit_rowlabels' `=rowname[`i']' "`label'"
    }

    esttab matrix(audit_table, fmt(%9.0fc %9.0fc %9.0fc %9.0fc %9.0fc)) ///
        using "${OUTPUTDIR}/tables/cemac_wbes_revenue_exporter_interaction_sample_audit.tex", ///
        replace booktabs fragment nomtitles nonumbers ///
        collabels("Total" "Exporters" "Non-exporters" "Support rule" "Estimated") ///
        varlabels(`audit_rowlabels')
restore

/*******************************************************************************
    Plot implied group slopes and the focal exporter slope difference
*******************************************************************************/
local plot_note ///
    "Weighted WBES cross-section. Controls: firm age, ownership shares, and ISIC section FE."

foreach plot_panel in country cameroon_activity {
    preserve
        if "`plot_panel'" == "country" {
            keep if panel == "country" & displayed_candidate == 1 & estimated == 1
            local plot_title "WBES employment response to revenue by exporter status"
            local output_file "cemac_wbes_revenue_exporter_interaction_country"
            local legend_rows 2
        }
        else {
            keep if panel == "cameroon_activity" & estimated == 1
            local plot_title "Cameroon WBES activity responses to revenue"
            local output_file "cemac_wbes_revenue_exporter_interaction_cameroon_activity"
            local legend_rows 3
        }

        quietly count
        if r(N) == 0 {
            restore
            continue
        }

        gsort slope_difference display_name
        generate int plot_order = _n
        generate double y_nonexporter = plot_order - 0.22
        generate double y_exporter = plot_order
        generate double y_difference = plot_order + 0.22

        quietly count
        local plot_n = r(N)
        capture label drop interaction_plot_labels
        forvalues i = 1/`plot_n' {
            local label = display_name[`i']
            label define interaction_plot_labels `i' "`label'", add
        }
        label values plot_order interaction_plot_labels
        label values y_nonexporter interaction_plot_labels
        label values y_exporter interaction_plot_labels
        label values y_difference interaction_plot_labels

        twoway ///
            (rcap nonexporter_lb nonexporter_ub y_nonexporter, ///
                horizontal lcolor("86 180 233") lwidth(thin)) ///
            (scatter y_nonexporter nonexporter_slope, ///
                msymbol(circle) mcolor("0 114 178") msize(small)) ///
            (rcap exporter_lb exporter_ub y_exporter, ///
                horizontal lcolor("0 158 115") lwidth(thin)) ///
            (scatter y_exporter exporter_slope, ///
                msymbol(triangle) mcolor("0 158 115") msize(small)) ///
            (rcap difference_lb difference_ub y_difference, ///
                horizontal lcolor("213 94 0") lwidth(medthick)) ///
            (scatter y_difference slope_difference, ///
                msymbol(diamond) mcolor("213 94 0") msize(medium)), ///
            ylabel(1(1)`plot_n', valuelabel angle(0) labsize(small) nogrid) ///
            xlabel(, grid glpattern(dash) glcolor(gs13)) ///
            xline(0, lpattern(dash) lcolor(black)) ///
            xtitle("Estimated employment response to revenue or group difference", size(small)) ///
            ytitle("") ///
            title("`plot_title'", size(medsmall)) ///
            legend(order(2 "Employment response to revenue: non-exporters" ///
                4 "Employment response to revenue: exporters" ///
                6 "Exporter-non-exporter difference") rows(`legend_rows') pos(6) ///
                size(small) region(lcolor(none) fcolor(none))) ///
            note("`plot_note'", size(vsmall)) ///
            plotregion(color(white)) graphregion(color(white)) ///
            bgcolor(white) xsize(8.5) ysize(5.2)

        graph export "${OUTPUTDIR}/figures/`output_file'.pdf", replace
        graph export "${OUTPUTDIR}/figures/`output_file'.png", replace
    restore
}

display as result "Exported WBES revenue-exporter interaction outputs to ${OUTPUTDIR}."

log close wbesrevenueinteraction
