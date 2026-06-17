version 17.0
set more off

/*******************************************************************************
    Purpose:
        Export a deck-ready WBES descriptive statistics table for retained CEMAC
        countries and benchmark groups.

    Inputs:
        Data/Analysis/wbes_trade_clean.dta
        World Bank WDI official exchange rates, PA.NUS.FCRF

    Outputs:
        Data/Intermediate/wdi_official_exchange_rates.dta
        output/tables/cemac_wbes_trade_descriptive_stats_deck.tex
        logs/02_wbes_trade_descriptive_stats.log

    Notes:
        WBES annual sales are reported in local currency for the last completed
        fiscal year. This file converts winsorized sales to current US dollars
        using the official exchange rate for that fiscal year, not the survey
        year or the current calendar year. PPP conversion factors are not used
        because WDI PPP factors are aggregate GDP/private-consumption measures,
        not firm-sales deflators.
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
    display as error "Add this user to the bootstrap block in code/WBES_trade/02_wbes_trade_descriptive_stats.do."
    exit 601
}

capture noisily cd "${project_root}"
if _rc | !fileexists("AGENTS.md") {
    display as error "Configured project_root is not a valid repo root: ${project_root}"
    exit 601
}

do "code/01_setup.do"

capture log close wbesdescriptives
log using "${LOGDIR}/02_wbes_trade_descriptive_stats.log", replace text name(wbesdescriptives)

/*******************************************************************************
    Download and prepare fiscal-year WDI exchange rates
*******************************************************************************/
local reference_raw_dir "${DATADIR}/Intermediate/reference_raw"
local fx_unzip_dir "${SCRATCHDIR}/wdi_pa_nus_fcrf"
local fx_zip "`reference_raw_dir'/wdi_pa_nus_fcrf_csv.zip"
local fx_dta "${DATADIR}/Intermediate/wdi_official_exchange_rates.dta"
local fx_url "https://api.worldbank.org/v2/en/indicator/PA.NUS.FCRF?downloadformat=csv"

capture mkdir "`reference_raw_dir'"
capture mkdir "`fx_unzip_dir'"

capture noisily copy "`fx_url'" "`fx_zip'", replace
if _rc {
    if fileexists("`fx_dta'") {
        display as error "WDI exchange-rate download failed; using cached file `fx_dta'."
    }
    else {
        display as error "WDI exchange-rate download failed and no cached exchange-rate file exists."
        error 601
    }
}
else {
    local current_dir = c(pwd)
    quietly cd "`fx_unzip_dir'"
    unzipfile "`fx_zip'", replace
    quietly cd "`current_dir'"

    local fx_csv_files : dir "`fx_unzip_dir'" files "API_PA.NUS.FCRF_DS2_en_csv_v2_*.csv"
    local fx_csv : word 1 of `fx_csv_files'

    if "`fx_csv'" == "" {
        display as error "Could not find the WDI PA.NUS.FCRF CSV inside `fx_unzip_dir'."
        error 601
    }

    import delimited using "`fx_unzip_dir'/`fx_csv'", clear varnames(5) ///
        bindquote(strict) stringcols(_all)

    local codevar
    foreach candidate in countrycode country_code countrycode_ {
        capture confirm variable `candidate'
        if !_rc {
            local codevar "`candidate'"
        }
    }

    if "`codevar'" == "" {
        display as error "Could not identify the country-code variable in the WDI exchange-rate CSV."
        describe
        error 111
    }

    rename `codevar' wb_iso3

    local metadata_vars countryname wb_iso3 indicatorname indicatorcode
    ds `metadata_vars', not

    local fx_year_vars
    local year = 1960
    foreach var of varlist `r(varlist)' {
        rename `var' fx_`year'
        local fx_year_vars `fx_year_vars' fx_`year'
        local ++year
    }

    keep wb_iso3 `fx_year_vars'
    reshape long fx_, i(wb_iso3) j(fiscal_year)
    rename fx_ exchange_rate_lcu_per_usd
    destring exchange_rate_lcu_per_usd, replace force
    keep if !missing(exchange_rate_lcu_per_usd)

    label variable wb_iso3 "World Bank ISO3/economy code"
    label variable fiscal_year "Calendar/fiscal year for WDI exchange rate"
    label variable exchange_rate_lcu_per_usd "Official exchange rate, LCU per US dollar, period average"

    isid wb_iso3 fiscal_year
    compress
    save "`fx_dta'", replace
}

