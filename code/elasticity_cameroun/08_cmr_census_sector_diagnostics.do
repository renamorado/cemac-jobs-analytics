version 17.0
set more off

/*******************************************************************************
    Purpose:
        Prepare Cameroon RGE 2024 census data for NACAM-aligned sector
        diagnostics using a reviewable PDF-derived classification crosswalk.

    Inputs:
        Data/Cameroon/Raw/CENSUS 2024 - Copy of BASE RGE 3 BANQUE MONDIALE - Copy.xlsx
        docs/reference/nacam_rev1_citi_bridge_extracted.xlsx
        docs/reference/cmr_census_activity_nacam_crosswalk.xlsx
        Data/Intermediate/cmr_nacam_data_export_mapping.dta

    Outputs:
        Data/Intermediate/cmr_census_activity_nacam_crosswalk.dta
        Data/Analysis/CMR_census_cleaned.dta
        Data/Analysis/CMR_census_nacam_diagnostics.dta
        output/tables/cmr_census_sector_audit.tex
        output/tables/cmr_census_crosswalk_examples.tex
        output/figures/cmr_census_*.pdf
        output/figures/cmr_census_*.png
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
    display as error "Add this user to the bootstrap block in code/elasticity_cameroun/08_cmr_census_sector_diagnostics.do."
    exit 601
}

capture noisily cd "${project_root}"
if _rc | !fileexists("AGENTS.md") {
    display as error "Configured project_root is not a valid repo root: ${project_root}"
    exit 601
}

do "code/01_setup.do"

local raw_file "${CAMEROONDIR}/Raw/CENSUS 2024 - Copy of BASE RGE 3 BANQUE MONDIALE - Copy.xlsx"
local official_bridge "${PROJECT_ROOT}/docs/reference/nacam_rev1_citi_bridge_extracted.xlsx"
local census_crosswalk_xlsx "${PROJECT_ROOT}/docs/reference/cmr_census_activity_nacam_crosswalk.xlsx"
local data_export_mapping "${DATADIR}/Intermediate/cmr_nacam_data_export_mapping.dta"
local activity_crosswalk "${DATADIR}/Intermediate/cmr_census_activity_nacam_crosswalk.dta"
local clean_out "${DATADIR}/Analysis/CMR_census_cleaned.dta"
local diagnostics_out "${DATADIR}/Analysis/CMR_census_nacam_diagnostics.dta"
local sleep_ms = real("${SLEEP_MS}")

if missing(`sleep_ms') {
    local sleep_ms 750
}

confirm file "`raw_file'"
confirm file "`official_bridge'"
confirm file "`census_crosswalk_xlsx'"
confirm file "`data_export_mapping'"

local log_stamp = subinstr(c(current_time), ":", "", .)
local log_stamp = subinstr("`log_stamp'", " ", "", .)
capture log close cmrcensus
capture log using "${LOGDIR}/08_cmr_census_sector_diagnostics_`log_stamp'.log", text name(cmrcensus)
if _rc {
    sleep `sleep_ms'
    log using "${LOGDIR}/08_cmr_census_sector_diagnostics_`log_stamp'.log", text name(cmrcensus)
}

/*******************************************************************************
    1. Import the raw census workbook and keep only task fields
*******************************************************************************/

import excel using "`raw_file'", sheet("BASE") firstrow allstring clear

generate str120 source_file = "CENSUS 2024 - Copy of BASE RGE 3 BANQUE MONDIALE - Copy.xlsx"
generate str20 source_sheet = "BASE"
generate long source_excel_row = _n + 1

keep source_file source_sheet source_excel_row ///
    S0Q01 S1Q13 S1Q14B SACTIV_S1Q14 BRANCHD_S1Q14 S6Q05AC S6Q01A

rename S0Q01 firmid_census
rename S1Q13 unit_status
rename S1Q14B activity_detail
rename SACTIV_S1Q14 activity_macro
rename BRANCHD_S1Q14 citi_branch
rename S6Q05AC employment_raw
rename S6Q01A annual_turnover_raw

