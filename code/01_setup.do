version 17.0
set more off

/*******************************************************************************
    Purpose:
        Define project paths, create the starter folder structure, and install
        core user-written commands required by the current Cameroon workflow.

    Inputs:
        Run from the repository root with do "code/01_setup.do", or from
        code/ with do "01_setup.do".

    Outputs:
        Project globals, expected folders, and installed Stata packages.
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
    display as error "Add this user to the bootstrap block in code/01_setup.do."
    exit 601
}

capture noisily cd "${project_root}"
if _rc | !fileexists("AGENTS.md") {
    display as error "Configured project_root is not a valid repo root: ${project_root}"
    exit 601
}

local root = subinstr(c(pwd), "\", "/", .)

global PROJECT_ROOT   "`root'"
global DATADIR        "${PROJECT_ROOT}/Data"
global CAMEROONDIR    "${DATADIR}/Cameroon"
global CODEDIR        "${PROJECT_ROOT}/code"
global ELASTICITY_CAMEROUN_CODEDIR "${CODEDIR}/elasticity_cameroun"
global WBES_TRADE_CODEDIR "${CODEDIR}/WBES_trade"
global OUTPUTDIR      "${PROJECT_ROOT}/output"
global LOGDIR         "${PROJECT_ROOT}/logs"
global MANUSCRIPTDIR  "${PROJECT_ROOT}/manuscript"
global SLIDESDIR      "${PROJECT_ROOT}/slides"
global SCRATCHDIR     "${PROJECT_ROOT}/scratch"

* Keep a small retry pause for transient Windows file and viewer locks.
global SLEEP_MS       750

* Optional machine-specific overrides belong in an untracked local file.
capture confirm file "config_local_paths.do"
if !_rc {
    do "config_local_paths.do"
}

* Set up the forward-looking folder structure.
foreach dir in ///
    "${CODEDIR}" ///
    "${ELASTICITY_CAMEROUN_CODEDIR}" ///
    "${WBES_TRADE_CODEDIR}" ///
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

local current_dir = c(pwd)

capture noisily cd "${CAMEROONDIR}/Raw"
if _rc {
    display as error "Expected folder missing: ${CAMEROONDIR}/Raw"
    display as error "Copy the Cameroon raw data from the archived OneDrive backup into this local repo before running the pipeline."
    error 693
}
quietly cd "`current_dir'"

capture noisily cd "${CAMEROONDIR}/Clean"
if _rc {
    display as error "Expected folder missing: ${CAMEROONDIR}/Clean"
    display as error "Copy the Cameroon cleaned data from the archived OneDrive backup into this local repo before running the pipeline."
    error 693
}
quietly cd "`current_dir'"

display as text "Project root set to ${PROJECT_ROOT}"
display as text "Cameroon folder structure verified."