/*******************************************************************************
    Load cleaned WBES data and create table variables
*******************************************************************************/
use "${DATADIR}/Analysis/wbes_trade_clean.dta", clear

foreach var in ///
    firm_id country_name wb_iso3 cemac_country wb_region wb_income_group ///
    a20y weight isic4_section sales_w export_status employment {
    confirm variable `var'
}

assert !missing(weight)
assert weight > 0

generate int fiscal_year = a20y
merge m:1 wb_iso3 fiscal_year using "`fx_dta'", ///
    keep(master match) generate(exchange_rate_merge)

count if exchange_rate_merge != 3 & !missing(sales_w) & ///
    ((cemac_country == 1 & country_name != "Gabon") | ///
    (strpos(wb_region, "Sub-Saharan Africa") > 0 & cemac_country != 1) | ///
    strpos(wb_income_group, "High income") > 0)
display as text "Table-sample observations with sales but no fiscal-year exchange rate = " r(N)

generate double sales_usd_thou = sales_w / exchange_rate_lcu_per_usd / 1000 ///
    if !missing(sales_w, exchange_rate_lcu_per_usd) & exchange_rate_lcu_per_usd > 0

generate byte retained_cemac = cemac_country == 1 & country_name != "Gabon"
generate byte ssa_excl_cemac = strpos(wb_region, "Sub-Saharan Africa") > 0 & cemac_country != 1
generate byte high_income = strpos(wb_income_group, "High income") > 0

generate byte manufacturing_firm = isic4_section == "C" if !missing(isic4_section)
generate byte construction_utilities_firm = inlist(isic4_section, "E", "F") ///
    if !missing(isic4_section)
generate byte trade_hosp_transport_firm = inlist(isic4_section, "G", "H", "I") ///
    if !missing(isic4_section)
generate byte other_services_firm = inlist(isic4_section, "J", "K", "M", "N", "S") ///
    if !missing(isic4_section)

generate double sales_manufacturing = sales_usd_thou * manufacturing_firm ///
    if !missing(sales_usd_thou, manufacturing_firm)
generate double sales_construction_utilities = sales_usd_thou * construction_utilities_firm ///
    if !missing(sales_usd_thou, construction_utilities_firm)
generate double sales_trade_hosp_transport = sales_usd_thou * trade_hosp_transport_firm ///
    if !missing(sales_usd_thou, trade_hosp_transport_firm)
generate double sales_other_services = sales_usd_thou * other_services_firm ///
    if !missing(sales_usd_thou, other_services_firm)

label variable sales_usd_thou "Winsorized annual sales, current US dollars, thousands"

capture program drop post_wbes_descriptive_column
program define post_wbes_descriptive_column, eclass
    args b_matrix v_matrix n_obs

    ereturn post `b_matrix' `v_matrix', obs(`n_obs')
    ereturn local cmd "wbes_descriptive"
end

/*******************************************************************************
    Build one stored-estimation column for each country or comparator group
*******************************************************************************/
local rows ///
    fiscal_year surveyed_firms firms_represented ///
    exporting_firms manufacturing_firms construction_utilities_firms ///
    trade_hosp_transport_firms other_services_firms ///
    activity_manufacturing activity_construction_utilities ///
    activity_trade_hosp_transport activity_other_services ///
    avg_sales_all avg_sales_exporters avg_sales_nonexporters ///
    avg_emp_all avg_emp_exporters avg_emp_nonexporters

