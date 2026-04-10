version 18.0
clear all
set more off

capture log close _all

args run_id

if "`run_id'" == "" {
    local run_id "default"
}

local log_path "logs/cmr_nacam_elasticity_batch_`run_id'.log"
local done_path "logs/cmr_nacam_elasticity_`run_id'.done"
local fail_path "logs/cmr_nacam_elasticity_`run_id'.failed"

capture erase "`done_path'"
capture erase "`fail_path'"

log using "`log_path'", replace text

display as text "Starting 01_cmr_nacam_elasticity.do at " c(current_time) " on " c(current_date)

capture noisily do "code/03_analysis/01_cmr_nacam_elasticity.do"
local run_rc = _rc

if `run_rc' {
    display as error "01_cmr_nacam_elasticity.do failed with return code `run_rc'."
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

display as result "01_cmr_nacam_elasticity.do completed successfully."

log close
exit 0
