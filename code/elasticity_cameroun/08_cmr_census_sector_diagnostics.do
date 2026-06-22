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
        output/tables/cmr_census_asset_availability_audit.tex
        output/tables/cmr_census_sector_audit.tex
        output/tables/cmr_census_crosswalk_examples.tex
        output/figures/cmr_census_*.pdf
        output/figures/cmr_census_*.png
*******************************************************************************/

local username = lower("`c(username)'")

* Configure the project root for known Windows users, with a repo-root fallback
* for batch runs launched from the CEMAC folder.
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
    display as error "Add this user to the bootstrap block in code/elasticity_cameroun/08_cmr_census_sector_diagnostics.do."
    exit 601
}

capture noisily cd "${project_root}"
if _rc | !fileexists("AGENTS.md") {
    display as error "Configured project_root is not a valid repo root: ${project_root}"
    exit 601
}

* Load standard project globals such as DATADIR, CAMEROONDIR, OUTPUTDIR,
* LOGDIR, and package requirements before defining this script's file paths.
do "code/01_setup.do"

* Keep all task-specific input and output paths together so the data lineage is
* easy to audit from the top of the do-file.
local raw_file "${CAMEROONDIR}/Raw/CENSUS 2024 - Copy of BASE RGE 3 BANQUE MONDIALE - Copy.xlsx"
local official_bridge "${PROJECT_ROOT}/docs/reference/nacam_rev1_citi_bridge_extracted.xlsx"
local census_crosswalk_xlsx "${PROJECT_ROOT}/docs/reference/cmr_census_activity_nacam_crosswalk.xlsx"
local data_export_mapping "${DATADIR}/Intermediate/cmr_nacam_data_export_mapping.dta"
local activity_crosswalk "${DATADIR}/Intermediate/cmr_census_activity_nacam_crosswalk.dta"
local clean_out "${DATADIR}/Analysis/CMR_census_cleaned.dta"
local diagnostics_out "${DATADIR}/Analysis/CMR_census_nacam_diagnostics.dta"
local sleep_ms = real("${SLEEP_MS}")