local nrows : word count `rows'

local bfmts "0 0 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1"

local rowlabels ///
    fiscal_year "Fiscal year" ///
    surveyed_firms "Surveyed firms" ///
    firms_represented "Firms represented (000s)" ///
    exporting_firms "\% Exporting firms" ///
    manufacturing_firms "\% Manufacturing" ///
    construction_utilities_firms "\% Construction/utilities" ///
    trade_hosp_transport_firms "\% Trade/hospitality/transport" ///
    other_services_firms "\% Other services" ///
    activity_manufacturing "Manufacturing" ///
    activity_construction_utilities "Construction/utilities" ///
    activity_trade_hosp_transport "Trade/hospitality/transport" ///
    activity_other_services "Other services" ///
    avg_sales_all "All firms" ///
    avg_sales_exporters "Exporting firms" ///
    avg_sales_nonexporters "Non-exporting firms" ///
    avg_emp_all "All firms" ///
    avg_emp_exporters "Exporting firms" ///
    avg_emp_nonexporters "Non-exporting firms"

local model_list

local column_keys cmr car tcd cog gnq ssa high
local column_titles ///
    `"Cameroon"' ///
    `"\shortstack{Central Afr.\\Rep.}"' ///
    `"Chad"' ///
    `"Congo"' ///
    `"\shortstack{Eq.\\Guinea}"' ///
    `"\shortstack{SSA excl.\\CEMAC}"' ///
    `"\shortstack{High-income\\countries}"'

local cond_cmr `"country_name == "Cameroon""'
local cond_car `"country_name == "Central African Republic""'
local cond_tcd `"country_name == "Chad""'
local cond_cog `"country_name == "Congo""'
local cond_gnq `"country_name == "Equatorial Guinea""'
local cond_ssa `"ssa_excl_cemac == 1"'
local cond_high `"high_income == 1"'

foreach key of local column_keys {
    local sample_condition `"`cond_`key''"'

    tempname b V
    matrix `b' = J(1, `nrows', .)
    matrix `V' = J(`nrows', `nrows', 0)
    matrix colnames `b' = `rows'
    matrix rownames `V' = `rows'
    matrix colnames `V' = `rows'

    quietly count if `sample_condition'
    local model_obs = r(N)

    quietly summarize fiscal_year if `sample_condition', detail
    matrix `b'[1, 1] = r(p50)

    quietly count if `sample_condition'
    matrix `b'[1, 2] = r(N)

    quietly summarize weight if `sample_condition', meanonly
    matrix `b'[1, 3] = r(sum) / 1000

    local row = 4
    foreach var in ///
        export_status manufacturing_firm construction_utilities_firm ///
        trade_hosp_transport_firm other_services_firm {
        quietly count if `sample_condition' & !missing(`var')
        if r(N) >= 2 {
            quietly mean `var' [pweight = weight] if `sample_condition' & !missing(`var')
            matrix mean_b = e(b)
            matrix mean_V = e(V)
            matrix `b'[1, `row'] = 100 * mean_b[1,1]
            matrix `V'[`row', `row'] = (100 * sqrt(mean_V[1,1]))^2
        }
        local ++row
    }

    foreach num in ///
        sales_manufacturing sales_construction_utilities ///
        sales_trade_hosp_transport sales_other_services {
        quietly count if `sample_condition' & !missing(`num', sales_usd_thou) & sales_usd_thou > 0
        if r(N) >= 2 {
            quietly ratio `num'/sales_usd_thou [pweight = weight] ///
                if `sample_condition' & !missing(`num', sales_usd_thou) & sales_usd_thou > 0
            matrix ratio_b = e(b)
            matrix ratio_V = e(V)
            matrix `b'[1, `row'] = 100 * ratio_b[1,1]
            matrix `V'[`row', `row'] = (100 * sqrt(ratio_V[1,1]))^2
        }
        local ++row
    }

    foreach sample in all exporters nonexporters {
        if "`sample'" == "all" {
            local extra_condition "!missing(sales_usd_thou)"
        }
        else if "`sample'" == "exporters" {
            local extra_condition "export_status == 1 & !missing(sales_usd_thou)"
        }
        else if "`sample'" == "nonexporters" {
            local extra_condition "export_status == 0 & !missing(sales_usd_thou)"
        }

        quietly count if `sample_condition' & `extra_condition'
        if r(N) >= 2 {
            quietly mean sales_usd_thou [pweight = weight] ///
                if `sample_condition' & `extra_condition'
            matrix sales_b = e(b)
            matrix sales_V = e(V)
            matrix `b'[1, `row'] = sales_b[1,1]
            matrix `V'[`row', `row'] = sales_V[1,1]
        }
        local ++row
    }

    foreach sample in all exporters nonexporters {
        if "`sample'" == "all" {
            local extra_condition "!missing(employment)"
        }
        else if "`sample'" == "exporters" {
            local extra_condition "export_status == 1 & !missing(employment)"
        }
        else if "`sample'" == "nonexporters" {
            local extra_condition "export_status == 0 & !missing(employment)"
        }

        quietly count if `sample_condition' & `extra_condition'
        if r(N) >= 2 {
            quietly mean employment [pweight = weight] ///
                if `sample_condition' & `extra_condition'
            matrix emp_b = e(b)
            matrix emp_V = e(V)
            matrix `b'[1, `row'] = emp_b[1,1]
            matrix `V'[`row', `row'] = emp_V[1,1]
        }
        local ++row
    }

    post_wbes_descriptive_column `b' `V' `model_obs'
    estimates store desc_`key'
    local model_list `model_list' desc_`key'
}