foreach var of varlist firmid_census unit_status activity_detail activity_macro ///
    citi_branch employment_raw annual_turnover_raw {
    replace `var' = ustrtrim(`var')
    replace `var' = "" if inlist(`var', "ND", "Ne sait pas")
}

assert !missing(firmid_census)
isid firmid_census

generate byte hq_sample = unit_status == "Siège"

generate byte employment_nonnumeric = !missing(employment_raw) ///
    & missing(real(subinstr(employment_raw, ",", "", .)))
generate byte turnover_nonnumeric = !missing(annual_turnover_raw) ///
    & missing(real(subinstr(annual_turnover_raw, ",", "", .)))

destring employment_raw, generate(employment) ignore(", ") force
destring annual_turnover_raw, generate(annual_turnover) ignore(", ") force

generate byte employment_missing = missing(employment)
generate byte employment_zero = employment == 0 if !missing(employment)
generate byte employment_negative = employment < 0 if !missing(employment)
generate byte turnover_missing = missing(annual_turnover)
generate byte turnover_zero = annual_turnover == 0 if !missing(annual_turnover)
generate byte turnover_negative = annual_turnover < 0 if !missing(annual_turnover)

replace employment = . if employment < 0
replace annual_turnover = . if annual_turnover < 0

tempfile census_imported observed_activity_labels official_nacam_rev1_prefixes
save "`census_imported'"

/*******************************************************************************
    2. Import the reviewable census activity crosswalk

    The official INS PDF bridge is stored as a workbook in docs/reference. The
    census-label crosswalk points to that extracted source and is merged here,
    rather than rebuilding the classification through replace rules.
*******************************************************************************/

preserve
keep citi_branch activity_detail activity_macro
duplicates drop
sort citi_branch activity_detail
isid citi_branch activity_detail
save "`observed_activity_labels'"
restore

import excel using "`official_bridge'", sheet("nacam_rev1_citi_bridge") firstrow allstring clear
quietly count
assert r(N) > 0
confirm variable nacam_ancien
confirm variable nacam_rev1
confirm variable citi_rev4
keep nacam_rev1
replace nacam_rev1 = ustrtrim(nacam_rev1)
keep if !missing(nacam_rev1)
generate str3 nacam_rev1_prefix = substr(nacam_rev1, 1, 3)
keep nacam_rev1_prefix
duplicates drop
sort nacam_rev1_prefix
isid nacam_rev1_prefix
save "`official_nacam_rev1_prefixes'"

import excel using "`census_crosswalk_xlsx'", sheet("activity_crosswalk") firstrow clear

foreach var in citi_branch activity_detail activity_macro isic_reference ///
    nacam_rev1_reference crosswalk_source_file crosswalk_source_sheet ///
    nacam_label_display nacam_label_short_display mapping_source mapping_note {
    capture confirm string variable `var'
    if _rc {
        tostring `var', replace force
    }
    replace `var' = ustrtrim(`var')
}

foreach var in official_legacy_nacam nacam review_flag {
    capture confirm numeric variable `var'
    if _rc {
        destring `var', replace force
    }
}

assert !missing(citi_branch, activity_detail)
isid citi_branch activity_detail
assert crosswalk_source_file == "nacam_rev1_citi_bridge_extracted.xlsx" if !missing(crosswalk_source_file)

generate str3 nacam_rev1_prefix = substr(nacam_rev1_reference, 1, 3)
merge m:1 nacam_rev1_prefix using "`official_nacam_rev1_prefixes'", ///
    keep(master match) generate(official_bridge_merge)
generate byte official_bridge_unmatched = !missing(nacam_rev1_reference) ///
    & official_bridge_merge != 3
count if official_bridge_unmatched == 1
if r(N) > 0 {
    display as error "Some census crosswalk rows point to NACAM Rev.1 prefixes absent from the official bridge:"
    list citi_branch activity_detail nacam_rev1_reference official_bridge_merge ///
        if official_bridge_unmatched == 1, noobs abbreviate(32)
    error 459
}
drop official_bridge_merge

merge 1:1 citi_branch activity_detail using "`observed_activity_labels'"
count if _merge != 3
if r(N) > 0 {
    display as error "Census activity crosswalk does not match observed census labels:"
    list citi_branch activity_detail _merge if _merge != 3, noobs abbreviate(32)
    error 459
}
drop _merge

