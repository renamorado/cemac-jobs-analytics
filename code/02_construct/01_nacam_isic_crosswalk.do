version 18.0
set more off

/*******************************************************************************
    Purpose:
        Build a merge-safe NACAM-to-ISIC Rev.4 crosswalk for the legacy NACAM
        branch codes observed in CMR_BDF.dta.

    Inputs:
        Globals created by 01_setup.do
        Data/Cameroon/Clean/CMR_BDF.dta
        docs/reference/nacam-rev1-ins-cameroon.pdf

    Outputs:
        Data/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta
*******************************************************************************/

if "${PROJECT_ROOT}" == "" {
    do "01_setup.do"
}

local clean_file "${DATADIR}/Cameroon/Clean/CMR_BDF.dta"
local source_pdf "${PROJECT_ROOT}/docs/reference/nacam-rev1-ins-cameroon.pdf"
local out_file "${DATADIR}/Intermediate/cmr_bdf_nacam_isic_crosswalk.dta"
local sleep_ms = real("${SLEEP_MS}")

if missing(`sleep_ms') {
    local sleep_ms 750
}

confirm file "`clean_file'"
confirm file "`source_pdf'"
capture mkdir "${DATADIR}/Intermediate"

tempfile observed_nacam

/*******************************************************************************
    1. Audit the observed legacy NACAM codes in CMR_BDF.dta
*******************************************************************************/

use "`clean_file'", clear
confirm variable nacam

keep nacam
drop if missing(nacam)
duplicates drop
isid nacam
sort nacam

count
local observed_nacam_count = r(N)
assert `observed_nacam_count' == 37

save "`observed_nacam'"

/*******************************************************************************
    2. Build the official crosswalk for the observed legacy branch codes only

    Source:
        Institut National de la Statistique du Cameroun,
        Nomenclature des activites et des produits du Cameroun (NACAM rev.1),
        Tables III.1 and III.2, pp. 8-15.

    Rule:
        isic_rev4_division is populated only when one legacy NACAM branch maps
        cleanly to a single ISIC Rev.4 division. Otherwise it remains blank and
        manual_review_flag = 1.
*******************************************************************************/

clear
input ///
    byte nacam ///
    str160 nacam_label ///
    str30 nacam_rev1 ///
    str80 naema_rev1 ///
    str20 isic_rev4_section ///
    str8 isic_rev4_division ///
    str180 isic_rev4_detail ///
    byte manual_review_flag
1  "AGRICULTURE"                                                                                                     "001"         "01"                                      "A"         "01" "011-013;016"                                                                          0
2  "AGRICULTURE"                                                                                                     "001"         "01"                                      "A"         "01" "011-013;016"                                                                          0
3  "ELEVAGE ET CHASSE"                                                                                               "002"         "01.4,01.6,01.7"                          "A"         "01" "014;016;017"                                                                          0
5  "PECHE ET AQUACULTURE"                                                                                            "004"         "03"                                      "A"         "03" "031,0311,032"                                                                         0
6  "EXTRACTION DES PRODUITS DES HYDROCARBURES ET D'AUTRES PRODUITS ENERGETIQUES"                                    "005"         "05,06,09"                                "B"         ""   "061-062;091;099"                                                                     1
7  "EXTRACTION DES MINERAIS"                                                                                         "006"         "07,08,09"                                "B"         ""   "071;081;089;099"                                                                     1
8  "INDUSTRIE DE LA VIANDE ET DU POISSON"                                                                            "007"         "10.1,10.2"                               "C"         "10" "101,102"                                                                              0
9  "TRAVAIL DES GRAINS ET FABRICATION DES PRODUITS AMYLACES"                                                         "008"         "10.6"                                    "C"         "10" "1061,1062,107"                                                                        0
10 "INDUSTRIE DU CACAO, DU CAFE, DU THE ET DU SUCRE"                                                                 "009"         "10.9"                                    "C"         "10" "1072,1073,1079"                                                                       0
11 "INDUSTRIE DES OLEAGINEUX ET D'ALIMENTS POUR ANIMAUX"                                                             "010"         "10.4,10.8"                               "C"         "10" "1040,1080"                                                                            0
12 "FABRICATION DE PRODUITS A BASE DE CEREALES"                                                                      "011"         "10.7"                                    "C"         "10" "1071,1074"                                                                            0
13 "INDUSTRIE DU LAIT, DES FRUITS ET LEGUMES ET DES AUTRES PRODUITS ALIMENTAIRES"                                   "012"         "10.3,10.5,10.7"                          "C"         "10" "103;1050;107"                                                                         0
15 "INDUSTRIES DU TABAC"                                                                                             "014"         "12"                                      "C"         "12" "120"                                                                                  0
16 "INDUSTRIES DU TEXTILE ET DE LA CONFECTION"                                                                       "015"         "13,14"                                   "C"         ""   "131x;139;141-143"                                                                     1
17 "INDUSTRIES DU CUIR ET FABRICATION DES CHAUSSURES"                                                                "016"         "15"                                      "C"         "15" "151,152"                                                                              0
18 "INDUSTRIES DU BOIS SAUF FABRICATION DES MEUBLES"                                                                 "017"         "16"                                      "C"         "16" "161;1621-1623;1629"                                                                   0
19 "FABRICATION DE PAPIER, CARTON ET D'ARTICLES EN PAPIER OU EN CARTON; IMPRIMERIE ET REPRODUCTION"                "018"         "17,18"                                   "C"         ""   "170,181"                                                                              1
20 "RAFFINAGE DU PETROLE ET COKEFACTION"                                                                             "019"         "19"                                      "C"         "19" "1910,1920"                                                                            0
21 "FABRICATION DE PRODUITS CHIMIQUES ET PHARMACEUTIQUES"                                                            "020"         "20,21"                                   "C"         ""   "201;202;2029;21"                                                                      1
22 "PRODUCTION DE CAOUTCHOUC ET FABRICATION D'ARTICLES EN CAOUTCHOUC ET EN MATIERES PLASTIQUES"                    "021"         "01.16,22"                                "A,C"       ""   "0116,221,222"                                                                         1
23 "FABRICATION DE PRODUITS MINERAUX NON METALLIQUES"                                                                "022"         "23"                                      "C"         "23" "2394,2396,2399"                                                                       0
24 "FABRICATION DES PRODUITS METALLURGIQUES DE BASE ET D'OUVRAGES EN METAUX"                                        "023"         "24,25"                                   "C"         ""   "24;25"                                                                                1
27 "FABRICATION DE MATERIEL DE TRANSPORT"                                                                            "026"         "29,30"                                   "C"         ""   "291,292,293,30"                                                                       1
28 "FABRICATION DE MEUBLES ET AUTRES ACTIVITES MANUFACTURIERES; RECUPERATION/DECHETS EN REV.1"                     "027,030"     "31,32,38"                                "C,E"       ""   "3100;32;380"                                                                          1
29 "PRODUCTION ET DISTRIBUTION D'ELECTRICITE ET D'EAU DANS LA NOMENCLATURE ANCIENNE"                                "029,030"     "35,36"                                   "D,E"       ""   "351-353;360"                                                                          1
30 "CONSTRUCTION"                                                                                                    "031"         "41,42,43"                                "F"         ""   "41,42,432,433"                                                                        1
31 "COMMERCE"                                                                                                        "032"         "45,46,47"                                "G"         ""   "451-454;4620;4630;464-466;4690;471-479"                                               1
32 "REPARATIONS"                                                                                                     "028,032,042" "33,45,95"                                "C,G,S"     ""   "331-332;452-454;952"                                                                  1
33 "HEBERGEMENT ET RESTAURATION"                                                                                     "033"         "55,56"                                   "I"         ""   "55,56"                                                                                1
34 "TRANSPORT ET ENTREPOSAGE"                                                                                        "034"         "49,50,51,52,53"                          "H"         ""   "491-4923;50;51;521-522;531-532"                                                       1
35 "POSTES ET TELECOMMUNICATIONS"                                                                                    "034,035"     "53,60,61"                                "H,J"       ""   "531,532,60,61"                                                                        1
36 "ACTIVITES FINANCIERES ET D'ASSURANCE"                                                                            "036"         "64,65,66"                                "K"         ""   "64-66;6491;6492;6499"                                                                 1
37 "ACTIVITES IMMOBILIERES"                                                                                          "037"         "68"                                      "L"         "68" "681,682"                                                                              0
38 "ACTIVITES FOURNIES PRINCIPALEMENT AUX ENTREPRISES"                                                               "035,038,042" "58,62,63,69,70,71,72,74,75,77,78,79,95" "J,M,N,S"   ""   "58;62;63;69-72;74;75;77-79;951"                                                       1
40 "ACTIVITES EDUCATIVES"                                                                                            "040"         "85"                                      "P"         "85" "85"                                                                                   0
41 "ACTIVITES POUR LA SANTE HUMAINE ET L'ACTION SOCIALE"                                                             "038,041"     "75,86,87,88"                             "M,Q"       ""   "75,86,87,88"                                                                          1
42 "AUTRES ACTIVITES FOURNIES A LA COLLECTIVITE, ACTIVITES SOCIALES ET PERSONNELLES"                                "030,035,042" "37,38,39,59,93,94,95,96,97"              "E,J,R,S,T" ""   "370;380;39;59;93-97"                                                                   1
end

generate str160 nacam_label_en = ""
generate str40 nacam_label_short_en = ""

replace nacam_label_en = "Agriculture" if nacam == 1
replace nacam_label_en = "Agriculture" if nacam == 2
replace nacam_label_en = "Livestock and hunting" if nacam == 3
replace nacam_label_en = "Fishing and aquaculture" if nacam == 5
replace nacam_label_en = "Extraction of hydrocarbons and other energy products" if nacam == 6
replace nacam_label_en = "Mining" if nacam == 7
replace nacam_label_en = "Meat and fish processing" if nacam == 8
replace nacam_label_en = "Grain milling and starch products" if nacam == 9
replace nacam_label_en = "Cocoa, coffee, tea, and sugar processing" if nacam == 10
replace nacam_label_en = "Oilseed processing and animal feed" if nacam == 11
replace nacam_label_en = "Cereal-based products" if nacam == 12
replace nacam_label_en = "Dairy, fruit and vegetable, and other food products" if nacam == 13
replace nacam_label_en = "Tobacco products" if nacam == 15
replace nacam_label_en = "Textiles and apparel" if nacam == 16
replace nacam_label_en = "Leather and footwear" if nacam == 17
replace nacam_label_en = "Wood products excluding furniture" if nacam == 18
replace nacam_label_en = "Paper, paperboard, printing, and reproduction" if nacam == 19
replace nacam_label_en = "Petroleum refining and coke" if nacam == 20
replace nacam_label_en = "Chemicals and pharmaceuticals" if nacam == 21
replace nacam_label_en = "Rubber and plastics" if nacam == 22
replace nacam_label_en = "Non-metallic mineral products" if nacam == 23
replace nacam_label_en = "Basic metals and fabricated metal products" if nacam == 24
replace nacam_label_en = "Transport equipment" if nacam == 27
replace nacam_label_en = "Furniture, other manufacturing, and recovery/waste" if nacam == 28
replace nacam_label_en = "Electricity and water supply" if nacam == 29
replace nacam_label_en = "Construction" if nacam == 30
replace nacam_label_en = "Trade" if nacam == 31
replace nacam_label_en = "Repair services" if nacam == 32
replace nacam_label_en = "Accommodation and food services" if nacam == 33
replace nacam_label_en = "Transport and warehousing" if nacam == 34
replace nacam_label_en = "Postal services and telecommunications" if nacam == 35
replace nacam_label_en = "Financial and insurance activities" if nacam == 36
replace nacam_label_en = "Real estate activities" if nacam == 37
replace nacam_label_en = "Business services" if nacam == 38
replace nacam_label_en = "Education" if nacam == 40
replace nacam_label_en = "Health and social work" if nacam == 41
replace nacam_label_en = "Community, social, personal, and collective services" if nacam == 42

replace nacam_label_short_en = "Agriculture" if nacam == 1
replace nacam_label_short_en = "Agriculture" if nacam == 2
replace nacam_label_short_en = "Livestock" if nacam == 3
replace nacam_label_short_en = "Fishing" if nacam == 5
replace nacam_label_short_en = "Hydrocarbons" if nacam == 6
replace nacam_label_short_en = "Mining" if nacam == 7
replace nacam_label_short_en = "Meat & fish" if nacam == 8
replace nacam_label_short_en = "Grains & starch" if nacam == 9
replace nacam_label_short_en = "Cocoa/coffee/sugar" if nacam == 10
replace nacam_label_short_en = "Oilseeds & feed" if nacam == 11
replace nacam_label_short_en = "Cereal products" if nacam == 12
replace nacam_label_short_en = "Other food" if nacam == 13
replace nacam_label_short_en = "Tobacco" if nacam == 15
replace nacam_label_short_en = "Textiles & apparel" if nacam == 16
replace nacam_label_short_en = "Leather & footwear" if nacam == 17
replace nacam_label_short_en = "Wood products" if nacam == 18
replace nacam_label_short_en = "Paper & printing" if nacam == 19
replace nacam_label_short_en = "Petroleum refining" if nacam == 20
replace nacam_label_short_en = "Chemicals & pharma" if nacam == 21
replace nacam_label_short_en = "Rubber & plastics" if nacam == 22
replace nacam_label_short_en = "Non-metallic minerals" if nacam == 23
replace nacam_label_short_en = "Metals" if nacam == 24
replace nacam_label_short_en = "Transport equipment" if nacam == 27
replace nacam_label_short_en = "Furniture & other mfg" if nacam == 28
replace nacam_label_short_en = "Utilities" if nacam == 29
replace nacam_label_short_en = "Construction" if nacam == 30
replace nacam_label_short_en = "Trade" if nacam == 31
replace nacam_label_short_en = "Repairs" if nacam == 32
replace nacam_label_short_en = "Hospitality" if nacam == 33
replace nacam_label_short_en = "Transport & storage" if nacam == 34
replace nacam_label_short_en = "Post & telecom" if nacam == 35
replace nacam_label_short_en = "Finance & insurance" if nacam == 36
replace nacam_label_short_en = "Real estate" if nacam == 37
replace nacam_label_short_en = "Business services" if nacam == 38
replace nacam_label_short_en = "Education" if nacam == 40
replace nacam_label_short_en = "Health & social work" if nacam == 41
replace nacam_label_short_en = "Other services" if nacam == 42

assert !missing(nacam_label_en)
assert !missing(nacam_label_short_en)

generate str120 mapping_source = "INS Cameroon NACAM Rev.1 PDF, Tables III.1-III.2 (pp. 8-15)"
generate str20 mapping_quality = cond(manual_review_flag == 1, "manual_review", "division_exact")

order nacam nacam_label nacam_label_en nacam_label_short_en ///
    nacam_rev1 naema_rev1 isic_rev4_section ///
    isic_rev4_division isic_rev4_detail mapping_source ///
    mapping_quality manual_review_flag
sort nacam

label variable nacam "Legacy NACAM branch code observed in CMR_BDF.dta"
label variable nacam_label "Legacy NACAM branch label"
label variable nacam_label_en "Legacy NACAM branch label in English"
label variable nacam_label_short_en "Abbreviated English NACAM branch label"
label variable nacam_rev1 "Mapped NACAM rev.1 branch code(s)"
label variable naema_rev1 "Mapped NAEMA rev.1 / ISIC rev.4 division reference"
label variable isic_rev4_section "Mapped ISIC rev.4 section(s)"
label variable isic_rev4_division "Canonical ISIC rev.4 division for merge-safe cases"
label variable isic_rev4_detail "Detailed ISIC rev.4 classes reflected by the branch"
label variable mapping_source "Official documentation source"
label variable mapping_quality "Crosswalk quality flag"
label variable manual_review_flag "1 if the branch splits across multiple ISIC divisions"

isid nacam

count
assert r(N) == 37

/*******************************************************************************
    3. Coverage audit against the observed CMR_BDF.dta codes
*******************************************************************************/

merge 1:1 nacam using "`observed_nacam'"

count if _merge != 3
local unmatched_nacam = r(N)

if `unmatched_nacam' > 0 {
    display as error "Observed NACAM codes missing from the crosswalk:"
    list nacam if _merge != 3, noobs abbreviate(20)
    error 459
}

drop _merge
sort nacam
isid nacam

assert manual_review_flag == 1 if missing(isic_rev4_division)
assert !missing(isic_rev4_division) if manual_review_flag == 0

quietly count if manual_review_flag == 1
local manual_review_n = r(N)

display as text "Built NACAM-to-ISIC crosswalk for `observed_nacam_count' observed legacy codes."
display as text "Manual review required for `manual_review_n' legacy NACAM branches."
display as text "Source PDF: `source_pdf'"

if `manual_review_n' > 0 {
    display as text "Legacy branches requiring manual review:"
    list nacam nacam_label isic_rev4_section naema_rev1 if manual_review_flag == 1, ///
        noobs abbreviate(32)
}

capture save "`out_file'", replace
if _rc {
    sleep `sleep_ms'
    save "`out_file'", replace
}

display as result "Saved crosswalk to `out_file'"