/*******************************************************************************
    Export the esttab fragment and clean count rows with no standard errors
*******************************************************************************/
local raw_table "${SCRATCHDIR}/cemac_wbes_trade_descriptive_stats_deck_raw.tex"
local final_table "${OUTPUTDIR}/tables/cemac_wbes_trade_descriptive_stats_deck.tex"

esttab `model_list' using "`raw_table'", ///
    replace booktabs fragment nonumbers noobs compress ///
    cells("b(fmt(`bfmts')) & se(fmt(1) par([ ]))") ///
    incelldelimiter(" ") ///
    refcat(fiscal_year "\textbf{Sample composition}" ///
        activity_manufacturing "\addlinespace \textbf{Economic activity (\% total sales)}" ///
        avg_sales_all "\addlinespace \textbf{Average sales (current USD thousands)}" ///
        avg_emp_all "\addlinespace \textbf{Average employment}", nolabel) ///
    varlabels(`rowlabels')

file open raw using "`raw_table'", read text
file open final using "`final_table'", write replace text

local header_row `"          &\multicolumn{1}{c}{Cameroon}&\multicolumn{1}{c}{\shortstack{Central Afr.\\Rep.}}&\multicolumn{1}{c}{Chad}&\multicolumn{1}{c}{Congo}&\multicolumn{1}{c}{\shortstack{Eq.\\Guinea}}&\multicolumn{1}{c}{\shortstack{SSA excl.\\CEMAC}}&\multicolumn{1}{c}{\shortstack{High-income\\countries}}\\"'

local raw_line_number = 0
file read raw line
while r(eof) == 0 {
    local ++raw_line_number
    local clean_line `"`line'"'

    if `raw_line_number' == 1 {
        file write final `"`header_row'"' _n
    }
    else if `raw_line_number' == 2 {
        * Drop esttab's generic b/se header row after replacing model titles.
    }
    else {
        local clean_line = subinstr(`"`clean_line'"', " [.]", "", .)
        local clean_line = subinstr(`"`clean_line'"', " [0.0]", "", .)
        local clean_line = subinstr(`"`clean_line'"', " (0.0)", "", .)

        local remaining `"`clean_line'"'
        gettoken row_stub remaining : remaining, parse("&")
        local formatted_line `"`row_stub'"'

        while `"`remaining'"' != "" {
            gettoken separator remaining : remaining, parse("&")
            gettoken cell remaining : remaining, parse("&")

            local row_end
            local cell = strtrim(`"`cell'"')
            local cell_length = length(`"`cell'"')
            if `cell_length' >= 2 & substr(`"`cell'"', `cell_length' - 1, 2) == "\\" {
                local row_end "\\"
                local cell = strtrim(substr(`"`cell'"', 1, `cell_length' - 2))
            }

            if regexm(`"`cell'"', "^(.+) \[([0-9.]+)\]$") {
                local estimate = strtrim(regexs(1))
                local se = regexs(2)
                local cell `"\shortstack{`estimate'\\{}[`se']}"'
            }

            local formatted_line `"`formatted_line'&`cell'`row_end'"'
        }

        file write final `"`formatted_line'"' _n
    }

    file read raw line
}

file close raw
file close final

display as result "Saved deck-ready WBES descriptive table to `final_table'."

log close wbesdescriptives
