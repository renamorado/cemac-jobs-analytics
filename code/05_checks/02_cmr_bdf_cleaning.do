version 18.0
set more off

/*******************************************************************************
    Purpose:
        Clean the Cameroon BDF file to one row per firm-year.
        Keep one record for perfect duplicates and drop conflicting duplicates.
        Export short LaTeX note fragments for duplicate cleaning and the
        NACAM-to-ISIC crosswalk summary.

    Inputs:
        Globals and packages created by code/01_setup.do.
        Data/Cameroon/Clean/CMR_BDF.dta
        Data/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta

    Outputs:
        Data/Analysis/CMR_BDF_cleaned.dta
        output/tables/cmr_bdf_cleaning_note_duplicate_summary.tex
        output/tables/cmr_bdf_cleaning_note_crosswalk_summary.tex
        logs/02_cmr_bdf_cleaning_*.log
*******************************************************************************/

* This stage assumes code/01_setup.do has already defined project globals and
* installed esttab.

local sleep_ms = real("${SLEEP_MS}")
local log_stamp = subinstr(c(current_time), ":", "", .)
local log_stamp = subinstr("`log_stamp'", " ", "", .)

if missing(`sleep_ms') {
    local sleep_ms 750
}

* Open a step log with a small retry for OneDrive sync delays.
capture log close cmrdiag
capture log using "${LOGDIR}/02_cmr_bdf_cleaning_`log_stamp'.log", text name(cmrdiag)
if _rc {
    sleep `sleep_ms'
    capture log using "${LOGDIR}/02_cmr_bdf_cleaning_`log_stamp'.log", text name(cmrdiag)
}
if _rc {
    display as error "Unable to open the cleaning log after retry."
    error _rc
}

* Load the working Cameroon BDF file from the repository.
confirm file "${CAMEROONDIR}/Clean/CMR_BDF.dta"
use "${CAMEROONDIR}/Clean/CMR_BDF.dta", clear

* Destring numeric fields before duplicate checks so formatting noise does not
* create fake conflicts across otherwise identical firm-year records.
ds, has(type string)
local string_vars `r(varlist)'
local id_string_vars firmid
local numeric_string_vars : list string_vars - id_string_vars

local forced_missing_vars
local forced_missing_total 0

foreach var of local numeric_string_vars {
    replace `var' = ustrtrim(`var')
    replace `var' = subinstr(`var', char(13), "", .)
    replace `var' = subinstr(`var', char(10), "", .)
    replace `var' = subinstr(`var', char(9), "", .)
    replace `var' = subinstr(`var', char(160), "", .)
    replace `var' = subinstr(`var', " ", "", .)
    replace `var' = "" if inlist(upper(`var'), "", "NA", "-")
    replace `var' = substr(`var', 1, length(`var') - 1) if regexm(`var', "^[0-9.]+-$")

    quietly count if !missing(`var') & missing(real(subinstr(`var', ",", "", .)))
    local forced_missing_here = r(N)

    if `forced_missing_here' > 0 {
        local forced_missing_total = `forced_missing_total' + `forced_missing_here'
        local forced_missing_vars `forced_missing_vars' `var'
        display as text "Coercing `forced_missing_here' corrupted values in `var' to missing during destring."
    }

    destring `var', replace ignore(",") force
}

ds, has(type string)
local remaining_string_vars `r(varlist)'
local unexpected_string_vars : list remaining_string_vars - id_string_vars

if "`unexpected_string_vars'" != "" {
    display as error "Unexpected string variables remain after numeric destringing: `unexpected_string_vars'"
    error 459
}

display as result "Destringed numeric string variables in Cameroon BDF source data."
if `forced_missing_total' > 0 {
    display as text "Total corrupted numeric-string values coerced to missing: `forced_missing_total'"
    display as text "Affected variables: `forced_missing_vars'"
}

* Record the starting file size before any cleaning.
quietly count
local original_observations = r(N)

* Preserve the original row order so exact-duplicate retention is deterministic.
gen long original_order = _n

* Count firm-year duplicates using the intended panel key.
sort firmid fin_yr
by firmid fin_yr: gen long firmyear_n = _N
egen byte tag_firmyear = tag(firmid fin_yr)

* Build the list of original data variables for full-row duplicate checks.
ds original_order, not
local original_vars `r(varlist)'

* Count distinct full records within each firm-year group.
sort `original_vars'
by `original_vars': gen byte tag_full_record = _n == 1
sort firmid fin_yr original_order
by firmid fin_yr: egen long distinct_record_profiles = total(tag_full_record)

* Classify each firm-year as unique, perfect duplicate, or conflicting duplicate.
gen byte duplicate_class = 0 if firmyear_n == 1
replace duplicate_class = 1 if firmyear_n > 1 & distinct_record_profiles == 1
replace duplicate_class = 2 if firmyear_n > 1 & distinct_record_profiles > 1
label define duplicate_class 0 "Unique firm-year" 1 "Perfect duplicate" 2 "Conflicting duplicate", replace
label values duplicate_class duplicate_class

* Save the counts needed for the short cleaning note.
quietly count if tag_firmyear & duplicate_class == 1
local exact_dup_groups = r(N)

quietly count if duplicate_class == 1
local exact_dup_observations = r(N)
local exact_dup_dropped = `exact_dup_observations' - `exact_dup_groups'

