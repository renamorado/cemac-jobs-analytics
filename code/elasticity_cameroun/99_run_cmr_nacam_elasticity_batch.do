version 17.0
clear all
set more off

capture log close _all

args run_id

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
    display as error "Add this user to the bootstrap block in code/elasticity_cameroun/99_run_cmr_nacam_elasticity_batch.do."
    exit 601
}

capture noisily cd "${project_root}"
if _rc | !fileexists("AGENTS.md") {
    display as error "Configured project_root is not a valid repo root: ${project_root}"
    exit 601
}

if "`run_id'" == "" {
    local run_id "default"
}

local log_path "logs/cmr_nacam_elasticity_batch_`run_id'.log"
local done_path "logs/cmr_nacam_elasticity_`run_id'.done"
local fail_path "logs/cmr_nacam_elasticity_`run_id'.failed"

capture erase "`done_path'"
capture erase "`fail_path'"

log using "`log_path'", replace text

display as text "Starting 06_cmr_nacam_elasticity.do at " c(current_time) " on " c(current_date)

capture noisily do "code/elasticity_cameroun/06_cmr_nacam_elasticity.do"
local run_rc = _rc

if `run_rc' {
    display as error "06_cmr_nacam_elasticity.do failed with return code `run_rc'."
    file open fail_marker using "`fail_path'", write text replace
    file write fail_marker "failed" _n
    file write fail_marker "rc=`run_rc'" _n
    file write fail_marker "run_id=`run_id'" _n
    file write fail_marker "date=`c(current_date)'" _n
    file write fail_marker "time=`c(current_time)'" _n
    file close fail_marker
    log close
    exit `run_rc'
}

file open done_marker using "`done_path'", write text replace
file write done_marker "ok" _n
file write done_marker "run_id=`run_id'" _n
file write done_marker "date=`c(current_date)'" _n
file write done_marker "time=`c(current_time)'" _n
file close done_marker

display as result "06_cmr_nacam_elasticity.do completed successfully."

log close
exit 0
