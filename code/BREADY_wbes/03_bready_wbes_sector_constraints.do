version 17.0
clear all
set more off

/*******************************************************************************
    Purpose:
        Construct weighted Cameroon WBES constraint indicators selected in the
        B-READY review workbook and compare agreed ISIC Rev.4 section groups in
        employment-opportunity bubble charts.

    Unit of observation:
        Input: latest-wave Cameroon WBES firm.
        Output: indicator-by-ISIC-section-group and indicator-by-high-elasticity group.

    Inputs:
        Data/B-Ready/Raw/2025/bready_enterprise_survey_questions.xlsx
        Data/World Bank Enterprise Survey/New_Comprehensive_July_21_2025.dta
        Data/Intermediate/isic4_broad_groups_codes.dta
        Data/Analysis/cmr_isic4_section_elasticity_ranking.dta
        Data/Analysis/cmr_isic4_section_elasticity_performance_scale.dta

    Outputs:
        Data/Analysis/bready_wbes_isic4_section_cmr_constraints.dta
        output/tables/bready_wbes_isic4_section_cmr_constraints_audit.tex
        output/tables/bready_wbes_isic4_section_cmr_indicator_validation.tex
        output/figures/bready_wbes_isic4_section_cmr_*_high_elasticity.{pdf,png}
        logs/03_bready_wbes_sector_constraints.log

    Notes:
        Results are weighted descriptive comparisons, not causal estimates.
        Bubble size represents terciles of average annual total employment, not WBES
        precision. Confidence intervals remain in the analytical dataset but
        are intentionally omitted from the figures.
*******************************************************************************/

if "${PROJECT_ROOT}" == "" {
    local username = lower("`c(username)'")
    if "`username'" == "wb648862" {
        global project_root "C:/Users/wb648862/Documents/Projects/CEMAC"
    }
    else if "`username'" == "wb603585" {
        global project_root "C:/Users/wb603585/OneDrive - WBG/Documents/Projects/CEMAC/FY26/CEMAC jobs analytics"
    }
    else if fileexists("AGENTS.md") {
        global project_root "`=subinstr(c(pwd), "\", "/", .)'"
    }
    else {
        display as error "No project_root path is configured for `c(username)'."
        exit 601
    }

    capture noisily cd "${project_root}"
    if _rc | !fileexists("AGENTS.md") {
        display as error "Configured project_root is not a valid repo root."
        exit 601
    }
    do "code/01_setup.do"
}

local priority_workbook "${DATADIR}/B-Ready/Raw/2025/bready_enterprise_survey_questions.xlsx"
local wbes_source "${DATADIR}/World Bank Enterprise Survey/New_Comprehensive_July_21_2025.dta"
local sector_crosswalk "${DATADIR}/Intermediate/isic4_broad_groups_codes.dta"
local elasticity_ranking "${DATADIR}/Analysis/cmr_isic4_section_elasticity_ranking.dta"
local elasticity_performance "${DATADIR}/Analysis/cmr_isic4_section_elasticity_performance_scale.dta"
local analysis_out "${DATADIR}/Analysis/bready_wbes_isic4_section_cmr_constraints.dta"

foreach file in "`wbes_source'" ///
    "`sector_crosswalk'" "`elasticity_ranking'" ///
    "`elasticity_performance'" {
    confirm file "`file'"
}

capture log close breadyconstraints
log using "${LOGDIR}/03_bready_wbes_sector_constraints.log", ///
    replace text name(breadyconstraints)

/*******************************************************************************
    1. Assert the live, hand-selected priority universe
*******************************************************************************/

