version 18.0
set more off

/*******************************************************************************
    Purpose:
        Provide a standalone Cameroon Phase II trade-analysis scaffold that lays
        out the intended export, import, GVC, and elasticity workflow using the
        cleaned firm-year panel.

    Inputs:
        Data/Analysis/CMR_BDF_cleaned.dta

    Planned outputs once the trade sections are activated:
        output/tables/cmr_trade_template_revenue_decomposition.tex
        output/tables/cmr_trade_template_extensive_margin.tex
        output/tables/cmr_trade_template_intensive_margin.tex
        output/tables/cmr_trade_template_gvc_shares.tex
        output/tables/cmr_trade_template_trade_elasticities.tex
        output/figures/cmr_trade_template_revenue_decomposition.pdf
        output/figures/cmr_trade_template_revenue_decomposition.png
        output/figures/cmr_trade_template_extensive_margin.pdf
        output/figures/cmr_trade_template_extensive_margin.png
        output/figures/cmr_trade_template_intensive_margin.pdf
        output/figures/cmr_trade_template_intensive_margin.png
        output/figures/cmr_trade_template_gvc_shares.pdf
        output/figures/cmr_trade_template_gvc_shares.png

    Notes:
        This file is a planning scaffold for the cleaned Cameroon analysis data.
        Replace the trade-variable placeholders below with the actual names used
        in Data/Analysis/CMR_BDF_cleaned.dta, then run the file.
*******************************************************************************/

/*******************************************************************************
    Bootstrap repository paths
*******************************************************************************/
local project_root = subinstr(c(pwd), "\\", "/", .)

if !fileexists("`project_root'/AGENTS.md") {
    if fileexists("`project_root'/../../AGENTS.md") {
        local project_root "`project_root'/../.."
    }
}

capture noisily cd "`project_root'"
if _rc | !fileexists("AGENTS.md") {
    display as error "Run code/03_analysis/02_cmr_trade_analysis_template.do from the repo root or from code/03_analysis."
    exit 601
}

do "code/01_setup.do"

/*******************************************************************************
    Shared output stub
*******************************************************************************/
local output_stub "cmr_trade_template"
local min_group_obs 30
local min_group_firms 10

/*******************************************************************************
    Load the cleaned analysis panel
*******************************************************************************/
use "${DATADIR}/Analysis/CMR_BDF_cleaned.dta", clear

/*******************************************************************************
    Trade-variable standardization
    - Replace the placeholder source names below with the actual cleaned-data
      variable names.
    - If your cleaned data already use the standardized names on the right-hand
      side, skip this block.
*******************************************************************************/
rename replace_with_cleaned_export_status_var export_status
rename replace_with_cleaned_export_value_var export_value
rename replace_with_cleaned_domestic_sales_var domestic_sales
rename replace_with_cleaned_local_sales_var local_sales
rename replace_with_cleaned_import_status_var import_status
rename replace_with_cleaned_import_value_var import_value

/*******************************************************************************
    Build labels and core variables for later sections
*******************************************************************************/
quietly summarize fin_yr, meanonly
local latest_year = r(max)

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

capture confirm string variable firmid
if !_rc {
    encode firmid, generate(firm_fe)
}
else {
    generate long firm_fe = firmid
}

tempfile sector_labels
preserve
    keep nacam nacam_label_short_display
    drop if missing(nacam)
    bysort nacam (nacam_label_short_display): assert nacam_label_short_display == nacam_label_short_display[1]
    by nacam: keep if _n == 1
    isid nacam
    save "`sector_labels'"
restore

