version 17.0
set more off	

/*******************************************************************************
    Purpose:
        Clean and standardize latest-wave WBES firm data for the trade-analysis
        branch, retaining all countries for downstream filters and comparator
        averages.

    Inputs:
        Globals and packages created by code/01_setup.do.
        Data/World Bank Enterprise Survey/New_Comprehensive_July_21_2025.dta

    Outputs:
        Data/Analysis/wbes_trade_clean.dta
        output/tables/wbes_trade_country_coverage.tex
        output/tables/wbes_trade_negative_values.tex
        output/tables/wbes_trade_variable_availability.tex
        output/tables/wbes_trade_winsor_cutoffs.tex
        logs/01_wbes_trade_clean_prep_*.log

    Notes:
        This file prepares a cross-sectional WBES dataset. It does not estimate
        firm fixed effects or time trends. CEMAC membership is retained as a
        filter variable, but the prepared dataset keeps every latest-wave
        economy in the source extract.
*******************************************************************************/

/*******************************************************************************
    Bootstrap repository paths
*******************************************************************************/
* This script is intended to run from the local Git clone, not the archived
* OneDrive copy. Define the repo root explicitly by machine user so path
* problems are visible at startup rather than silently inferred from c(pwd).
* If you run this on a new machine, add another else-if branch below with your
* Stata username from c(username) and the local path to this repository.


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
    display as error "Add this user to the bootstrap block in code/WBES_trade/01_wbes_trade_clean_prep.do."
    exit 601
}

* Move to the repository root before calling the shared setup file. The setup
* script defines DATADIR, LOGDIR, OUTPUTDIR, and other project-wide globals.
capture noisily cd "${project_root}"
if _rc | !fileexists("AGENTS.md") {
    display as error "Configured project_root is not a valid repo root: ${project_root}"
    exit 601
}

do "code/01_setup.do"

* Download official reference sources, then prepare merge-ready reference files.
do "${WBES_TRADE_CODEDIR}/00_download_reference_data.do"
do "${WBES_TRADE_CODEDIR}/00_prepare_reference_merges.do"

* Use a compact time stamp so repeated runs create separate step logs.
local log_stamp = subinstr(c(current_time), ":", "", .)
local log_stamp = subinstr("`log_stamp'", " ", "", .)

* Open a named step log. The local clone should not need OneDrive-style
* sleep-and-retry handling; write failures should stop the script immediately.
capture log close wbesprep
log using "${LOGDIR}/01_wbes_trade_clean_prep_`log_stamp'.log", text name(wbesprep)

/*******************************************************************************
    Load WBES source and keep only variables used by this prep stage
*******************************************************************************/
local source_file "${DATADIR}/World Bank Enterprise Survey/New_Comprehensive_July_21_2025.dta"
confirm file "`source_file'"

use ///
    idstd country region sample wt wt_rs wt_BR ///
    stra_sector sector_MS size size_num l1 ///
    a20y a20_BR isic_v4 isic_v3_1 ///
    b2a b2b b2c b2d b5 ///
    d2 d3a d3b d3c d31x d12a d12b d13 d38x n2e n2i ///
    using "`source_file'", clear

generate str80 country_wave = country
generate int country_length = length(country_wave)
generate int survey_year = real(substr(country_wave, country_length - 3, 4))
generate str60 country_name = substr(country_wave, 1, country_length - 4)
replace country_name = strtrim(country_name)
replace country_name = "Cote d'Ivoire" if strpos(country_name, "Ivoire") > 0

generate byte cemac_country = inlist(country_name, ///
    "Cameroon", "Central African Republic", "Chad", "Congo", ///
    "Equatorial Guinea", "Gabon")

generate byte latest_wave = sample == 1 if !missing(sample)

merge m:1 country_name using "${DATADIR}/Intermediate/wbes_wb_country_metadata.dta", ///
    keep(master match) generate(country_metadata_merge)
assert country_metadata_merge == 3
drop country_metadata_merge

