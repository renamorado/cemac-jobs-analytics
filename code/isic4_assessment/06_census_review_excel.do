version 17.0
set more off
local out "${OUTPUTDIR}/checks/census_isic4"
local review "`out'/census_isic4_review.xlsx"

* This is a review copy of the Stata diagnostics and the separately maintained CSV.
foreach view in coverage unresolved_review activity_review exporter_coverage {
    local input "census_`view'"
    if "`view'" == "coverage" local input "census_mapping_coverage"
    import delimited using "`out'/`input'.csv", varnames(1) stringcols(_all) ///
        bindquote(strict) encoding(utf8) clear
    foreach v of varlist _all {
        if substr("`v'", 1, 3) == "hq_" | substr("`v'", 1, 4) == "pct_" ///
            | inlist("`v'", "activities", "units", "headquarters", "review_order") {
            destring `v', replace
        }
    }
    local tab "Coverage"
    if "`view'" == "coverage" {
        keep mapping_status activities pct_activities units pct_units headquarters ///
            pct_headquarters hq_employment pct_hq_employment hq_turnover ///
            pct_hq_turnover hq_exporter pct_hq_exporter hq_positive_emp_sales
    }
    if inlist("`view'", "unresolved_review", "activity_review") {
        local tab "All activities"
        if "`view'" == "unresolved_review" local tab "Needs review"
        keep review_order citi_branch activity_detail final_division proposed_division ///
            review_status possible_divisions units headquarters hq_employment hq_turnover ///
            hq_exporter reasoning supporting_classes official_pages official_url ///
            possibilities_complete final_division_label
        order review_order citi_branch activity_detail final_division proposed_division ///
            review_status possible_divisions units headquarters hq_employment hq_turnover ///
            hq_exporter reasoning supporting_classes official_pages official_url
    }
    if "`view'" == "exporter_coverage" {
        local tab "Exporter coverage"
        keep exporter_status assigned units pct_units headquarters pct_headquarters ///
            hq_employment pct_hq_employment hq_turnover pct_hq_turnover hq_exports
    }
    local mode "sheetreplace"
    if "`view'" == "coverage" local mode "replace"
    if _N > 0 export excel using "`review'", sheet("`tab'") firstrow(variables) ///
        cell(A4) `mode'
    if _N == 0 {
        putexcel set "`review'", sheet("`tab'", replace) modify
        putexcel A4 = "No unresolved activities remain."
    }
    putexcel set "`review'", sheet("`tab'") modify
    putexcel A1 = "Cameroon census - ISIC Rev. 4 divisions"
    putexcel A2 = "Generated review copy. Edit docs/reference/cmr_census_activity_isic4_crosswalk.csv and rerun the Stata entrypoint."
    putexcel A3 = "All units retained; hq measures use headquarters only. Percentages include unresolved records. Exports mean reported positive export turnover."
    local lastrow = max(5, _N + 4)
    local lastcol = c(k)
    mata: census_book = xl()
    mata: census_book.load_book(st_local("review"))
    mata: census_book.set_mode("open")
    mata: census_book.set_sheet(st_local("tab"))
    mata: census_nr = strtoreal(st_local("lastrow"))
    mata: census_nc = strtoreal(st_local("lastcol"))
    mata: census_book.set_font((1,census_nr), (1,census_nc), "Calibri", 11)
    mata: census_book.set_column_width(1, census_nc, 22)
    mata: census_book.set_row_height(1, 1, 27)
    mata: census_book.set_row_height(2, 3, 20)
    mata: census_book.set_row_height(4, 4, 45)
    mata: census_book.set_text_wrap(4, (1,census_nc), "on")
    mata: census_book.set_font(4, (1,census_nc), "Calibri", 11, "white")
    mata: census_book.set_font_bold(4, (1,census_nc), "on")
    mata: census_book.set_fill_pattern(4, (1,census_nc), "solid", "navy")
    mata: census_book.set_font(1, 1, "Calibri", 16, "navy")
    mata: census_book.set_font_bold(1, 1, "on")
    local column = 0
    foreach v of varlist _all {
        local ++column
        capture confirm numeric variable `v'
        if !_rc {
            local format "#,##0"
            if substr("`v'", 1, 4) == "pct_" local format "0.00"
            mata: census_book.set_number_format((5,census_nr), strtoreal(st_local("column")), st_local("format"))
        }
    }
    if inlist("`tab'", "Needs review", "All activities") {
        mata: census_book.set_column_width(1, 1, 12)
        mata: census_book.set_column_width(2, 2, 30)
        mata: census_book.set_column_width(3, 3, 60)
        mata: census_book.set_column_width(13, 13, 88)
        mata: census_book.set_column_width(14, 14, 35)
        mata: census_book.set_column_width(15, 15, 85)
        mata: census_book.set_column_width(16, 16, 50)
        mata: census_book.set_column_width(18, 18, 50)
        mata: census_book.set_text_wrap((5,census_nr), (2,census_nc), "on")
        mata: census_book.set_row_height(5, census_nr, 105)
        mata: census_book.set_number_format((5,census_nr), (8,12), "#,##0")
    }
    mata: census_book.close_book()
}
