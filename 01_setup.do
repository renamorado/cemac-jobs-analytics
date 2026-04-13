version 18.0
set more off

/*******************************************************************************
    Purpose:
        Define project paths, create the starter folder structure, and install
        core user-written commands required by the default workflow.

    Inputs:
        Run from the project root.

    Outputs:
        Project globals, expected folders, and installed Stata packages.
*******************************************************************************/

local root = c(pwd)

if !fileexists("`root'/AGENTS.md") {
    display as error "01_setup.do must be run from the repository root."
    error 601
}

global PROJECT_ROOT "`root'"
global DATADIR      "${PROJECT_ROOT}/Data"
global CODEDIR      "${PROJECT_ROOT}/code"
global OUTPUTDIR    "${PROJECT_ROOT}/output"
global LOGDIR       "${PROJECT_ROOT}/logs"
global MANUSCRIPTDIR "${PROJECT_ROOT}/manuscript"
global SLIDESDIR    "${PROJECT_ROOT}/slides"
global SCRATCHDIR   "${PROJECT_ROOT}/scratch"

* Keep a small retry pause for transient Windows file and viewer locks.
global SLEEP_MS     750

* Optional machine-specific overrides belong in an untracked local file.
capture confirm file "config_local_paths.do"
if !_rc {
    do "config_local_paths.do"
}

*Setup folder structure if it doesn't exist.
foreach dir in ///
    "${CODEDIR}" ///
    "${CODEDIR}/01_data_prep" ///
    "${CODEDIR}/02_construct" ///
    "${CODEDIR}/03_analysis" ///
    "${CODEDIR}/04_output" ///
    "${CODEDIR}/05_checks" ///
    "${DATADIR}/Intermediate" ///
    "${DATADIR}/Analysis" ///
    "${DATADIR}/WBES_manual" ///
    "${OUTPUTDIR}" ///
    "${OUTPUTDIR}/tables" ///
    "${OUTPUTDIR}/figures" ///
    "${OUTPUTDIR}/slides" ///
    "${LOGDIR}" ///
    "${SCRATCHDIR}" ///
    "${MANUSCRIPTDIR}" ///
    "${SLIDESDIR}" {
    capture mkdir "`dir'"
}

/*******************************************************************************
    Core package setup
*******************************************************************************/

capture which esttab
if _rc {
    ssc install estout
}

capture which ftools
if _rc {
    ssc install ftools
}

capture which reghdfe
if _rc {
    ssc install reghdfe
}

/*******************************************************************************
    Baseline data checks
*******************************************************************************/

if !direxists("${DATADIR}/Cameroon/Raw") {
    display as error "Expected folder missing: ${DATADIR}/Cameroon/Raw"
    display as error "Copy the Cameroon raw data from the OneDrive backup into the active local repo before running the pipeline."
    error 693
}

if !direxists("${DATADIR}/Cameroon/Clean") {
    display as error "Expected folder missing: ${DATADIR}/Cameroon/Clean"
    display as error "Copy the Cameroon cleaned data from the OneDrive backup into the active local repo before running the pipeline."
    error 693
}

display as text "Project root set to ${PROJECT_ROOT}"
display as text "Starter folder structure verified."
