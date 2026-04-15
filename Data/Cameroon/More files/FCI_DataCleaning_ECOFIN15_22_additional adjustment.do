version 18.0
set more off


************************************************
************************************************
*     Cleaning of Cameroon Ecofin dataset      *
************************************************
************************************************

/*
   Purpose: Adjusting inconsistent employment values
   Prepared by: Johanne Buba
   Obs: 9325
   Input: ECOFIN 2015 - 2022
   Output: Mutiple graphs & tests & regressions  
   Number of firms : 1639	
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

do "code/01_setup.do"

global ecofin "${PROJECT_ROOT}/Data/Cameroon/More files"

use "${ecofin}/ecofin15_22_clean_panel.dta", clear
xtset id year

** Recheck concistency of employment, value added, revenue and wagebill variables particularly for the agriculture and textile industries

	/**Coherence of growth values
foreach var in revenues wagebill va va_comp ebe inv cap cmat emp { 
	bysort id: gen `var'_gr = `var'[_n]/`var'[1]
	bysort id: egen `var'_gmax =max(`var'_gr)
}

	sort sector_12 id year
	order sector_12 sector CODE2 year emp emp_gr emp_gmax wagebill wagebill_gr wagebill_gmax va va_gr va_gmax cap cap_gr cap_gmax cmat cmat_gr cmat_gmax revenues revenues_gr revenues_gmax
	
labelbook sector
labelbook sector_12
*/


* Define dummies
gen badfirm=0
la var badfirm "Exclude firm because of inconcistent values - employment, wagebill, revenues"

gen nearbadfirm=0
la var nearbadfirm "Exclude firm because of inconcistent values but somehow logical see if can be kept"

gen almostbadfirm=0
la var almostbadfirm "Exclude firm because of inconcistent values in certain years - but don't do both almostbadfirm and badyears"

gen badyears=0
la var badyears "Exclude certain years for given firm due to inconcistent values"



*sector_12==1 Agriculture // Initially 88 firms
replace badfirm=1 if CODE2== "ECOFIN0175"
replace badfirm=1 if CODE2== "ECOFIN0924"
replace nearbadfirm=1 if CODE2== "ECOFIN0951" 
replace badfirm=1 if CODE2== "ECOFIN1069"
replace nearbadfirm=1 if CODE2== "ECOFIN1095" 
replace badfirm=1 if CODE2== "ECOFIN1043"
replace badfirm=1 if CODE2== "ECOFIN1501"
replace badfirm=1 if CODE2== "ECOFIN1590" 
replace almostbadfirm=1 if CODE2== "ECOFIN1494" 
	replace badyears=1 if CODE2== "ECOFIN0076" & inlist(year, 2021, 2022)


*sector_12==2 Extractive // Initially 34 firms
replace badfirm=1 if CODE2== "ECOFIN0003"
replace almostbadfirm=1 if CODE2== "ECOFIN0012" // some years look good - use one or the other
	replace badyears=1 if CODE2== "ECOFIN0012" & inlist(year, 2016, 2017, 2018)
replace nearbadfirm=1 if CODE2== "ECOFIN0021" 
replace badfirm=1 if CODE2== "ECOFIN0051" 
replace almostbadfirm=1 if CODE2== "ECOFIN0076" 
	replace badyears=1 if CODE2== "ECOFIN0076" & inlist(year, 2021, 2022)
replace badfirm=1 if CODE2== "ECOFIN0096" 
replace almostbadfirm=1 if CODE2== "ECOFIN0127"
	replace badyears=1 if CODE2== "ECOFIN0127" & inlist(year, 2020, 2021, 2022)
replace badfirm=1 if CODE2== "ECOFIN0148"
replace nearbadfirm=1 if CODE2== "ECOFIN0157"
replace badfirm=1 if CODE2== "ECOFIN0260"	

*sector_12==3 Agribusiness // Initially 79 firms
replace nearbadfirm=1 if CODE2== "ECOFIN0304"
replace almostbadfirm=1 if CODE2== "ECOFIN0373"
	replace badyears=1 if CODE2== "ECOFIN0373" & inlist(year, 2020, 2021, 2022)
replace almostbadfirm=1 if CODE2== "ECOFIN0498"
	replace badyears=1 if CODE2== "ECOFIN0498" & inlist(year, 2020)