quietly count if tag_firmyear & duplicate_class == 2
local conflicting_dup_groups = r(N)

quietly count if duplicate_class == 2
local conflicting_dup_observations = r(N)

display as text "Duplicate rule: keep one record for perfect duplicates and drop conflicting firm-years."
display as result "Perfect duplicate groups kept once: `exact_dup_groups'"
display as result "Extra rows dropped from perfect duplicates: `exact_dup_dropped'"
display as result "Conflicting duplicate groups dropped: `conflicting_dup_groups'"
display as result "Rows dropped from conflicting groups: `conflicting_dup_observations'"

* Keep the first original row inside each perfect-duplicate group.
sort firmid fin_yr original_order
by firmid fin_yr: gen byte keep_first_exact = _n == 1 if duplicate_class == 1
drop if duplicate_class == 1 & keep_first_exact == 0

* Drop all records in firm-years with conflicting values.
drop if duplicate_class == 2

* Check that the cleaned file is now one row per firm-year.
isid firmid fin_yr

quietly count
local final_observations = r(N)

* Export a short duplicate-cleaning summary for the manuscript note.
matrix duplicate_cleaning = ( ///
    `original_observations' \ ///
    `exact_dup_groups' \ ///
    `exact_dup_dropped' \ ///
    `conflicting_dup_groups' \ ///
    `conflicting_dup_observations' \ ///
    `final_observations' ///
)
matrix colnames duplicate_cleaning = Value
matrix rownames duplicate_cleaning = original_obs exact_dup_groups exact_dup_drop conflict_dup_groups conflict_dup_drop final_obs

esttab matrix(duplicate_cleaning, fmt(%12.0fc)) using "${OUTPUTDIR}/tables/cmr_bdf_cleaning_note_duplicate_summary.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels( ///
        original_obs "Original observations" ///
        exact_dup_groups "Perfect duplicate firm-years" ///
        exact_dup_drop "Rows dropped from perfect duplicates" ///
        conflict_dup_groups "Conflicting duplicate firm-years" ///
        conflict_dup_drop "Rows dropped from conflicting duplicates" ///
        final_obs "Final cleaned observations" ///
    )

* Attach NACAM labels for downstream analysis figures and tables.
confirm file "${DATADIR}/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta"
merge m:1 nacam using "${DATADIR}/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta", ///
    keep(master match) keepusing(nacam_label nacam_label_en nacam_label_short_en)
assert _merge == 3 if !missing(nacam)
drop _merge
assert !missing(nacam_label, nacam_label_en, nacam_label_short_en) if !missing(nacam)

* Build display labels here so downstream analysis only reads prepared fields.
generate str180 nacam_label_display = ""
replace nacam_label_display = nacam_label_en if !missing(nacam)
assert !missing(nacam_label_display) if !missing(nacam)

generate str60 nacam_label_short_display = ""
replace nacam_label_short_display = nacam_label_short_en if !missing(nacam)
assert !missing(nacam_label_short_display) if !missing(nacam)

* Remove helper variables before saving the cleaned analysis file.
drop original_order firmyear_n tag_firmyear tag_full_record distinct_record_profiles duplicate_class keep_first_exact

* Save the cleaned file with a small retry for OneDrive sync delays.
capture save "${DATADIR}/Analysis/CMR_BDF_cleaned.dta", replace
if _rc {
    sleep `sleep_ms'
    capture save "${DATADIR}/Analysis/CMR_BDF_cleaned.dta", replace
}
if _rc {
    display as error "Unable to save ${DATADIR}/Analysis/CMR_BDF_cleaned.dta after retry."
    error _rc
}

display as result "Saved cleaned file to ${DATADIR}/Analysis/CMR_BDF_cleaned.dta"

/*******************************************************************************
    2. Export a short NACAM-to-ISIC crosswalk summary for the cleaning note
*******************************************************************************/

confirm file "${DATADIR}/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta"
use "${DATADIR}/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta", clear

isid nacam

quietly count
local crosswalk_observed_codes = r(N)

quietly count if manual_review_flag == 0
local crosswalk_exact_codes = r(N)

quietly count if manual_review_flag == 1
local crosswalk_manual_review_codes = r(N)

assert `crosswalk_exact_codes' + `crosswalk_manual_review_codes' == `crosswalk_observed_codes'
assert !missing(isic_rev4_division) if manual_review_flag == 0
assert missing(isic_rev4_division) if manual_review_flag == 1

matrix crosswalk_summary = ( ///
    `crosswalk_observed_codes' \ ///
    `crosswalk_exact_codes' \ ///
    `crosswalk_manual_review_codes' ///
)
matrix colnames crosswalk_summary = Value
matrix rownames crosswalk_summary = observed_codes exact_division_codes manual_review_codes

esttab matrix(crosswalk_summary, fmt(%12.0fc)) using "${OUTPUTDIR}/tables/cmr_bdf_cleaning_note_crosswalk_summary.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels( ///
        observed_codes "Observed legacy NACAM codes covered" ///
        exact_division_codes "Codes with exact ISIC Rev.4 division assignment" ///
        manual_review_codes "Codes flagged for manual review" ///
    )

display as result "Saved crosswalk summary to ${OUTPUTDIR}/tables/cmr_bdf_cleaning_note_crosswalk_summary.tex"

log close cmrdiag

