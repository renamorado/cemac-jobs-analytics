version 18.0
set more off

/*******************************************************************************
    Purpose:
        Clean the Cameroon BDF file to one row per firm-year.
        Keep one record for perfect duplicates and drop conflicting duplicates.
        Export short LaTeX note fragments for duplicate cleaning and the
        NACAM-to-ISIC crosswalk summary.

    Inputs:
        Run after 01_setup.do from the repository root.
        Data/Cameroon/Clean/CMR_BDF.dta
        Data/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta

    Outputs:
        Data/Analysis/CMR_BDF_cleaned.dta
        output/tables/cmr_bdf_cleaning_note_duplicate_summary.tex
        output/tables/cmr_bdf_cleaning_note_crosswalk_summary.tex
        logs/02_cmr_bdf_cleaning_*.log
*******************************************************************************/

* Stop early if setup has not already defined the project globals.
local setup_missing = "${PROJECT_ROOT}" == "" | "${LOGDIR}" == "" | "${OUTPUTDIR}" == ""
if `setup_missing' display as error "Setup is not loaded. Run 00_master.do or 01_setup.do from the repository root first."
if `setup_missing' exit 197

* esttab should already be available from 01_setup.do.
capture which esttab
local missing_esttab = _rc
if `missing_esttab' display as error "esttab is not available. Run 01_setup.do from the repository root first."
if `missing_esttab' exit 199

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
confirm file "Data/Cameroon/Clean/CMR_BDF.dta"
use "Data/Cameroon/Clean/CMR_BDF.dta", clear

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

esttab matrix(duplicate_cleaning, fmt(%12.0fc)) using "output/tables/cmr_bdf_cleaning_note_duplicate_summary.tex", ///
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
confirm file "Data/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta"
merge m:1 nacam using "Data/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta", ///
    keep(master match) keepusing(nacam_label nacam_label_en nacam_label_short_en)
assert _merge == 3 if !missing(nacam)
drop _merge
assert !missing(nacam_label, nacam_label_en, nacam_label_short_en) if !missing(nacam)

* Remove helper variables before saving the cleaned analysis file.
drop original_order firmyear_n tag_firmyear tag_full_record distinct_record_profiles duplicate_class keep_first_exact

* Save the cleaned file with a small retry for OneDrive sync delays.
capture save "Data/Analysis/CMR_BDF_cleaned.dta", replace
if _rc {
    sleep `sleep_ms'
    capture save "Data/Analysis/CMR_BDF_cleaned.dta", replace
}
if _rc {
    display as error "Unable to save Data/Analysis/CMR_BDF_cleaned.dta after retry."
    error _rc
}

display as result "Saved cleaned file to Data/Analysis/CMR_BDF_cleaned.dta"

/*******************************************************************************
    2. Export a short NACAM-to-ISIC crosswalk summary for the cleaning note
*******************************************************************************/

confirm file "Data/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta"
use "Data/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta", clear

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

esttab matrix(crosswalk_summary, fmt(%12.0fc)) using "output/tables/cmr_bdf_cleaning_note_crosswalk_summary.tex", ///
    replace booktabs fragment nomtitles nonumbers ///
    varlabels( ///
        observed_codes "Observed legacy NACAM codes covered" ///
        exact_division_codes "Codes with exact ISIC Rev.4 division assignment" ///
        manual_review_codes "Codes flagged for manual review" ///
    )

display as result "Saved crosswalk summary to output/tables/cmr_bdf_cleaning_note_crosswalk_summary.tex"

log close cmrdiag