order citi_branch activity_detail activity_macro official_legacy_nacam nacam ///
    isic_reference nacam_rev1_reference crosswalk_source_file ///
    crosswalk_source_sheet nacam_label_display nacam_label_short_display ///
    review_flag official_bridge_unmatched mapping_source mapping_note

sort citi_branch activity_detail
save "`activity_crosswalk'", replace

/*******************************************************************************
    3. Merge the crosswalk back to firm-level census data
*******************************************************************************/

use "`census_imported'", clear
merge m:1 citi_branch activity_detail using "`activity_crosswalk'", nogen keep(master match)
assert !missing(review_flag)

merge m:1 nacam using "`data_export_mapping'", keep(master match) keepusing(data_export)
drop if _merge == 2
drop _merge

replace employment = . if !hq_sample
replace annual_turnover = . if !hq_sample

generate byte has_employment = !missing(employment)
generate byte has_turnover = !missing(annual_turnover)
generate byte plotted_sample = hq_sample == 1 & !missing(nacam)

label variable firmid_census "Census firm identifier"
label variable source_excel_row "Original Excel row in BASE sheet"
label variable activity_detail "Census detailed activity label, S1Q14B"
label variable citi_branch "Census CITI Rev.4 branch label, BRANCHD_S1Q14"
label variable official_legacy_nacam "Official legacy NACAM branch from PDF-derived crosswalk"
label variable nacam "Legacy/admin NACAM branch observed in CMR_BDF elasticity data"
label variable review_flag "1 if mapping is approximate, absent from CMR_BDF sectors, or needs review"
label variable plotted_sample "Headquarters row with a NACAM sector used in current diagnostics"

capture save "`clean_out'", replace
if _rc {
    sleep `sleep_ms'
    save "`clean_out'", replace
}

/*******************************************************************************
    4. Audit tables
*******************************************************************************/

quietly count
local all_rows = r(N)
quietly count if hq_sample == 1
local hq_rows = r(N)
quietly count if plotted_sample == 1
local plotted_rows = r(N)
quietly count if hq_sample == 1 & missing(nacam)
local hq_unmapped_rows = r(N)
quietly count if hq_sample == 1 & review_flag == 1
local hq_review_rows = r(N)

preserve
keep citi_branch activity_detail review_flag nacam
duplicates drop
quietly count
local activity_labels = r(N)
quietly count if !missing(nacam)
local mapped_labels = r(N)
quietly count if review_flag == 1
local review_labels = r(N)
restore

preserve
keep citi_branch activity_detail official_bridge_unmatched
duplicates drop
quietly count if official_bridge_unmatched == 1
local bridge_unmatched_labels = r(N)
restore

