version 17.0
set more off

/*******************************************************************************
    Purpose:
        Link Census headquarters to 2023 customs exports using exact,
        normalized NIUs.

    Inputs:
        Data/Cameroon/Raw/CENSUS 2024 with exports BASE RGE 3 BANQUE MONDIALE exp.xlsx
        Data/Analysis/CMR_census_cleaned.dta

    Outputs:
        Data/Analysis/CMR_census_customs_linked.dta
        output/tables/cmr_customs_census_merge_audit.tex
*******************************************************************************/

* Use the project globals when called from the master script. Load them when
* this do-file is run by itself from the repository root.
if "${PROJECT_ROOT}" == "" {
    do "code/01_setup.do"
}

local source_file "${CAMEROONDIR}/Raw/CENSUS 2024 with exports BASE RGE 3 BANQUE MONDIALE exp.xlsx"
local census_file "${DATADIR}/Analysis/CMR_census_cleaned.dta"
local linked_file "${DATADIR}/Analysis/CMR_census_customs_linked.dta"

confirm file "`source_file'"
confirm file "`census_file'"

tempfile census_niu customs_by_niu

/*******************************************************************************
    1. Census ID-to-NIU bridge
*******************************************************************************/

import excel using "`source_file'", sheet("Feuil2") firstrow allstring clear
confirm variable S0Q01 S1Q16

keep S0Q01 S1Q16
rename S0Q01 firmid_census
rename S1Q16 census_niu_raw

replace firmid_census = ustrtrim(firmid_census)
replace census_niu_raw = ustrtrim(census_niu_raw)

assert !missing(firmid_census)
isid firmid_census

generate str20 census_niu_norm = ustrupper(census_niu_raw)
replace census_niu_norm = ustrregexra(census_niu_norm, "[[:space:]]", "")
replace census_niu_norm = subinstr(census_niu_norm, "-", "", .)
generate byte census_niu_valid = ///
    ustrregexm(census_niu_norm, "^[A-Z][0-9]{12}[A-Z]$")

* Only validated NIUs are eligible to merge. Keep the raw and normalized
* values so missing and malformed identifiers remain auditable.
generate str14 niu_merge_key = census_niu_norm if census_niu_valid == 1
save "`census_niu'"

/*******************************************************************************
    2. Customs totals by valid NIU
*******************************************************************************/

import excel using "`source_file'", sheet("Sheet3") firstrow allstring clear
confirm variable NIU ENTREPRISE EXPV2023

keep NIU ENTREPRISE EXPV2023
generate long customs_source_row = _n + 1

rename NIU customs_niu_raw
rename ENTREPRISE customs_enterprise
rename EXPV2023 customs_export_value_raw

replace customs_niu_raw = ustrtrim(customs_niu_raw)
replace customs_enterprise = ustrtrim(customs_enterprise)

generate str20 customs_niu_norm = ustrupper(customs_niu_raw)
replace customs_niu_norm = ustrregexra(customs_niu_norm, "[[:space:]]", "")
replace customs_niu_norm = subinstr(customs_niu_norm, "-", "", .)
generate byte customs_niu_valid = ///
    ustrregexm(customs_niu_norm, "^[A-Z][0-9]{12}[A-Z]$")

generate byte customs_export_nonnumeric = ///
    !missing(customs_export_value_raw) ///
    & missing(real(subinstr(customs_export_value_raw, ",", "", .)))
destring customs_export_value_raw, generate(customs_export_value) ///
    ignore(", ") force

quietly count
local customs_rows = r(N)

* Exact duplicate rows remain in the source import. The second total below
* keeps only the first identical NIU-enterprise-value row for sensitivity.
duplicates tag customs_niu_norm customs_enterprise customs_export_value_raw, ///
    generate(customs_exact_duplicate)
replace customs_exact_duplicate = customs_exact_duplicate > 0

sort customs_niu_norm customs_enterprise customs_export_value_raw customs_source_row
by customs_niu_norm customs_enterprise customs_export_value_raw: ///
    generate byte customs_dedup_row = _n == 1

keep if customs_niu_valid == 1

quietly count if customs_exact_duplicate == 1
local customs_duplicate_rows = r(N)

generate byte customs_row = 1
generate byte customs_positive_row = customs_export_value > 0 ///
    if !missing(customs_export_value)
replace customs_positive_row = 0 if missing(customs_positive_row)

generate double customs_export_raw_component = ///
    cond(missing(customs_export_value), 0, customs_export_value)
generate double customs_export_dedup_component = ///
    cond(customs_dedup_row == 1 & !missing(customs_export_value), ///
        customs_export_value, 0)