replace nearbadfirm=1 if CODE2== "ECOFIN0564"
replace almostbadfirm=1 if CODE2== "ECOFIN0852"
	replace badyears=1 if CODE2== "ECOFIN0852" & inlist(year, 2021, 2022)
*replace nearbadfirm=1 if CODE2== "ECOFIN0879"	
	
*sector_12==4 Textile // Initially 13 firms


*sector_12==5 Wood // Initially 83 firms
replace badfirm=1 if CODE2== "ECOFIN0904"
replace almostbadfirm=1 if CODE2== "ECOFIN0940"
	replace badyears=1 if CODE2== "ECOFIN0940" & inlist(year, 2021, 2022)
replace nearbadfirm=1 if CODE2== "ECOFIN1087"
replace nearbadfirm=1 if CODE2== "ECOFIN1088"
replace nearbadfirm=1 if CODE2== "ECOFIN1090"
replace almostbadfirm=1 if CODE2== "ECOFIN1092"
	replace badyears=1 if CODE2== "ECOFIN1092" & inlist(year, 2018, 2019, 2020, 2021, 2022)
replace nearbadfirm=1 if CODE2== "ECOFIN1100"	
replace almostbadfirm=1 if CODE2== "ECOFIN1102"
	replace badyears=1 if CODE2== "ECOFIN1102" & inlist(year, 2020, 2021, 2022)
replace almostbadfirm=1 if CODE2== "ECOFIN1102"
	replace badyears=1 if CODE2== "ECOFIN1102" & inlist(year, 2020, 2021, 2022)	
replace almostbadfirm=1 if CODE2== "ECOFIN1114"
	replace badyears=1 if CODE2== "ECOFIN1114" & inlist(year, 2020)	


*sector_12==6 Other manuf // Initially 118 firms
*replace badfirm=1 if CODE2== "ECOFIN0175"
replace badfirm=1 if CODE2== "ECOFIN10970"
replace badfirm=1 if CODE2== "ECOFIN0983"
replace almostbadfirm=1 if CODE2== "ECOFIN1052"
	replace badyears=1 if CODE2== "ECOFIN1052" & inlist(year, 2018, 2019)
replace almostbadfirm=1 if CODE2== "ECOFIN1076"
	replace badyears=1 if CODE2== "ECOFIN1076" & inlist(year, 2015)
replace badfirm=1 if CODE2== "ECOFIN1081"
replace badfirm=1 if CODE2== "ECOFIN1084"
	
*sector_12==7 Utilities // Initially 17 firms
replace badfirm=1 if CODE2== "ECOFIN1127"
replace almostbadfirm=1 if CODE2== "ECOFIN1143"
	replace badyears=1 if CODE2== "ECOFIN1143" & inlist(year, 2018 2019, 2020, 2021, 2022)
replace badfirm=1 if CODE2== "ECOFIN1144"


*sector_12==8 Construction // Initially 130 firms
replace almostbadfirm=1 if CODE2== "ECOFIN1173"
	replace badyear=1 if CODE2== "ECOFIN1173" & inlist(year, 2015,2016)
replace badfirm=1 if CODE2== "ECOFIN1177"
replace almostbadfirm=1 if CODE2== "ECOFIN1178"
	replace badyear=1 if CODE2== "ECOFIN1178" & inlist(year, 2022)
replace almostbadfirm=1 if CODE2== "ECOFIN1197"
	replace badyear=1 if CODE2== "ECOFIN1197" & inlist(year, 2015)
replace badfirm=1 if CODE2== "ECOFIN1201"
replace badfirm=1 if CODE2== "ECOFIN1206"
replace almostbadfirm=1 if CODE2== "ECOFIN1216"
	replace badyear=1 if CODE2== "ECOFIN1216" & inlist(year, 2019)
replace badfirm=1 if CODE2== "ECOFIN1223"
replace badfirm=1 if CODE2== "ECOFIN1234"
replace almostbadfirm=1 if CODE2== "ECOFIN1235"
	replace badyear=1 if CODE2== "ECOFIN1235" & inlist(year, 2017, 2018)
replace badfirm=1 if CODE2== "ECOFIN1245"
replace almostbadfirm=1 if CODE2== "ECOFIN1247"
	replace badyear=1 if CODE2== "ECOFIN1247" & inlist(year, 2017)
