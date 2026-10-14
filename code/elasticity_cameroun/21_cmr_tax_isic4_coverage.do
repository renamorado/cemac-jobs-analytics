version 17.0
set more off
args assessment
assert inlist("`assessment'", "", "rev1")
local suffix
local panel_suffix
local extra_metrics
local coverage_groups mapped preliminary gained lost changed
if "`assessment'" == "rev1" {
    local suffix "_rev1"
    local panel_suffix "_rev1_assessment"
    local coverage_groups `coverage_groups' combined partial pending covered
    local extra_metrics combined_employment partial_employment pending_employment covered_employment ///
        combined_revenue partial_revenue pending_revenue covered_revenue
}

/*******************************************************************************
    Audit reviewed tax classifications without changing either input dataset.
    Run after 20_cmr_tax_isic4_merge.do, using the existing project setup.

    Coverage is descriptive and unweighted. A covered firm/category has at least
    one covered record in the reported group; firms may occur in several groups.
    Employment summed over years is a firm-year employment total, not workers.
    Revenue retains the units of tot_rev in the input data.
*******************************************************************************/

if "${PROJECT_ROOT}" == "" {
    do "code/01_setup.do"
}
capture mkdir "${OUTPUTDIR}/checks"
capture mkdir "${OUTPUTDIR}/checks/tax_isic4`suffix'"
local checkdir "${OUTPUTDIR}/checks/tax_isic4`suffix'"
capture log close taxcoverage
log using "${LOGDIR}/21_cmr_tax_isic4_coverage`suffix'.log", text replace name(taxcoverage)

tempfile previous prepared summaries keyaudit valuesaudit changes
tempname keypost valuepost summarytable
postfile `keypost' str7 sample long records missing_firmid missing_year ///
    missing_nacam duplicate_records duplicate_groups excess_records ///
    using "`keyaudit'", replace
postfile `valuepost' str7 sample str12 variable long records valid_records ///
    zero_records negative_records missing_records parse_failed_records ///
    trailing_minus_adjusted double excluded_negative_sum using "`valuesaudit'", replace

* The earlier correspondence is only a comparison, never an assignment source.
if "`assessment'" == "rev1" {
    import delimited using "${PROJECT_ROOT}/docs/reference/cmr_tax_isic4_decisions.csv", clear varnames(1) stringcols(_all)
    destring nacam, replace
    keep nacam isic4_division
    rename isic4_division audit_old_division
}
else {
    use "${DATADIR}/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta", clear
    keep nacam isic_rev4_division
    rename isic_rev4_division audit_old_division
}
isid nacam
save "`previous'"

local divisions 01 02 03 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 ///
    20 21 22 23 24 25 26 27 28 29 30 31 32 33 35 36 37 38 39 41 42 43 ///
    45 46 47 49 50 51 52 53 55 56 58 59 60 61 62 63 64 65 66 68 69 70 ///
    71 72 73 74 75 77 78 79 80 81 82 84 85 86 87 88 90 91 92 93 94 95 ///
    96 97 98 99

matrix `summarytable' = J(11, 2, .)
matrix rownames `summarytable' = records firms categories mapped_records ///
    record_pct firm_pct category_pct employment_pct revenue_pct gained_records lost_records
matrix colnames `summarytable' = Source Cleaned
tempname grouptable
matrix `grouptable' = J(12, 2, .)
matrix rownames `grouptable' = single_records combined_records partial_records pending_records ///
    single_pct combined_pct partial_pct pending_pct covered_pct covered_firms_pct covered_emp_pct covered_rev_pct
matrix colnames `grouptable' = Source Cleaned
local first_summary 1
local column 0

foreach sample in source cleaned {
    local ++column
    if "`sample'" == "source" {
        use "${DATADIR}/Intermediate/cmr_tax_isic4_source_audit`suffix'.dta", clear
    }
    else {
        use "${DATADIR}/Analysis/CMR_BDF_isic4`panel_suffix'.dta", clear
        isid firmid fin_yr
    }
    confirm variable firmid fin_yr nacam totemp tot_rev isic4_division isic4_status
    * Source row breaks duplicate-key ties; cleaned inputs are unique firm-years.
    generate long audit_row = _n
    local n = _N
    if "`assessment'" == "rev1" assert revision_assumed == 1 if !missing(nacam)
    quietly count if missing(firmid)
    local missing_firmid = r(N)
    quietly count if missing(fin_yr)
    local missing_year = r(N)
    quietly count if missing(nacam)
    local missing_nacam = r(N)
    sort firmid fin_yr
    by firmid fin_yr: generate long audit_key_n = _N
    egen byte audit_key_tag = tag(firmid fin_yr), missing
    quietly count if audit_key_n > 1
    local duplicate_records = r(N)
    quietly count if audit_key_n > 1 & audit_key_tag
    local duplicate_groups = r(N)
    local excess_records = `duplicate_records' - `duplicate_groups'
    post `keypost' ("`sample'") (`n') (`missing_firmid') (`missing_year') ///
        (`missing_nacam') (`duplicate_records') (`duplicate_groups') (`excess_records')
    drop audit_key_n audit_key_tag

    merge m:1 nacam using "`previous'", keep(master match) generate(audit_old_merge)
    tabulate audit_old_merge, missing
    generate byte preliminary_records = 0
    generate byte audit_valid_division = 0
    foreach division of local divisions {
        replace preliminary_records = 1 if audit_old_division == "`division'"
        replace audit_valid_division = 1 if isic4_division == "`division'"
    }
    assert audit_valid_division if !missing(isic4_division)
    generate byte mapped_records = !missing(isic4_division)
    generate byte gained_records = mapped_records & !preliminary_records
    generate byte lost_records = !mapped_records & preliminary_records
    generate byte changed_records = mapped_records & preliminary_records & ///
        isic4_division != audit_old_division
    generate byte same_records = mapped_records & preliminary_records & ///
        isic4_division == audit_old_division
    generate byte unresolved_records = !mapped_records
    if "`assessment'" == "rev1" {
        generate byte combined_records = correspondence_status == "combined"
        generate byte partial_records = correspondence_status == "partial"
        generate byte pending_records = correspondence_status == "unresolved"
        generate byte covered_records = mapped_records | combined_records
        assert mapped_records + combined_records + partial_records + pending_records == 1
        replace isic4_status = correspondence_status
    }
    generate byte records = 1
    generate byte missing_firmid = missing(firmid)
    generate byte missing_year = missing(fin_yr)
    generate byte missing_nacam = missing(nacam)

    * Parse source values on helper copies using the cleaning script's rules.
    * A trailing minus is stripped there; count that convention explicitly here.
    foreach measure in employment revenue {
        local input totemp
        if "`measure'" == "revenue" local input tot_rev
        generate byte `measure'_parse_failed = 0
        generate byte `measure'_trailing_minus = 0
        capture confirm string variable `input'
        if !_rc {
            generate strL audit_number = ustrtrim(`input')
            foreach charcode in 13 10 9 160 {
                replace audit_number = subinstr(audit_number, char(`charcode'), "", .)
            }
            replace audit_number = subinstr(audit_number, " ", "", .)
            replace audit_number = "" if inlist(upper(audit_number), "", "NA", "-")
            replace `measure'_trailing_minus = regexm(audit_number, "^[0-9.]+-$")
            replace audit_number = substr(audit_number, 1, length(audit_number)-1) ///
                if `measure'_trailing_minus
            generate double audit_`measure' = real(subinstr(audit_number, ",", "", .))
            replace `measure'_parse_failed = !missing(audit_number) & ///
                missing(audit_`measure') & !regexm(audit_number, "^[.][a-z]?$")
            drop audit_number
        }
        else {
            generate double audit_`measure' = `input'
        }
        generate byte `measure'_valid = !missing(audit_`measure') & audit_`measure' >= 0
        generate byte `measure'_negative = audit_`measure' < 0
        generate byte `measure'_missing = missing(audit_`measure') & !`measure'_parse_failed
        generate byte `measure'_zero = audit_`measure' == 0
        assert `measure'_valid + `measure'_negative + `measure'_missing + ///
            `measure'_parse_failed == 1
        foreach metric in valid zero negative missing parse_failed trailing_minus {
            quietly count if `measure'_`metric'
            local `metric' = r(N)
        }
        quietly summarize audit_`measure' if `measure'_negative, meanonly
        local negative_sum = cond(r(N) > 0, r(sum), 0)
        post `valuepost' ("`sample'") ("`input'") (`n') (`valid') (`zero') ///
            (`negative') (`missing') (`parse_failed') (`trailing_minus') (`negative_sum')
        generate double `measure' = cond(`measure'_valid, audit_`measure', 0)
        foreach group of local coverage_groups {
            generate double `group'_`measure' = `measure' * `group'_records
        }
    }

    * Retain only audit columns in the temporary working dataset. Inputs stay intact.
    keep firmid fin_yr nacam audit_row isic4_division isic4_status records *_records ///
        missing_firmid missing_year missing_nacam employment* revenue* ///
        mapped_employment preliminary_employment gained_employment lost_employment ///
        changed_employment mapped_revenue preliminary_revenue gained_revenue ///
        lost_revenue changed_revenue `extra_metrics'
    save "`prepared'", replace

    foreach breakdown in overall year status year_status category year_category {
        use "`prepared'", clear
        local groups
        if inlist("`breakdown'", "year", "year_status", "year_category") local groups fin_yr
        if inlist("`breakdown'", "status", "year_status") local groups `groups' isic4_status
        if inlist("`breakdown'", "category", "year_category") local groups `groups' nacam
        if _N == 0 & "`breakdown'" != "overall" continue

        * Exclude unknown IDs/codes from distinct counts, but retain their records.
        local category_keys `groups' nacam
        local category_keys : list uniq category_keys
        egen byte firms = tag(`groups' firmid), missing
        replace firms = 0 if missing(firmid)
        egen byte categories = tag(`category_keys'), missing
        replace categories = 0 if missing(nacam)
        foreach group of local coverage_groups {
            egen byte `group'_firms = tag(`groups' firmid) if `group'_records, missing
            replace `group'_firms = 0 if missing(firmid)
            egen byte `group'_categories = tag(`category_keys') if `group'_records, missing
            replace `group'_categories = 0 if missing(nacam)
        }
        local totals records *_records firms categories *_firms *_categories ///
            missing_firmid missing_year missing_nacam employment* revenue* ///
            mapped_employment preliminary_employment gained_employment lost_employment ///
            changed_employment mapped_revenue preliminary_revenue gained_revenue ///
            lost_revenue changed_revenue `extra_metrics'
        unab totals : `totals'
        local totals : list uniq totals
        * A truly empty input still gets an overall row with zero counts.
        if _N == 0 {
            set obs 1
            foreach variable of varlist `totals' {
                replace `variable' = 0
            }
        }
        * Floating-point sums must see the same record order on every run.
        local collapse_order `groups' firmid fin_yr audit_row
        local collapse_order : list uniq collapse_order
        sort `collapse_order'
        if "`groups'" == "" collapse (sum) `totals'
        else collapse (sum) `totals', by(`groups')
        foreach measure in employment revenue {
            replace `measure' = . if `measure'_valid == 0
            foreach group of local coverage_groups {
                replace `group'_`measure' = . if `measure'_valid == 0
                generate double `group'_`measure'_share = `group'_`measure' / ///
                    `measure' if `measure' > 0 & !missing(`measure')
            }
        }
        foreach group of local coverage_groups {
            foreach measure in records firms categories {
                generate double `group'_`measure'_share = `group'_`measure' / ///
                    `measure' if `measure' > 0
            }
        }
        assert mapped_records == preliminary_records + gained_records - lost_records
        assert mapped_records == gained_records + changed_records + same_records
        assert records == mapped_records + unresolved_records
        if "`assessment'" == "rev1" {
            assert records == mapped_records + combined_records + partial_records + pending_records
            assert covered_records == mapped_records + combined_records
        }
        generate str7 sample = "`sample'"
        generate str16 breakdown = "`breakdown'"
        foreach key in fin_yr nacam {
            capture confirm variable `key'
            if _rc generate int `key' = .
        }
        capture confirm variable isic4_status
        if _rc generate str32 isic4_status = ""
        order sample breakdown fin_yr nacam isic4_status
        if "`breakdown'" == "overall" {
            if "`assessment'" == "rev1" {
                local row 0
                foreach metric in mapped_records combined_records partial_records pending_records ///
                    mapped_records_share combined_records_share partial_records_share pending_records_share ///
                    covered_records_share covered_firms_share covered_employment_share covered_revenue_share {
                    local ++row
                    local factor 1
                    if strpos("`metric'", "_share") local factor 100
                    matrix `grouptable'[`row', `column'] = `metric'[1] * `factor'
                }
            }
            local row 0
            foreach metric in records firms categories mapped_records ///
                mapped_records_share mapped_firms_share mapped_categories_share ///
                mapped_employment_share mapped_revenue_share gained_records lost_records {
                local ++row
                local factor 1
                if strpos("`metric'", "_share") local factor 100
                matrix `summarytable'[`row', `column'] = `metric'[1] * `factor'
            }
        }
        if `first_summary' {
            save "`summaries'", replace
            local first_summary 0
        }
        else {
            append using "`summaries'"
            save "`summaries'", replace
        }
    }

    if "`sample'" == "cleaned" {
        use "`prepared'", clear
        sort firmid fin_yr
        by firmid: generate byte comparison_pairs = _n > 1
        by firmid: generate byte consecutive_year_pairs = comparison_pairs & ///
            fin_yr == fin_yr[_n-1] + 1
        by firmid: generate byte nacam_comparable = comparison_pairs & ///
            !missing(nacam, nacam[_n-1])
        by firmid: generate byte nacam_changes = nacam_comparable & nacam != nacam[_n-1]
        by firmid: generate byte isic_comparable = comparison_pairs & ///
            !missing(isic4_division) & !missing(isic4_division[_n-1])
        by firmid: generate byte isic_changes = isic_comparable & ///
            isic4_division != isic4_division[_n-1]
        by firmid: generate byte becomes_mapped = comparison_pairs & ///
            mapped_records & !mapped_records[_n-1]
        by firmid: generate byte becomes_unresolved = comparison_pairs & ///
            !mapped_records & mapped_records[_n-1]
        by firmid: generate byte status_changes = comparison_pairs & ///
            isic4_status != isic4_status[_n-1]
        save "`prepared'", replace
        foreach breakdown in overall year {
            use "`prepared'", clear
            local groups
            if "`breakdown'" == "year" local groups fin_yr
            if _N == 0 & "`breakdown'" == "year" continue
            egen byte firms_changing_isic = tag(`groups' firmid) if isic_changes, missing
            egen byte firms_changing_nacam = tag(`groups' firmid) if nacam_changes, missing
            local totals comparison_pairs consecutive_year_pairs nacam_comparable ///
                nacam_changes isic_comparable isic_changes becomes_mapped ///
                becomes_unresolved status_changes firms_changing_isic firms_changing_nacam
            if _N == 0 {
                set obs 1
                foreach variable of varlist `totals' {
                    replace `variable' = 0
                }
            }
            if "`groups'" == "" collapse (sum) `totals'
            else collapse (sum) `totals', by(`groups')
            generate str7 breakdown = "`breakdown'"
            if "`groups'" == "" generate int fin_yr = .
            order breakdown fin_yr
            if "`breakdown'" == "overall" save "`changes'", replace
            else {
                append using "`changes'"
                save "`changes'", replace
            }
        }
    }
}
postclose `keypost'
postclose `valuepost'

use "`summaries'", clear
sort sample breakdown fin_yr nacam isic4_status
label variable employment "Nonnegative firm-year employment total"
label variable revenue "Nonnegative revenue total in input units"
label variable firms "Distinct nonmissing firms; groups can overlap"
label variable categories "Distinct nonmissing NACAM codes"
if "`assessment'" == "rev1" {
    rename unresolved_records strict_unassigned_records
    generate str50 comparison_basis = "Superseded legacy reviewed crosswalk"
}
export delimited using "`checkdir'/coverage_summary.csv", replace

use "`keyaudit'", clear
export delimited using "`checkdir'/key_audit.csv", replace
use "`valuesaudit'", clear
export delimited using "`checkdir'/numeric_value_audit.csv", replace
use "`changes'", clear
sort breakdown fin_yr
export delimited using "`checkdir'/within_firm_changes.csv", replace

local table_footer `""\bottomrule""'
if "`assessment'" == "rev1" {
    local table_footer `"`table_footer' "\multicolumn{3}{p{0.95\linewidth}}{\footnotesize Provisional NACAM Rev.1, 2015--2022. Strict two-digit coverage only; changes compare with superseded legacy assignments. Employment sums firm-years. Value shares use nonmissing nonnegative values; firms may span statuses.}\\""'
}
local comparison_note "Changes compare with the preliminary correspondence."
if "`assessment'" == "rev1" local comparison_note "Changes compare with superseded legacy assignments, not verified truth. Rev.1 is provisional."
esttab matrix(`summarytable', fmt(%12.2fc)) ///
    using "${OUTPUTDIR}/tables/cmr_tax_isic4_coverage`suffix'.tex", replace fragment booktabs ///
    nomtitles nonumber collabels("Source" "Cleaned") ///
    coeflabels(records "Firm-year records" firms "Distinct firms" ///
        categories "Observed NACAM categories" mapped_records "Assigned ISIC records" ///
        record_pct "Records covered (\%)" firm_pct "Firms with an assignment (\%)" ///
        category_pct "Categories with an assignment (\%)" ///
        employment_pct "Employment covered (\%)" revenue_pct "Revenue covered (\%)" ///
        gained_records "Newly assigned records" lost_records "Prior assignments withheld") ///
    prehead("\toprule") postfoot(`table_footer') ///
    addnotes("`comparison_note'" "Descriptive, unweighted coverage; source records may include duplicates." ///
        "Firms and categories are covered if at least one record has an assignment." ///
        "Employment is summed over firm-years; revenue retains input units." ///
        "Value shares exclude missing, unparseable, and negative values; zero denominators give missing shares.")

if "`assessment'" == "rev1" {
    esttab matrix(`grouptable', fmt(%12.2fc)) using "${OUTPUTDIR}/tables/cmr_tax_isic4_groups_rev1.tex", ///
        replace fragment booktabs nomtitles nonumber collabels("Source" "Cleaned") ///
        coeflabels(single_records "Single-division records" combined_records "Combined-division records" ///
            partial_records "Partial-correspondence records" pending_records "Unresolved records" ///
            single_pct "Single division (\%)" combined_pct "Combined divisions (\%)" ///
            partial_pct "Partial correspondence (\%)" pending_pct "Unresolved (\%)" ///
            covered_pct "Single or combined records (\%)" covered_firms_pct "Firms with single or combined records (\%)" ///
            covered_emp_pct "Single or combined employment (\%)" covered_rev_pct "Single or combined revenue (\%)") ///
        prehead("\toprule") postfoot("\bottomrule" ///
            "\multicolumn{3}{p{0.95\linewidth}}{\footnotesize Provisional NACAM Rev.1 for 2015--2022. Combined groups are separate from strict divisions; partial links are excluded from group coverage. Employment sums firm-years. Value shares exclude missing and negative values; firms may span statuses.}\\") ///
        addnotes("NACAM Rev.1 assumed provisionally for 2015-2022; classifications are not source-certified." ///
            "Combined groups are separate from strict two-digit assignments; partial links are excluded from group coverage." ///
            "Employment is a firm-year total. Shares use nonmissing nonnegative values; firms can span statuses.")
}
display as result "TAX ISIC4 COVERAGE CHECKS PASSED"
log close taxcoverage
