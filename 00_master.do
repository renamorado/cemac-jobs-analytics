version 18.0
clear all
set more off

capture log close _all

do "01_setup.do"

log using "${LOGDIR}/00_master.log", replace text

display as text "Starting repository pipeline from ${PROJECT_ROOT}"
display as text "Current setup stage: repository scaffolding and validation only."

/*******************************************************************************
    Future pipeline order
*******************************************************************************/

* 1. Data preparation
* do "${CODEDIR}/01_data_prep/..."

* 2. Variable construction
* do "${CODEDIR}/02_construct/..."

* 3. Analysis
* do "${CODEDIR}/03_analysis/..."

* 4. Outputs
* do "${CODEDIR}/04_output/..."

* 5. Checks
do "${CODEDIR}/05_checks/01_repo_checks.do"

display as result "Repository scaffolding check completed successfully."

log close

