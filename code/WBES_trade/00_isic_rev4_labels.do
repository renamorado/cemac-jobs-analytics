version 17.0
set more off

/*******************************************************************************
    Compatibility wrapper.

    The WBES reference workflow is now split into:
        1. code/WBES_trade/00_download_reference_data.do
        2. code/WBES_trade/00_prepare_reference_merges.do

    This wrapper preserves the older command name for ad hoc runs.
*******************************************************************************/

if "${WBES_TRADE_CODEDIR}" == "" {
    local username = lower("`c(username)'")

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
        display as error "Add this user to the bootstrap block in code/WBES_trade/00_isic_rev4_labels.do."
        exit 601
    }

    capture noisily cd "${project_root}"
    if _rc | !fileexists("AGENTS.md") {
        display as error "Configured project_root is not a valid repo root: ${project_root}"
        exit 601
    }

    do "code/01_setup.do"
}

do "${WBES_TRADE_CODEDIR}/00_download_reference_data.do"
do "${WBES_TRADE_CODEDIR}/00_prepare_reference_merges.do"
