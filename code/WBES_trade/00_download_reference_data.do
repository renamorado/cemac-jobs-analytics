version 17.0
set more off

/*******************************************************************************
    Purpose:
        Download official reference sources used by the WBES trade prep stage.
        This step stores raw source files unchanged so the provenance of later
        merge-ready datasets is transparent.

    Inputs:
        Globals created by code/01_setup.do.

    Outputs:
        Data/Intermediate/reference_raw/world_bank_wits_country_metadata.xlsx
        Data/Intermediate/reference_raw/isic_rev4_english_structure.csv

    Sources:
        World Bank/WITS Country Metadata:
        https://wits.worldbank.org/Country-Metadata.aspx

        UNSD ISIC Rev.4 English structure:
        https://unstats.un.org/unsd/classifications/Econ/Download/In%20Text/ISIC_Rev_4_english_structure.Txt
*******************************************************************************/

if "${DATADIR}" == "" {
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
        display as error "Add this user to the bootstrap block in code/WBES_trade/00_download_reference_data.do."
        exit 601
    }

    capture noisily cd "${project_root}"
    if _rc | !fileexists("AGENTS.md") {
        display as error "Configured project_root is not a valid repo root: ${project_root}"
        exit 601
    }

    do "code/01_setup.do"
}

local reference_raw_dir "${DATADIR}/Intermediate/reference_raw"
capture mkdir "`reference_raw_dir'"

local wb_country_url "https://wits.worldbank.org/data/public/WITSCountryProfile-Country_Indicator_ProductMetada-en.xlsx"
local isic_url "https://unstats.un.org/unsd/classifications/Econ/Download/In%20Text/ISIC_Rev_4_english_structure.Txt"

if !fileexists("`reference_raw_dir'/world_bank_wits_country_metadata.xlsx") {
    copy "`wb_country_url'" "`reference_raw_dir'/world_bank_wits_country_metadata.xlsx"
}

if !fileexists("`reference_raw_dir'/isic_rev4_english_structure.csv") {
    copy "`isic_url'" "`reference_raw_dir'/isic_rev4_english_structure.csv"
}

confirm file "`reference_raw_dir'/world_bank_wits_country_metadata.xlsx"
confirm file "`reference_raw_dir'/isic_rev4_english_structure.csv"

display as result "Official reference sources are available in `reference_raw_dir'."