* The reviewed indicators and published benchmarks are coded below. The private
* review workbook supplies an additional selection-count check when available.
local priority_indicators "reg12 disp6 fin27 fin26 fin30 fin33 tr18_u tr20 tr24_u tr25 tr26 in23 wk28 comp1 tax6 in2"
local priority_indicator_count : word count `priority_indicators'
assert `priority_indicator_count' == 16
if fileexists("`priority_workbook'") {
    import excel using "`priority_workbook'", ///
        sheet("enterprise_survey_questions") firstrow clear
    confirm variable Priority
    count if lower(ustrtrim(Priority)) == "yes"
    assert r(N) == `priority_indicator_count'
}
else {
    display as text "Review workbook unavailable: using the 16 reviewed indicators explicitly coded here."
    display as text "National indicator values are still checked against the published benchmarks."
}

/*******************************************************************************
    2. Read official ISIC classes and derive the agreed section comparison groups
*******************************************************************************/

tempfile sector_bridge validation long_firms sector_roster ///
    sector_opportunity sector_results pooled_results

use "`sector_crosswalk'", clear
keep if isic4_level == 4
rename isic4_code class_code
generate int isic4_code = real(class_code)
generate byte isic4_division = real(substr(class_code, 1, 2))
rename isic4_section isic4_official_section
generate str5 isic4_section = isic4_official_section
replace isic4_section = "M+N" if inlist(isic4_official_section, "M", "N")
replace isic4_section = "R+S+T" ///
    if inlist(isic4_official_section, "R", "S") | isic4_division == 97
replace isic4_section = "" if isic4_official_section == "T" & isic4_division != 97
assert missing(isic4_section) if isic4_division == 98
keep isic4_code isic4_division isic4_official_section isic4_section
isid isic4_code
save "`sector_bridge'"

/*******************************************************************************
    3. Load Cameroon WBES firms and merge both sector sources
*******************************************************************************/

use idstd country sample wt d1a2_v4 ///
    g30a h30 k32 k16 k17 k36 k30 ///
    d33a d33b d342 d34 d40a d40b d412 d41 d30b d30a ///
    l30a e1 e31a e31b j38 j40 c6 c7 ///
    using "`wbes_source'", clear

keep if country == "Cameroon2024" & sample == 1
count
assert r(N) == 615
isid idstd
assert wt > 0 & !missing(wt)

rename idstd firm_id
rename wt weight
generate int isic4_code = d1a2_v4
assert isic4_code == d1a2_v4

merge m:1 isic4_code using "`sector_bridge'", keep(master match) generate(sector_bridge_merge)
tabulate sector_bridge_merge, missing
assert sector_bridge_merge != 2
isid firm_id
assert _N == 615
generate byte review_flag = sector_bridge_merge != 3 | missing(isic4_section)
generate str48 mapping_status = cond(review_flag, "Unknown or outside comparison scope", "Official ISIC section comparison group")
drop sector_bridge_merge

merge m:1 isic4_section using "`elasticity_ranking'", ///
    keepusing(isic4_sector_id isic4_label_short_display revenue_decile high_elasticity) ///
    keep(master match) generate(elasticity_merge)
tabulate elasticity_merge, missing
assert elasticity_merge != 2
isid firm_id
preserve
    keep firm_id isic4_code isic4_division isic4_official_section isic4_section ///
        mapping_status review_flag elasticity_merge
    save "${DATADIR}/Analysis/bready_wbes_isic4_section_cmr_mapping_audit.dta", replace
restore
assert elasticity_merge == 1 if review_flag == 1
assert inrange(revenue_decile, 1, 10) if elasticity_merge == 3
assert high_elasticity == (revenue_decile >= 7) if elasticity_merge == 3
generate byte elasticity_eligible = elasticity_merge == 3

quietly count
local wb_firms = r(N)
quietly count if review_flag == 0
local mapped_firms = r(N)
quietly count if review_flag == 1
local review_excluded_firms = r(N)
quietly count if review_flag == 0 & elasticity_eligible == 0
local outside_ranking_firms = r(N)
quietly count if elasticity_eligible == 1
local ranked_firms = r(N)
quietly count if high_elasticity == 1 & review_flag == 0
local high_firms = r(N)

preserve
    keep if elasticity_eligible == 1
    egen byte isic4_sector_id_tag = tag(isic4_sector_id)
    quietly count if isic4_sector_id_tag == 1
    local ranked_sectors = r(N)
    quietly count if isic4_sector_id_tag == 1 & high_elasticity == 1
    local high_sectors = r(N)
restore

matrix mapping_audit = ( ///
    `priority_indicator_count' \ ///
    `wb_firms' \ ///
    `mapped_firms' \ ///
    `review_excluded_firms' \ ///
    `outside_ranking_firms' \ ///
    `ranked_firms' \ ///
    `ranked_sectors' \ ///
    `high_firms' \ ///
    `high_sectors' ///
)
matrix colnames mapping_audit = Value
matrix rownames mapping_audit = priority_indicators wb_firms mapped_firms review_excluded_firms outside_ranking_firms ranked_firms ranked_sectors high_firms high_sectors

esttab matrix(mapping_audit, fmt(%12.0fc)) ///
    using "${OUTPUTDIR}/tables/bready_wbes_isic4_section_cmr_constraints_audit.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels( ///
        priority_indicators "Selected priority indicators" ///
        wb_firms "Cameroon latest-wave WBES firms" ///
        mapped_firms "Firms with official ISIC comparison groups" ///
        review_excluded_firms "Firms with unknown or out-of-scope codes" ///
        outside_ranking_firms "Classified firms outside elasticity ranking" ///
        ranked_firms "Firms eligible for elasticity comparison" ///
        ranked_sectors "ISIC sections in elasticity comparison" ///
        high_firms "Firms in elasticity deciles 7--10" ///
        high_sectors "Mapped sectors in elasticity deciles 7--10" ///
    )

/*******************************************************************************
    4. Construct the sixteen selected indicators

    WBES special negative values are missing. Obstacle responses are converted
    from the 0-4 WBES scale to the 0-100 B-READY index scale.
*******************************************************************************/

foreach var in g30a h30 k32 k16 k17 k36 k30 d33a d33b d342 d34 ///
    d40a d40b d412 d41 d30b d30a l30a e1 e31a e31b j38 j40 c6 c7 {
    replace `var' = . if `var' < 0
}

generate double value_reg12 = 25 * g30a if !missing(g30a)
generate double value_disp6 = 25 * h30 if !missing(h30)
generate double value_fin27 = k32 if !missing(k32)
generate double value_fin26 = 100 * inlist(k17, 2, 3, 4) ///
    if k16 == 2 & inrange(k17, 1, 7)
generate double value_fin30 = k36 if !missing(k36)
generate double value_fin33 = 25 * k30 if !missing(k30)

generate double value_tr18_u = d33a if !missing(d33a)
replace value_tr18_u = d33b / 24 if missing(value_tr18_u) & !missing(d33b)
generate double value_tr20 = d342 if !missing(d342)
replace value_tr20 = d34 if missing(value_tr20) & !missing(d34)
generate double value_tr24_u = d40a if !missing(d40a)
replace value_tr24_u = d40b / 24 if missing(value_tr24_u) & !missing(d40b)
generate double value_tr25 = d412 if !missing(d412)
replace value_tr25 = d41 if missing(value_tr25) & !missing(d41)
generate double value_tr26 = 25 * d30b if !missing(d30b)
generate double value_in23 = 25 * d30a if !missing(d30a)
generate double value_wk28 = 25 * l30a if !missing(l30a)

* The selected market-concentration sources exist in the comprehensive file
* but have no Cameroon responses. Keep the indicator explicitly unavailable.
generate double value_comp1 = .

* Among non-applicants who still report a substantive barrier/no-barrier reason,
* compare long/complicated processing with "other"; firms reporting no need for
* a refund are outside the barrier denominator.
generate double value_tax6 = 100 * inlist(j40, 1, 2) ///
    if inlist(j40, 1, 2, 4)
generate double value_in2 = c7 if !missing(c7)

keep firm_id weight isic4_code isic4_section isic4_sector_id isic4_label_short_display ///
    revenue_decile high_elasticity review_flag mapping_status elasticity_eligible ///
    value_reg12 value_disp6 value_fin27 value_fin26 value_fin30 value_fin33 ///
    value_tr18_u value_tr20 value_tr24_u value_tr25 value_tr26 value_in23 ///
    value_wk28 value_comp1 value_tax6 value_in2

reshape long value_, i(firm_id) j(indicator) string
rename value_ value
levelsof indicator, local(constructed_indicators)
local constructed_count : word count `constructed_indicators'
assert `constructed_count' == `priority_indicator_count'
foreach item of local priority_indicators {
    quietly count if indicator == "`item'"
    assert r(N) == `wb_firms'
}

generate double benchmark = .
replace benchmark = 40.21287004 if indicator == "reg12"
replace benchmark = 41.36882994 if indicator == "disp6"
replace benchmark = 34.27348663 if indicator == "fin27"
replace benchmark = 43.52387891 if indicator == "fin26"
replace benchmark = 2.43586086 if indicator == "fin30"
replace benchmark = 65.89248225 if indicator == "fin33"
replace benchmark = 5.249497526 if indicator == "tr18_u"
replace benchmark = 6.822299802 if indicator == "tr20"
replace benchmark = 7.665937757 if indicator == "tr24_u"
replace benchmark = 17.91927313 if indicator == "tr25"
replace benchmark = 36.23582704 if indicator == "tr26"
replace benchmark = 43.86432462 if indicator == "in23"
replace benchmark = 25.19203466 if indicator == "wk28"
replace benchmark = 89.92508605 if indicator == "comp1"
replace benchmark = 64.17794055 if indicator == "tax6"
replace benchmark = 10.3532987 if indicator == "in2"
assert !missing(benchmark)

generate str32 topic = ""
replace topic = "Business location" if indicator == "reg12"
replace topic = "Dispute resolution" if indicator == "disp6"
replace topic = "Financial services" if inlist(indicator, "fin26", "fin27", "fin30", "fin33")
replace topic = "International trade" if inlist(indicator, "tr18_u", "tr20", "tr24_u", "tr25", "tr26", "in23")
replace topic = "Labor" if indicator == "wk28"
replace topic = "Market competition" if indicator == "comp1"
replace topic = "Taxation" if indicator == "tax6"
replace topic = "Utility services" if indicator == "in2"
assert !missing(topic)

generate str100 indicator_label = ""
replace indicator_label = "Access to land constraint index" if indicator == "reg12"
replace indicator_label = "Courts constraint index" if indicator == "disp6"
replace indicator_label = "Loan decision time" if indicator == "fin27"
replace indicator_label = "Discouraged loan applicants" if indicator == "fin26"
replace indicator_label = "Cost to receive e-payments" if indicator == "fin30"
replace indicator_label = "Access to finance constraint index" if indicator == "fin33"
replace indicator_label = "Export border-compliance time" if indicator == "tr18_u"
replace indicator_label = "Export compliance cost" if indicator == "tr20"
replace indicator_label = "Import border-compliance time" if indicator == "tr24_u"
replace indicator_label = "Import compliance cost" if indicator == "tr25"
replace indicator_label = "Customs/trade constraint index" if indicator == "tr26"
replace indicator_label = "Transport constraint index" if indicator == "in23"
replace indicator_label = "Labor-regulation constraint index" if indicator == "wk28"
replace indicator_label = "Largest competitor market share" if indicator == "comp1"
replace indicator_label = "VAT refund process barrier" if indicator == "tax6"
replace indicator_label = "Electrical outages per month" if indicator == "in2"
assert !missing(indicator_label)

generate str36 unit = "Percent / index (0-100)"
replace unit = "Days" if inlist(indicator, "fin27", "tr18_u", "tr24_u")
replace unit = "Percent of transaction/value" if inlist(indicator, "fin30", "tr20", "tr25")
replace unit = "Outages per month" if indicator == "in2"

sort firm_id indicator
isid firm_id indicator
save "`long_firms'"

/*******************************************************************************
    5. National benchmark validation
*******************************************************************************/

preserve
    bysort indicator: egen int sample_n = total(!missing(value))
    collapse (mean) national_estimate=value benchmark ///
        (max) sample_n [pw=weight], by(indicator topic indicator_label unit)
    generate double abs_difference = abs(national_estimate - benchmark)
    generate byte validated = abs_difference <= 2 if sample_n > 0
    replace validated = 0 if missing(validated)
    sort indicator
    isid indicator
    save "`validation'"

    generate str20 rowname = "indicator_" + string(_n)
    mkmat sample_n national_estimate benchmark abs_difference validated, ///
        matrix(indicator_validation) rownames(rowname)
    matrix colnames indicator_validation = N Estimate Benchmark AbsDiff Validated

    local validation_rowlabels
    quietly count
    forvalues i = 1/`r(N)' {
        local label = subinstr(indicator_label[`i'], "&", "\&", .)
        local validation_rowlabels `validation_rowlabels' `=rowname[`i']' "`label'"
    }

    esttab matrix(indicator_validation, fmt(%9.0fc %9.2f %9.2f %9.2f %9.0f)) ///
        using "${OUTPUTDIR}/tables/bready_wbes_isic4_section_cmr_indicator_validation.tex", ///
        replace booktabs fragment nomtitles nonumbers ///
        collabels("N" "WBES estimate" "B-READY value" "Absolute difference" "Validated") ///
        varlabels(`validation_rowlabels')
restore

/*******************************************************************************
    6. Sector and pooled descriptive estimates
*******************************************************************************/

use "`long_firms'", clear
keep if elasticity_eligible == 1
assert !missing(isic4_sector_id, revenue_decile, high_elasticity)
save "`long_firms'", replace

preserve
    keep indicator topic indicator_label unit benchmark isic4_section isic4_sector_id ///
        isic4_label_short_display revenue_decile high_elasticity
    bysort indicator isic4_sector_id: keep if _n == 1
    isid indicator isic4_sector_id
    quietly count
    assert r(N) == `priority_indicator_count' * `ranked_sectors'
    save "`sector_roster'"
restore

* Fix employment-size groups once on the observed section-group comparison universe. These
* groups and their legend ranges are therefore identical for every indicator.
preserve
    keep isic4_section isic4_sector_id isic4_label_short_display
    bysort isic4_sector_id: keep if _n == 1
    sort isic4_sector_id
    isid isic4_sector_id
    quietly count
    assert r(N) == `ranked_sectors'

    merge 1:1 isic4_section using "`elasticity_performance'", ///
        keepusing(tot_rev_elasticity avg_annual_total_employment) ///
        keep(master match) generate(performance_merge)
    assert performance_merge == 3
    drop performance_merge
    assert !missing(tot_rev_elasticity)
    assert avg_annual_total_employment > 0 ///
        & !missing(avg_annual_total_employment)

    sort avg_annual_total_employment isic4_sector_id
    generate byte employment_size_tercile = ceil(3 * _n / _N)
    assert inrange(employment_size_tercile, 1, 3)

    forvalues size_group = 1/3 {
        quietly count if employment_size_tercile == `size_group'
        local employment_group_n_`size_group' = r(N)
    }
    local employment_group_min = min(`employment_group_n_1', ///
        `employment_group_n_2', `employment_group_n_3')
    local employment_group_max = max(`employment_group_n_1', ///
        `employment_group_n_2', `employment_group_n_3')
    assert `employment_group_max' - `employment_group_min' <= 1

    label variable tot_rev_elasticity ///
        "Administrative total-revenue employment elasticity"
    label variable avg_annual_total_employment ///
        "Average annual total sector employment"
    label variable employment_size_tercile ///
        "Fixed employment-size tercile among overlapping section groups"
    save "`sector_opportunity'"
restore

local zcrit = invnormal(.975)
levelsof indicator, local(estimate_indicators)
levelsof isic4_sector_id, local(estimate_sectors)

tempname sector_handle
postfile `sector_handle' str12 indicator int isic4_sector_id ///
    double estimate se ci_low ci_high int sample_n ///
    using "`sector_results'", replace

foreach item of local estimate_indicators {
    foreach sector of local estimate_sectors {
        quietly count if indicator == "`item'" & isic4_sector_id == `sector' ///
            & !missing(value) & weight > 0
        local cell_n = r(N)
        local cell_estimate = .
        local cell_se = .
        local cell_ci_low = .
        local cell_ci_high = .
        local cell_variance = .

        if `cell_n' > 0 {
            capture quietly mean value [pweight = weight] ///
                if indicator == "`item'" & isic4_sector_id == `sector' ///
                & !missing(value) & weight > 0

            if !_rc {
                matrix cell_b = e(b)
                local cell_estimate = cell_b[1,1]

                capture matrix cell_v = e(V)
                local variance_rc = _rc
                if !`variance_rc' {
                    local cell_variance = cell_v[1,1]
                }
                if !`variance_rc' & `cell_variance' >= 0 ///
                    & !missing(`cell_variance') {
                    local cell_se = sqrt(`cell_variance')
                    local cell_ci_low = `cell_estimate' - `zcrit' * `cell_se'
                    local cell_ci_high = `cell_estimate' + `zcrit' * `cell_se'
                }
            }
            else {
                * A one-observation cell can have a weighted mean but no
                * estimable sampling variance.
                quietly summarize value [aweight = weight] ///
                    if indicator == "`item'" & isic4_sector_id == `sector' ///
                    & !missing(value) & weight > 0, meanonly
                local cell_estimate = r(mean)
            }
        }

        post `sector_handle' ("`item'") (`sector') ///
            (`cell_estimate') (`cell_se') (`cell_ci_low') (`cell_ci_high') ///
            (`cell_n')
    }
}
postclose `sector_handle'

use "`sector_results'", clear
merge 1:1 indicator isic4_sector_id using "`sector_roster'", assert(match) nogen
merge m:1 indicator using "`validation'", ///
    keepusing(national_estimate abs_difference validated) assert(match) nogen
merge m:1 isic4_sector_id using "`sector_opportunity'", ///
    keepusing(tot_rev_elasticity avg_annual_total_employment ///
        employment_size_tercile) assert(match) nogen
assert !missing(tot_rev_elasticity, avg_annual_total_employment, ///
    employment_size_tercile)
replace se = . if sample_n < 2
replace ci_low = . if sample_n < 2
replace ci_high = . if sample_n < 2
generate byte ci_available = !missing(se, ci_low, ci_high)
generate byte small_cell = inrange(sample_n, 1, 9)
generate byte suppressed = missing(estimate) | validated != 1
generate str12 result_level = "sector"
sort indicator isic4_sector_id
isid indicator isic4_sector_id
save "`sector_results'", replace

use "`long_firms'", clear
tempname pooled_handle
postfile `pooled_handle' str12 indicator byte high_elasticity ///
    double estimate se ci_low ci_high int sample_n ///
    using "`pooled_results'", replace

foreach item of local estimate_indicators {
    forvalues high_group = 0/1 {
        quietly count if indicator == "`item'" ///
            & high_elasticity == `high_group' & !missing(value) & weight > 0
        local cell_n = r(N)
        local cell_estimate = .
        local cell_se = .
        local cell_ci_low = .
        local cell_ci_high = .
        local cell_variance = .

        if `cell_n' > 0 {
            capture quietly mean value [pweight = weight] ///
                if indicator == "`item'" ///
                & high_elasticity == `high_group' ///
                & !missing(value) & weight > 0

            if !_rc {
                matrix cell_b = e(b)
                local cell_estimate = cell_b[1,1]

                capture matrix cell_v = e(V)
                local variance_rc = _rc
                if !`variance_rc' {
                    local cell_variance = cell_v[1,1]
                }
                if !`variance_rc' & `cell_variance' >= 0 ///
                    & !missing(`cell_variance') {
                    local cell_se = sqrt(`cell_variance')
                    local cell_ci_low = `cell_estimate' - `zcrit' * `cell_se'
                    local cell_ci_high = `cell_estimate' + `zcrit' * `cell_se'
                }
            }
            else {
                quietly summarize value [aweight = weight] ///
                    if indicator == "`item'" ///
                    & high_elasticity == `high_group' ///
                    & !missing(value) & weight > 0, meanonly
                local cell_estimate = r(mean)
            }
        }

        post `pooled_handle' ("`item'") (`high_group') ///
            (`cell_estimate') (`cell_se') (`cell_ci_low') (`cell_ci_high') ///
            (`cell_n')
    }
}
postclose `pooled_handle'

use "`pooled_results'", clear
merge m:1 indicator using "`validation'", ///
    keepusing(topic indicator_label unit benchmark national_estimate ///
        abs_difference validated) assert(match) nogen
replace se = . if sample_n < 2
replace ci_low = . if sample_n < 2
replace ci_high = . if sample_n < 2
generate byte ci_available = !missing(se, ci_low, ci_high)
generate byte small_cell = inrange(sample_n, 1, 9)
generate byte suppressed = missing(estimate) | validated != 1
generate str12 result_level = "pooled"
generate int isic4_sector_id = .
generate byte revenue_decile = .
generate str100 isic4_label_short_display = ///
    cond(high_elasticity == 1, "High elasticity (deciles 7-10)", "Other mapped sectors")

append using "`sector_results'"
recast double estimate se ci_low ci_high
order result_level indicator topic indicator_label unit isic4_sector_id ///
    isic4_label_short_display revenue_decile high_elasticity estimate se ///
    ci_low ci_high ci_available sample_n small_cell benchmark ///
    national_estimate abs_difference validated suppressed ///
    tot_rev_elasticity avg_annual_total_employment employment_size_tercile
sort indicator result_level high_elasticity isic4_sector_id
save "`analysis_out'", replace

* Every indicator keeps the complete observed section-group comparison roster.
quietly count if result_level == "sector"
assert r(N) == `priority_indicator_count' * `ranked_sectors'
bysort indicator result_level: assert _N == `ranked_sectors' if result_level == "sector"
assert high_elasticity == (revenue_decile >= 7) if result_level == "sector"
bysort isic4_sector_id (employment_size_tercile): assert ///
    employment_size_tercile == employment_size_tercile[1] ///
    if result_level == "sector"
assert !missing(tot_rev_elasticity, avg_annual_total_employment, ///
    employment_size_tercile) if result_level == "sector"

levelsof indicator if result_level == "sector" & validated == 1, ///
    local(validated_indicators)
local validated_indicator_count : word count `validated_indicators'
assert `validated_indicator_count' == 14

quietly count if result_level == "sector"
local sector_result_rows = r(N)
quietly count if result_level == "sector" & validated == 1 ///
    & small_cell == 1 & !missing(estimate)
local displayed_small_cells = r(N)
quietly count if result_level == "sector" & validated == 1 & sample_n == 0
local displayed_zero_response_rows = r(N)
quietly count if result_level == "sector" & validated == 1 ///
    & !missing(estimate) & ci_available == 0
local points_without_intervals = r(N)

matrix final_audit = ( ///
    `priority_indicator_count' \ ///
    `validated_indicator_count' \ ///
    `wb_firms' \ ///
    `mapped_firms' \ ///
    `review_excluded_firms' \ ///
    `outside_ranking_firms' \ ///
    `ranked_firms' \ ///
    `ranked_sectors' \ ///
    `high_firms' \ ///
    `high_sectors' \ ///
    `sector_result_rows' \ ///
    `displayed_small_cells' \ ///
    `displayed_zero_response_rows' \ ///
    `points_without_intervals' ///
)
matrix colnames final_audit = Value
matrix rownames final_audit = priority_indicators validated_indicators ///
    wb_firms mapped_firms review_excluded_firms outside_ranking_firms ///
    ranked_firms ranked_sectors high_firms high_sectors sector_result_rows ///
    displayed_small_cells displayed_zero_response_rows ///
    points_without_intervals

esttab matrix(final_audit, fmt(%12.0fc)) ///
    using "${OUTPUTDIR}/tables/bready_wbes_isic4_section_cmr_constraints_audit.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels( ///
        priority_indicators "Selected priority indicators" ///
        validated_indicators "Nationally validated indicators plotted" ///
        wb_firms "Cameroon latest-wave WBES firms" ///
        mapped_firms "Firms with official ISIC comparison groups" ///
        review_excluded_firms "Firms with unknown or out-of-scope codes" ///
        outside_ranking_firms "Classified firms outside elasticity ranking" ///
        ranked_firms "Firms eligible for elasticity comparison" ///
        ranked_sectors "ISIC sections in elasticity comparison" ///
        high_firms "Firms in elasticity deciles 7--10" ///
        high_sectors "Mapped sectors in elasticity deciles 7--10" ///
        sector_result_rows "Indicator-sector rows retained" ///
        displayed_small_cells "Displayed estimates with 1--9 firms" ///
        displayed_zero_response_rows "Displayed zero-response sector rows" ///
        points_without_intervals "Displayed points without estimable intervals" ///
    )

/*******************************************************************************
    7. Employment-opportunity bubbles for nationally validated indicators
*******************************************************************************/

keep if result_level == "sector" & validated == 1
bysort indicator: assert _N == `ranked_sectors'
levelsof indicator, local(plot_indicators)
local plotted_indicator_count : word count `plot_indicators'
assert `plotted_indicator_count' == 14

* Calculate the three employment legend ranges once from unique sectors.
preserve
    keep isic4_sector_id avg_annual_total_employment employment_size_tercile
    bysort isic4_sector_id: keep if _n == 1
    isid isic4_sector_id
    quietly count
    assert r(N) == `ranked_sectors'
    forvalues size_group = 1/3 {
        quietly summarize avg_annual_total_employment ///
            if employment_size_tercile == `size_group', meanonly
        local employment_min_`size_group' = ///
            trim(string(r(min), "%12.0fc"))
        local employment_max_`size_group' = ///
            trim(string(r(max), "%12.0fc"))
    }
restore

local exported_figure_pairs = 0
foreach item of local plot_indicators {
    preserve
        keep if indicator == "`item'"
        generate byte plot_ready = !missing(estimate, tot_rev_elasticity, ///
            avg_annual_total_employment, employment_size_tercile, benchmark)
        assert plot_ready == 0 if missing(estimate)
        assert !missing(estimate, tot_rev_elasticity, ///
            avg_annual_total_employment, employment_size_tercile, benchmark) ///
            if plot_ready == 1
        quietly count if plot_ready == 1
        local usable_groups = r(N)
        assert `usable_groups' > 0

        generate byte opportunity = plot_ready == 1 & high_elasticity == 1
        gsort -plot_ready -avg_annual_total_employment isic4_sector_id
        generate int employment_rank = _n if plot_ready == 1
        generate byte label_sector = plot_ready == 1 ///
            & (opportunity == 1 | employment_rank <= 2)
        quietly count if plot_ready == 1 & employment_rank <= 2
        assert r(N) == min(2, `usable_groups')
        generate str100 plot_label = isic4_label_short_display ///
            if label_sector == 1
        * Keep labels inside the panel; right-side points use left-facing labels.
        quietly summarize estimate if plot_ready == 1, meanonly
        local label_midpoint = (r(min) + r(max))/2
        local xpadding = max((r(max) - r(min))*.08, 1)
        local plot_xmin = r(min) - `xpadding'
        local plot_xmax = r(max) + `xpadding'
        generate byte label_position = 3 if label_sector == 1
        replace label_position = 9 if label_sector == 1 & estimate >= `label_midpoint'

        local benchmark_value = benchmark[1]
        local plot_title = indicator_label[1]
        local plot_unit = unit[1]

        twoway ///
            (scatter tot_rev_elasticity estimate ///
                if plot_ready == 1 & employment_size_tercile == 1 ///
                & opportunity == 0, msymbol(O) msize(small) ///
                mcolor("92 105 118") mlcolor(white)) ///
            (scatter tot_rev_elasticity estimate ///
                if plot_ready == 1 & employment_size_tercile == 2 ///
                & opportunity == 0, msymbol(O) msize(medlarge) ///
                mcolor("92 105 118") mlcolor(white)) ///
            (scatter tot_rev_elasticity estimate ///
                if plot_ready == 1 & employment_size_tercile == 3 ///
                & opportunity == 0, msymbol(O) msize(huge) ///
                mcolor("92 105 118") mlcolor(white)) ///
            (scatter tot_rev_elasticity estimate ///
                if plot_ready == 1 & employment_size_tercile == 1 ///
                & opportunity == 1, msymbol(O) msize(small) ///
                mcolor("213 94 0") mlcolor(white)) ///
            (scatter tot_rev_elasticity estimate ///
                if plot_ready == 1 & employment_size_tercile == 2 ///
                & opportunity == 1, msymbol(O) msize(medlarge) ///
                mcolor("213 94 0") mlcolor(white)) ///
            (scatter tot_rev_elasticity estimate ///
                if plot_ready == 1 & employment_size_tercile == 3 ///
                & opportunity == 1, msymbol(O) msize(huge) ///
                mcolor("213 94 0") mlcolor(white)) ///
            (scatter tot_rev_elasticity estimate ///
                if label_sector == 1 & opportunity == 0, ///
                msymbol(none) mlabel(plot_label) mlabvposition(label_position) ///
                mlabsize(vsmall) mlabcolor("65 75 85")) ///
            (scatter tot_rev_elasticity estimate ///
                if label_sector == 1 & opportunity == 1, ///
                msymbol(none) mlabel(plot_label) mlabvposition(label_position) ///
                mlabsize(vsmall) mlabcolor("180 70 0")), ///
            xline(`benchmark_value', lcolor("0 114 178") ///
                lpattern(dash) lwidth(medthin)) ///
            yline(0, lcolor(gs8) lpattern(shortdash) lwidth(thin)) ///
            xscale(range(`plot_xmin' `plot_xmax')) ///
            xlabel(, grid glpattern(dash) glcolor(gs13)) ///
            ylabel(, grid glpattern(dash) glcolor(gs13)) ///
            ytitle("Ecofin section revenue elasticity", size(small)) ///
            xtitle("WBES-weighted section estimate (`plot_unit')", size(small)) ///
            title("`plot_title'", size(medsmall)) ///
            legend(order(1 "Small: `employment_min_1'-`employment_max_1'" ///
                2 "Middle: `employment_min_2'-`employment_max_2'" ///
                3 "Large: `employment_min_3'-`employment_max_3'") ///
                title("Average annual total employment", size(vsmall)) ///
                rows(1) pos(6) size(vsmall) ///
                region(lcolor(none) fcolor(none))) ///
            note("Dashed vertical line: published Cameroon B-READY benchmark. Orange: revenue elasticity deciles 7-10." ///
                "Descriptive; sections without responses omitted. Sector coverage may differ across datasets." ///
                "ISIC Rev.4 sections based on the NACAM-ISIC Rev.4 crosswalk." "Combined: professional & admin. support; arts/recreation, other services & household employers (division 97)." "Sizes are employment terciles. * Includes branches spanning sections; see classification notes.", ///
                size(tiny)) ///
            graphregion(color(white)) plotregion(color(white)) ///
            bgcolor(white) xsize(7.5) ysize(5.5)

        graph export ///
            "${OUTPUTDIR}/figures/bready_wbes_isic4_section_cmr_`item'_high_elasticity.pdf", name(Graph) replace
        graph export "${OUTPUTDIR}/figures/bready_wbes_isic4_section_cmr_`item'_high_elasticity.png", name(Graph) ///
            replace width(2400)
        confirm file ///
            "${OUTPUTDIR}/figures/bready_wbes_isic4_section_cmr_`item'_high_elasticity.pdf"
        confirm file ///
            "${OUTPUTDIR}/figures/bready_wbes_isic4_section_cmr_`item'_high_elasticity.png"
        local ++exported_figure_pairs
    restore
}
assert `exported_figure_pairs' == 14

display as result "Saved B-READY/WBES constraint results to `analysis_out'."
display as result "Generated 14 validated employment-opportunity figure pairs."
log close breadyconstraints
