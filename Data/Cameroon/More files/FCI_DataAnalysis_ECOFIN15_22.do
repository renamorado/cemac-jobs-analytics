version 18.0
set more off

************************************************
************************************************
*     Analysis using Cameroon Ecofin dataset      *
************************************************
************************************************

/*
   Purpose: This program uses firm-level survey to compute key performance measures on firms
   Prepared by: Johanne Buba
   Obs: 8680
   Input: ECOFIN 2015 - 2022
   Output: Mutiple graphs & tests & regressions  
   Number of firms : 1561	
*/

local project_root = subinstr(c(pwd), "\", "/", .)

if !fileexists("`project_root'/AGENTS.md") {
    if fileexists("`project_root'/../../AGENTS.md") {
        local project_root "`project_root'/../.."
    }
}

capture noisily cd "`project_root'"
if _rc | !fileexists("AGENTS.md") {
    display as error "Run this legacy file from the repo root or from Data/Cameroon/More files."
    exit 601
}

do "01_setup.do"

global ecofin "${PROJECT_ROOT}/Data/Cameroon/More files"
global output "${OUTPUTDIR}/legacy_ecofin"
global tfp_employment_file "${DATADIR}/Analysis/tfp_employment.dta"

capture mkdir "${output}"

use "${ecofin}/ecofin15_22_clean_panel.dta", replace

**------------------------- Settings for graphs -----------------------------** 
grstyle clear
grstyle init myscheme, replace
grstyle color background white
grstyle anglestyle vertical_tick horizontal
grstyle color major_grid dimgray
grstyle linewidth major_grid thinrec
grstyle yesno draw_major_hgrid yes
grstyle yesno grid_draw_min yes
grstyle yesno grid_draw_max yes
grstyle clockdir legend_position 4
grstyle numstyle legend_cols 1
colorpalette BrBG, select(10 3 2 11 9 8 4 1 5)
local mycolors `" `r(p)'"'
grstyle set color `mycolors'
grstyle linestyle legend dot


**------------------------- TFP -----------------------------**

*** Using normal cobb-douglas function
reg ldva ldcap lemp if win_dum_va!=1 & win_dum_cap!=1 & win_dum_emp!=1
predict ltfp_ols, resid
gen tfp_ols=exp(ltfp_ols)

/**** Using Levinsohn-Petrin
levpet ldva if win_dum_va!=1 & win_dum_cap!=1 & win_dum_emp!=1 & win_dum_cmat!=1, free(lemp) proxy(ldcmat) capital(ldcap) va reps(20) level(99)
predict tfp_lp, omega
replace tfp_lp=tfp_lp/1000000
*/

**------------------------- Descriptives -----------------------------**

*** TFP ***
*** With weights being the share of revenues

preserve
collapse (mean) tfp_ols [aw = drevenues] if tfp_ols!=., by(year)
sort year
tsset year
line tfp year, lwidth(.6)  ///
graphregion(color(white)) ///
ylabel(, gmax gmin format(%6.1fc)) xlabel() ///
ytitle("") xtitle("") title("TFP", color(black)) name(graph`i', replace) ysize(15) xsize(25)
graph export "tfp_ols_evolution", as (jpg) replace
restore

preserve
collapse (mean) tfp_lp [aw = drevenues] if tfp_lp!=., by(year)
sort year
tsset year
line tfp year, lwidth(.6) ///
graphregion(color(white)) ///
ylabel(, gmax gmin format(%6.1fc)) xlabel() ///
ytitle("") xtitle("") title("TFP", color(black)) name(graph`i', replace) ysize(15) xsize(25)
graph export "tfp_lp_evolution", as (jpg) replace
restore

preserve 
collapse (mean) tfp_lp [aw = drevenues] if tfp_lp!=., by(sector_12 year)
twoway (line tfp_lp year if sector_12==1) (line tfp_lp year if sector_12==2) (line tfp_lp year if sector_12==3) (line tfp_lp year if sector_12==4) (line tfp_lp year if sector_12==5) (line tfp_lp year if sector_12==6) (line tfp_lp year if sector_12==7) (line tfp_lp year if sector_12==8, lpattern(dash)) (line tfp_lp year if sector_12==9, lpattern(dash)) (line tfp_lp year if sector_12==10, lpattern(dash)) (line tfp_lp year if sector_12==11, lpattern(dash)) (line tfp_lp year if sector_12==12, lpattern(dash)), legend(label(1 "Agriculture Fisheries Wood") label(2 "Extractive industries") label(3 "Agribusiness") label(4 "Textile Leather") label(5 "Wood Paper Furniture") label (6 "Other manufacturing") label(7 "Utilities") label(8 "Construction") label(9 "Wholesale and Retail") label(10 "Accomodation and restaurants") label(11 "Transport") label(12 "Other services") pos(6) col(3) size(vsmall)) ytitle("") xtitle("")
graph export "tfp_lp_evolution_bysector", as (jpg) replace
restore

*** Employment
preserve
collapse (sum) emp if win_dum_emp!=1, by(year)
sort year
tsset year
line emp year, lwidth(.6)  ///
graphregion(color(white)) ///
ylabel(, gmax gmin format(%6.0fc)) xlabel() ///
ytitle("") xtitle("") title("Employment", color(black)) name(graph`i', replace) ysize(15) xsize(25)
graph export "emp_evolution", as (jpg) replace
restore

preserve 
collapse (sum) emp if win_dum_emp!=1, by(year sector_12)
twoway (line emp year if sector_12==1) (line emp year if sector_12==2) (line emp year if sector_12==3) (line emp year if sector_12==4) (line emp year if sector_12==5) (line emp year if sector_12==6) (line emp year if sector_12==7) (line emp year if sector_12==8, lpattern(dash)) (line emp year if sector_12==9, lpattern(dash)) (line emp year if sector_12==10, lpattern(dash)) (line emp year if sector_12==11, lpattern(dash)) (line emp year if sector_12==12, lpattern(dash)), legend(label(1 "Agriculture Fisheries Wood") label(2 "Extractive industries") label(3 "Agribusiness") label(4 "Textile Leather") label(5 "Wood Paper Furniture") label (6 "Other manufacturing") label(7 "Utilities") label(8 "Construction") label(9 "Wholesale and Retail") label(10 "Accomodation and restaurants") label(11 "Transport") label(12 "Other services") pos(6) col(3) size(vsmall)) ytitle("") xtitle("")
graph export "emp_evolution_bysector", as (jpg) replace
restore

********************************************************************************
* ECOFIN
********************************************************************************
use "$ecofin\ecofin15_22_clean_panel.dta", replace

**------------------------- Descriptive trends -----------------------------** 

/*
foreach var in cap inv revenues {
	replace `var' = `var'/1000000
}
*/



*** Employment
preserve
collapse (sum) emp if win_dum_emp!=1, by(year)
sort year
tsset year
twoway bar emp year, lwidth(.6)  ///
graphregion(color(white)) ///
ylabel(150000(1000)160000) xlabel(2015(1)2022) ///
ytitle("") xtitle("") title("Employment", color(black)) name(graph`i', replace) ysize(15) xsize(25)
graph export "$output\emp_evolution.jpg", as (jpg) replace
restore

preserve 
collapse (sum) emp if win_dum_emp!=1, by(year sector_12)
twoway (line emp year if sector_12==1) (line emp year if sector_12==2) (line emp year if sector_12==3) (line emp year if sector_12==4) (line emp year if sector_12==5) (line emp year if sector_12==6) (line emp year if sector_12==7) (line emp year if sector_12==8, lpattern(dash)) (line emp year if sector_12==9, lpattern(dash)) (line emp year if sector_12==10, lpattern(dash)) (line emp year if sector_12==11, lpattern(dash)) (line emp year if sector_12==12, lpattern(dash)), legend(label(1 "Agriculture Fisheries Wood") label(2 "Extractive industries") label(3 "Agribusiness") label(4 "Textile Leather") label(5 "Wood Paper Furniture") label (6 "Other manufacturing") label(7 "Utilities") label(8 "Construction") label(9 "Wholesale and Retail") label(10 "Accomodation and restaurants") label(11 "Transport") label(12 "Other services") pos(6) col(3) size(vsmall)) ytitle("") xtitle("") xlabel(2015(1)2022)
graph export "$output\emp_evolution_bysector.jpg", as (jpg) replace
restore


*** Revenues
preserve
collapse (sum) drevenues if win_dum_revenues!=1, by(year)
replace drevenues = drevenues/1000000
sort year
tsset year
twoway bar drevenues year, lwidth(.6)  ///
graphregion(color(white)) ///
ylabel(, gmax gmin format(%12.0fc)) xlabel(2015(1)2022) ///
ytitle("") xtitle("") title("Revenues (real in millions CFA)", color(black)) name(graph`i', replace) ysize(15) xsize(25)
graph export "$output\revenue_evolution.jpg", as (jpg) replace
restore

preserve 
collapse (sum) drevenues if win_dum_revenues!=1, by(year sector_12)
replace drevenues = drevenues/1000000
twoway (line drevenues year if sector_12==1) (line drevenues year if sector_12==2) (line drevenues year if sector_12==3) (line drevenues year if sector_12==4) (line drevenues year if sector_12==5) (line drevenues year if sector_12==6) (line drevenues year if sector_12==7) (line drevenues year if sector_12==8, lpattern(dash)) (line drevenues year if sector_12==9, lpattern(dash)) (line drevenues year if sector_12==10, lpattern(dash)) (line drevenues year if sector_12==11, lpattern(dash)) (line drevenues year if sector_12==12, lpattern(dash)), legend(label(1 "Agriculture Fisheries Wood") label(2 "Extractive industries") label(3 "Agribusiness") label(4 "Textile Leather") label(5 "Wood Paper Furniture") label (6 "Other manufacturing") label(7 "Utilities") label(8 "Construction") label(9 "Wholesale and Retail") label(10 "Accomodation and restaurants") label(11 "Transport") label(12 "Other services") pos(6) col(3) size(vsmall)) ytitle("") xtitle("") xlabel(2015(1)2022) title("Revenues (real in millions CFA)")
graph export "$output\revenues_evolution_bysector.jpg", as (jpg) replace
restore


*Wage bill
preserve
collapse (sum) dwagebill if win_dum_wagebill!=1, by(year)
replace dwagebill = dwagebill/1000000
sort year
tsset year
twoway bar dwagebill year, lwidth(.6)  ///
graphregion(color(white)) ///
ylabel(, gmax gmin format(%12.0fc)) xlabel(2015(1)2022) ///
ytitle("") xtitle("") title("Wage bill (real in millions CFA)", color(black)) name(graph`i', replace) ysize(15) xsize(25)
graph export "$output\wagebill_evolution.jpg", as (jpg) replace
restore

preserve 
collapse (sum) dwagebill if win_dum_wagebill!=1, by(year sector_12)
replace dwagebill = dwagebill/1000000
twoway (line dwagebill year if sector_12==1) (line dwagebill year if sector_12==2) (line dwagebill year if sector_12==3) (line dwagebill year if sector_12==4) (line dwagebill year if sector_12==5) (line dwagebill year if sector_12==6) (line dwagebill year if sector_12==7) (line dwagebill year if sector_12==8, lpattern(dash)) (line dwagebill year if sector_12==9, lpattern(dash)) (line dwagebill year if sector_12==10, lpattern(dash)) (line dwagebill year if sector_12==11, lpattern(dash)) (line dwagebill year if sector_12==12, lpattern(dash)), legend(label(1 "Agriculture Fisheries Wood") label(2 "Extractive industries") label(3 "Agribusiness") label(4 "Textile Leather") label(5 "Wood Paper Furniture") label (6 "Other manufacturing") label(7 "Utilities") label(8 "Construction") label(9 "Wholesale and Retail") label(10 "Accomodation and restaurants") label(11 "Transport") label(12 "Other services") pos(6) col(3) size(vsmall)) ytitle("") xtitle("") xlabel(2015(1)2022) title("Wage bill (in millions CFA)")
graph export "$output\wagebill_evolution_bysector.jpg", as (jpg) replace
restore


**Capital and investment
preserve
collapse (sum) dcap dinv if win_dum_cap!=1 | win_dum_inv!=1, by(year)
replace dcap = dcap/1000000000
replace dinv = dinv/1000000000
la var dcap "Capital (in billions CFA)"
la var dinv "Investment (in billions CFA)"
sort year
tsset year
line dcap dinv year, lwidth(.6)  ///
graphregion(color(white)) ///
ylabel(, gmax gmin format(%6.1fc)) xlabel(2015(1)2022) ///
ytitle("") xtitle("") title("Investment and capital", color(black)) name(graph`i', replace) ysize(15) xsize(25)
graph export "$output\capinv_evolution.jpg", as (jpg) replace
restore

/*
preserve 
collapse (sum) dcap dinv if win_dum_cap!=1 | win_dum_inv!=1, by(year sector_12)
replace dcap = dcap/1000000
replace dinv = dinv/1000000
la var dcap "Capital (in millions CFA)"
la var dinv "Investment (in millions CFA)"

twoway (line dcap dinv year if sector_12==1) (line dcap dinv year if sector_12==2) (line dcap dinv year if sector_12==3) (line dcap dinv year if sector_12==4) (line dcap dinv year if sector_12==5) (line dcap dinv year if sector_12==6) (line dcap dinv year if sector_12==7) (line dcap dinv year if sector_12==8, lpattern(dash)) (line dcap dinv year if sector_12==9, lpattern(dash)) (line dcap dinv year if sector_12==10, lpattern(dash)) (line dcap dinv year if sector_12==11, lpattern(dash)) (line dcap dinv year if sector_12==12, lpattern(dash)), legend(label(1 "Agriculture Fisheries Wood") label(2 "Extractive industries") label(3 "Agribusiness") label(4 "Textile Leather") label(5 "Wood Paper Furniture") label (6 "Other manufacturing") label(7 "Utilities") label(8 "Construction") label(9 "Wholesale and Retail") label(10 "Accomodation and restaurants") label(11 "Transport") label(12 "Other services") pos(6) col(3) size(vsmall)) ytitle("") xtitle("") xlabel(2015(1)2022)
graph export "$output\capinv_evolution_bysector.jpg", as (jpg) replace
restore
*/

**------------------------- TFP -----------------------------**
use "$ecofin\ecofin15_22_clean_panel.dta", replace
xtset id year
duplicates report id year

*** Using normal cobb-douglas function
reg ldva ldcap lemp if win_dum_va!=1 & win_dum_cap!=1 & win_dum_emp!=1
predict ltfp_ols, resid
gen tfp_ols=exp(ltfp_ols)

**** Using Levinsohn-Petrin
levpet ldva if win_dum_va!=1 & win_dum_cap!=1 & win_dum_emp!=1 & win_dum_cmat!=1, free(lemp) proxy(ldcmat) capital(ldcap) va reps(20) level(99)
predict tfp_lp, omega
replace tfp_lp=tfp_lp/1000000
replace tfp_lp=. if tfp_lp >1 & sector_12 ==4 // outlier in the textile sector 

*Calculate labor productivity
gen vapw = dva/emp
replace vapw=vapw/100000000
la var vapw "Labor productivity (in millions)"

*** With weights being the share of revenues

***TFP growth, 2015-2022
preserve
collapse(mean) tfp_lp tfp_ols vapw dva [aw=drevenues] if tfp_lp !=., by(year)
tsset year
sort year
gen g_tfp = D.tfp_lp / L.tfp_lp
gen g_vapw = D.vapw / L.vapw

sum g_tfp
egen ag_tfp=mean(g_tfp)
gen ag_tfp2 = (tfp_lp[_N]/tfp_lp[1])^(1/(year[_N]-year[1])) - 1

drop if year==2015
twoway bar g_tfp year, lwidth(.6)  ///
graphregion(color(white)) ///
ylabel(, gmax gmin format(%6.2fc)) xlabel(2016(1)2022) ///
ytitle("") xtitle("") title("TFP annual growth", color(black)) name(graph`i', replace) ysize(5) xsize(10) barwidth(0.5)
graph export "$output\tfp_growth_evolution.jpg", as (jpg) replace

twoway bar g_vapw year, lwidth(.6)  ///
graphregion(color(white)) ///
ylabel(, gmax gmin format(%6.2fc)) xlabel(2016(1)2022) ///
ytitle("") xtitle("") title("Labor productivity annual growth", color(black)) name(graph`i', replace) ysize(5) xsize(10) barwidth(0.5)
graph export "$output\vapw_growth_evolution.jpg", as (jpg) replace


restore

***TFP growth by industry, 2015-2022
preserve

use "$ecofin\ecofin15_22_clean_panel_final.dta", replace
xtset id year
duplicates report id year
keep if win_dum_va!=1 & win_dum_cap!=1 & win_dum_emp!=1

*** Using normal cobb-douglas function
reg ldva ldcap lemp if win_dum_va!=1 & win_dum_cap!=1 & win_dum_emp!=1
predict ltfp_ols, resid
gen tfp_ols=exp(ltfp_ols)

****** TFP Growth and employment growth // Labor productivity growth and employment growth

use "${tfp_employment_file}", clear

scatter emp tfp, mlabel(sector)
set scheme s1mono
scatter emp tfp, mlabel(sector)
set scheme s2mono
scatter emp tfp, mlabel(sector)
save "${tfp_employment_file}"
la var tfp "Total factor productivity growth"
la var lp "Labor productivity growth"
la var tfp "Total factor productivity compound annual growth (2015-2022)"
la var lp "Labor productivity compound annual growth (2015-2022)"
la var emp "Employment compound annual growth (2015-2022)"
save "${tfp_employment_file}", replace
sum tfp emp
scatter emp tfp, mlabel(sector) xlabel(-20(10)20)
set scheme s2color
scatter emp tfp, mlabel(sector) xlabel(-20(10)20)
set scheme s2mono
scatter emp tfp, mlabel(sector) xlabel(-20(10)20)
set scheme s1mono
scatter emp tfp, mlabel(sector) xlabel(-20(10)20)
scatter emp lp, mlabel(sector) xlabel(-20(10)20)
scatter emp lp, mlabel(sector)
scatter emp lp, mlabel(sector) xlabel(-30(10)10)
scatter emp tfp, mlabel(sector) xlabel(-20(10)20)
scatter emp lp, mlabel(sector) xlabel(-20(10)20)
scatter emp lp, mlabel(sector) xlabel(-20(10)20) xline(0)
scatter emp tfp, mlabel(sector) xlabel(-20(10)20) xline(0)
scatter emp tfp, mlabel(sector) xlabel(-20(10)30) xline(0)

**** Using Levinsohn-Petrin
levpet ldva if win_dum_va!=1 & win_dum_cap!=1 & win_dum_emp!=1 & win_dum_cmat!=1, free(lemp) proxy(ldcmat) capital(ldcap) va reps(20) level(99)
predict tfp_lp, omega
replace tfp_lp=tfp_lp/1000000
replace tfp_lp=. if tfp_lp >1 & sector_12 ==4 // outlier in the textile sector 

*Calculate labor productivity
gen vapw = dva/emp
replace vapw=vapw/100000000
la var vapw "Labor productivity (in millions)"
la var dva "Value added (in millions)"
replace dva=dva/100000000

collapse(mean) tfp_lp tfp_ols dva vapw [aw=drevenues] if tfp_lp !=., by(year sector_12)
xtset sector year
sort sector year
foreach var in tfp_lp tfp_ols dva vapw {
bysort sector : gen g`var' = D.`var' / L.`var'*100
bysort sector : egen ag`var'=mean(g`var')
bysort sector : gen ag2`var' = [(`var'[_N]/`var'[1])^(1/(year[_N]-year[1])) - 1]*100
format g`var' %6.0fc
format ag`var' %6.0fc
format ag2`var' %6.0fc
}

la var agtfp_lp "Average annual TFP growth by industry"
la var ag2tfp_lp "Compound annual TFP growth by industry"
la var year "Year"
la var tfp_lp "TFP"

*TFP graph -lp
graph hbar agtfp_lp, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Average annual TFP (LP) growth by industry", size(small)) ylabel(, nogrid) ytitle("")
graph export "$output\annualtfpgrowth_bysector.jpg", as (jpg) replace
 
graph hbar ag2tfp_lp, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Growth TFP (LP) by industry", size(small)) ylabel(-25(5)25, nogrid) ytitle("")
graph export "$output\compoundtfpgrowth_bysector.jpg", as (jpg) replace 

*TFP graph - ols
graph hbar agtfp_ols, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Average annual TFP (OLS) growth by industry", size(small)) ylabel(, nogrid) ytitle("")
graph export "$output\annualtfpolsgrowth_bysector.jpg", as (jpg) replace
 
graph hbar ag2tfp_ols, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Growth of TFP (OLS) by industry", size(small)) ylabel(-25(5)25, nogrid) ytitle("")
graph export "$output\compoundtfpolsgrowth_bysector.jpg", as (jpg) replace 

*Labor productivity graph
graph hbar agvapw, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Average annual labor productivity growth by industry", size(small)) ylabel(-40(20)100, nogrid) ytitle("")
graph export "$output\annualvapwgrowth_bysector.jpg", as (jpg) replace

graph hbar ag2vapw, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Compound annual labor productivity growth by industry", size(small)) ylabel(-50(10)10, nogrid) ytitle("")
graph export "$output\compoundvapwgrowth_bysector.jpg", as (jpg) replace


*value added
graph hbar agdva, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Average annual value added growth by industry", size(small)) ylabel(-40(20)100, nogrid) ytitle("")
graph export "$output\annualvagrowth_bysector.jpg", as (jpg) replace

graph hbar ag2dva, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Compound annual value added growth by industry", size(small)) ylabel(-50(10)10, nogrid) ytitle("")
graph export "$output\compoundvagrowth_bysector.jpg", as (jpg) replace

*what's going on with textile industry

levelsof sector_12, local(sector_values)
foreach i of local sector_values { 
    local sector_label : label (sector_12) `i'
    twoway(line tfp_lp year) (lfit tfp_lp year, lpattern(dash)) if sector_12==`i', xlabel(2015(1)2022) title("TFP (LP) of the `sector_label' industry")
graph export "$output\tfp_sector`i'.jpg", as (jpg) replace

}

levelsof sector_12, local(sector_values)
foreach i of local sector_values { 
    local sector_label : label (sector_12) `i'
    twoway(line tfp_ols year) (lfit tfp_ols year, lpattern(dash)) if sector_12==`i', xlabel(2015(1)2022) title("TFP (OLS) of the `sector_label' industry")
graph export "$output\tfpols_sector`i'.jpg", as (jpg) replace

}

levelsof sector_12, local(sector_values)
foreach i of local sector_values { 
    local sector_label : label (sector_12) `i'
    twoway(line dva year) (lfit dva year, lpattern(dash)) if sector_12==`i', xlabel(2015(1)2022) title("Value added of the `sector_label' industry")
graph export "$output\va_sector`i'.jpg", as (jpg) replace

}

restore

************* Drop oil refinery 
preserve

use "$ecofin\ecofin15_22_clean_panel.dta", replace
xtset id year
duplicates report id year
keep if win_dum_va!=1 & win_dum_cap!=1 & win_dum_emp!=1

drop if sector==19 // drop oil refinery

*** Using normal cobb-douglas function
reg ldva ldcap lemp if win_dum_va!=1 & win_dum_cap!=1 & win_dum_emp!=1
predict ltfp_ols, resid
gen tfp_ols=exp(ltfp_ols)

**** Using Levinsohn-Petrin
levpet ldva if win_dum_va!=1 & win_dum_cap!=1 & win_dum_emp!=1 & win_dum_cmat!=1, free(lemp) proxy(ldcmat) capital(ldcap) va reps(20) level(99)
predict tfp_lp, omega
replace tfp_lp=tfp_lp/1000000
replace tfp_lp=. if tfp_lp >1 & sector_12 ==4 // outlier in the textile sector 

*Calculate labor productivity
gen vapw = dva/emp
replace vapw=vapw/100000000
la var vapw "Labor productivity (in millions)"
la var dva "Value added (in millions)"
replace dva=dva/100000000

collapse(mean) tfp_lp tfp_ols dva vapw [aw=drevenues] if tfp_lp !=., by(year sector_12)
xtset sector year
sort sector year
foreach var in tfp_lp tfp_ols dva vapw {
bysort sector : gen g`var' = D.`var' / L.`var'*100
bysort sector : egen ag`var'=mean(g`var')
bysort sector : gen ag2`var' = [(`var'[_N]/`var'[1])^(1/(year[_N]-year[1])) - 1]*100
format g`var' %6.0fc
format ag`var' %6.0fc
format ag2`var' %6.0fc
}

la var agtfp_lp "Average annual TFP growth by industry"
la var ag2tfp_lp "Compound annual TFP growth by industry"
la var year "Year"
la var tfp_lp "TFP"

*TFP graph -lp
graph hbar agtfp_lp, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Average annual TFP (LP) growth by industry", size(small)) ylabel(, nogrid) ytitle("")
graph export "$output\annualtfpgrowth_bysectornoil.jpg", as (jpg) replace
 
graph hbar ag2tfp_lp, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Growth TFP (LP) by industry", size(small)) ylabel(-25(5)25, nogrid) ytitle("")
graph export "$output\compoundtfpgrowth_bysectornoil.jpg", as (jpg) replace 

*TFP graph - ols
graph hbar agtfp_ols, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Average annual TFP (OLS) growth by industry", size(small)) ylabel(, nogrid) ytitle("")
graph export "$output\annualtfpolsgrowth_bysectornoil.jpg", as (jpg) replace
 
graph hbar ag2tfp_ols, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Growth of TFP (OLS) by industry", size(small)) ylabel(-25(5)25, nogrid) ytitle("")
graph export "$output\compoundtfpolsgrowth_bysectornoil.jpg", as (jpg) replace 

*Labor productivity graph
graph hbar agvapw, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Average annual labor productivity growth by industry", size(small)) ylabel(-40(20)100, nogrid) ytitle("")
graph export "$output\annualvapwgrowth_bysectornoil.jpg", as (jpg) replace

graph hbar ag2vapw, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Compound annual labor productivity growth by industry", size(small)) ylabel(-50(10)10, nogrid) ytitle("")
graph export "$output\compoundvapwgrowth_bysectornoil.jpg", as (jpg) replace


*value added
graph hbar agdva, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Average annual value added growth by industry", size(small)) ylabel(-40(20)100, nogrid) ytitle("")
graph export "$output\annualvagrowth_bysectornoil.jpg", as (jpg) replace

graph hbar ag2dva, over(sector_12) sort(sector_12) blabel(bar, format(%6.2fc)) title("Compound annual value added growth by industry", size(small)) ylabel(-50(10)10, nogrid) ytitle("")
graph export "$output\compoundvagrowth_bysectornoil.jpg", as (jpg) replace

restore


**check tfp of wood, etc. 
***TFP growth by industry, 2015-2022
preserve

use "$ecofin\ecofin15_22_clean_panel_final.dta", replace
xtset id year
duplicates report id year
keep if win_dum_va!=1 & win_dum_cap!=1 & win_dum_emp!=1

*** Using normal cobb-douglas function
reg ldva ldcap lemp if win_dum_va!=1 & win_dum_cap!=1 & win_dum_emp!=1
predict ltfp_ols, resid
gen tfp_ols=exp(ltfp_ols)

**** Using Levinsohn-Petrin
levpet ldva if win_dum_va!=1 & win_dum_cap!=1 & win_dum_wagebill!=1 & win_dum_cmat!=1, free(ldwagebill) proxy(ldcmat) capital(ldcap) i(id) t(year) va reps(20) level(99)
predict tfp_wage_lp, omega
replace tfp_wage_lp=log(tfp_wage_lp)
replace tfp_wage_lp=. if tfp_wage_lp >1 & sector_12 ==4 

**** Using Levinsohn-Petrin by prodest 
gen betawage = .                            
gen betacap = .
gen epsilon = .

prodest ldva if win_dum_va!=1 & win_dum_cap!=1 & win_dum_wagebill!=1 & win_dum_cmat!=1, free(ldwagebill) proxy(ldcmat) state(ldcap) method(lp) id(id) t(year) reps(20) va fsresiduals(fsres)
replace betawage = _b[ldwagebill] 
replace betacap = _b[ldcap] 
replace epsilon =  fsres 
replace epsilon = 0 if epsilon ==.
drop fsres

gen tfp_lp = ldva - epsilon - betawage*ldwagebill - betacap*ldcap 

*Calculate labor productivity
gen vapw = log(dva/emp)
*replace vapw=vapw/100000000
la var vapw "Labor productivity"
*replace dva=dva/100000000

collapse(mean) tfp_lp tfp_ols dva vapw [iw=drevenues], by(year sector_12)
xtset sector year
sort sector year
foreach var in tfp_lp tfp_ols dva vapw {
bysort sector : gen g`var' = D.`var' / L.`var'*100
bysort sector : egen ag`var'=mean(g`var')
*bysort sector : gen ag2`var' = [((exp(`var'[_N])/exp(`var'[1]))^(1/(year[_N]-year[1]))) - 1]*100
bysort sector: gen ag2`var' =(((exp(`var'[1])/exp(`var'[_N]))^(1/7))-1)*100
format g`var' %6.0fc
format ag`var' %6.0fc
format ag2`var' %6.0fc
}

la var agtfp_lp "Average annual TFP growth by industry"
la var ag2tfp_lp "Compound annual TFP growth by industry"
la var year "Year"
la var tfp_lp "TFP"

*TFP graph -lp
graph hbar agtfp_lp, over(sector, lab(labsize(vsmall))) sort(sector) blabel(bar, format(%6.2fc) size(vsmall)) title("Average annual TFP (LP) growth by industry", size(small)) ylabel(, nogrid labsize(vsmall)) ytitle("")
graph export "$output\antfpgrowth_bysectorlong.jpg", as (jpg) replace
 
graph hbar ag2tfp_lp, over(sector, lab(labsize(vsmall))) sort(sector) blabel(bar, format(%6.2fc) size(vsmall)) title("Compound annual TFP (LP) growth by industry", size(small)) ylabel(-25(5)25, nogrid labsize(vsmall)) ytitle("")
graph export "$output\tfpgrowth_bysectorlong_newdata.jpg", as (jpg) replace 

*TFP graph - ols
graph hbar agtfp_ols, over(sector, lab(labsize(vsmall))) sort(sector) blabel(bar, format(%6.2fc) size(vsmall)) title("Average annual TFP (OLS) growth by industry", size(small)) ylabel(, nogrid labsize(vsmall))  ytitle("")
graph export "$output\anltfpolsgrowth_bysectorlong.jpg", as (jpg) replace
 
graph hbar ag2tfp_ols, over(sector, lab(labsize(vsmall))) sort(sector) blabel(bar, format(%6.2fc) size(vsmall)) title("Compound annual TFP (OLS) growth by industry", size(small)) ylabel(-25(5)25, nogrid labsize(vsmall)) ytitle("")
graph export "$output\tfpolsgrowth_bysectorlong.jpg", as (jpg) replace 

*Labor productivity graph
graph hbar agvapw, over(sector, lab(labsize(vsmall))) sort(sector) blabel(bar, format(%6.2fc) size(vsmall)) title("Average annual labor productivity growth by industry", size(small)) ylabel(-40(20)100, nogrid labsize(vsmall)) ytitle("")
graph export "$output\anvapwgrowth_bysectorlong.jpg", as (jpg) replace

graph hbar ag2vapw, over(sector, lab(labsize(vsmall))) sort(sector) blabel(bar, format(%6.2fc) size(vsmall)) title("Compound annual labor productivity growth by industry", size(small)) ylabel(-50(10)10, nogrid labsize(vsmall)) ytitle("")
graph export "$output\vapwgrowth_bysectorlong.jpg", as (jpg) replace

*value added
graph hbar agdva, over(sector, lab(labsize(vsmall))) sort(sector) blabel(bar, format(%6.2fc) size(vsmall)) title("Average annual value added growth by industry", size(small)) ylabel(-40(20)100, nogrid labsize(vsmall)) ytitle("")
graph export "$output\anvagrowth_bysectorlong.jpg", as (jpg) replace

graph hbar ag2dva, over(sector, lab(labsize(vsmall))) sort(sector) blabel(bar, format(%6.2fc) size(vsmall)) title("Compound annual value added growth by industry", size(small)) ylabel(-50(10)10, nogrid labsize(vsmall)) ytitle("")
graph export "$output\vagrowth_bysectorlong.jpg", as (jpg) replace

*by industry

levelsof sector, local(sector_values)
foreach i of local sector_values { 
    local sector_label : label (sector) `i'
    twoway(line tfp_lp year) (lfit tfp_lp year, lpattern(dash)) if sector==`i', xlabel(2015(1)2022) title("TFP of the `sector_label' industry")
