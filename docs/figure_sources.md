# Figure Sources

Date: 2026-06-03

This note records the short source notes used in the current CEMAC slide deck
and the fuller reference text behind them. Source notes are added in the
Beamer/LaTeX layer, not embedded in Stata graph exports, so the same generated
figure files can be reused in manuscripts, slides, and drafts with different
caption conventions.

## Short Figure Notes

- Census figures: `Source: INS Cameroon, RGE3 (2023-2024); calculations by authors.`
- Cameroon administrative elasticity figures: `Source: Cameroon administrative tax/BDF panel; calculations by authors.`
- Census and administrative comparison figures: `Sources: INS Cameroon, RGE3 (2023-2024), and Cameroon administrative tax/BDF panel; calculations by authors.`
- WBES figures: `Source: World Bank Enterprise Surveys, latest available CEMAC waves; calculations by authors.`

## References

Institut National de la Statistique du Cameroun. (2025). *Rapport final des
resultats de la cartographie et de denombrement du RGE3* [Institutional
report]. https://ins-cameroun.cm/statistique/rapport-final-des-resultats-de-la-carthographie-et-de-denombrement-du-rge3/

Cameroon administrative tax/BDF panel. (n.d.). *Cameroon administrative
tax/BDF firm-year panel* [Unpublished raw data set].

World Bank Enterprise Surveys. (n.d.). *Enterprise Surveys: Latest available
CEMAC formal-sector firm surveys* [Data set]. World Bank Group.
https://www.enterprisesurveys.org/en/survey-datasets

World Bank Enterprise Surveys. (n.d.). *Enterprise Surveys methodology*
[Methodology documentation]. World Bank Group.
https://www.enterprisesurveys.org/en/methodology

## Notes

- The Census note uses RGE3 because the source workbook and INS publication
  describe the third enterprise census collected in 2023-2024.
- The administrative panel note intentionally does not name a responsible
  institution until the project confirms the precise source institution.
- The Census/admin comparison note is used only for figures that place RGE3
  cross-sectional estimates and administrative tax/BDF panel estimates on the
  same plot.
- The WBES note refers to the latest available CEMAC waves because the current
  Stata prep stage constructs a latest-wave cross-section and excludes Gabon
  from the main descriptive panels for documented coverage reasons.
- The active Beamer source defines the short notes in `slides/slides_cemac.tex`.
  Stata figure exports should remain source-note-free unless a later output
  format requires standalone figures with embedded captions.
