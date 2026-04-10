version 18.0
clear all
set more off

capture log close _all

do "01_setup.do"

log using "${LOGDIR}/00_master.log", replace text

display as text "Starting repository pipeline from ${PROJECT_ROOT}"
display as text "Current setup stage: NACAM crosswalk construction, repository validation, and Cameroon cleaning-note exports."

/*******************************************************************************
    Future pipeline order
*******************************************************************************/

* 1. Data preparation
* do "${CODEDIR}/01_data_prep/..."

* 2. Variable construction
do "${CODEDIR}/02_construct/01_nacam_isic_crosswalk.do"

* 3. Analysis
* do "${CODEDIR}/03_analysis/..."

* 4. Outputs
* do "${CODEDIR}/04_output/..."

* 5. Checks and cleaning
do "${CODEDIR}/05_checks/01_repo_checks.do"
do "${CODEDIR}/05_checks/02_cmr_bdf_cleaning.do"

display as result "Repository checks and Cameroon BDF cleaning completed successfully."

log close