replace badfirm=1 if CODE2== "ECOFIN1254" & year==2015
replace nearbadfirm=1 if CODE2== "ECOFIN1258"
replace badfirm=1 if CODE2== "ECOFIN1262"
replace badfirm=1 if CODE2== "ECOFIN1278"
replace badfirm=1 if CODE2== "ECOFIN1287"
replace badfirm=1 if CODE2== "ECOFIN1578"
replace badfirm=1 if CODE2== "ECOFIN1640"


	
*sector_12==9 Wholesale // Initially 304 firms
replace badfirm=1 if CODE2== "ECOFIN0007"
replace almostbadfirm=1 if CODE2== "ECOFIN0010"
	replace badyear=1 if CODE2== "ECOFIN0010" & inlist(year, 2020, 2021, 2022)
replace badfirm=1 if CODE2== "ECOFIN0028"
replace badfirm=1 if CODE2== "ECOFIN0033"
replace badfirm=1 if CODE2== "ECOFIN0039"
replace nearbadfirm=1 if CODE2== "ECOFIN0046"
replace badfirm=1 if CODE2== "ECOFIN0053"
replace almostbadfirm=1 if CODE2== "ECOFIN1322"
	replace badyear=1 if CODE2== "ECOFIN1322" & inlist(year, 2022)
replace badfirm=1 if CODE2== "ECOFIN1352"	
replace badfirm=1 if CODE2== "ECOFIN1357"
replace badfirm=1 if CODE2== "ECOFIN1358"	
replace almostbadfirm=1 if CODE2== "ECOFIN1375"
	replace badyear=1 if CODE2== "ECOFIN1375" & inlist(year, 2018, 2019)
replace badfirm=1 if CODE2== "ECOFIN1400"
replace badfirm=1 if CODE2== "ECOFIN1447"	
replace badfirm=1 if CODE2== "ECOFIN1453"		
replace nearbadfirm=1 if CODE2== "ECOFIN1489"
replace badfirm=1 if CODE2== "ECOFIN1503"
replace badfirm=1 if CODE2== "ECOFIN1510"
replace badfirm=1 if CODE2== "ECOFIN1521"
replace nearbadfirm=1 if CODE2== "ECOFIN1552"
replace badfirm=1 if CODE2== "ECOFIN1616"	
	
*sector_12==10 Accomodation // Initially 46 firms
replace badfirm=1 if CODE2== "ECOFIN0075" & year==2015
replace nearbadfirm=1 if CODE2== "ECOFIN0083"
replace nearbadfirm=1 if CODE2== "ECOFIN0097"
replace nearbadfirm=1 if CODE2== "ECOFIN0110"


*sector_12==11 Transport // Initially 131 firms
replace badfirm=1 if CODE2== "ECOFIN0124" & year==2017
replace badfirm=1 if CODE2== "ECOFIN0130"
replace badfirm=1 if CODE2== "ECOFIN0173"
replace badfirm=1 if CODE2== "ECOFIN0181"
replace badfirm=1 if CODE2== "ECOFIN0182" & year==2021
replace badfirm=1 if CODE2== "ECOFIN0184"
replace badfirm=1 if CODE2== "ECOFIN0189" & year==2018
replace badfirm=1 if CODE2== "ECOFIN0196" & year==2015
replace badfirm=1 if CODE2== "ECOFIN0197"
replace badfirm=1 if CODE2== "ECOFIN0205"
replace almostbadfirm=1 if CODE2== "ECOFIN0216"
	replace badyear=1 if CODE2== "ECOFIN0216" & inlist(year, 2017, 2018, 2019)
replace almostbadfirm=1 if CODE2== "ECOFIN0227"
	replace badyear=1 if CODE2== "ECOFIN0227" & inlist(year, 2020, 2021)
replace badfirm=1 if CODE2== "ECOFIN0231" & year==2015
replace badfirm=1 if CODE2== "ECOFIN0248" & year==2018
replace badfirm=1 if CODE2== "ECOFIN0252" & year==2015
replace badfirm=1 if CODE2== "ECOFIN0256" & year==2015

*sector_12==12 Other services // Initially 518 firms
replace almostbadfirm=1 if CODE2== "ECOFIN0262"
	replace badyear=1 if CODE2== "ECOFIN0262" & inlist(year, 2015, 2016, 2017)
