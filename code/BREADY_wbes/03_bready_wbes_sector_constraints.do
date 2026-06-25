version 17.0
clear all
set more off

/*******************************************************************************
    Purpose:
        Construct weighted Cameroon WBES constraint indicators selected in the
        B-READY review workbook and compare harmonized NACAM sectors in
        employment-opportunity bubble charts.

    Unit of observation:
        Input: latest-wave Cameroon WBES firm.
        Output: indicator-by-NACAM-sector and indicator-by-high-elasticity group.

    Inputs:
        Data/B-Ready/Raw/2025/bready_enterprise_survey_questions.xlsx
        Data/World Bank Enterprise Survey/New_Comprehensive_July_21_2025.dta
        docs/reference/cmr_wbes_isic4_nacam_crosswalk.xlsx
        Data/Analysis/cmr_nacam_elasticity_ranking.dta
        Data/Analysis/cmr_nacam_elasticity_performance_scale.dta

    Outputs:
        Data/Analysis/bready_wbes_sector_constraints_cmr.dta
        output/tables/bready_wbes_sector_constraints_cmr_audit.tex
        output/tables/bready_wbes_indicator_validation_cmr.tex
        output/figures/bready_wbes_cmr_*_high_elasticity.{pdf,png}
        logs/03_bready_wbes_sector_constraints.log

    Notes:
        Results are weighted descriptive comparisons, not causal estimates.
        Bubble area represents average annual total sector employment, not WBES
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
local sector_crosswalk "${PROJECT_ROOT}/docs/reference/cmr_wbes_isic4_nacam_crosswalk.xlsx"
local elasticity_ranking "${DATADIR}/Analysis/cmr_nacam_elasticity_ranking.dta"
local elasticity_performance "${DATADIR}/Analysis/cmr_nacam_elasticity_performance_scale.dta"
local analysis_out "${DATADIR}/Analysis/bready_wbes_sector_constraints_cmr.dta"

foreach file in "`priority_workbook'" "`wbes_source'" ///
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

import excel using "`priority_workbook'", ///
    sheet("enterprise_survey_questions") firstrow clear
confirm variable Priority
count if lower(ustrtrim(Priority)) == "yes"
assert r(N) == 16
local priority_indicator_count = r(N)

/*******************************************************************************
    2. Import the reviewed four-digit ISIC-to-NACAM crosswalk
*******************************************************************************/

tempfile sector_bridge validation long_firms sector_roster ///
    sector_opportunity sector_results pooled_results

import excel using "`sector_crosswalk'", ///
    sheet("isic4_nacam_crosswalk") cellrange(A4) firstrow clear
confirm variable isic4_code cameroon_firms nacam mapping_status review_flag
isid isic4_code
assert inlist(review_flag, 0, 1)
assert missing(nacam) if review_flag == 1
assert !missing(nacam, nacam_label_short_display) if review_flag == 0
quietly summarize cameroon_firms, meanonly
assert r(sum) == 615
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

merge m:1 isic4_code using "`sector_bridge'", generate(sector_bridge_merge)
assert sector_bridge_merge == 3
drop sector_bridge_merge

merge m:1 nacam using "`elasticity_ranking'", ///
    keep(master match) generate(elasticity_merge)
assert elasticity_merge != 2
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
    egen byte nacam_tag = tag(nacam)
    quietly count if nacam_tag == 1
    local ranked_sectors = r(N)
    quietly count if nacam_tag == 1 & high_elasticity == 1
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
    using "${OUTPUTDIR}/tables/bready_wbes_sector_constraints_cmr_audit.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels( ///
        priority_indicators "Selected priority indicators" ///
        wb_firms "Cameroon latest-wave WBES firms" ///
        mapped_firms "Firms with unique NACAM mapping" ///
        review_excluded_firms "Firms excluded for mapping review" ///
        outside_ranking_firms "Uniquely mapped firms outside elasticity ranking" ///
        ranked_firms "Firms eligible for elasticity comparison" ///
        ranked_sectors "NACAM sectors in elasticity comparison" ///
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