/*******************************************************************************
    Country coverage audit for all latest-wave economies
*******************************************************************************/
preserve
    keep if latest_wave == 1

    generate byte has_isic_v4 = !missing(isic_v4)

    collapse ///
        (count) firms = idstd ///
        (max) survey_year ///
        (mean) fiscal_year = a20y ///
        (sum) firms_with_isic_v4 = has_isic_v4 ///
        (max) cemac_country, ///
        by(country_name country_wave wb_iso3 wb_region wb_income_group)

    sort country_name
    generate str16 rowname = "country_" + string(_n)

    mkmat firms survey_year fiscal_year firms_with_isic_v4 cemac_country, ///
        matrix(country_coverage) rownames(rowname)
    matrix colnames country_coverage = Firms SurveyYear FiscalYear FirmsWithISIC4 CEMAC

    local coverage_rowlabels
    quietly count
    local coverage_n = r(N)
    forvalues i = 1/`coverage_n' {
        local label = subinstr(country_name[`i'], "&", "\&", .)
        local coverage_rowlabels `coverage_rowlabels' `=rowname[`i']' "`label'"
    }

    esttab matrix(country_coverage, fmt(%9.0fc %9.0fc %9.0fc %9.0fc %9.0fc)) ///
        using "${OUTPUTDIR}/tables/wbes_trade_country_coverage.tex", ///
        replace booktabs fragment nomtitles nonumbers ///
        varlabels(`coverage_rowlabels')
restore

/*******************************************************************************
    CEMAC country coverage for slides
*******************************************************************************/
preserve
    keep if latest_wave == 1 & cemac_country == 1

    generate byte has_isic_v4 = !missing(isic_v4)
    generate byte retained_cemac = country_name != "Gabon"

    collapse ///
        (count) firms = idstd ///
        (max) survey_year ///
        (mean) fiscal_year = a20y ///
        (sum) firms_with_isic_v4 = has_isic_v4 ///
        (max) retained_cemac, ///
        by(country_name country_wave)

    sort country_name
    generate str16 rowname = "country_" + string(_n)

    mkmat firms survey_year fiscal_year firms_with_isic_v4 retained_cemac, ///
        matrix(cemac_country_coverage) rownames(rowname)
    matrix colnames cemac_country_coverage = Firms SurveyYear FiscalYear FirmsWithISIC4 Retained

    local cemac_coverage_rowlabels
    quietly count
    local cemac_coverage_n = r(N)
    forvalues i = 1/`cemac_coverage_n' {
        local label = subinstr(country_name[`i'], "&", "\&", .)
        local cemac_coverage_rowlabels `cemac_coverage_rowlabels' `=rowname[`i']' "`label'"
    }

    esttab matrix(cemac_country_coverage, fmt(%9.0fc %9.0fc %9.0fc %9.0fc %9.0fc)) ///
        using "${OUTPUTDIR}/tables/cemac_wbes_trade_country_coverage.tex", ///
        replace booktabs fragment nomtitles nonumbers ///
        varlabels(`cemac_coverage_rowlabels')
restore

/*******************************************************************************
    Keep latest-wave records for every economy in the extract
*******************************************************************************/
keep if latest_wave == 1

quietly count
local latest_wave_obs = r(N)
egen byte country_tag = tag(country_name)
quietly count if country_tag == 1
local latest_wave_country_count = r(N)
drop country_tag

display as text "Latest-wave WBES records retained = `latest_wave_obs'."
display as text "Latest-wave WBES economies retained = `latest_wave_country_count'."

/*******************************************************************************
    Standardize identifiers and preserve raw source fields
*******************************************************************************/
clonevar firm_id = idstd
isid firm_id

clonevar weight = wt
clonevar weight_rescaled = wt_rs
clonevar weight_business_register = wt_BR

clonevar firm_size = size
clonevar employment_raw = size_num
clonevar permanent_employment_raw = l1
clonevar sector_isic4 = isic_v4
clonevar sector_isic31 = isic_v3_1
clonevar sector_strata = stra_sector
clonevar sector_manufacturing_services = sector_MS

clonevar dom_private_own_pct_raw = b2a
clonevar foreign_own_pct_raw = b2b
clonevar gov_own_pct_raw = b2c
clonevar other_own_pct_raw = b2d
clonevar establishment_year_raw = b5

capture confirm numeric variable sector_isic4
if !_rc {
    generate int isic4_division = sector_isic4
}
else {
    generate int isic4_division = real(sector_isic4)
}
generate str2 isic4_division_code = string(isic4_division, "%02.0f") ///
    if !missing(isic4_division)

merge m:1 isic4_division_code using "${DATADIR}/Intermediate/isic_rev4_division_labels.dta", ///
    keep(master match) generate(isic4_label_merge)
assert isic4_label_merge == 3 if !missing(isic4_division_code)
drop isic4_label_merge

clonevar sales_raw = d2
clonevar domestic_sales_pct_raw = d3a
clonevar indirect_export_pct_raw = d3b
clonevar direct_export_pct_raw = d3c
clonevar direct_export_destination_raw = d31x
clonevar domestic_input_pct_raw = d12a
clonevar foreign_input_pct_raw = d12b
clonevar direct_import_raw = d13
clonevar import_origin_raw = d38x
clonevar raw_material_cost_raw = n2e
clonevar resale_goods_cost_raw = n2i

/*******************************************************************************
    Negative-value audit before recoding WBES special negative values to missing
*******************************************************************************/
foreach var in ///
    employment_raw permanent_employment_raw sales_raw ///
    domestic_sales_pct_raw indirect_export_pct_raw direct_export_pct_raw ///
    domestic_input_pct_raw foreign_input_pct_raw direct_import_raw ///
    raw_material_cost_raw resale_goods_cost_raw {
    generate byte neg_`var' = `var' < 0 if !missing(`var')
}

preserve
    collapse ///
        (sum) ///
        neg_employment_raw neg_permanent_employment_raw neg_sales_raw ///
        neg_domestic_sales_pct_raw neg_indirect_export_pct_raw neg_direct_export_pct_raw ///
        neg_domestic_input_pct_raw neg_foreign_input_pct_raw neg_direct_import_raw ///
        neg_raw_material_cost_raw neg_resale_goods_cost_raw, ///
        by(country_name)

    sort country_name
    generate str16 rowname = "country_" + string(_n)

    mkmat ///
        neg_employment_raw neg_permanent_employment_raw neg_sales_raw ///
        neg_domestic_sales_pct_raw neg_indirect_export_pct_raw neg_direct_export_pct_raw ///
        neg_domestic_input_pct_raw neg_foreign_input_pct_raw neg_direct_import_raw ///
        neg_raw_material_cost_raw neg_resale_goods_cost_raw, ///
        matrix(negative_values) rownames(rowname)
    matrix colnames negative_values = Employment PermanentEmp Sales DomesticShare IndirectExport DirectExport DomesticInput ForeignInput DirectImport RawMatCost ResaleCost

    local negative_rowlabels
    quietly count
    local negative_n = r(N)
    forvalues i = 1/`negative_n' {
        local label = subinstr(country_name[`i'], "&", "\&", .)
        local negative_rowlabels `negative_rowlabels' `=rowname[`i']' "`label'"
    }

    esttab matrix(negative_values, fmt(%9.0fc)) ///
        using "${OUTPUTDIR}/tables/wbes_trade_negative_values.tex", ///
        replace booktabs fragment nomtitles nonumbers ///
        varlabels(`negative_rowlabels')
restore

/*******************************************************************************
    CEMAC negative-value audit for retained slide sample
*******************************************************************************/
preserve
    keep if cemac_country == 1 & country_name != "Gabon"

    collapse ///
        (sum) ///
        neg_employment_raw neg_permanent_employment_raw neg_sales_raw ///
        neg_domestic_sales_pct_raw neg_indirect_export_pct_raw neg_direct_export_pct_raw ///
        neg_domestic_input_pct_raw neg_foreign_input_pct_raw neg_direct_import_raw ///
        neg_raw_material_cost_raw neg_resale_goods_cost_raw, ///
        by(country_name)

    sort country_name
    generate str16 rowname = "country_" + string(_n)

    mkmat ///
        neg_employment_raw neg_permanent_employment_raw neg_sales_raw ///
        neg_domestic_sales_pct_raw neg_indirect_export_pct_raw neg_direct_export_pct_raw ///
        neg_domestic_input_pct_raw neg_foreign_input_pct_raw neg_direct_import_raw ///
        neg_raw_material_cost_raw neg_resale_goods_cost_raw, ///
        matrix(cemac_negative_values) rownames(rowname)
    matrix colnames cemac_negative_values = Employment PermanentEmp Sales DomesticShare IndirectExport DirectExport DomesticInput ForeignInput DirectImport RawMatCost ResaleCost

    local cemac_negative_rowlabels
    quietly count
    local cemac_negative_n = r(N)
    forvalues i = 1/`cemac_negative_n' {
        local label = subinstr(country_name[`i'], "&", "\&", .)
        local cemac_negative_rowlabels `cemac_negative_rowlabels' `=rowname[`i']' "`label'"
    }

    esttab matrix(cemac_negative_values, fmt(%9.0fc)) ///
        using "${OUTPUTDIR}/tables/cemac_wbes_trade_negative_values.tex", ///
        replace booktabs fragment nomtitles nonumbers ///
        varlabels(`cemac_negative_rowlabels')
restore

/*******************************************************************************
    Clean nonnegative levels, percentages, and binary survey responses
*******************************************************************************/
generate double employment = employment_raw
replace employment = . if employment < 0

generate double permanent_employment = permanent_employment_raw
replace permanent_employment = . if permanent_employment < 0

generate double sales = sales_raw
replace sales = . if sales < 0

foreach pct in ///
    domestic_sales_pct indirect_export_pct direct_export_pct ///
    domestic_input_pct foreign_input_pct ///
    dom_private_own_pct foreign_own_pct gov_own_pct other_own_pct {
    generate double `pct' = `pct'_raw
    replace `pct' = . if `pct' < 0
    replace `pct' = . if `pct' > 100
}

generate int establishment_year = establishment_year_raw
replace establishment_year = . if establishment_year < 0
replace establishment_year = . if establishment_year > survey_year

generate double firm_age = survey_year - establishment_year ///
    if !missing(survey_year, establishment_year)
generate double ln_firm_age = ln(firm_age + 1) if firm_age >= 0

generate double domestic_own_share = dom_private_own_pct / 100 ///
    if !missing(dom_private_own_pct)
generate double foreign_own_share = foreign_own_pct / 100 ///
    if !missing(foreign_own_pct)
generate double gov_own_share = gov_own_pct / 100 ///
    if !missing(gov_own_pct)
generate double other_own_share = other_own_pct / 100 ///
    if !missing(other_own_pct)
generate double ownership_share_sum = dom_private_own_pct ///
    + foreign_own_pct + gov_own_pct + other_own_pct ///
    if !missing(dom_private_own_pct, foreign_own_pct, ///
        gov_own_pct, other_own_pct)
generate byte ownership_share_off_100 = abs(ownership_share_sum - 100) > .001 ///
    if !missing(ownership_share_sum)
generate byte wbes_controls_available = !missing(ln_firm_age, ///
    foreign_own_share, gov_own_share)

generate double raw_material_cost = raw_material_cost_raw
replace raw_material_cost = . if raw_material_cost < 0

generate double resale_goods_cost = resale_goods_cost_raw
replace resale_goods_cost = . if resale_goods_cost < 0

egen double input_cost = rowtotal(raw_material_cost resale_goods_cost), missing

generate double direct_import_response = direct_import_raw
replace direct_import_response = . if direct_import_response < 0
replace direct_import_response = . if !inlist(direct_import_response, 1, 2) & !missing(direct_import_response)

assert employment >= 0 if !missing(employment)
assert permanent_employment >= 0 if !missing(permanent_employment)
assert sales >= 0 if !missing(sales)
assert firm_age >= 0 if !missing(firm_age)
assert raw_material_cost >= 0 if !missing(raw_material_cost)
assert resale_goods_cost >= 0 if !missing(resale_goods_cost)
assert input_cost >= 0 if !missing(input_cost)

/*******************************************************************************
    Winsorize monetary variables at the 5th and 95th percentiles by country-wave
*******************************************************************************/
egen long country_wave_id = group(country_wave), label

foreach var in sales input_cost {
    generate double `var'_w = `var'
    generate double `var'_p5 = .
    generate double `var'_p95 = .

    quietly summarize country_wave_id, meanonly
    local max_group = r(max)

    forvalues group = 1/`max_group' {
        quietly count if country_wave_id == `group' & !missing(`var')
        if r(N) > 0 {
            quietly _pctile `var' if country_wave_id == `group' & !missing(`var'), p(5 95)
            replace `var'_p5 = r(r1) if country_wave_id == `group'
            replace `var'_p95 = r(r2) if country_wave_id == `group'
            replace `var'_w = `var'_p5 if country_wave_id == `group' & !missing(`var', `var'_p5) & `var' < `var'_p5
            replace `var'_w = `var'_p95 if country_wave_id == `group' & !missing(`var', `var'_p95) & `var' > `var'_p95
        }
    }
}