* Use a short retry delay for local file-lock issues when Stata writes logs or
* datasets on Windows.
if missing(`sleep_ms') {
    local sleep_ms 750
}

* Fail immediately if any required source is missing; downstream merges should
* never silently run from partial inputs.
confirm file "`raw_file'"
confirm file "`official_bridge'"
confirm file "`census_crosswalk_xlsx'"
confirm file "`data_export_mapping'"

* Create a timestamped step log. If the file is briefly locked, sleep once and
* retry rather than leaving this diagnostic stage unlogged.
local log_stamp = subinstr(c(current_time), ":", "", .)
local log_stamp = subinstr("`log_stamp'", " ", "", .)
capture log close cmrcensus
capture log using "${LOGDIR}/08_cmr_census_sector_diagnostics_`log_stamp'.log", text name(cmrcensus)
if _rc {
    sleep `sleep_ms'
    log using "${LOGDIR}/08_cmr_census_sector_diagnostics_`log_stamp'.log", text name(cmrcensus)
}

/*******************************************************************************
    0. Audit whether the current Census source contains an asset field

    The workbook dictionary lists S4Q00 as "Capital social", but the current
    BASE sheet does not include that variable. Keep this as a generated audit so
    the asset-distribution task is visibly blocked until a fuller Census source
    is supplied.
*******************************************************************************/

import excel using "`raw_file'", sheet("DICTIONNAIRE DES VARIABLE") firstrow allstring clear

local dictionary_has_s4q00 = 0
foreach var of varlist _all {
    quietly count if ustrupper(ustrtrim(`var')) == "S4Q00"
    if r(N) > 0 {
        local dictionary_has_s4q00 = 1
    }
}

/*******************************************************************************
    1. Import the raw census workbook and keep only task fields
*******************************************************************************/

* Unit of observation at import is one row from the raw Census BASE sheet.
* The script keeps only provenance, activity, employment, and turnover fields
* needed for NACAM sector diagnostics. S4Q00 is checked before the keep step
* because the dictionary names it as a capital field, but the current BASE sheet
* distributed with the project does not contain it.
import excel using "`raw_file'", sheet("BASE") firstrow allstring clear

local base_has_s4q00 = 0
capture confirm variable S4Q00
if !_rc {
    local base_has_s4q00 = 1
}

local asset_figures_generated = 0
if `dictionary_has_s4q00' == 1 & `base_has_s4q00' == 0 {
    display as text "Census dictionary lists S4Q00 / Capital social, but the current BASE sheet does not contain S4Q00."
    display as text "Asset distribution figures are not generated from this Census source."
}

matrix census_asset_audit = ( ///
    `dictionary_has_s4q00' \ ///
    `base_has_s4q00' \ ///
    `asset_figures_generated' ///
)
matrix colnames census_asset_audit = Value
matrix rownames census_asset_audit = dictionary_lists_s4q00 base_sheet_has_s4q00 asset_figures_generated

esttab matrix(census_asset_audit, fmt(%9.0f)) ///
    using "${OUTPUTDIR}/tables/cmr_census_asset_availability_audit.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels( ///
        dictionary_lists_s4q00 "Dictionary lists S4Q00 / Capital social" ///
        base_sheet_has_s4q00 "BASE sheet contains S4Q00" ///
        asset_figures_generated "Asset figures generated from Census source" ///
    )

* Preserve workbook provenance so suspicious records can be traced back to the
* original Excel file, sheet, and row number.
generate str120 source_file = "CENSUS 2024 - Copy of BASE RGE 3 BANQUE MONDIALE - Copy.xlsx"
generate str20 source_sheet = "BASE"
generate long source_excel_row = _n + 1

* Drop unused Census fields early to keep the rest of the pipeline auditable.
keep source_file source_sheet source_excel_row ///
    S0Q01 S1Q13 S1Q14B SACTIV_S1Q14 BRANCHD_S1Q14 S6Q05AC S6Q01A

* Rename raw questionnaire variables to analysis-facing names.
rename S0Q01 firmid_census
rename S1Q13 unit_status
rename S1Q14B activity_detail
rename SACTIV_S1Q14 activity_macro
rename BRANCHD_S1Q14 citi_branch
rename S6Q05AC employment_raw
rename S6Q01A annual_turnover_raw

* Standardize string fields and convert Census nonresponse markers to Stata
* missing strings before numeric parsing or classification merges.
foreach var of varlist firmid_census unit_status activity_detail activity_macro ///
    citi_branch employment_raw annual_turnover_raw {
    replace `var' = ustrtrim(`var')
    replace `var' = "" if inlist(`var', "ND", "Ne sait pas")
}

assert !missing(firmid_census)
isid firmid_census

* Restrict measured employment and turnover to headquarters rows later in the
* script; the flag is kept here because it comes directly from unit status.

generate byte hq_sample = unit_status == "Siège"

* Record parse problems before destringing with force, so diagnostics can later
* distinguish true missing values from nonnumeric source entries.
generate byte employment_nonnumeric = !missing(employment_raw) ///
    & missing(real(subinstr(employment_raw, ",", "", .)))
generate byte turnover_nonnumeric = !missing(annual_turnover_raw) ///
    & missing(real(subinstr(annual_turnover_raw, ",", "", .)))

* Convert employment and turnover to numeric measures used for sector totals.
destring employment_raw, generate(employment) ignore(", ") force
destring annual_turnover_raw, generate(annual_turnover) ignore(", ") force

* Keep simple audit flags before replacing invalid negative values with missing.
generate byte employment_missing = missing(employment)
generate byte employment_zero = employment == 0 if !missing(employment)
generate byte employment_negative = employment < 0 if !missing(employment)
generate byte turnover_missing = missing(annual_turnover)
generate byte turnover_zero = annual_turnover == 0 if !missing(annual_turnover)
generate byte turnover_negative = annual_turnover < 0 if !missing(annual_turnover)

replace employment = . if employment < 0
replace annual_turnover = . if annual_turnover < 0

* Tempfiles hold intermediate states inside this run without adding more
* generated datasets to the repository.
tempfile census_imported observed_activity_labels official_nacam_rev1_prefixes
save "`census_imported'"

/*******************************************************************************
    2. Import the reviewable census activity crosswalk

    The official INS PDF bridge is stored as a workbook in docs/reference. The
    census-label crosswalk points to that extracted source and is merged here,
    rather than rebuilding the classification through replace rules.
*******************************************************************************/

* Build the list of activity labels that actually appear in the Census. This is
* the coverage universe the external crosswalk must match exactly.
preserve
keep citi_branch activity_detail activity_macro
duplicates drop
sort citi_branch activity_detail
isid citi_branch activity_detail
save "`observed_activity_labels'"
restore

* Import the official PDF-derived bridge and keep the three-digit NACAM Rev.1
* prefixes used to validate crosswalk references below.
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

* Import the manually reviewable Census activity crosswalk. The workbook is the
* only place where detailed Census labels are assigned to official/admin sectors.
import excel using "`census_crosswalk_xlsx'", sheet("activity_crosswalk") firstrow clear

* Normalize crosswalk text fields because Excel may mix blank cells, numeric
* import decisions, and extra spaces.
foreach var in citi_branch activity_detail activity_macro isic_reference ///
    nacam_rev1_reference crosswalk_source_file crosswalk_source_sheet ///
    nacam_label_display nacam_label_short_display mapping_source mapping_note {
    capture confirm string variable `var'
    if _rc {
        tostring `var', replace force
    }
    replace `var' = ustrtrim(`var')
}

* Convert numeric classification fields to Stata numeric variables when Excel
* imported them as strings.
foreach var in official_legacy_nacam nacam review_flag {
    capture confirm numeric variable `var'
    if _rc {
        destring `var', replace force
    }
}

