# WBES Trade Variables and Representativeness

Date: 2026-05-22

## Main Recommendation

Use the World Bank Enterprise Surveys (WBES) trade variables for weighted, firm-level descriptive comparisons and exploratory cross-sectional employment/trade associations. Do not interpret them as country-level trade totals, sector-level national accounts, or panel-style employment elasticities.

For the current CEMAC deck, the most defensible empirical framing is:

- report all WBES trade statistics with WBES sampling weights and unweighted firm counts;
- keep the country as the primary level of comparison;
- suppress small cells before showing sector or activity-group results;
- estimate exporter-only intensive-margin models separately from all-firm models;
- in all-firm models, include an exporter dummy so the log export-value slope is not forced to absorb the extensive-margin exporter/non-exporter difference.

## What WBES Represents

WBES is designed to represent the formal private sector covered by each country survey frame, not all economic activity in a country. The Enterprise Surveys methodology describes a stratified random sample of establishments, commonly stratified by sector, firm size, and location, with sampling weights used to recover frame-representative estimates. This makes the data well suited for questions such as "what share of covered firms export?" or "how do exporters and non-exporters differ among surveyed formal firms?"

The same design means WBES should not be treated as a direct source for national export totals or complete sector trade accounts. The survey frame excludes parts of the economy, especially informal activity and sectors outside the survey universe. For Cameroon/CEMAC, this is especially important because current slides compare WBES results to administrative and census evidence that have different coverage.

Official WBES documentation and indicators define export measures from firm responses on domestic sales, indirect exports, and direct exports as shares of sales. The current prep stage therefore uses:

- `d3a`: domestic sales share;
- `d3b`: indirect export share;
- `d3c`: direct export share;
- `export_share = d3b + d3c`;
- `export_value = winsorized sales * export_share`.

This is appropriate for within-survey analysis, but it inherits measurement error from reported sales and reported export shares.

## All Firms vs Exporters Only

The all-firm and exporter-only samples answer different questions.

Use all firms when the question is about the employment profile of exporters relative to non-exporters. The preferred all-firm specification is:

```text
ln(employment_i) = alpha + beta ln(export_value_i^+) + gamma exporter_i + controls_i + e_i
```

where `ln(export_value_i^+)` is set to zero for non-exporters and `exporter_i` captures the extensive-margin difference between exporters and non-exporters. This keeps the export-value slope closer to an intensive-margin association among positive exporters, while still retaining non-exporting firms for comparison.

Use exporters only when the question is whether larger export values among exporters are associated with higher employment:

```text
ln(employment_i) = alpha + beta ln(export_value_i) + controls_i + e_i,
export_value_i > 0
```

This is cleaner as an intensive-margin elasticity, but it no longer describes the full covered firm population. The exporter-only sample also becomes thin quickly for small CEMAC countries and activity groups.

## Country vs Sector-Level Elasticities

Country-level estimates are more defensible than sector-level estimates for the current WBES branch. The latest-wave CEMAC file is cross-sectional, and exporter counts are small in several countries. Sector/activity-group estimates should be treated as diagnostics and only shown when unweighted cell counts pass a minimum threshold.

For the current deck:

- country-level estimates can be shown for retained CEMAC countries and equal-country benchmark averages;
- Cameroon activity-group estimates can be shown as an exploratory diagnostic;
- pooled CEMAC sector-level elasticities should be avoided unless a later pass documents adequate cell counts and a clear pooling design.

## Literature Signals

Exporting firms are often larger and more productive than non-exporters, but the firm-level trade literature generally treats this as a mix of selection into exporting and possible learning-by-exporting. That distinction matters for the deck: a WBES cross-sectional association between employment and export value should be presented as a descriptive association, not as a causal employment multiplier.

Relevant references:

- World Bank Enterprise Surveys, [Methodology](https://www.enterprisesurveys.org/en/Methodology/): official documentation on survey universe, stratified sampling, and weights.
- World Bank Enterprise Surveys, [Indicator Description](https://www.enterprisesurveys.org/content/dam/enterprisesurveys/documents/methodology/Indicator-Description.pdf): documentation for direct and indirect exports as shares of sales.
- Bernard, Jensen, Redding, and Schott (2007), [Firms in International Trade](https://www.nber.org/papers/w13054), which summarizes the exporter premia and selection/causality issues in firm-level trade analysis.
- Brambilla, Lederman, and Porto (2012), [Exports, Export Destinations, and Skills](https://econpapers.repec.org/RePEc:nbr:nberwo:15995), which shows how export destinations and export intensity relate to employment composition using firm-level data.
- Fernandes, Freund, and Pierola (2016), [Exporter Behavior, Country Size and Stage of Development](https://econpapers.repec.org/RePEc:wbk:wbrwps:7452), which emphasizes firm-level export heterogeneity across countries.

## Implementation Implication for This Repository

The WBES elasticity stage should remain separate from the Cameroon administrative panel elasticity stage. It should start from `Data/Analysis/wbes_trade_clean.dta`, use WBES weights, write generated outputs under `output/`, and label results as "WBES cross-sectional associations" in both filenames and slides.