preserve
    keep country_name country_wave sales_p5 sales_p95 input_cost_p5 input_cost_p95
    bysort country_wave: keep if _n == 1
    sort country_name
    generate str16 rowname = "country_" + string(_n)

    mkmat sales_p5 sales_p95 input_cost_p5 input_cost_p95, ///
        matrix(winsor_cutoffs) rownames(rowname)
    matrix colnames winsor_cutoffs = SalesP5 SalesP95 InputCostP5 InputCostP95

    local winsor_rowlabels
    quietly count
    local winsor_n = r(N)
    forvalues i = 1/`winsor_n' {
        local label = subinstr(country_name[`i'], "&", "\&", .)
        local winsor_rowlabels `winsor_rowlabels' `=rowname[`i']' "`label'"
    }

    esttab matrix(winsor_cutoffs, fmt(%12.0fc)) ///
        using "${OUTPUTDIR}/tables/wbes_trade_winsor_cutoffs.tex", ///
        replace booktabs fragment nomtitles nonumbers ///
        varlabels(`winsor_rowlabels')
restore

/*******************************************************************************
    CEMAC winsorization cutoffs for retained slide sample
*******************************************************************************/
preserve
    keep if cemac_country == 1 & country_name != "Gabon"
    keep country_name country_wave sales_p5 sales_p95 input_cost_p5 input_cost_p95
    bysort country_wave: keep if _n == 1
    sort country_name
    generate str16 rowname = "country_" + string(_n)

    mkmat sales_p5 sales_p95 input_cost_p5 input_cost_p95, ///
        matrix(cemac_winsor_cutoffs) rownames(rowname)
    matrix colnames cemac_winsor_cutoffs = SalesP5 SalesP95 InputCostP5 InputCostP95

    local cemac_winsor_rowlabels
    quietly count
    local cemac_winsor_n = r(N)
    forvalues i = 1/`cemac_winsor_n' {
        local label = subinstr(country_name[`i'], "&", "\&", .)
        local cemac_winsor_rowlabels `cemac_winsor_rowlabels' `=rowname[`i']' "`label'"
    }

    esttab matrix(cemac_winsor_cutoffs, fmt(%12.0fc)) ///
        using "${OUTPUTDIR}/tables/cemac_wbes_trade_winsor_cutoffs.tex", ///
        replace booktabs fragment nomtitles nonumbers ///
        varlabels(`cemac_winsor_rowlabels')
restore

/*******************************************************************************
    Build scaffold-compatible trade variables
*******************************************************************************/
generate double domestic_sales_share = domestic_sales_pct / 100 if !missing(domestic_sales_pct)
generate double indirect_export_share = indirect_export_pct / 100 if !missing(indirect_export_pct)
generate double direct_export_share = direct_export_pct / 100 if !missing(direct_export_pct)
generate double export_share = (indirect_export_pct + direct_export_pct) / 100 ///
    if !missing(indirect_export_pct, direct_export_pct)
generate double foreign_input_share = foreign_input_pct / 100 if !missing(foreign_input_pct)
generate double domestic_input_share = domestic_input_pct / 100 if !missing(domestic_input_pct)

foreach share in ///
    domestic_sales_share indirect_export_share direct_export_share export_share ///
    foreign_input_share domestic_input_share {
    assert `share' >= 0 & `share' <= 1 if !missing(`share')
}

generate double sales_share_sum = domestic_sales_pct + indirect_export_pct + direct_export_pct ///
    if !missing(domestic_sales_pct, indirect_export_pct, direct_export_pct)
generate double input_share_sum = domestic_input_pct + foreign_input_pct ///
    if !missing(domestic_input_pct, foreign_input_pct)

assert sales_share_sum <= 100.0001 if !missing(sales_share_sum)
assert input_share_sum <= 100.0001 if !missing(input_share_sum)

generate double domestic_sales = sales_w * domestic_sales_share ///
    if !missing(sales_w, domestic_sales_share)
generate double local_sales = domestic_sales
generate double export_value = sales_w * export_share if !missing(sales_w, export_share)
generate double import_value = input_cost_w * foreign_input_share ///
    if !missing(input_cost_w, foreign_input_share)

generate byte export_status = export_share > 0 if !missing(export_share)
generate byte direct_exporter_10 = direct_export_pct >= 10 if !missing(direct_export_pct)

generate byte direct_import_status = .
replace direct_import_status = 1 if direct_import_response == 1
replace direct_import_status = 0 if direct_import_response == 2

generate byte import_status = .
replace import_status = direct_import_status if !missing(direct_import_status)
replace import_status = 1 if foreign_input_share > 0 & !missing(foreign_input_share)
replace import_status = 0 if missing(import_status) & foreign_input_share == 0

generate byte positive_sales = sales_w > 0 if !missing(sales_w)
generate byte gvc_local_only = positive_sales == 1 & export_status == 0 & import_status == 0 ///
    if !missing(positive_sales, export_status, import_status)
generate byte gvc_import_only = positive_sales == 1 & export_status == 0 & import_status == 1 ///
    if !missing(positive_sales, export_status, import_status)
generate byte gvc_export_only = positive_sales == 1 & export_status == 1 & import_status == 0 ///
    if !missing(positive_sales, export_status, import_status)
generate byte gvc_two_way = positive_sales == 1 & export_status == 1 & import_status == 1 ///
    if !missing(positive_sales, export_status, import_status)

egen byte gvc_status_sum = rowtotal(gvc_local_only gvc_import_only gvc_export_only gvc_two_way)
assert inlist(gvc_status_sum, 0, 1)
drop gvc_status_sum

/*******************************************************************************
    Variable availability audit for the retained analysis sample
*******************************************************************************/
generate byte has_sales = !missing(sales)
generate byte has_sales_w = !missing(sales_w)
generate byte has_employment = !missing(employment)
generate byte has_weight = !missing(weight) & weight > 0
generate byte has_sector_isic4 = !missing(sector_isic4)
generate byte has_export_share = !missing(export_share)
generate byte has_import_status = !missing(import_status)
generate byte has_import_value = !missing(import_value)
generate byte has_firm_age = !missing(ln_firm_age)
generate byte has_ownership_controls = !missing(foreign_own_share, gov_own_share)
generate byte sales_share_off_100 = abs(sales_share_sum - 100) > .001 if !missing(sales_share_sum)
generate byte input_share_off_100 = abs(input_share_sum - 100) > .001 if !missing(input_share_sum)

preserve
    collapse ///
        (count) firms = firm_id ///
        (sum) has_sales has_sales_w has_employment has_weight has_sector_isic4 ///
              has_export_share has_import_status has_import_value ///
              has_firm_age has_ownership_controls ///
              sales_share_off_100 input_share_off_100 ownership_share_off_100, ///
        by(country_name)

    sort country_name
    generate str16 rowname = "country_" + string(_n)

    mkmat firms has_sales has_sales_w has_employment has_weight has_sector_isic4 ///
        has_export_share has_import_status has_import_value ///
        has_firm_age has_ownership_controls ///
        sales_share_off_100 input_share_off_100 ownership_share_off_100, ///
        matrix(variable_availability) rownames(rowname)
    matrix colnames variable_availability = Firms Sales SalesW Employment Weight ISIC4 ExportShare ImportStatus ImportValue FirmAge OwnershipControls SalesShareOff100 InputShareOff100 OwnershipShareOff100

    local availability_rowlabels
    quietly count
    local availability_n = r(N)
    forvalues i = 1/`availability_n' {
        local label = subinstr(country_name[`i'], "&", "\&", .)
        local availability_rowlabels `availability_rowlabels' `=rowname[`i']' "`label'"
    }

    esttab matrix(variable_availability, fmt(%9.0fc)) ///
        using "${OUTPUTDIR}/tables/wbes_trade_variable_availability.tex", ///
        replace booktabs fragment nomtitles nonumbers ///
        varlabels(`availability_rowlabels')
restore

/*******************************************************************************
    CEMAC variable availability for retained slide sample
*******************************************************************************/
preserve
    keep if cemac_country == 1 & country_name != "Gabon"

    collapse ///
        (count) firms = firm_id ///
        (sum) has_sales has_sales_w has_employment has_weight has_sector_isic4 ///
              has_export_share has_import_status has_import_value ///
              has_firm_age has_ownership_controls ///
              sales_share_off_100 input_share_off_100 ownership_share_off_100, ///
        by(country_name)

    sort country_name
    generate str16 rowname = "country_" + string(_n)

    mkmat firms has_sales has_sales_w has_employment has_weight has_sector_isic4 ///
        has_export_share has_import_status has_import_value ///
        has_firm_age has_ownership_controls ///
        sales_share_off_100 input_share_off_100 ownership_share_off_100, ///
        matrix(cemac_variable_availability) rownames(rowname)
    matrix colnames cemac_variable_availability = Firms Sales SalesW Employment Weight ISIC4 ExportShare ImportStatus ImportValue FirmAge OwnershipControls SalesShareOff100 InputShareOff100 OwnershipShareOff100

    local cemac_availability_rowlabels
    quietly count
    local cemac_availability_n = r(N)
    forvalues i = 1/`cemac_availability_n' {
        local label = subinstr(country_name[`i'], "&", "\&", .)
        local cemac_availability_rowlabels `cemac_availability_rowlabels' `=rowname[`i']' "`label'"
    }

    esttab matrix(cemac_variable_availability, fmt(%9.0fc)) ///
        using "${OUTPUTDIR}/tables/cemac_wbes_trade_variable_availability.tex", ///
        replace booktabs fragment nomtitles nonumbers ///
        varlabels(`cemac_availability_rowlabels')
restore

/*******************************************************************************
    Final labels, order, and save
*******************************************************************************/
label variable firm_id "WBES standardized firm identifier"
label variable country_wave "WBES country-wave string"
label variable country_name "Country name parsed from WBES country-wave string"
label variable survey_year "Survey year parsed from WBES country-wave string"
label variable cemac_country "CEMAC country filter"
label variable wb_iso3 "World Bank ISO3/economy code"
label variable wb_country_code "World Bank/WITS numeric country code"
label variable wb_country_name "World Bank/WITS country/economy name"
label variable wb_country_long_name "World Bank/WITS long country/economy name"
label variable wb_region "World Bank/WITS region"
label variable wb_income_group "World Bank income group"
label variable wb_lending_group "World Bank lending group"
label variable wb_currency_unit "World Bank/WITS currency unit"
label variable wb_metadata_note "Country metadata match note"
label variable a20y "Last completed fiscal year reported in WBES"
label variable weight "Primary WBES sampling weight"
label variable weight_rescaled "WBES rescaled weight retained for sensitivity checks"
label variable sector_isic4 "ISIC Rev.4 sector code"
label variable isic4_division "ISIC Rev.4 two-digit division code"
label variable isic4_division_code "ISIC Rev.4 two-digit division code as string"
label variable isic4_section "ISIC Rev.4 section code"
label variable isic4_section_label "ISIC Rev.4 section label"
label variable isic4_division_label "ISIC Rev.4 division label"
label variable sector_strata "WBES stratification sector"
label variable firm_size "WBES firm size category"
label variable establishment_year "Year establishment began operations"
label variable firm_age "Firm age in years at survey year"
label variable ln_firm_age "Log firm age plus one"
label variable domestic_own_share "Domestic private ownership share"
label variable foreign_own_share "Foreign private ownership share"
label variable gov_own_share "Government/state ownership share"
label variable other_own_share "Other ownership share"
label variable wbes_controls_available "Firm age and ownership controls available"
label variable employment "Employment from WBES size_num, with negative codes set missing"
label variable permanent_employment "Permanent full-time employment from WBES l1, with negative codes set missing"
label variable sales "Annual sales from WBES d2, with negative codes set missing"
label variable sales_w "Annual sales winsorized at 5/95 by country-wave"
label variable input_cost "Raw materials plus resale goods cost, cleaned"
label variable input_cost_w "Input cost winsorized at 5/95 by country-wave"
label variable domestic_sales_share "Domestic sales share from WBES d3a"
label variable indirect_export_share "Indirect export share from WBES d3b"
label variable direct_export_share "Direct export share from WBES d3c"
label variable export_share "Direct plus indirect export share of sales"
label variable domestic_sales "Winsorized sales times domestic sales share"
label variable local_sales "Alias for domestic sales for scaffold compatibility"
label variable export_value "Winsorized sales times export share"
label variable export_status "Firm exports directly or indirectly"
label variable direct_exporter_10 "Direct exporter under WBES 10 percent direct-export threshold"
label variable domestic_input_share "Domestic-origin input share from WBES d12a"
label variable foreign_input_share "Foreign-origin input share from WBES d12b"
label variable import_status "Firm imports directly or uses foreign-origin inputs"
label variable import_value "Winsorized input cost times foreign input share"
label variable gvc_local_only "Positive-sales firm with no exports or imports"
label variable gvc_import_only "Positive-sales firm with imports or foreign inputs only"
label variable gvc_export_only "Positive-sales firm with exports only"
label variable gvc_two_way "Positive-sales firm with both exports and imports"

assert has_weight == 1
assert !missing(country_name, survey_year)

order ///
    firm_id country_name wb_iso3 wb_country_code wb_country_name ///
    wb_country_long_name wb_region wb_income_group wb_lending_group ///
    wb_currency_unit cemac_country ///
    country_wave survey_year a20y ///
    weight weight_rescaled weight_business_register ///
    sector_isic4 isic4_division isic4_division_code ///
    isic4_section isic4_section_label isic4_division_label ///
    sector_isic31 sector_strata sector_manufacturing_services ///
    firm_size establishment_year firm_age ln_firm_age ///
    domestic_own_share foreign_own_share gov_own_share other_own_share ///
    wbes_controls_available ///
    employment permanent_employment ///
    sales sales_w input_cost input_cost_w ///
    domestic_sales_share indirect_export_share direct_export_share export_share ///
    domestic_sales local_sales export_value export_status direct_exporter_10 ///
    domestic_input_share foreign_input_share direct_import_status import_status import_value ///
    gvc_local_only gvc_import_only gvc_export_only gvc_two_way

keep ///
    firm_id country_name wb_iso3 wb_country_code wb_country_name ///
    wb_country_long_name wb_region wb_income_group wb_lending_group ///
    wb_currency_unit wb_metadata_note cemac_country ///
    country_wave survey_year a20y region sample ///
    weight weight_rescaled weight_business_register ///
    sector_isic4 isic4_division isic4_division_code ///
    isic4_section isic4_section_label isic4_division_label ///
    sector_isic31 sector_strata sector_manufacturing_services ///
    firm_size establishment_year establishment_year_raw firm_age ln_firm_age ///
    dom_private_own_pct dom_private_own_pct_raw ///
    foreign_own_pct foreign_own_pct_raw ///
    gov_own_pct gov_own_pct_raw ///
    other_own_pct other_own_pct_raw ///
    domestic_own_share foreign_own_share gov_own_share other_own_share ///
    ownership_share_sum ownership_share_off_100 wbes_controls_available ///
    employment employment_raw permanent_employment permanent_employment_raw ///
    sales sales_raw sales_w sales_p5 sales_p95 ///
    input_cost input_cost_w input_cost_p5 input_cost_p95 ///
    raw_material_cost raw_material_cost_raw resale_goods_cost resale_goods_cost_raw ///
    domestic_sales_pct domestic_sales_pct_raw indirect_export_pct indirect_export_pct_raw ///
    direct_export_pct direct_export_pct_raw direct_export_destination_raw ///
    domestic_sales_share indirect_export_share direct_export_share export_share sales_share_sum ///
    domestic_sales local_sales export_value export_status direct_exporter_10 ///
    domestic_input_pct domestic_input_pct_raw foreign_input_pct foreign_input_pct_raw ///
    domestic_input_share foreign_input_share input_share_sum ///
    direct_import_response direct_import_status direct_import_raw import_origin_raw ///
    import_status import_value ///
    gvc_local_only gvc_import_only gvc_export_only gvc_two_way ///
    has_sales has_sales_w has_employment has_weight has_sector_isic4 ///
    has_export_share has_import_status has_import_value ///
    has_firm_age has_ownership_controls ///
    sales_share_off_100 input_share_off_100 ownership_share_off_100

compress

* Save the cleaned analysis file. Any file-lock or permission problem should
* fail loudly now that the active workflow writes to the local clone.
save "${DATADIR}/Analysis/wbes_trade_clean.dta", replace

display as result "Saved cleaned latest-wave WBES trade prep file to ${DATADIR}/Analysis/wbes_trade_clean.dta"

log close wbesprep