* Keep display labels aligned with the source-backed English NACAM labels used
* in the BDF elasticity crosswalk.
replace nacam_label_display = "Wholesale/retail" if nacam == 31
replace nacam_label_short_display = "Wholesale/retail" if nacam == 31
replace nacam_label_short_display = "Industrial/export agriculture" if nacam == 2
replace nacam_label_short_display = "Food crop agriculture" if nacam == 1
replace nacam_label_short_display = "Electricity/water supply" if nacam == 29
replace nacam_label_short_display = "Accommodation/food services" if nacam == 33
replace nacam_label_short_display = "Post/telecommunications" if nacam == 35
replace nacam_label_short_display = "Services mainly to enterprises" if nacam == 38

assert nacam_label_display == "Wholesale/retail" if nacam == 31
assert nacam_label_short_display == "Wholesale/retail" if nacam == 31
assert nacam_label_short_display == "Industrial/export agriculture" if nacam == 2

* The crosswalk must be unique at the Census branch/detail-label level and must
* explicitly point back to the PDF-derived bridge workbook when a source is named.
assert !missing(citi_branch, activity_detail)
isid citi_branch activity_detail
assert crosswalk_source_file == "nacam_rev1_citi_bridge_extracted.xlsx" if !missing(crosswalk_source_file)

* Validate that each nonmissing NACAM Rev.1 reference uses a prefix observed in
* the official bridge; this catches typos in the reviewable workbook.
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

* Require one-to-one coverage between observed Census activity labels and the
* reviewable crosswalk. Any mismatch means the workbook or source data changed.
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
* Save the Stata copy of the activity crosswalk used by this run.
save "`activity_crosswalk'", replace

/*******************************************************************************
    3. Merge the crosswalk back to firm-level census data
*******************************************************************************/

use "`census_imported'", clear
* Attach sector mappings at the Census activity-label level. The merge is m:1
* because many firms can share the same branch/detail activity label.
merge m:1 citi_branch activity_detail using "`activity_crosswalk'", nogen keep(master match)
assert !missing(review_flag)

* Attach the broad data-export group used in the elasticity plots where an
* admin/BDF NACAM sector is available.
merge m:1 nacam using "`data_export_mapping'", keep(master match) keepusing(data_export)
drop if _merge == 2
drop _merge