collapse ///
    (sum) customs_row_count_raw = customs_row ///
        customs_row_count_dedup = customs_dedup_row ///
        customs_positive_rows = customs_positive_row ///
        customs_export_value_raw = customs_export_raw_component ///
        customs_export_value_dedup = customs_export_dedup_component ///
    (max) customs_has_exact_duplicate = customs_exact_duplicate ///
        customs_export_nonnumeric, ///
    by(customs_niu_norm)

rename customs_niu_norm niu_merge_key
isid niu_merge_key

quietly count
local customs_unique_nius = r(N)
quietly summarize customs_export_value_raw, meanonly
local customs_raw_total = r(sum)
quietly summarize customs_export_value_dedup, meanonly
local customs_dedup_total = r(sum)

generate byte customs_positive_export = customs_positive_rows > 0
save "`customs_by_niu'"

/*******************************************************************************
    3. Headquarters-level Census-customs merge
*******************************************************************************/

use "`census_file'", clear
isid firmid_census

merge 1:1 firmid_census using "`census_niu'"
assert _merge == 3
drop _merge

keep if hq_sample == 1
isid firmid_census

quietly count
local census_headquarters = r(N)
quietly count if census_niu_valid == 1
local census_valid_niu = r(N)

bysort niu_merge_key: generate long census_hq_per_niu = _N ///
    if !missing(niu_merge_key)

merge m:1 niu_merge_key using "`customs_by_niu'", ///
    keep(master match) generate(customs_merge)

generate byte customs_link_status = 1
replace customs_link_status = 2 if !missing(census_niu_raw) ///
    & census_niu_valid == 0
replace customs_link_status = 3 if census_niu_valid == 1 ///
    & customs_merge == 1
replace customs_link_status = 4 if customs_merge == 3 ///
    & customs_positive_export == 0
replace customs_link_status = 5 if customs_merge == 3 ///
    & customs_positive_export == 1

label define customs_link_status_lbl ///
    1 "Missing Census NIU" ///
    2 "Invalid Census NIU" ///
    3 "Valid NIU unmatched to customs" ///
    4 "Matched NIU without positive exports" ///
    5 "Matched NIU with positive exports"
label values customs_link_status customs_link_status_lbl

generate byte census_niu_multiple_hq = census_hq_per_niu > 1 ///
    if !missing(census_hq_per_niu)

quietly count if customs_merge == 3
local matched_headquarters = r(N)
quietly count if customs_link_status == 5
local positive_export_headquarters = r(N)

egen byte matched_niu_tag = tag(niu_merge_key) if customs_merge == 3
quietly count if matched_niu_tag == 1
local matched_unique_nius = r(N)
drop matched_niu_tag

isid firmid_census
compress
save "`linked_file'", replace

/*******************************************************************************
    4. Combined source, duplicate, and merge audit
*******************************************************************************/

matrix customs_merge_audit = ( ///
    `customs_rows' \ ///
    `customs_unique_nius' \ ///
    `customs_duplicate_rows' \ ///
    `customs_raw_total' \ ///
    `customs_dedup_total' \ ///
    `census_headquarters' \ ///
    `census_valid_niu' \ ///
    `matched_unique_nius' \ ///
    `matched_headquarters' \ ///
    `positive_export_headquarters' ///
)
matrix colnames customs_merge_audit = Value
matrix rownames customs_merge_audit = ///
    customs_rows customs_unique_valid_nius customs_exact_duplicate_rows ///
    customs_export_raw_total customs_export_dedup_total ///
    census_headquarters census_valid_niu_rows matched_unique_nius ///
    matched_headquarters positive_export_headquarters

esttab matrix(customs_merge_audit, fmt(%18.0fc)) ///
    using "${OUTPUTDIR}/tables/cmr_customs_census_merge_audit.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels( ///
        customs_rows "Raw customs rows" ///
        customs_unique_valid_nius "Unique valid customs NIUs" ///
        customs_exact_duplicate_rows "Rows in exact duplicate groups" ///
        customs_export_raw_total "Valid-NIU raw customs export total" ///
        customs_export_dedup_total "Valid-NIU exact-row-deduplicated export total" ///
        census_headquarters "Census headquarters" ///
        census_valid_niu_rows "Census headquarters with valid NIU" ///
        matched_unique_nius "Unique NIUs matched to Census" ///
        matched_headquarters "Census headquarters matched to customs" ///
        positive_export_headquarters "Matched headquarters with positive exports" ///
    )

display as result "Saved `linked_file'"
display as result "Matched headquarters: `matched_headquarters'"
display as result "Matched headquarters with positive exports: `positive_export_headquarters'"