graph export "$output\tfp_sector`i'long.jpg", as (jpg) replace

}

levelsof sector, local(sector_values)
foreach i of local sector_values { 
    local sector_label : label (sector) `i'
    twoway(line tfp_ols year) (lfit tfp_ols year, lpattern(dash)) if sector==`i', xlabel(2015(1)2022) title("TFP of the `sector_label' industry")
graph export "$output\tfpols_sector`i'long.jpg", as (jpg) replace

}


levelsof sector, local(sector_values)
foreach i of local sector_values { 
    local sector_label : label (sector) `i'
    twoway(line dva year) (lfit dva year, lpattern(dash)) if sector==`i', xlabel(2015(1)2022) title("TFP of the `sector_label' industry")
graph export "$output\va_sector`i'long.jpg", as (jpg) replace

}


restore



***Descriptive
preserve
collapse (mean) tfp_ols [aw = drevenues] if tfp_ols!=., by(year)
sort year
tsset year
line tfp year, lwidth(.6)  ///
graphregion(color(white)) ///
ylabel(, gmax gmin format(%6.1fc)) xlabel(2015(1)2022) ///
ytitle("") xtitle("") title("TFP", color(black)) name(graph`i', replace) ysize(15) xsize(25)
graph export "$output\tfp_ols_evolution.jpg", as (jpg) replace
restore

preserve
collapse (mean) tfp_lp [aw = drevenues] if tfp_lp!=., by(year)
sort year
tsset year
line tfp year, lwidth(.6) ///
graphregion(color(white)) ///
ylabel(, gmax gmin format(%6.1fc)) xlabel(2015(1)2022) ///
ytitle("") xtitle("") title("TFP", color(black)) name(graph`i', replace) ysize(15) xsize(25)
graph export "$output\tfp_lp_evolution.jpg", as (jpg) replace
restore

preserve
collapse (mean) dva tfp_ols [aw = drevenues] if tfp_ols!=., by(year)
replace  dva=dva/1000000
sort year
tsset year
twoway (line tfp year, lwidth(.6) yaxis(1)) ///
       (line dva year, lwidth(.6) yaxis(2)), ///
graphregion(color(white)) ///
ylabel(, gmax gmin format(%6.1fc) axis(1)) ylabel(, gmax gmin format(%6.1fc) axis(2)) ///
xlabel(2015(1)2022) ///
ytitle("") xtitle("") title("TFP and VA (real in millions CFA)", color(black)) ///
name(graph`i', replace) ysize(15) xsize(25)
graph export "$output\tfp_ols_va_evolution.jpg", as (jpg) replace
restore

preserve
gen sector_3=.
replace sector_3= 1 if inlist(sector_12, 1, 2)
replace sector_3= 2 if inlist(sector_12, 2, 4, 5, 6)
replace sector_3= 3 if sector_12 >=7
label define sector_3 1 "Agriculture and mining" 2 "Manufacturing" 3 "Services"
label values sector_3 sector_3 

collapse (mean) tfp_lp [aw = drevenues] if tfp_lp!=., by(sector_3 year)

twoway (line tfp_lp year if sector_3==1) (line tfp_lp year if sector_3==2) (line tfp_lp year if sector_3==3), legend(label(1 "Agriculture and mining") label(2 "Manufacturing") label(3 "Services") pos(6) col(3) size(vsmall)) ytitle("") xtitle("") xlabel(2015(1)2022)
graph export "$output\tfp_lp_3sectors.jpg", as (jpg) replace

drop if sector_3==1
twoway (line tfp_lp year if sector_3==2) (line tfp_lp year if sector_3==3), legend(label(1 "Manufacturing") label(2 "Services") pos(6) col(3) size(vsmall)) ytitle("") xtitle("") xlabel(2015(1)2022)
graph export "$output\tfp_lp_2sectors.jpg", as (jpg) replace

restore


preserve 
collapse (mean) tfp_lp [aw = drevenues] if tfp_lp!=., by(sector_12 year)
twoway (line tfp_lp year if sector_12==1) (line tfp_lp year if sector_12==2) (line tfp_lp year if sector_12==3) (line tfp_lp year if sector_12==4) (line tfp_lp year if sector_12==5) (line tfp_lp year if sector_12==6) (line tfp_lp year if sector_12==7) (line tfp_lp year if sector_12==8, lpattern(dash)) (line tfp_lp year if sector_12==9, lpattern(dash)) (line tfp_lp year if sector_12==10, lpattern(dash)) (line tfp_lp year if sector_12==11, lpattern(dash)) (line tfp_lp year if sector_12==12, lpattern(dash)), legend(label(1 "Agriculture Fisheries Wood") label(2 "Extractive industries") label(3 "Agribusiness") label(4 "Textile Leather") label(5 "Wood Paper Furniture") label (6 "Other manufacturing") label(7 "Utilities") label(8 "Construction") label(9 "Wholesale and Retail") label(10 "Accomodation and restaurants") label(11 "Transport") label(12 "Other services") pos(6) col(3) size(vsmall)) ytitle("") xtitle("") xlabel(2015(1)2022)
graph export "$output\tfp_lp_evolution_bysector.jpg", as (jpg) replace
restore

*Reported issues
if "${dsf}" == "" {
    display as error "Set global dsf in config_local_paths.do before running the DSF section of FCI_DataAnalysis_ECOFIN15_22.do."
    exit 198
}

use "${dsf}/rge2016_and_dsf2022_clean.dta", clear
keep if year==2016
replace constraint1 = constraint2 if constraint1==5 & constraint2!=.

tab constraint1
tab constraint1, nol
labelbook constraint1
labelbook constraint2
labelbook constraint3
labelbook constraint4
labelbook constraint5

label define constraint1lb 1 "Lack of public-private dialogue" 2 "Lack of access to credit" 3 "Access to raw materials" 4 "No obstacle" 5 "Other obstacles" 6 "Unfair competition"  7 "Corruption" 8 "Cost of financing" 9 "Lack of market opportunities" 10 "Energy and water" 11 "Taxation" 12 "Administrative formalities" 13 "Training/skills" 14 "Infrastructure" 15 "Justice" 16 "Labor legislation" 17 "Preferential treatment (free trade zones)" 18 "Administrative hassles" 19 "Transport"
label values constraint1 constraint1lb
label values constraint2 constraint1lb
label values constraint3 constraint1lb
label values constraint4 constraint1lb
label values constraint5 constraint1lb

set scheme s1color
graph hbar (percent), over(constraint1, sort(1)) ytitle("Percent") title(Percentage of establishments citing as top obstacle, size(small))
graph export "$output\constraints.jpg", as(jpg) name("Graph") quality(90) replace

graph hbar (percent) if sector1==2, over(constraint1, sort(1)) ytitle("Percent") title(Percentage of establishments citing as top obstacle (Secondary sector), size(small))
graph export "$output\constraints_sector1.jpg", as(jpg) name("Graph") quality(90) replace

graph hbar (percent) if sector2==12, over(constraint1, sort(1)) ytitle("Percent") title(Percentage of establishments citing as top obstacle (Agroindustry sector), size(small))
graph export "$output\constraints_agroindustry.jpg", as(jpg) name("Graph") quality(90) replace

graph hbar (percent) if sector2==12 | sector2==3, over(constraint1, sort(1)) ytitle("Percent") title(Percentage of establishments citing as top obstacle (Manufacturing sector), size(small) )
graph export "$output\constraints_sector2.jpg", as(jpg) name("Graph") quality(90) replace

restore
