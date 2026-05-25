version 17.0
set more off

/*******************************************************************************
    Purpose:
        Convert downloaded official reference files into Stata merge-ready
        datasets for the WBES trade prep stage.

    Inputs:
        Data/Intermediate/reference_raw/world_bank_wits_country_metadata.xlsx
        Data/Intermediate/reference_raw/isic_rev4_english_structure.csv
        Data/World Bank Enterprise Survey/New_Comprehensive_July_21_2025.dta

    Outputs:
        Data/Intermediate/wbes_wb_country_metadata.dta
        Data/Intermediate/isic_rev4_division_labels.dta

    Notes:
        Labels and categories come from downloaded official files. The only
        hand-maintained values here are merge keys needed because the WBES
        extract stores country names in compact survey-specific forms and does
        not include ISO country codes.
*******************************************************************************/

if "${DATADIR}" == "" {
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
        display as error "Add this user to the bootstrap block in code/WBES_trade/00_prepare_reference_merges.do."
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
local wb_xlsx "`reference_raw_dir'/world_bank_wits_country_metadata.xlsx"
local isic_csv "`reference_raw_dir'/isic_rev4_english_structure.csv"

confirm file "`wb_xlsx'"
confirm file "`isic_csv'"

/*******************************************************************************
    1. Build observed WBES latest-wave country keys
*******************************************************************************/
local source_file "${DATADIR}/World Bank Enterprise Survey/New_Comprehensive_July_21_2025.dta"
confirm file "`source_file'"

use country sample using "`source_file'", clear

generate str80 country_wave = country
generate int country_length = length(country_wave)
generate str60 country_name = substr(country_wave, 1, country_length - 4)
replace country_name = strtrim(country_name)
replace country_name = "Cote d'Ivoire" if strpos(country_name, "Ivoire") > 0

keep if sample == 1
keep country_name
duplicates drop
isid country_name

generate str80 country_match_key = lower(country_name)
replace country_match_key = ustrregexra(country_match_key, "[^a-z0-9]", "")
replace country_match_key = "drc" if country_name == "DRC"

generate str3 wb_iso3_crosswalk = ""

* Manual crosswalk: only survey-name exceptions needed to reach the official
* World Bank/WITS ISO3 code. All labels and categories are imported below.
* WITS uses ZAR for Congo, Dem. Rep. in this workbook.
replace wb_iso3_crosswalk = "ATG" if country_name == "Antiguaandbarbuda"
replace wb_iso3_crosswalk = "BFA" if country_name == "BurkinaFaso"
replace wb_iso3_crosswalk = "CPV" if country_name == "Cabo Verde"
replace wb_iso3_crosswalk = "CIV" if country_name == "Cote d'Ivoire"
replace wb_iso3_crosswalk = "CZE" if country_name == "Czechia"
replace wb_iso3_crosswalk = "ZAR" if country_name == "DRC"
replace wb_iso3_crosswalk = "DOM" if country_name == "DominicanRepublic"
replace wb_iso3_crosswalk = "SLV" if country_name == "ElSalvador"
replace wb_iso3_crosswalk = "ETH" if country_name == "Ethiopia"
replace wb_iso3_crosswalk = "GNB" if country_name == "GuineaBissau"
replace wb_iso3_crosswalk = "HKG" if country_name == "Hong Kong SAR China"
replace wb_iso3_crosswalk = "KOR" if country_name == "Korea Republic"
replace wb_iso3_crosswalk = "FSM" if country_name == "Micronesia"
replace wb_iso3_crosswalk = "RUS" if country_name == "Russia"
replace wb_iso3_crosswalk = "ZAF" if country_name == "SouthAfrica"
replace wb_iso3_crosswalk = "LKA" if country_name == "SriLanka"
replace wb_iso3_crosswalk = "KNA" if country_name == "StKittsandNevis"
replace wb_iso3_crosswalk = "LCA" if country_name == "StLucia"
replace wb_iso3_crosswalk = "VCT" if country_name == "StVincentandGrenadines"
replace wb_iso3_crosswalk = "TMP" if country_name == "Timor-Leste"
replace wb_iso3_crosswalk = "TUR" if country_name == "Turkiye"
replace wb_iso3_crosswalk = "VEN" if country_name == "Venezuela"
replace wb_iso3_crosswalk = "PSE" if country_name == "West Bank And Gaza"
replace wb_iso3_crosswalk = "YEM" if country_name == "Yemen"

tempfile wbes_countries
save "`wbes_countries'", replace

/*******************************************************************************
    2. Prepare downloaded World Bank/WITS country metadata
*******************************************************************************/
import excel using "`wb_xlsx'", sheet("Country-Metadata") firstrow allstring clear

rename CountryName wb_country_name
rename CountryISO3 wb_iso3
rename CountryCode wb_country_code
rename LongName wb_country_long_name
rename IncomeGroup wb_income_group
rename LendingCategory wb_lending_group
rename Region wb_region
rename CurrencyUnit wb_currency_unit

foreach var of varlist wb_country_name-wb_currency_unit {
    replace `var' = strtrim(`var')
}

drop if missing(wb_country_name) & missing(wb_iso3)
drop if length(wb_iso3) != 3

generate str80 country_match_key = lower(wb_country_name)
replace country_match_key = ustrregexra(country_match_key, "[^a-z0-9]", "")

replace country_match_key = "bahamas" if wb_iso3 == "BHS"
replace country_match_key = "congo" if wb_iso3 == "COG"
replace country_match_key = "drc" if wb_iso3 == "COD"
replace country_match_key = "egypt" if wb_iso3 == "EGY"
replace country_match_key = "gambia" if wb_iso3 == "GMB"
replace country_match_key = "korearepublic" if wb_iso3 == "KOR"
replace country_match_key = "micronesia" if wb_iso3 == "FSM"
replace country_match_key = "russia" if wb_iso3 == "RUS"
replace country_match_key = "stvincentandgrenadines" if wb_iso3 == "VCT"
replace country_match_key = "venezuela" if wb_iso3 == "VEN"
replace country_match_key = "yemen" if wb_iso3 == "YEM"

isid country_match_key
tempfile wb_metadata_by_name
save "`wb_metadata_by_name'", replace

preserve
    drop country_match_key
    isid wb_iso3
    tempfile wb_metadata_by_iso3
    save "`wb_metadata_by_iso3'", replace
restore

use "`wbes_countries'", clear
merge 1:1 country_match_key using "`wb_metadata_by_name'", ///
    keep(master match) generate(wb_metadata_merge)

preserve
    keep if wb_metadata_merge == 1 & !missing(wb_iso3_crosswalk)
    drop wb_metadata_merge wb_iso3 wb_country_code wb_country_name ///
        wb_country_long_name wb_income_group wb_lending_group wb_region ///
        wb_currency_unit
    rename wb_iso3_crosswalk wb_iso3
    merge m:1 wb_iso3 using "`wb_metadata_by_iso3'", keep(master match) ///
        generate(wb_iso3_merge)
    count if wb_iso3_merge != 3
    if r(N) > 0 {
        display as error "WBES ISO3 crosswalk entries not found in World Bank/WITS metadata:"
        list country_name wb_iso3 if wb_iso3_merge != 3, noobs abbreviate(40)
    }
    assert wb_iso3_merge == 3
    drop wb_iso3_merge country_match_key
    generate byte wb_metadata_merge = 3
    generate byte matched_by_crosswalk = 1
    tempfile iso3_matches
    save "`iso3_matches'", replace
restore

generate byte matched_by_crosswalk = 0
drop if wb_metadata_merge == 1 & !missing(wb_iso3_crosswalk)
append using "`iso3_matches'"

generate str120 wb_metadata_note = "Matched by normalized WBES and World Bank/WITS country name."
replace wb_metadata_note = "Matched by explicit WBES country-name to World Bank/WITS ISO3 crosswalk." ///
    if matched_by_crosswalk == 1
replace wb_metadata_note = "No match in downloaded World Bank/WITS metadata; WBES name retained." ///
    if wb_metadata_merge == 1

generate byte known_missing_wb_metadata = inlist(country_name, ///
    "Kosovo", "Serbia", "Taiwan China")

count if wb_metadata_merge == 1 & known_missing_wb_metadata == 0
if r(N) > 0 {
    display as error "Unmatched WBES country names after World Bank/WITS metadata merge:"
    list country_name if wb_metadata_merge == 1 & known_missing_wb_metadata == 0, ///
        noobs abbreviate(40)
}
assert wb_metadata_merge == 3 if known_missing_wb_metadata == 0
drop wb_metadata_merge country_match_key wb_iso3_crosswalk matched_by_crosswalk ///
    known_missing_wb_metadata

label variable country_name "WBES parsed country name"
label variable wb_iso3 "World Bank ISO3/economy code"
label variable wb_country_code "World Bank/WITS numeric country code"
label variable wb_country_name "World Bank/WITS country/economy name"
label variable wb_country_long_name "World Bank/WITS long country/economy name"
label variable wb_region "World Bank/WITS region"
label variable wb_income_group "World Bank income group"
label variable wb_lending_group "World Bank lending group"
label variable wb_currency_unit "World Bank/WITS currency unit"
label variable wb_metadata_note "Country metadata match note"

compress
save "${DATADIR}/Intermediate/wbes_wb_country_metadata.dta", replace

/*******************************************************************************
    3. Prepare downloaded UNSD ISIC Rev.4 division labels
*******************************************************************************/
import delimited using "`isic_csv'", clear varnames(1) stringcols(_all) bindquote(strict)

capture rename Code isic_code
if _rc {
    rename code isic_code
}
capture rename Description isic_label
if _rc {
    rename description isic_label
}

replace isic_code = strtrim(isic_code)
replace isic_label = strtrim(isic_label)
drop if missing(isic_code)

generate str1 isic4_section = isic_code if length(isic_code) == 1
generate str130 isic4_section_label = isic_label if length(isic_code) == 1
replace isic4_section = isic4_section[_n - 1] if missing(isic4_section)
replace isic4_section_label = isic4_section_label[_n - 1] if missing(isic4_section_label)

keep if length(isic_code) == 2
rename isic_code isic4_division_code
rename isic_label isic4_division_label

keep isic4_division_code isic4_section isic4_section_label isic4_division_label
isid isic4_division_code

label variable isic4_division_code "ISIC Rev.4 two-digit division code"
label variable isic4_section "ISIC Rev.4 section code"
label variable isic4_section_label "ISIC Rev.4 section label"
label variable isic4_division_label "ISIC Rev.4 division label"

compress
save "${DATADIR}/Intermediate/isic_rev4_division_labels.dta", replace

display as result "Prepared merge-ready World Bank and ISIC reference datasets."
