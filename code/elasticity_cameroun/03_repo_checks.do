version 17.0
set more off

/*******************************************************************************
    Purpose:
        Verify that the analysis-module repository structure exists and that the
        current Cameroon data folders are reachable from the project root.

    Inputs:
        Globals created by code/01_setup.do.

    Outputs:
        Console checks only.
*******************************************************************************/

if "${PROJECT_ROOT}" == "" {
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
        display as error "Add this user to the bootstrap block in code/elasticity_cameroun/03_repo_checks.do."
        exit 601
    }

    capture noisily cd "${project_root}"
    if _rc | !fileexists("AGENTS.md") {
        display as error "Configured project_root is not a valid repo root: ${project_root}"
        exit 601
    }

    do "code/01_setup.do"
}

display as text "Running repository structure checks..."

local current_dir = c(pwd)

foreach dir in ///
    "${ELASTICITY_CAMEROUN_CODEDIR}" ///
    "${WBES_TRADE_CODEDIR}" ///
    "${CAMEROONDIR}/Raw" ///
    "${CAMEROONDIR}/Clean" ///
    "${DATADIR}/WBES_manual" ///
    "${OUTPUTDIR}/tables" ///
    "${OUTPUTDIR}/figures" ///
    "${OUTPUTDIR}/slides" ///
    "${LOGDIR}" ///
    "${MANUSCRIPTDIR}" ///
    "${SLIDESDIR}" {
    capture noisily cd "`dir'"
    if _rc {
        display as error "Expected directory missing: `dir'"
        error 693
    }
    quietly cd "`current_dir'"
}

display as result "Repository directories verified."