* Prefer the admin/BDF-overlap NACAM sector when available; otherwise keep the
* official legacy NACAM sector so whole-economy Census diagnostics include
* sectors absent from the elasticity panel.
generate int census_nacam = nacam
replace census_nacam = official_legacy_nacam if missing(census_nacam)

* Start plot labels from the reviewed crosswalk labels, then fill a small number
* of Census-only sectors that are not present in the admin elasticity mapping.
generate str180 census_nacam_label_display = nacam_label_display
generate str60 census_nacam_label_short_display = nacam_label_short_display

replace census_nacam_label_display = "Machinery and equipment manufacturing" ///
    if missing(census_nacam_label_display) & official_legacy_nacam == 25
replace census_nacam_label_short_display = "Machinery/equipment" ///
    if missing(census_nacam_label_short_display) & official_legacy_nacam == 25

replace census_nacam_label_display = "Electronics and precision equipment manufacturing" ///
    if missing(census_nacam_label_display) & official_legacy_nacam == 26
replace census_nacam_label_short_display = "Electronics/equipment" ///
    if missing(census_nacam_label_short_display) & official_legacy_nacam == 26

replace census_nacam_label_display = "Public administration" ///
    if missing(census_nacam_label_display) & official_legacy_nacam == 39
replace census_nacam_label_short_display = "Public administration" ///
    if missing(census_nacam_label_short_display) & official_legacy_nacam == 39

replace census_nacam_label_display = "Extraterritorial organizations" ///
    if missing(census_nacam_label_display) & official_legacy_nacam == 43
replace census_nacam_label_short_display = "Extraterritorial org." ///
    if missing(census_nacam_label_short_display) & official_legacy_nacam == 43

replace data_export = "C – Manufacturing" if missing(data_export) ///
    & inlist(census_nacam, 25, 26)
replace data_export = "Other services" if missing(data_export) ///
    & inlist(census_nacam, 39, 43)

* Employment and turnover questions are headquarters-only in the Census
* documentation, so non-headquarters values are excluded from diagnostics.
replace employment = . if !hq_sample
replace annual_turnover = . if !hq_sample

* These flags separate data availability from sector inclusion in later audit
* tables and plots.
generate byte has_employment = !missing(employment)
generate byte has_turnover = !missing(annual_turnover)
generate byte plotted_sample = hq_sample == 1 & !missing(census_nacam)

label variable firmid_census "Census firm identifier"
label variable source_excel_row "Original Excel row in BASE sheet"
label variable activity_detail "Census detailed activity label, S1Q14B"
label variable citi_branch "Census CITI Rev.4 branch label, BRANCHD_S1Q14"
label variable official_legacy_nacam "Official legacy NACAM branch from PDF-derived crosswalk"
label variable nacam "Legacy/admin NACAM branch observed in CMR_BDF elasticity data"
label variable census_nacam "Legacy NACAM branch used for Census diagnostics"
label variable review_flag "1 if mapping is approximate, absent from CMR_BDF sectors, or needs review"
label variable plotted_sample "Headquarters row with an official/admin NACAM sector used in Census diagnostics"

* Save the firm-level cleaned Census file before sector aggregation.
capture save "`clean_out'", replace
if _rc {
    sleep `sleep_ms'
    save "`clean_out'", replace
}

/*******************************************************************************
    4. Audit tables
*******************************************************************************/

* Store headline row counts in locals for a compact LaTeX audit table. These
* counts document the sample path from raw Census rows to plotted HQ sectors.
quietly count
local all_rows = r(N)
quietly count if hq_sample == 1
local hq_rows = r(N)
quietly count if plotted_sample == 1
local plotted_rows = r(N)
quietly count if hq_sample == 1 & missing(nacam) & !missing(census_nacam)
local hq_outside_elasticity_rows = r(N)
quietly count if hq_sample == 1 & missing(census_nacam)
local hq_unmapped_rows = r(N)
quietly count if hq_sample == 1 & review_flag == 1
local hq_review_rows = r(N)

* Count unique observed activity labels separately from firm rows; this audits
* crosswalk coverage at the classification-label level.
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

* Official bridge unmatched labels should be zero after the validation step
* above; keeping the count in the table makes that check visible in outputs.
preserve
keep citi_branch activity_detail official_bridge_unmatched
duplicates drop
quietly count if official_bridge_unmatched == 1
local bridge_unmatched_labels = r(N)
restore

