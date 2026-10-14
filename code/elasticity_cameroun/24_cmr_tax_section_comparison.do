version 17.0
clear all
set more off
do "code/01_setup.do"
capture log close sectioncomparison
log using "${LOGDIR}/24_cmr_tax_section_comparison.log", text replace name(sectioncomparison)

* Recreate the two statistics in slides_cemac's Ecofin employment/revenue
* figures, changing only classification. Slide labels are retained verbatim
* on the left, including the superseded legacy interpretation.
tempfile cleaned panel results plot_groups

* Preserve the ten broad labels, colors and symbols from the original figures.
* Map corrected group meanings, never the superseded raw-code color assignment.
* NACAM 005 and 006 share section B and the existing Mining style.
do "${CODEDIR}/02_construct/01_isic4_broad_groups.do"
use "${DATADIR}/Intermediate/cmr_tax_isic4_sections_crosswalk.dta", clear
keep isic4_section
duplicates drop
rename isic4_section group
split group, parse("+") generate(section)
reshape long section, i(group) j(component)
drop if missing(section)
rename section isic4_section
merge m:1 isic4_section using "${DATADIR}/Intermediate/isic4_broad_groups_sections.dta", ///
    keep(master match) keepusing(broad_sector broad_sector_label plot_color plot_symbol) assert(match using) nogen
* A combined tax group gets a shared style only if all its sections agree.
bysort group (component): assert broad_sector == broad_sector[1]
by group: keep if _n == 1
keep group broad_sector broad_sector_label plot_color plot_symbol
rename broad_sector tax_plot_group
rename broad_sector_label tax_plot_label
rename plot_color tax_plot_color
rename plot_symbol tax_plot_symbol
isid group
assert _N == 16
assert inrange(tax_plot_group, 1, 10)
assert !missing(tax_plot_label, tax_plot_color, tax_plot_symbol)
bysort tax_plot_group (group): assert tax_plot_label == tax_plot_label[1] & ///
    tax_plot_color == tax_plot_color[1] & tax_plot_symbol == tax_plot_symbol[1]
