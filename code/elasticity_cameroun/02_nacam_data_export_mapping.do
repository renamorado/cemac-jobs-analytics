version 17.0
set more off

/*******************************************************************************
    Purpose:
        Assign each observed legacy NACAM branch to a data_export aggregate group
        for figure colors. The assignment is based on the NACAM branch label, not
        on the mechanical ISIC crosswalk, because several legacy branches span
        multiple ISIC divisions.

    Inputs:
        Globals created by code/01_setup.do
        Data/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta
        Data/Intermediate/data_export.xlsx

    Outputs:
        Data/Intermediate/cmr_nacam_data_export_mapping.dta
        Data/Intermediate/cmr_nacam_data_export_mapping.xlsx
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
        display as error "Add this user to the bootstrap block in code/elasticity_cameroun/02_nacam_data_export_mapping.do."
        exit 601
    }

    capture noisily cd "${project_root}"
    if _rc | !fileexists("AGENTS.md") {
        display as error "Configured project_root is not a valid repo root: ${project_root}"
        exit 601
    }

    do "code/01_setup.do"
}

local crosswalk_file "${DATADIR}/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta"
local group_file "${DATADIR}/Intermediate/data_export.xlsx"
local out_file "${DATADIR}/Intermediate/cmr_nacam_data_export_mapping.dta"
local audit_file "${DATADIR}/Intermediate/cmr_nacam_data_export_mapping.xlsx"

confirm file "`crosswalk_file'"
confirm file "`group_file'"

tempfile data_export_groups

import excel "`group_file'", sheet("Data") firstrow clear
keep Groups
drop if missing(Groups)
duplicates drop
rename Groups data_export
isid data_export
save "`data_export_groups'"

use "`crosswalk_file'", clear
keep nacam nacam_label
isid nacam

generate str70 data_export = ""
generate str240 data_export_reason = ""

replace data_export = "A – Agriculture, Forestry and Fishing" if ///
    inlist(nacam, 1, 2, 3, 5)
replace data_export_reason = "NACAM label is agriculture, livestock/hunting, fishing, or aquaculture." if ///
    inlist(nacam, 1, 2, 3, 5)

replace data_export = "B – Mining and Quarrying" if inlist(nacam, 6, 7)
replace data_export_reason = "NACAM label is hydrocarbon extraction or other extractive activities." if ///
    inlist(nacam, 6, 7)

replace data_export = "C – Manufacturing" if ///
    inlist(nacam, 8, 9, 10, 11, 12, 13, 15, 16, 17) | ///
    inlist(nacam, 18, 19, 20, 21, 22, 23, 24, 27) | ///
    nacam == 28
replace data_export_reason = "NACAM label is a manufacturing branch." if ///
    inlist(nacam, 8, 9, 10, 11, 12, 13, 15, 16, 17) | ///
    inlist(nacam, 18, 19, 20, 21, 23, 24, 27)
replace data_export_reason = "Assigned to manufacturing because the label is rubber and plastic products, despite a small agricultural reference in the ISIC detail." if ///
    nacam == 22
replace data_export_reason = "Assigned to manufacturing because the label centers on furniture and other manufacturing; the recovery/waste wording is secondary." if ///
    nacam == 28

replace data_export = "Utilities" if nacam == 29
replace data_export_reason = "NACAM label is electricity and water supply in the legacy nomenclature." if ///
    nacam == 29

replace data_export = "F – Construction" if nacam == 30
replace data_export_reason = "NACAM label is construction." if nacam == 30

replace data_export = "G – Wholesale and Retail Trade; Repair of Motor Vehicles" if ///
    inlist(nacam, 31, 32)
replace data_export_reason = "NACAM label is commerce." if nacam == 31
replace data_export_reason = "Assigned to trade/repair because the label is repairs and the data_export group explicitly includes repair of motor vehicles." if ///
    nacam == 32

replace data_export = "H – Transportation and Storage" if nacam == 34
replace data_export_reason = "NACAM label is transport and warehousing." if nacam == 34

replace data_export = "J – Information and Communication" if nacam == 35
replace data_export_reason = "Assigned to information and communication because the mixed postal/telecom label includes telecommunications." if ///
    nacam == 35

replace data_export = "K – Financial and Insurance Activities" if nacam == 36
replace data_export_reason = "NACAM label is financial and insurance activities." if nacam == 36

replace data_export = "Other services" if ///
    inlist(nacam, 33, 37, 38, 40, 41, 42)
replace data_export_reason = "NACAM label is a service branch outside the named trade, transport, ICT, and finance groups." if ///
    inlist(nacam, 33, 37, 38, 40, 41, 42)

assert !missing(data_export)
assert !missing(data_export_reason)

merge m:1 data_export using "`data_export_groups'", keep(master match)
assert _merge == 3
drop _merge

order nacam nacam_label data_export data_export_reason
sort nacam

label variable nacam "Legacy NACAM branch code observed in CMR_BDF.dta"
label variable nacam_label "Legacy NACAM branch label"
label variable data_export "Aggregate sector group used for elasticity figure colors"
label variable data_export_reason "Reason for label-based data_export assignment"

save "`out_file'", replace
export excel using "`audit_file'", firstrow(variables) replace

display as result "Saved NACAM data_export mapping to `out_file'"
display as result "Saved NACAM data_export audit workbook to `audit_file'"