* Convert audit locals to a matrix so esttab can export a booktabs LaTeX
* fragment without manual table editing.
matrix census_audit = ( ///
    `all_rows' \ ///
    `hq_rows' \ ///
    `activity_labels' \ ///
    `mapped_labels' \ ///
    `review_labels' \ ///
    `bridge_unmatched_labels' \ ///
    `hq_review_rows' \ ///
    `hq_outside_elasticity_rows' \ ///
    `hq_unmapped_rows' \ ///
    `plotted_rows' ///
)
matrix colnames census_audit = Value
matrix rownames census_audit = all_rows hq_rows activity_labels mapped_labels review_labels bridge_unmatched_labels hq_review_rows hq_outside_elasticity_rows hq_unmapped_rows plotted_rows

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
        hq_outside_elasticity_rows "Headquarters rows outside elasticity NACAM sectors" ///
        hq_unmapped_rows "Headquarters rows without official/admin NACAM" ///
        plotted_rows "Headquarters rows used in Census NACAM plots" ///
    )

* Provide a small, fixed set of mapping examples for the deck/note. These are
* illustrative examples, not inputs to the Census merge logic above.
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
* Sector diagnostics are based on headquarters rows with an official/admin NACAM
* sector. The firm-level cleaned data saved above still retains all rows.
keep if plotted_sample == 1
assert !missing(census_nacam, census_nacam_label_short_display, data_export)

* Firm-level turnover per worker is computed before collapsing so the sector
* average captures the average firm ratio, distinct from aggregate revenue per
* aggregate worker computed after collapse.
generate double turnover_per_worker_firm = annual_turnover / employment ///
    if !missing(annual_turnover, employment) & annual_turnover >= 0 ///
    & employment > 0

* Collapse from firm rows to one row per Census NACAM sector, carrying both
* aggregate scale measures and simple sector firm averages.
collapse ///
    (count) firms = source_excel_row ///
    (sum) total_employment = employment annual_turnover has_employment has_turnover ///
    (mean) average_employment = employment ///
        average_revenue = annual_turnover ///
        average_turnover_per_worker = turnover_per_worker_firm, ///
    by(census_nacam census_nacam_label_display census_nacam_label_short_display data_export)

* Harmonize names with the elasticity sector outputs so downstream figure code
* can use the same label vocabulary.
rename census_nacam nacam
rename census_nacam_label_display nacam_label_display
rename census_nacam_label_short_display nacam_label_short_display
rename annual_turnover total_turnover

* Construct scale, ratio, and log variables used in the diagnostic figures.
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

* Save the sector-level dataset that directly feeds the Census figures.
save "`diagnostics_out'", replace