replace almostbadfirm=1 if CODE2== "ECOFIN0279"
	replace badyear=1 if CODE2== "ECOFIN0279" & inlist(year, 2017)
replace almostbadfirm=1 if CODE2== "ECOFIN0286"
	replace badyear=1 if CODE2== "ECOFIN0286" & inlist(year, 2015)
replace almostbadfirm=1 if CODE2== "ECOFIN0286"
	replace badyear=1 if CODE2== "ECOFIN0286" & inlist(year, 2015)
replace almostbadfirm=1 if CODE2== "ECOFIN0336"
	replace badyear=1 if CODE2== "ECOFIN0336" & inlist(year, 2015)
replace badfirm=1 if CODE2== "ECOFIN0379"	
replace nearbadfirm=1 if CODE2== "ECOFIN0388"
replace nearbadfirm=1 if CODE2== "ECOFIN0403"
replace almostbadfirm=1 if CODE2== "ECOFIN0401"
	replace badyear=1 if CODE2== "ECOFIN0401" & inlist(year, 2018)
replace almostbadfirm=1 if CODE2== "ECOFIN0406"
	replace badyear=1 if CODE2== "ECOFIN0406" & inlist(year, 2018, 2019, 2020, 2021)
replace nearbadfirm=1 if CODE2== "ECOFIN0410"
replace badfirm=1 if CODE2== "ECOFIN0433"		
replace nearbadfirm=1 if CODE2== "ECOFIN0435"
replace almostbadfirm=1 if CODE2== "ECOFIN0454"
	replace badyear=1 if CODE2== "ECOFIN0454" & inlist(year, 2017)
replace almostbadfirm=1 if CODE2== "ECOFIN0462"
	replace badyear=1 if CODE2== "ECOFIN0462" & inlist(year, 2022)
replace almostbadfirm=1 if CODE2== "ECOFIN0487"
	replace badyear=1 if CODE2== "ECOFIN0487" & inlist(year, 2017, 2018)
replace almostbadfirm=1 if CODE2== "ECOFIN0500"
	replace badyear=1 if CODE2== "ECOFIN0500" & inlist(year, 2017, 2018, 2019, 2020, 2021, 2022)
replace badfirm=1 if CODE2== "ECOFIN0503"		
replace almostbadfirm=1 if CODE2== "ECOFIN0518"
	replace badyear=1 if CODE2== "ECOFIN0518" & inlist(year, 2021)	
replace almostbadfirm=1 if CODE2== "ECOFIN0541"
	replace badyear=1 if CODE2== "ECOFIN0541" & inlist(year, 2018, 2019, 2020)	
replace nearbadfirm=1 if CODE2== "ECOFIN0545"		
replace almostbadfirm=1 if CODE2== "ECOFIN0555"
	replace badyear=1 if CODE2== "ECOFIN0555" & inlist(year, 2017, 2018, 2019, 2020, 2021, 2022)
replace badfirm=1 if CODE2== "ECOFIN0562"	
replace almostbadfirm=1 if CODE2== "ECOFIN0565"
	replace badyear=1 if CODE2== "ECOFIN0565" & inlist(year, 2018, 2019, 2020, 2021, 2022)
replace badfirm=1 if CODE2== "ECOFIN0579"		
replace badfirm=1 if CODE2== "ECOFIN0580"	
replace badfirm=1 if CODE2== "ECOFIN0595"	
replace badfirm=1 if CODE2== "ECOFIN0598"	
replace badfirm=1 if CODE2== "ECOFIN0600"	
replace badfirm=1 if CODE2== "ECOFIN0604"	
replace nearbadfirm=1 if CODE2== "ECOFIN0605"
replace badfirm=1 if CODE2== "ECOFIN0606" & inlist(year, 2020, 2021)		
replace badfirm=1 if CODE2== "ECOFIN0646"	& year ==2022
replace badfirm=1 if CODE2== "ECOFIN0662" & inlist(year, 2021, 2022)			
replace badfirm=1 if CODE2== "ECOFIN0692"
replace badfirm=1 if CODE2== "ECOFIN0693"
replace badfirm=1 if CODE2== "ECOFIN0708" & inlist(year, 2018, 2019)			
replace badfirm=1 if CODE2== "ECOFIN0714" & inlist(year, 2015, 2016, 2017)			
replace badfirm=1 if CODE2== "ECOFIN0718"
replace badfirm=1 if CODE2== "ECOFIN0726" & year==2022
replace badfirm=1 if CODE2== "ECOFIN0759"
replace badfirm=1 if CODE2== "ECOFIN0783"
replace badfirm=1 if CODE2== "ECOFIN0777"
replace nearbadfirm=1 if CODE2== "ECOFIN0787"
replace badfirm=1 if CODE2== "ECOFIN0788"
replace badfirm=1 if CODE2== "ECOFIN0802"
replace badfirm=1 if CODE2== "ECOFIN0816"
replace badfirm=1 if CODE2== "ECOFIN0857"
replace badfirm=1 if CODE2== "ECOFIN1574"
replace nearbadfirm=1 if CODE2== "ECOFIN1587"
	