matrix census_audit = ( ///
    `all_rows' \ ///
    `hq_rows' \ ///
    `activity_labels' \ ///
    `mapped_labels' \ ///
    `review_labels' \ ///
    `bridge_unmatched_labels' \ ///
    `hq_review_rows' \ ///
    `hq_unmapped_rows' \ ///
    `plotted_rows' ///
)
matrix colnames census_audit = Value
matrix rownames census_audit = all_rows hq_rows activity_labels mapped_labels review_labels bridge_unmatched_labels hq_review_rows hq_unmapped_rows plotted_rows

esttab matrix(census_audit, fmt(%12.0fc)) ///
    using "${OUTPUTDIR}/tables/cmr_census_sector_audit.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels( ///
        all_rows "Raw census rows" ///
        hq_rows "Headquarters rows" ///
        activity_labels "Observed detailed activity labels" ///
        mapped_labels "Detailed labels mapped to admin NACAM" ///
        review_labels "Detailed labels flagged for review" ///
        bridge_unmatched_labels "Crosswalk labels not found in official NACAM Rev.1 bridge" ///
        hq_review_rows "Headquarters rows flagged for review" ///
        hq_unmapped_rows "Headquarters rows outside elasticity NACAM sectors" ///
        plotted_rows "Headquarters rows used in NACAM plots" ///
    )

matrix crosswalk_examples = ( ///
    9602, 42, 42 \ ///
    5610, 33, 33 \ ///
    5630, 33, 33 \ ///
    47,   32, 31 \ ///
    61,   35, 35 ///
)
matrix colnames crosswalk_examples = ISICRev4 NACAMRev1 AdminNACAM
matrix rownames crosswalk_examples = coiffure restauration debit_boissons retail telecom

esttab matrix(crosswalk_examples, fmt(%9.0f %9.0f %9.0f)) ///
    using "${OUTPUTDIR}/tables/cmr_census_crosswalk_examples.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    collabels("ISIC Rev.4" "NACAM rev.1" "Admin NACAM") ///
    varlabels( ///
        coiffure "Hairdressing and beauty care" ///
        restauration "Restauration" ///
        debit_boissons "Beverage-serving activities" ///
        retail "Retail activity labels" ///
        telecom "Telecommunications" ///
    )

/*******************************************************************************
    5. Sector diagnostics and figures
*******************************************************************************/

preserve
keep if plotted_sample == 1
assert !missing(nacam, nacam_label_short_display, data_export)

generate double turnover_per_worker_firm = annual_turnover / employment ///
    if !missing(annual_turnover, employment) & annual_turnover >= 0 ///
    & employment > 0

collapse ///
    (count) firms = source_excel_row ///
    (sum) total_employment = employment annual_turnover has_employment has_turnover ///
    (mean) average_employment = employment ///
        average_revenue = annual_turnover ///
        average_turnover_per_worker = turnover_per_worker_firm, ///
    by(nacam nacam_label_display nacam_label_short_display data_export)

rename annual_turnover total_turnover
generate double total_revenue_bil = total_turnover / 1000000000
generate double turnover_per_worker = total_turnover / total_employment if total_employment > 0
generate double log_total_employment = ln(total_employment) if total_employment > 0
generate double log_total_revenue = ln(total_turnover) if total_turnover > 0
generate double log_turnover_per_worker = ln(turnover_per_worker) ///
    if turnover_per_worker > 0
generate double log_average_employment = ln(average_employment) ///
    if average_employment > 0
generate double log_average_revenue = ln(average_revenue) ///
    if average_revenue > 0
generate double log_average_turnover_per_worker = ln(average_turnover_per_worker) ///
    if average_turnover_per_worker > 0

assert !missing(total_employment, total_turnover, total_revenue_bil)

label variable firms "Number of headquarters firms"
label variable total_employment "Total employment"
label variable average_employment "Average employment"
label variable total_turnover "Total annual turnover"
label variable total_revenue_bil "Total annual turnover, CFAF billions"
label variable average_revenue "Average annual turnover"
label variable turnover_per_worker "Annual turnover per worker"
label variable average_turnover_per_worker "Average annual turnover per worker"
label variable log_total_employment "Log total employment"
label variable log_total_revenue "Log total annual turnover"
label variable log_turnover_per_worker "Log annual turnover per worker"
label variable log_average_employment "Log average firm employment"
label variable log_average_revenue "Log average firm annual turnover"
label variable log_average_turnover_per_worker "Log average annual turnover per worker"

sort nacam
isid nacam

save "`diagnostics_out'", replace

graph hbar firms, ///
    over(nacam_label_short_display, sort(firms) descending label(labsize(vsmall))) ///
    ytitle("Headquarters firms", size(small)) ///
    title("Census firm counts by NACAM sector", size(medsmall)) ///
    bar(1, color("44 123 182")) ///
    plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
    ysize(6.2) xsize(7.5)
graph export "${OUTPUTDIR}/figures/cmr_census_firm_count_by_nacam.pdf", replace
graph export "${OUTPUTDIR}/figures/cmr_census_firm_count_by_nacam.png", replace

graph hbar log_total_employment if !missing(log_total_employment), ///
    over(nacam_label_short_display, sort(log_total_employment) descending label(labsize(tiny))) ///
    ytitle("Log total employment", size(vsmall)) ///
    title("Aggregate sector total", size(small)) ///
    bar(1, color("27 158 119")) ///
    plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
    ysize(6.2) xsize(4.2) name(census_emp_total, replace)

graph hbar log_average_employment if !missing(log_average_employment), ///
    over(nacam_label_short_display, sort(log_average_employment) descending label(labsize(tiny))) ///
    ytitle("Log average firm employment", size(vsmall)) ///
    title("Sector firm average", size(small)) ///
    bar(1, color("27 158 119")) ///
    plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
    ysize(6.2) xsize(4.2) name(census_emp_average, replace)

graph combine census_emp_total census_emp_average, ///
    cols(2) title("Census log employment by NACAM sector", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(6.2) xsize(10) name(census_emp_combined, replace)
graph display census_emp_combined
graph export "${OUTPUTDIR}/figures/cmr_census_total_employment_by_nacam.pdf", replace
graph export "${OUTPUTDIR}/figures/cmr_census_total_employment_by_nacam.png", replace

graph hbar log_total_revenue if !missing(log_total_revenue), ///
    over(nacam_label_short_display, sort(log_total_revenue) descending label(labsize(tiny))) ///
    ytitle("Log total annual revenue", size(vsmall)) ///
    title("Aggregate sector total", size(small)) ///
    bar(1, color("117 112 179")) ///
    plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
    ysize(6.2) xsize(4.2) name(census_rev_total, replace)

graph hbar log_average_revenue if !missing(log_average_revenue), ///
    over(nacam_label_short_display, sort(log_average_revenue) descending label(labsize(tiny))) ///
    ytitle("Log average firm annual revenue", size(vsmall)) ///
    title("Sector firm average", size(small)) ///
    bar(1, color("117 112 179")) ///
    plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
    ysize(6.2) xsize(4.2) name(census_rev_average, replace)

graph combine census_rev_total census_rev_average, ///
    cols(2) title("Census log annual revenue by NACAM sector", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(6.2) xsize(10) name(census_rev_combined, replace)
graph display census_rev_combined
graph export "${OUTPUTDIR}/figures/cmr_census_total_revenue_by_nacam.pdf", replace
graph export "${OUTPUTDIR}/figures/cmr_census_total_revenue_by_nacam.png", replace

graph hbar average_employment, ///
    over(nacam_label_short_display, sort(average_employment) descending label(labsize(vsmall))) ///
    ytitle("Average employment", size(small)) ///
    title("Census average employment by NACAM sector", size(medsmall)) ///
    bar(1, color("217 95 2")) ///
    plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
    ysize(6.2) xsize(7.5)
graph export "${OUTPUTDIR}/figures/cmr_census_average_employment_by_nacam.pdf", replace
graph export "${OUTPUTDIR}/figures/cmr_census_average_employment_by_nacam.png", replace

graph hbar log_turnover_per_worker if !missing(log_turnover_per_worker), ///
    over(nacam_label_short_display, sort(log_turnover_per_worker) descending label(labsize(tiny))) ///
    ytitle("Log annual revenue per worker", size(vsmall)) ///
    title("Aggregate sector ratio", size(small)) ///
    bar(1, color("231 41 138")) ///
    plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
    ysize(6.2) xsize(4.2) name(census_rpw_total, replace)

graph hbar log_average_turnover_per_worker ///
    if !missing(log_average_turnover_per_worker), ///
    over(nacam_label_short_display, sort(log_average_turnover_per_worker) descending label(labsize(tiny))) ///
    ytitle("Log average annual revenue per worker", size(vsmall)) ///
    title("Sector firm average", size(small)) ///
    bar(1, color("231 41 138")) ///
    plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
    ysize(6.2) xsize(4.2) name(census_rpw_average, replace)

graph combine census_rpw_total census_rpw_average, ///
    cols(2) title("Census log annual revenue per worker by NACAM sector", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(6.2) xsize(10) name(census_rpw_combined, replace)
graph display census_rpw_combined
graph export "${OUTPUTDIR}/figures/cmr_census_turnover_per_worker_by_nacam.pdf", replace
graph export "${OUTPUTDIR}/figures/cmr_census_turnover_per_worker_by_nacam.png", replace
restore

display as result "Saved census cleaned data to `clean_out'"
display as result "Saved census NACAM diagnostics to `diagnostics_out'"
display as result "Saved census activity crosswalk to `activity_crosswalk'"

log close cmrcensus