forvalues style = 1/10 {
    quietly count if tax_plot_group == `style'
    assert r(N) > 0
    local style_row 1
    while tax_plot_group[`style_row'] != `style' {
        local ++style_row
    }
    local color`style' = tax_plot_color[`style_row']
    local symbol`style' = tax_plot_symbol[`style_row']
}
generate str8 classification = "sections"
save `plot_groups'
use "${DATADIR}/Analysis/CMR_BDF_cleaned.dta", clear
isid firmid fin_yr
sort firmid fin_yr
unab original_vars : _all
save `cleaned'
use "${DATADIR}/Analysis/CMR_BDF_isic4_sections_assessment.dta", clear
isid firmid fin_yr
sort firmid fin_yr
cf `original_vars' using `cleaned'
assert inrange(fin_yr, 2015, 2022)
assert !missing(nacam_label_short_display, isic4_section, isic4_section_label)
generate double employment = totemp if totemp >= 0
generate double revenue = tot_rev if tot_rev >= 0
save `panel'

foreach classification in slides sections {
    use `panel', clear
    if "`classification'" == "slides" {
        generate str8 group = string(nacam, "%03.0f")
        generate str100 group_label = nacam_label_short_display
        generate byte exception = 0
    }
    else {
        generate str8 group = isic4_section
        generate str100 group_label = isic4_section + " " + isic4_section_label
        generate byte qualified_record = section_status != "single_section"
        bysort group: egen byte exception = max(qualified_record)
        drop qualified_record
        replace group_label = isic4_section + "* " + isic4_section_label if exception
        replace group_label = "M+N* Professional and business services" if group == "M+N"
    }
    sort group fin_yr firmid
    collapse (sum) annual_total_employment=employment annual_total_revenue=revenue ///
        (mean) annual_mean_employment=employment annual_mean_revenue=revenue, ///
        by(group group_label exception fin_yr)
    isid group fin_yr
    collapse (mean) total_employment=annual_total_employment total_revenue=annual_total_revenue ///
        mean_employment=annual_mean_employment mean_revenue=annual_mean_revenue ///
        (count) contributing_years=fin_yr, by(group group_label exception)
    * Equal year coverage makes total-preservation checks directly comparable.
    assert contributing_years == 8
    if "`classification'" == "slides" assert _N == 37
    else assert _N == 16
    foreach measure in employment revenue {
        quietly summarize total_`measure', meanonly
        if "`classification'" == "slides" local original_`measure' = r(sum)
        else assert reldif(r(sum), `original_`measure'') < 1e-12
        foreach statistic in total mean {
            assert `statistic'_`measure' > 0 & !missing(`statistic'_`measure')
            generate double log_`statistic'_`measure' = ln(`statistic'_`measure')
        }
    }
    generate str8 classification = "`classification'"
    if "`classification'" == "slides" save `results'
    else {
        append using `results'
        sort classification group
        save `results', replace
    }
}
merge 1:1 classification group using `plot_groups'
assert _merge == 3 if classification == "sections"
assert _merge == 1 if classification == "slides"
drop _merge
sort classification group
save `results', replace
export delimited using "${OUTPUTDIR}/checks/tax_isic4_sections/slide_comparison.csv", replace

* Each row of the comparison has identical axes; groups are ranked separately.
foreach measure in employment revenue {
    foreach statistic in total mean {
        use `results', clear
        quietly summarize log_`statistic'_`measure', meanonly
        local lower = floor(r(min))
        local upper = ceil(r(max))
        local axis "Log average annual total `measure'"
        if "`statistic'" == "mean" local axis "Log average firm `measure'"
        foreach classification in slides sections {
            use `results', clear
            keep if classification == "`classification'"
            gsort -log_`statistic'_`measure' group
            generate int rank = _n
            local n = _N
            capture label drop comparison_labels
            forvalues i = 1/`n' {
                local text = group_label[`i']
                label define comparison_labels `i' `"`text'"', add
            }
            label values rank comparison_labels
            local title "Slides: 37 NACAM branches"
            local color "95 105 115"
            if "`classification'" == "sections" {
                local title "New: 16 section-based tax groups"
                local color "0 130 125"
            }
            local dots `"(scatter rank log_`statistic'_`measure', mcolor("`color'") msymbol(O) msize(small))"'
            if "`classification'" == "sections" {
                local dots
                forvalues style = 1/10 {
                    local dots `"`dots' (scatter rank log_`statistic'_`measure' if tax_plot_group == `style', mcolor("`color`style''") msymbol(`symbol`style'') msize(small))"'
                }
            }
            twoway `dots', ///
                ylabel(1(1)`n', valuelabel angle(horizontal) labsize(tiny) noticks) ///
                yscale(reverse) ytitle("") ///
                xlabel(`lower'(1)`upper', labsize(vsmall) grid glcolor(gs14)) ///
                xscale(range(`lower' `upper')) xtitle("`axis'", size(vsmall)) ///
                title("`title'", size(small)) legend(off) ///
                graphregion(color(white)) plotregion(color(white)) ///
                xsize(8) ysize(9) ///
                name(`classification'_`statistic', replace)
        }
    }
    local heading "Employment"
    if "`measure'" == "revenue" local heading "Revenue"
    * Match the original slide style without changing any estimates or shares.
    * Font tags keep this independent of a user's permanent graph-font settings.
    foreach statistic in total mean {
        use `results', clear
        keep if classification == "sections"
        generate str80 short_label = ""
        replace short_label = "Agriculture & forestry" if group == "A"
        replace short_label = "Mining & quarrying" if group == "B"
        replace short_label = "Manufacturing" if group == "C"
        replace short_label = "Electricity & gas" if group == "D"
        replace short_label = "Water & waste" if group == "E"
        replace short_label = "Construction" if group == "F"
        replace short_label = "Wholesale/retail" if group == "G"
        replace short_label = "Transport & storage" if group == "H"
        replace short_label = "Accommodation/food services" if group == "I"
        replace short_label = "Information & communication" if group == "J"
        replace short_label = "Finance & insurance" if group == "K"
        replace short_label = "Real estate" if group == "L"
        replace short_label = "Professional/business services*" if group == "M+N"
        replace short_label = "Education" if group == "P"
        replace short_label = "Health & social work" if group == "Q"
        replace short_label = "Arts/other services/households*" if group == "R+S+T"
        replace short_label = short_label + "*" if inlist(group, "A", "B", "C", "D", "L")
        assert !missing(short_label)
        gsort -log_`statistic'_`measure' group
        generate int rank = _n
        capture label drop slide_style_labels
        forvalues i = 1/`=_N' {
            local text = short_label[`i']
            label define slide_style_labels `i' `"{stSans:`text'}"', add
        }
        label values rank slide_style_labels
        local title "Aggregate sector total"
        local axis "Log average annual total `measure'"
        if "`statistic'" == "mean" {
            local title "Sector firm average"
            local axis "Log average firm `measure'"
        }
        quietly summarize log_`statistic'_`measure', meanonly
        local lower = floor(r(min))
        local upper = ceil(r(max))
        local ticks
        forvalues tick = `lower'/`upper' {
            local ticks `"`ticks' `tick' "{stSans:`tick'}""'
        }
        local dots
        forvalues style = 1/10 {
            local dots `"`dots' (scatter rank log_`statistic'_`measure' if tax_plot_group == `style', mcolor("`color`style''") msymbol(`symbol`style'') msize(medlarge))"'
        }
        twoway `dots', ///
            ylabel(1(1)16, valuelabel angle(horizontal) labsize(vsmall) noticks ///
                grid glpattern(dash) glcolor(gs15) glwidth(vthin)) ///
            yscale(reverse lwidth(vthin)) ytitle("") ///
            xlabel(`ticks', grid glpattern(dash) glcolor(gs13) glwidth(vthin) labsize(small)) ///
            xscale(lwidth(vthin)) xtitle("{stSans:`axis'}", size(small)) ///
            title("{stSans:`title'}", size(small) color(black)) legend(off) ///
            scheme(s2color) plotregion(color(white)) graphregion(color(white)) bgcolor(white) ///
            ysize(6.2) xsize(5.2) name(styled_`statistic', replace)
    }
    graph combine styled_total styled_mean, cols(2) ///
        title("{stSans:Ecofin log `measure' by ISIC Rev.4 tax group}", size(medsmall) color(black)) ///
        note("{stSans:* Analytical groups: 005/006 to B; 009 to A (including cocoa/coffee/tea/sugar processing); 021 to C; 029 to D; 037 to L.}" ///
             "{stSans:M+N and R+S+T combine sections (T:97 only); 005 in B has B/C/H boundaries. NACAM Rev.1, 2015-2022.}", ///
             size(tiny) span) plotregion(color(white)) graphregion(color(white)) ///
        scheme(s2color) xsize(11.5) ysize(6.2) name(new_`measure', replace)
    graph export "${OUTPUTDIR}/figures/cmr_tax_sections_new_`measure'.png", width(2400) replace
    graph export "${OUTPUTDIR}/figures/cmr_tax_sections_new_`measure'.pdf", replace
    foreach statistic in total mean {
    local description "Average annual sector totals"
    if "`statistic'" == "mean" local description "Average firm size within sector"
    graph combine slides_`statistic' sections_`statistic', cols(2) ///
        title("`heading': slides versus new tax grouping", size(medsmall)) ///
        subtitle("`description' | same cleaned firm-years, 2015-2022", size(small)) ///
        note("Slide statistics recreated on common axes. Yearly totals or firm means averaged equally across years. Natural logs." ///
             "Left retains the slide labels, including the superseded NACAM interpretation. Right uses Rev.1." ///
             "Colors/symbols retain the original broad-sector scheme. Asterisks mark analytical groupings/combinations; 005 in B has B/C/H boundaries." ///
             "Analytical assignments: 005/006 to B; 009 to A (including processing); 021 to C; 029 to D; 037 to L. T covers 97 only." ///
             "Missing and negative values excluded separately by measure. Ranks differ across panels; rows do not align.", ///
             size(vsmall) span) graphregion(color(white) margin(l=3 r=3)) ///
        xsize(16) ysize(11) iscale(.65) name(comparison_`measure', replace)
    local suffix
    if "`statistic'" == "mean" local suffix "_firm_average"
    graph export "${OUTPUTDIR}/figures/cmr_tax_sections_vs_slides_`measure'`suffix'.png", width(3000) replace
    graph export "${OUTPUTDIR}/figures/cmr_tax_sections_vs_slides_`measure'`suffix'.pdf", replace
    }
}
display as result "TAX SLIDE COMPARISON CHECKS PASSED"
log close sectioncomparison