/*******************************************************************************
    1. Revenue decomposition
    - Goal: split total revenue into domestic and export components once the
      cleaned-data trade variables have been mapped.
*******************************************************************************/
preserve
    keep nacam fin_yr nacam_label_short_display tot_rev domestic_sales export_value
    collapse (sum) tot_rev domestic_sales export_value, ///
        by(nacam nacam_label_short_display fin_yr)

    generate double export_share = export_value / tot_rev if tot_rev > 0
    generate double domestic_share = domestic_sales / tot_rev if tot_rev > 0

    preserve
        * Build a latest-year table for slides showing domestic and export revenue shares by sector.
        keep if fin_yr == `latest_year'
        gsort -export_share nacam
        generate str16 rowname = "sector_" + string(_n)

        mkmat domestic_share export_share tot_rev, ///
            matrix(revenue_decomp_table) rownames(rowname)
        matrix colnames revenue_decomp_table = DomesticShare ExportShare TotalRevenue

        local revenue_rowlabels
        quietly count
        local revenue_n = r(N)
        forvalues i = 1/`revenue_n' {
            local label = subinstr(nacam_label_short_display[`i'], "&", "\\&", .)
            local revenue_rowlabels `revenue_rowlabels' `=rowname[`i']' "`label'"
        }

        esttab matrix(revenue_decomp_table, fmt(%9.3f %9.3f %9.0fc)) ///
            using "output/tables/`output_stub'_revenue_decomposition.tex", ///
            replace booktabs fragment nomtitles nonumbers ///
            varlabels(`revenue_rowlabels')
    restore

    * Export a latest-year stacked figure showing the composition of revenue by sector.
    graph bar (asis) domestic_share export_share if fin_yr == `latest_year', ///
        over(nacam_label_short_display, sort(export_share) descending label(angle(45) labsize(vsmall))) ///
        stack legend(order(1 "Domestic sales share" 2 "Export sales share") rows(2)) ///
        ytitle("Share of total revenue") ///
        title("Revenue composition by sector, `latest_year'")

    graph export "output/figures/`output_stub'_revenue_decomposition.pdf", replace
    graph export "output/figures/`output_stub'_revenue_decomposition.png", replace
restore

/*******************************************************************************
    2. Extensive margin
    - Goal: measure the share of firms by sector-year that export.
*******************************************************************************/
preserve
    keep firmid fin_yr nacam nacam_label_short_display export_status export_value

    generate byte exporter = .
    replace exporter = export_status if !missing(export_status)
    replace exporter = export_value > 0 if missing(exporter) & !missing(export_value)

    egen tag_firm_year = tag(firmid fin_yr)
    keep if tag_firm_year == 1

    collapse (mean) exporter (count) n_firms = exporter, ///
        by(nacam nacam_label_short_display fin_yr)
    rename exporter exporter_share

    preserve
        * Build a latest-year table ranking sectors by the exporter share of firms.
        keep if fin_yr == `latest_year'
        gsort -exporter_share nacam
        generate str16 rowname = "sector_" + string(_n)

        mkmat exporter_share n_firms, matrix(extensive_margin_table) rownames(rowname)
        matrix colnames extensive_margin_table = ExporterShare Firms

        local extensive_rowlabels
        quietly count
        local extensive_n = r(N)
        forvalues i = 1/`extensive_n' {
            local label = subinstr(nacam_label_short_display[`i'], "&", "\\&", .)
            local extensive_rowlabels `extensive_rowlabels' `=rowname[`i']' "`label'"
        }

        esttab matrix(extensive_margin_table, fmt(%9.3f %9.0fc)) ///
            using "output/tables/`output_stub'_extensive_margin.tex", ///
            replace booktabs fragment nomtitles nonumbers ///
            varlabels(`extensive_rowlabels')
    restore

    * Export a latest-year figure comparing exporter shares across sectors.
    graph hbar (asis) exporter_share if fin_yr == `latest_year', ///
        over(nacam_label_short_display, sort(1) descending label(labsize(vsmall))) ///
        ytitle("Exporter share") ///
        title("Extensive export margin by sector, `latest_year'")

    graph export "output/figures/`output_stub'_extensive_margin.pdf", replace
    graph export "output/figures/`output_stub'_extensive_margin.png", replace
restore

/*******************************************************************************
    3. Intensive margin
    - Goal: measure export intensity among exporters.
*******************************************************************************/
preserve
    keep nacam fin_yr nacam_label_short_display export_status export_value tot_rev

    generate byte exporter = .
    replace exporter = export_status if !missing(export_status)
    replace exporter = export_value > 0 if missing(exporter) & !missing(export_value)
    generate double export_share = export_value / tot_rev if tot_rev > 0 & !missing(export_value)

    keep if exporter == 1
    collapse (mean) export_share (count) n_exporters = export_share, ///
        by(nacam nacam_label_short_display fin_yr)

    preserve
        * Build a latest-year table ranking sectors by export intensity among exporters.
        keep if fin_yr == `latest_year'
        gsort -export_share nacam
        generate str16 rowname = "sector_" + string(_n)

        mkmat export_share n_exporters, matrix(intensive_margin_table) rownames(rowname)
        matrix colnames intensive_margin_table = ExportShare Exporters

        local intensive_rowlabels
        quietly count
        local intensive_n = r(N)
        forvalues i = 1/`intensive_n' {
            local label = subinstr(nacam_label_short_display[`i'], "&", "\\&", .)
            local intensive_rowlabels `intensive_rowlabels' `=rowname[`i']' "`label'"
        }

        esttab matrix(intensive_margin_table, fmt(%9.3f %9.0fc)) ///
            using "output/tables/`output_stub'_intensive_margin.tex", ///
            replace booktabs fragment nomtitles nonumbers ///
            varlabels(`intensive_rowlabels')
    restore

    * Export a latest-year figure comparing export intensity across sectors.
    graph hbar (asis) export_share if fin_yr == `latest_year', ///
        over(nacam_label_short_display, sort(1) descending label(labsize(vsmall))) ///
        ytitle("Mean export share among exporters") ///
        title("Intensive export margin by sector, `latest_year'")

    graph export "output/figures/`output_stub'_intensive_margin.pdf", replace
    graph export "output/figures/`output_stub'_intensive_margin.png", replace
restore

/*******************************************************************************
    4. GVC status
    - Goal: classify firms into local only, importer only, exporter only, and
      two-way trader categories.
*******************************************************************************/
preserve
*Here we keep and standardize the trade variables needed to assign firms to GVC participation categories.
    keep nacam fin_yr nacam_label_short_display tot_rev export_status export_value import_status import_value

    generate byte exporter = .
    generate byte importer = .
    replace exporter = export_status if !missing(export_status)
    replace exporter = export_value > 0 if missing(exporter) & !missing(export_value)
    replace importer = import_status if !missing(import_status)
    replace importer = import_value > 0 if missing(importer) & !missing(import_value)

    generate byte positive_sales = tot_rev > 0 if !missing(tot_rev)
    generate byte gvc_local_only = positive_sales == 1 & exporter == 0 & importer == 0 if !missing(positive_sales, exporter, importer)
    generate byte gvc_import_only = positive_sales == 1 & exporter == 0 & importer == 1 if !missing(positive_sales, exporter, importer)
    generate byte gvc_export_only = positive_sales == 1 & exporter == 1 & importer == 0 if !missing(positive_sales, exporter, importer)
    generate byte gvc_two_way = positive_sales == 1 & exporter == 1 & importer == 1 if !missing(positive_sales, exporter, importer)

    *collapse to the sector-year level to get the share of firms in each GVC participation category.
    collapse (mean) gvc_local_only gvc_import_only gvc_export_only gvc_two_way, ///
        by(nacam nacam_label_short_display fin_yr)

    preserve
        * Build a latest-year table showing the sector mix of GVC participation categories.
        keep if fin_yr == `latest_year'
        gsort -gvc_two_way nacam
        generate str16 rowname = "sector_" + string(_n)

        mkmat gvc_local_only gvc_import_only gvc_export_only gvc_two_way, ///
            matrix(gvc_table) rownames(rowname)
        matrix colnames gvc_table = LocalOnly ImportOnly ExportOnly TwoWay

        local gvc_rowlabels
        quietly count
        local gvc_n = r(N)
        forvalues i = 1/`gvc_n' {
            local label = subinstr(nacam_label_short_display[`i'], "&", "\\&", .)
            local gvc_rowlabels `gvc_rowlabels' `=rowname[`i']' "`label'"
        }

        esttab matrix(gvc_table, fmt(%9.3f %9.3f %9.3f %9.3f)) ///
            using "output/tables/`output_stub'_gvc_shares.tex", ///
            replace booktabs fragment nomtitles nonumbers ///
            varlabels(`gvc_rowlabels')
    restore

    * Export a latest-year stacked figure comparing GVC participation patterns across sectors.
    graph bar (asis) gvc_local_only gvc_import_only gvc_export_only gvc_two_way if fin_yr == `latest_year', ///
        over(nacam_label_short_display, sort(gvc_two_way) descending label(angle(45) labsize(vsmall))) ///
        stack legend(order(1 "Local only" 2 "Importer only" 3 "Exporter only" 4 "Two-way trader") rows(2)) ///
        ytitle("Share of firms") ///
        title("GVC participation by sector, `latest_year'")

    graph export "output/figures/`output_stub'_gvc_shares.pdf", replace
    graph export "output/figures/`output_stub'_gvc_shares.png", replace
restore

/*******************************************************************************
    5. Employment elasticity by trade group
    - Goal: rerun the employment elasticity exercise within trade categories.
*******************************************************************************/
* Post sector-specific employment elasticities by trade group, then export one compact summary table.
tempfile trade_elasticity_results
tempname trade_elasticity_handle
postfile `trade_elasticity_handle' str16 trade_group int nacam ///
    double elasticity se group_obs group_firms using "`trade_elasticity_results'", replace

preserve
    * Keep only the variables needed to assign trade groups and estimate the
    * sector-specific employment elasticities within each group.
    keep firmid firm_fe fin_yr nacam ln_emp ln_tot_rev tot_rev ///
        nacam_label_short_display export_status export_value import_status import_value

    * Standardize exporter and importer indicators so every downstream block uses
    * one consistent binary definition for each trade margin.
    generate byte exporter = .
    generate byte importer = .
    replace exporter = export_status if !missing(export_status)
    replace exporter = export_value > 0 if missing(exporter) & !missing(export_value)
    replace importer = import_status if !missing(import_status)
    replace importer = import_value > 0 if missing(importer) & !missing(import_value)

    * Assign each firm-year to one mutually exclusive trade category before the
    * elasticity exercise is rerun within each subgroup.
    generate byte positive_sales = tot_rev > 0 if !missing(tot_rev)
    generate byte gvc_local_only = positive_sales == 1 & exporter == 0 & importer == 0 if !missing(positive_sales, exporter, importer)
    generate byte gvc_import_only = positive_sales == 1 & exporter == 0 & importer == 1 if !missing(positive_sales, exporter, importer)
    generate byte gvc_export_only = positive_sales == 1 & exporter == 1 & importer == 0 if !missing(positive_sales, exporter, importer)
    generate byte gvc_two_way = positive_sales == 1 & exporter == 1 & importer == 1 if !missing(positive_sales, exporter, importer)

    foreach trade_group in local_only import_only export_only two_way {
        preserve
            * Restrict to one trade group at a time and keep only sectors with
            * enough observations and firms to support a stable estimate.
            keep if gvc_`trade_group' == 1
            generate byte sample_tot_rev = !missing(ln_emp, ln_tot_rev, firm_fe, fin_yr, nacam)

            egen tag_group_firm = tag(nacam firm_fe) if sample_tot_rev == 1
            by nacam, sort: egen group_obs = total(sample_tot_rev)
            by nacam: egen group_firms = total(tag_group_firm)

            keep if sample_tot_rev == 1
            keep if group_obs >= `min_group_obs' & group_firms >= `min_group_firms'

            quietly count
            if r(N) == 0 {
                restore
                continue
            }

            * Reuse the same interacted revenue specification as the main NACAM
            * analysis, but estimate it separately within the current trade group.
            areg ln_emp c.ln_tot_rev##i.nacam i.nacam#i.fin_yr, ///
                absorb(firm_fe) vce(cluster firm_fe)

            * Recover the implied sector elasticity for the current trade group
            * and post it to the final summary table.
            levelsof nacam, local(trade_codes)
            local trade_base : word 1 of `trade_codes'

            foreach code of local trade_codes {
                if `code' == `trade_base' {
                    lincom _b[ln_tot_rev]
                }
                else {
                    lincom _b[ln_tot_rev] + _b[`code'.nacam#c.ln_tot_rev]
                }

                quietly summarize group_obs if nacam == `code', meanonly
                local code_obs = r(max)
                quietly summarize group_firms if nacam == `code', meanonly
                local code_firms = r(max)

                post `trade_elasticity_handle' ("`trade_group'") (`code') ///
                    (r(estimate)) (r(se)) (`code_obs') (`code_firms')
            }
        restore
    }
restore

postclose `trade_elasticity_handle'

use "`trade_elasticity_results'", clear
merge m:1 nacam using "`sector_labels'", nogen keep(match)

generate str120 trade_sector_label = ""
replace trade_sector_label = "Local only: " + nacam_label_short_display if trade_group == "local_only"
replace trade_sector_label = "Importer only: " + nacam_label_short_display if trade_group == "import_only"
replace trade_sector_label = "Exporter only: " + nacam_label_short_display if trade_group == "export_only"
replace trade_sector_label = "Two-way trader: " + nacam_label_short_display if trade_group == "two_way"

generate str16 rowname = "trade_" + string(_n)
replace trade_sector_label = subinstr(trade_sector_label, "&", "\\&", .)

mkmat elasticity se group_obs group_firms, ///
    matrix(trade_elasticity_table) rownames(rowname)
matrix colnames trade_elasticity_table = Elasticity StdErr Obs Firms

local trade_rowlabels
quietly count
local trade_n = r(N)
forvalues i = 1/`trade_n' {
    local label = trade_sector_label[`i']
    local trade_rowlabels `trade_rowlabels' `=rowname[`i']' "`label'"
}

esttab matrix(trade_elasticity_table, fmt(%9.3f %9.3f %9.0fc %9.0fc)) ///
    using "output/tables/`output_stub'_trade_elasticities.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels(`trade_rowlabels')

/*******************************************************************************
    6. Slide-feed checklist
*******************************************************************************/
* Planned slide-feed outputs:
*   - output/tables/`output_stub'_revenue_decomposition.tex
*   - output/tables/`output_stub'_extensive_margin.tex
*   - output/tables/`output_stub'_intensive_margin.tex
*   - output/tables/`output_stub'_gvc_shares.tex
*   - output/tables/`output_stub'_trade_elasticities.tex
*   - output/figures/`output_stub'_revenue_decomposition.(pdf|png)
*   - output/figures/`output_stub'_extensive_margin.(pdf|png)
*   - output/figures/`output_stub'_intensive_margin.(pdf|png)
*   - output/figures/`output_stub'_gvc_shares.(pdf|png)