* Reusable plotting helper for horizontal dot plots. Each plotted variable is
* sorted descending within the current dataset, and marker color/shape comes
* from the broad data_export sector group.
capture program drop cmr_census_colored_dotplot
program define cmr_census_colored_dotplot
    version 17.0
    syntax varname(numeric) [if], Title(string asis) XTitle(string asis) ///
        Name(name) [LABSZ(string) TITLESZ(string) XDIM(string) ///
        YDIM(string) LEGENDOFF]

    marksample touse

    * Defaults are tuned for the slide dimensions used by this project.
    if "`labsz'" == "" {
        local labsz "vsmall"
    }
    if "`titlesz'" == "" {
        local titlesz "medsmall"
    }
    if "`xdim'" == "" {
        local xdim "7.5"
    }
    if "`ydim'" == "" {
        local ydim "6.2"
    }

    * Standalone plots keep a legend; combined two-panel plots use the right
    * panel as the shared color/shape legend.
    if "`legendoff'" == "legendoff" {
        local legend_options legend(off)
    }
    else {
        local legend_options ///
            legend(order(1 "Agriculture" 2 "Mining" 3 "Manufacturing" ///
                4 "Utilities" 5 "Construction" 6 "Wholesale/retail + repair" ///
                7 "Transport" 8 "Information" 9 "Finance" ///
                10 "Other services") cols(1) pos(3) ring(1) size(tiny) ///
                region(lcolor(none) fcolor(none)))
    }

    preserve
    * Keep only rows that the caller requested and that have a nonmissing metric.
    keep if `touse'
    keep if !missing(`varlist')
    count
    if r(N) == 0 {
        display as error "No nonmissing observations for `varlist'."
        exit 2000
    }

    * Sort sectors by the plotted metric so each figure is independently ranked.
    gsort -`varlist' nacam
    generate int plot_order = _n

    * Build a temporary value label for the y-axis from the short NACAM labels.
    capture label drop census_sector_plot
    forvalues i = 1/`=_N' {
        local sector_label = subinstr(nacam_label_short_display[`i'], char(34), "'", .)
        if `i' == 1 {
            label define census_sector_plot `i' `"`sector_label'"'
        }
        else {
            label define census_sector_plot `i' `"`sector_label'"', modify
        }
    }
    label values plot_order census_sector_plot

    local last_order = _N

    * Draw one scatter layer per broad sector group so the legend and marker
    * vocabulary match the Cameroon elasticity plots.
    twoway ///
        (scatter plot_order `varlist' if data_export == "A – Agriculture, Forestry and Fishing", ///
            msymbol(circle) mcolor("27 158 119") msize(medlarge)) ///
        (scatter plot_order `varlist' if data_export == "B – Mining and Quarrying", ///
            msymbol(diamond) mcolor("117 112 179") msize(medlarge)) ///
        (scatter plot_order `varlist' if data_export == "C – Manufacturing", ///
            msymbol(square) mcolor("44 123 182") msize(medlarge)) ///
        (scatter plot_order `varlist' if data_export == "Utilities", ///
            msymbol(triangle) mcolor("230 171 2") msize(medlarge)) ///
        (scatter plot_order `varlist' if data_export == "F – Construction", ///
            msymbol(Oh) mcolor("208 28 139") msize(medlarge)) ///
        (scatter plot_order `varlist' if data_export == "G – Wholesale and Retail Trade; Repair of Motor Vehicles", ///
            msymbol(Th) mcolor("217 95 2") msize(medlarge)) ///
        (scatter plot_order `varlist' if data_export == "H – Transportation and Storage", ///
            msymbol(Sh) mcolor("102 166 30") msize(medlarge)) ///
        (scatter plot_order `varlist' if data_export == "J – Information and Communication", ///
            msymbol(plus) mcolor("102 166 30") msize(medlarge)) ///
        (scatter plot_order `varlist' if data_export == "K – Financial and Insurance Activities", ///
            msymbol(x) mcolor("117 112 179") msize(medlarge)) ///
        (scatter plot_order `varlist' if data_export == "Other services", ///
            msymbol(Dh) mcolor("102 102 102") msize(medlarge)), ///
        ylabel(1(1)`last_order', valuelabel angle(horizontal) ///
            labsize(`labsz') noticks) ///
        yscale(reverse) ///
        xlabel(, grid glpattern(dash) glcolor(gs13)) ///
        xtitle(`xtitle', size(small)) ///
        ytitle("") ///
        title(`title', size(`titlesz')) ///
        `legend_options' ///
        plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
        ysize(`ydim') xsize(`xdim') name(`name', replace)
    restore
end

* Firm-count plot: a single count panel is enough because counts have no
* meaningful sector-average counterpart.
cmr_census_colored_dotplot firms, ///
    title("Census firm counts by NACAM sector") ///
    xtitle("Headquarters firms") ///
    name(census_firms) labsz(tiny) titlesz(medsmall) ///
    ydim(6.2) xdim(7.5)
graph export "${OUTPUTDIR}/figures/cmr_census_firm_count_by_nacam.pdf", replace
graph export "${OUTPUTDIR}/figures/cmr_census_firm_count_by_nacam.png", replace

* Employment scale plot: combine aggregate sector employment with the average
* firm size in the sector, both on log scales for readability.
cmr_census_colored_dotplot total_employment if !missing(total_employment), ///
    title("Aggregate sector total") ///
    xtitle("Log total employment") ///
    name(census_emp_total) labsz(tiny) titlesz(small) ///
    ydim(6.2) xdim(4.2) legendoff

cmr_census_colored_dotplot average_employment if !missing(average_employment), ///
    title("Sector firm average") ///
    xtitle("Log average firm employment") ///
    name(census_emp_average) labsz(tiny) titlesz(small) ///
    ydim(6.2) xdim(5.4)

graph combine census_emp_total census_emp_average, ///
    cols(2) title("Census log employment by NACAM sector", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(6.2) xsize(11.5) name(census_emp_combined, replace)
graph display census_emp_combined
graph export "${OUTPUTDIR}/figures/cmr_census_total_employment_by_nacam.pdf", replace
graph export "${OUTPUTDIR}/figures/cmr_census_total_employment_by_nacam.png", replace

* Revenue scale plot: show the sector total and the mean firm turnover side by
* side so large sectors are not confused with high-average firms.
cmr_census_colored_dotplot log_total_revenue if !missing(log_total_revenue), ///
    title("Aggregate sector total") ///
    xtitle("Log total annual revenue") ///
    name(census_rev_total) labsz(tiny) titlesz(small) ///
    ydim(6.2) xdim(4.2) legendoff

cmr_census_colored_dotplot log_average_revenue if !missing(log_average_revenue), ///
    title("Sector firm average") ///
    xtitle("Log average firm annual revenue") ///
    name(census_rev_average) labsz(tiny) titlesz(small) ///
    ydim(6.2) xdim(5.4)

graph combine census_rev_total census_rev_average, ///
    cols(2) title("Census log annual revenue by NACAM sector", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(6.2) xsize(11.5) name(census_rev_combined, replace)
graph display census_rev_combined
graph export "${OUTPUTDIR}/figures/cmr_census_total_revenue_by_nacam.pdf", replace
graph export "${OUTPUTDIR}/figures/cmr_census_total_revenue_by_nacam.png", replace

* Keep the older average-employment standalone figure available for slides or
* quick review even though the combined employment figure is now primary.
cmr_census_colored_dotplot average_employment, ///
    title("Census average employment by NACAM sector") ///
    xtitle("Average employment") ///
    name(census_avg_emp) labsz(tiny) titlesz(medsmall) ///
    ydim(6.2) xdim(7.5)
graph export "${OUTPUTDIR}/figures/cmr_census_average_employment_by_nacam.pdf", replace
graph export "${OUTPUTDIR}/figures/cmr_census_average_employment_by_nacam.png", replace

* Revenue-per-worker plot: compare the aggregate ratio with the average of
* firm-level ratios, which answer related but distinct diagnostic questions.
cmr_census_colored_dotplot log_turnover_per_worker ///
    if !missing(log_turnover_per_worker), ///
    title("Aggregate sector ratio") ///
    xtitle("Log annual revenue per worker") ///
    name(census_rpw_total) labsz(tiny) titlesz(small) ///
    ydim(6.2) xdim(4.2) legendoff

cmr_census_colored_dotplot log_average_turnover_per_worker ///
    if !missing(log_average_turnover_per_worker), ///
    title("Sector firm average") ///
    xtitle("Log average annual revenue per worker") ///
    name(census_rpw_average) labsz(tiny) titlesz(small) ///
    ydim(6.2) xdim(5.4)

graph combine census_rpw_total census_rpw_average, ///
    cols(2) title("Census log annual revenue per worker by NACAM sector", size(medsmall)) ///
    plotregion(color(white)) graphregion(color(white)) ///
    ysize(6.2) xsize(11.5) name(census_rpw_combined, replace)
graph display census_rpw_combined
graph export "${OUTPUTDIR}/figures/cmr_census_turnover_per_worker_by_nacam.pdf", replace
graph export "${OUTPUTDIR}/figures/cmr_census_turnover_per_worker_by_nacam.png", replace
restore

display as result "Saved census cleaned data to `clean_out'"
display as result "Saved census NACAM diagnostics to `diagnostics_out'"
display as result "Saved census activity crosswalk to `activity_crosswalk'"

log close cmrcensus