keep firm_id weight isic4_code nacam nacam_label_short_display ///
    revenue_decile high_elasticity review_flag mapping_status elasticity_eligible ///
    value_reg12 value_disp6 value_fin27 value_fin26 value_fin30 value_fin33 ///
    value_tr18_u value_tr20 value_tr24_u value_tr25 value_tr26 value_in23 ///
    value_wk28 value_comp1 value_tax6 value_in2

reshape long value_, i(firm_id) j(indicator) string
rename value_ value

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
        using "${OUTPUTDIR}/tables/bready_wbes_indicator_validation_cmr.tex", ///
        replace booktabs fragment nomtitles nonumbers ///
        collabels("N" "WBES estimate" "B-READY value" "Absolute difference" "Validated") ///
        varlabels(`validation_rowlabels')
restore

/*******************************************************************************
    6. Sector and pooled descriptive estimates
*******************************************************************************/

use "`long_firms'", clear
keep if elasticity_eligible == 1
assert !missing(nacam, revenue_decile, high_elasticity)
save "`long_firms'", replace

preserve
    keep indicator topic indicator_label unit benchmark nacam ///
        nacam_label_short_display revenue_decile high_elasticity
    bysort indicator nacam: keep if _n == 1
    isid indicator nacam
    quietly count
    assert r(N) == 16 * 16
    save "`sector_roster'"
restore

* Fix employment-size groups once on the 16-sector comparison universe. These
* groups and their legend ranges are therefore identical for every indicator.
preserve
    keep nacam nacam_label_short_display
    bysort nacam: keep if _n == 1
    sort nacam
    isid nacam
    quietly count
    assert r(N) == 16

    merge 1:1 nacam using "`elasticity_performance'", ///
        keepusing(tot_rev_elasticity avg_annual_total_employment) ///
        keep(master match) generate(performance_merge)
    assert performance_merge == 3
    drop performance_merge
    assert !missing(tot_rev_elasticity)
    assert avg_annual_total_employment > 0 ///
        & !missing(avg_annual_total_employment)

    sort avg_annual_total_employment nacam
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
        "Fixed employment-size tercile among 16 overlapping sectors"
    save "`sector_opportunity'"
restore

local zcrit = invnormal(.975)
levelsof indicator, local(estimate_indicators)
levelsof nacam, local(estimate_sectors)

tempname sector_handle
postfile `sector_handle' str12 indicator int nacam ///
    double estimate se ci_low ci_high int sample_n ///
    using "`sector_results'", replace

foreach item of local estimate_indicators {
    foreach sector of local estimate_sectors {
        quietly count if indicator == "`item'" & nacam == `sector' ///
            & !missing(value) & weight > 0
        local cell_n = r(N)
        local cell_estimate = .
        local cell_se = .
        local cell_ci_low = .
        local cell_ci_high = .
        local cell_variance = .

        if `cell_n' > 0 {
            capture quietly mean value [pweight = weight] ///
                if indicator == "`item'" & nacam == `sector' ///
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
                    if indicator == "`item'" & nacam == `sector' ///
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
merge 1:1 indicator nacam using "`sector_roster'", assert(match) nogen
merge m:1 indicator using "`validation'", ///
    keepusing(national_estimate abs_difference validated) assert(match) nogen
merge m:1 nacam using "`sector_opportunity'", ///
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
sort indicator nacam
isid indicator nacam
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
generate int nacam = .
generate byte revenue_decile = .
generate str40 nacam_label_short_display = ///
    cond(high_elasticity == 1, "High elasticity (deciles 7-10)", "Other mapped sectors")

append using "`sector_results'"
recast double estimate se ci_low ci_high
order result_level indicator topic indicator_label unit nacam ///
    nacam_label_short_display revenue_decile high_elasticity estimate se ///
    ci_low ci_high ci_available sample_n small_cell benchmark ///
    national_estimate abs_difference validated suppressed ///
    tot_rev_elasticity avg_annual_total_employment employment_size_tercile
sort indicator result_level high_elasticity nacam
save "`analysis_out'", replace

* Every indicator keeps the complete 16-sector comparison roster.
quietly count if result_level == "sector"
assert r(N) == 16 * 16
bysort indicator result_level: assert _N == 16 if result_level == "sector"
assert high_elasticity == (revenue_decile >= 7) if result_level == "sector"
bysort nacam (employment_size_tercile): assert ///
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
    using "${OUTPUTDIR}/tables/bready_wbes_sector_constraints_cmr_audit.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels( ///
        priority_indicators "Selected priority indicators" ///
        validated_indicators "Nationally validated indicators plotted" ///
        wb_firms "Cameroon latest-wave WBES firms" ///
        mapped_firms "Firms with unique NACAM mapping" ///
        review_excluded_firms "Firms excluded for mapping review" ///
        outside_ranking_firms "Uniquely mapped firms outside elasticity ranking" ///
        ranked_firms "Firms eligible for elasticity comparison" ///
        ranked_sectors "NACAM sectors in elasticity comparison" ///
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
bysort indicator: assert _N == 16
levelsof indicator, local(plot_indicators)
local plotted_indicator_count : word count `plot_indicators'
assert `plotted_indicator_count' == 14

* Calculate the three employment legend ranges once from unique sectors.
preserve
    keep nacam avg_annual_total_employment employment_size_tercile
    bysort nacam: keep if _n == 1
    isid nacam
    quietly count
    assert r(N) == 16
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
        assert r(N) > 0

        generate byte opportunity = plot_ready == 1 & high_elasticity == 1
        gsort -plot_ready -avg_annual_total_employment nacam
        generate int employment_rank = _n if plot_ready == 1
        generate byte label_sector = plot_ready == 1 ///
            & (opportunity == 1 | employment_rank <= 2)
        quietly count if plot_ready == 1 & employment_rank <= 2
        assert r(N) == 2
        generate str40 plot_label = nacam_label_short_display ///
            if label_sector == 1
        generate byte label_position = 12 if label_sector == 1
        replace label_position = 9 if employment_rank == 1
        replace label_position = 3 if employment_rank == 2
        replace label_position = 3 if opportunity == 1 ///
            & employment_rank > 2 & mod(nacam, 4) == 0
        replace label_position = 9 if opportunity == 1 ///
            & employment_rank > 2 & mod(nacam, 4) == 2
        replace label_position = 6 if opportunity == 1 ///
            & employment_rank > 2 & mod(nacam, 4) == 3

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
            xlabel(, grid glpattern(dash) glcolor(gs13)) ///
            ylabel(, grid glpattern(dash) glcolor(gs13)) ///
            ytitle("Administrative revenue elasticity", size(small)) ///
            xtitle("WBES-weighted sector estimate (`plot_unit')", size(small)) ///
            title("`plot_title'", size(medsmall)) ///
            legend(order(1 "Small: `employment_min_1'-`employment_max_1'" ///
                2 "Middle: `employment_min_2'-`employment_max_2'" ///
                3 "Large: `employment_min_3'-`employment_max_3'") ///
                title("Average annual total employment", size(vsmall)) ///
                rows(1) pos(6) size(vsmall) ///
                region(lcolor(none) fcolor(none))) ///
            note("Dashed vertical line: published Cameroon B-READY benchmark. Orange: revenue elasticity deciles 7-10." ///
                "Descriptive; sectors without indicator responses omitted.", ///
                size(tiny)) ///
            graphregion(color(white)) plotregion(color(white)) ///
            bgcolor(white) xsize(7.5) ysize(5.5)

        graph export ///
            "${OUTPUTDIR}/figures/bready_wbes_cmr_`item'_high_elasticity.pdf", replace
        graph export "${OUTPUTDIR}/figures/bready_wbes_cmr_`item'_high_elasticity.png", ///
            replace width(2400)
        confirm file ///
            "${OUTPUTDIR}/figures/bready_wbes_cmr_`item'_high_elasticity.pdf"
        confirm file ///
            "${OUTPUTDIR}/figures/bready_wbes_cmr_`item'_high_elasticity.png"
        local ++exported_figure_pairs
    restore
}
assert `exported_figure_pairs' == 14

display as result "Saved B-READY/WBES constraint results to `analysis_out'."
display as result "Generated 14 validated employment-opportunity figure pairs."
log close breadyconstraints
