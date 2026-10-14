# Shared broad display groups for ISIC Rev.4

Use these ten project labels, colors and Stata symbols for any dataset with a
reviewed ISIC Rev.4 code. They provide consistent figure styling while preserving
the analysis at its existing section, division, group or class level. This is a
project display scheme, not an additional official ISIC classification level.

| Broad label | ISIC Rev.4 sections | RGB color | Stata symbol |
|---|---|---|---|
| Agriculture | A | 27 158 119 | circle |
| Mining | B | 117 112 179 | diamond |
| Manufacturing | C | 44 123 182 | square |
| Utilities | D, E | 230 171 2 | triangle |
| Construction | F | 208 28 139 | Oh |
| Trade | G | 217 95 2 | Th |
| Transport | H | 102 166 30 | Sh |
| Information | J | 102 166 30 | plus |
| Finance | K | 117 112 179 | x |
| Other services | I, L, M, N, O, P, Q, R, S, T, U | 102 102 102 | Dh |

The labels are deliberately short: Agriculture includes forestry and fishing;
Trade includes vehicle repair; Information includes communication; Finance
includes insurance. Other services includes accommodation/food, real estate,
professional and administrative services, public administration, education,
health, arts, other services, households and extraterritorial organizations.
Utilities includes electricity/gas and water/waste. These labels do not change
the official activity boundaries.

## Files and reproduction

- `docs/reference/isic4_broad_groups.csv`: editable section-to-display mapping,
  covering all 21 official sections, including sections absent from the tax data.
- `docs/reference/isic_rev4_english_structure.csv`: the official UN hierarchy;
  see its adjacent source note for provenance.
- `code/02_construct/01_isic4_broad_groups.do`: validates the mapping and extends
  it to all 21 sections, 88 divisions, 238 groups and 419 classes.
- `Data/Intermediate/isic4_broad_groups_sections.dta`: unique key `isic4_section`.
- `Data/Intermediate/isic4_broad_groups_codes.dta`: unique text key `isic4_code`,
  with `isic4_level`, official labels, section and shared display fields.

From the project root:

```stata
do "code/02_construct/01_isic4_broad_groups.do"
do "code/05_checks/06_isic4_broad_groups_checks.do"
```

The shared variables are `broad_sector`, `broad_sector_label`, `plot_color` and
`plot_symbol`. Keep code widths and leading zeros: `01`, `011` and `0111` are
different levels. Numeric division codes must first be formatted to two digits;
numeric class codes must be formatted to four digits. Do not guess the level
from a numeric value or treat missing codes as Other services.

For an existing text `isic4_code`, merge the shared fields without changing the
original classification:

```stata
merge m:1 isic4_code using "Data/Intermediate/isic4_broad_groups_codes.dta", ///
    keep(master match) keepusing(broad_sector broad_sector_label plot_color plot_symbol)
tabulate _merge, missing
* Inspect unmatched observations; retain them with missing display fields.
drop _merge
```

For section-level data, use the section file and key instead. The merge example
retains every original observation, including missing or unsupported codes.

## Tax combinations and current use

The tax comparison script `24_cmr_tax_section_comparison.do` now builds and reads
this shared mapping. It checks every component of M+N and R+S+T: both combinations
receive Other services because all their component sections share that label.
A future combination spanning different broad sectors must be reviewed; the
script fails rather than assigning it the first component's style.

The tax output retains `tax_plot_*` compatibility names. The tax-only style CSV
has been replaced by the general mapping. The 16 tax analysis groups and their
qualifications, including analytical assignment of 005 to B, remain unchanged.
The broad Trade label replaces the longer Wholesale/retail + repair wording;
its color and symbol are unchanged.

This change makes the mapping available to census and WBES workflows. Their
existing datasets, estimates and figures have not been regenerated or restyled.
Apply the shared labels using their reviewed Rev.4 codes when updating those
figures; do not use the superseded NACAM display mapping as an ISIC crosswalk.