**Additional fixes
/*
replace emp=61 if CODE2=="ECOFIN0500" & year==2015
replace emp=61 if CODE2=="ECOFIN0500" & year==2016
replace emp=107 if CODE2=="ECOFIN606" & year==2020 // originally it was 1077, but that looks like a typo with extra 7. 107 looks consistent with employment in other years.
replace emp=107 if CODE2=="ECOFIN0606" & year==2020 // idem
replace emp=54 if CODE2== "ECOFIN0983" & year==2018 //545 likely typo 
replace emp=69 if CODE2== "ECOFIN0983" & year==2019 //695 likely typo 
replace emp=45 if CODE2== "ECOFIN0774" & year==2019 //5 likely typo 
replace emp=31 if CODE2== "ECOFIN0744" & inlist(year, 2018, 2019, 2020, 2021 2022) //5 likely typo 
replace emp=200 if CODE2== "ECOFIN0726" & year==2022
replace emp=1 if CODE2== "ECOFIN0419" & year==2017
replace wagebill=562320  if CODE2== "ECOFIN0032" & year==2021 // all other years are 563,320 and this year was 56,232 - looks clearly that one zero was missing

*/





/** Winsorize by the smallest sector 
drop win_dum*

*What if we winsorize by abnormal growth?


foreach var in revenues wagebill va va_comp ebe inv cap cmat emp { 
	bysort id : gen emp_gr= emp[_n] / emp[1] if win_dum_emp ==0 & sector_12==4	
	bys sector: egen top_`var' = pctile(`var'), p(99.9)       
	bys sector: egen bottom_`var' = pctile(`var'), p(0.1)
	gen win_dum_`var' = 0
	replace win_dum_`var' = 1 if `var' >= top_`var' & `var'!=. & top_`var'!= .
	replace win_dum_`var' = 1 if `var' <= bottom_`var' & `var'!= . & bottom_`var'!= .
}

** should we drop the firm all the way?!!!!!!!!!!!!!!!

*Fix employment numbers of workers relative to first year 
	xtset id year
	bysort id : gen emp_gr= emp[_n] / emp[1] if win_dum_emp ==0 & sector_12==1
	bysort id : gen dva_gr= dva[_n] / dva[1] if win_dum_va ==0 & sector_12==1
	
*	order sector sector_12 id year emp_gr_ag1 emp dva_gr dva va
	format dva %22.0fc
	format va %22.0fc
	format revenues %22.0fc
	order CODE2 year sector sector_12 emp_gr emp revenues wagebill dva_gr dva va win_dum_emp win_dum_va win_dum_revenues

	
	bysort id: egen maxgremp=max(emp_gr)
	drop if maxgremp > 3 & sector_12==1 // dropping extreme values
	bysort id: egen maxgrva=max(dva_gr)
	drop if maxgrva > 3 & sector_12==1 
	*replace ldwagebill=. if emp_gr_ag1 > 3 & sector_12==1
	
	drop emp_gr dva_gr max*
	
	replace drevenues=. if drevenues==0
	
	*drop inconcistent values
	drop if CODE2=="ECOFIN1095" & year==2021  
	drop if CODE2=="ECOFIN1095" & year==2022
	drop if CODE2=="ECOFIN1121" & year==2017
	drop if CODE2=="ECOFIN1121" & year==2018
	replace emp=3 if emp==38 & CODE2=="ECOFIN1501"
	drop if CODE2=="ECOFIN1069"
	drop if CODE2 =="ECOFIN1129"
*/
	
save "${ecofin}/ecofin15_22_clean_panel_new5.dta", replace
