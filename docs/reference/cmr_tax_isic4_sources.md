# Reviewed legacy tax NACAM to ISIC Rev. 4 decisions

> **Superseded on 2026-09-29: the raw tax numbering is NACAM Rev.1.** The official
> ECOFIN methodology and matching branch-count/employment profiles establish the
> revision. This legacy-based CSV and its 27-unresolved result must not be used
> for tax analysis. Use `cmr_tax_nacam_rev1_isic4_decisions.csv` instead. See
> [the evidence](../cmr_tax_ecofin2019_comparison.md). The historical definitions
> below remain an audit record, not current instructions for interpreting tax codes.

Historical review dated 2026-09-28. The CSV interpreted the 37 tax codes as legacy branches and returned **10 unique**, **26 ambiguous**, and **1 insufficient_information**. That source-revision interpretation was incorrect; these counts do not describe current tax mapping coverage. The old-definition review is retained for audit only. No firm was assigned an industry from its name, and no possible-division list supplies allocation weights.

## Sources and page numbering

All sources below are official publications. References in the CSV use printed page numbers. The saved text uses one-based PDF page numbers. RGE printed page 13 is PDF page 14; NACAM Rev1 printed page 9 is PDF page 10; UN ISIC4 printed page 74 is PDF page 89. Class and branch identifiers in the CSV are the most precise locators when a page spans several entries.

| Source ID in CSV | Publication and official URL | Local file | Retrieval/verification |
|---|---|---|---|
| INS RGE2009 Nomenclatures | INS, *Recensement General des Entreprises: document de nomenclatures*, cover dated July 2009 (cover calls the operation RGE 2008; catalogue labels it RGE2009). [Official PDF](https://nada.stat.cm/index.php/catalog/16/download/101); [INS catalogue](https://www.stat.cm/nada/index.php/catalog/16). Activity definitions, printed pp.13-34. | `tax_isic4/rge2009_nomenclatures.pdf` | Downloaded 2026-09-28; 71 PDF pages. |
| INS NACAM Rev1 Table III.2 | INS, *Nomenclature des activites et des produits du Cameroun*, NACAM/NPC Rev1, September 2013. [Official PDF](https://ins-cameroun.cm/wp-content/uploads/2025/06/NOMENCLATURE_DES-ACTIVITES-AU-CAMEROUN.pdf). Table III.1 pp.8; Table III.2 pp.9-15, including the **NACAM Ancien** column. | `nacam-rev1-ins-cameroon.pdf` | Existing local file re-downloaded in memory and confirmed byte-for-byte identical to the official URL on 2026-09-28; original local acquisition date not assumed. 150 PDF pages. |
| UN ISIC4 | UN Statistics Division, *International Standard Industrial Classification of All Economic Activities, Revision 4*, Statistical Papers Series M No.4/Rev.4, 2008. [Official PDF](https://unstats.un.org/unsd/publication/seriesm/seriesm_4rev4e.pdf). Detailed structure and explanatory notes. | `tax_isic4/isic_rev4_un.pdf` | Downloaded 2026-09-28; 306 PDF pages. |
| UN division labels | [Official English structure](https://unstats.un.org/unsd/classifications/Econ/Download/In%20Text/ISIC_Rev_4_english_structure.Txt); see `isic_rev4_english_structure_source.md` for the existing snapshot provenance. | `isic_rev4_english_structure.csv` | Used to validate all possible divisions and copy the exact English labels for unique assignments. |

SHA-256 of source PDFs:

- RGE2009: `d3e49d2f22d78bfa4ecf1cee3c4802307290a1587793504eda06e32a5cc88702`
- NACAM Rev1: `16c558dd84c6f329c634d76cc98436c8231415f497dfea3d7407c1356a491031`
- UN ISIC4: `d7f1c2b12e17fece32b588ee2d67beddf21d8eef28f085ef95ceb72081845968`

The accompanying `.txt` files were extracted with pdfplumber from embedded PDF text; no OCR was used. Page markers were added. Extraction preserves wording for searching but does not preserve table alignment; consult the PDFs for columns. In particular, old branch numbers must be read from **NACAM Ancien**, not inferred from the new branch heading. RGE bullet characters extract as `(cid:132)` in places; this does not affect the activity text.

## Decision rules

- A `unique` assignment requires the reviewed old branch's specified activities to remain within one ISIC Rev.4 division. Ten old branches meet that standard: **2, 3, 5, 9, 12, 13, 15, 18, 23, 40**.
- `ambiguous` means the source definition spans divisions, or an explicit conflict between the old definition, correspondence table and ISIC prevents selecting one. The listed divisions are supported possibilities under the documented interpretations; they do not imply that every activity is present in the tax data.
- `insufficient_information` is used for old branch **8** because the phrase concerning worked hides/skins does not establish whether the activity is only a slaughterhouse by-product or includes tanning/dressing. The possible list **10 15** records that uncertainty without claiming an observed split.
- ISIC classifies establishments by principal activity. A by-product or incidental process does not automatically change a firm's classification. These decisions only ask whether the **branch definition alone** is enough to assign every possible member. Finer evidence could restore individual records to division 10 or another appropriate division.
- Broad `n.c.a.` wording is not treated as permission to add every conceivable activity. Explicit inclusions, exclusions and documented correspondence conflicts drive the lists. The lists remain reviewable, not an exhaustive guarantee for unrecorded or miscoded activities.
- `nacam_original_label` records the official legacy branch name (accents normalized in this CSV); it does not overwrite labels in the original dataset. Leading zeros are preserved in ISIC strings, while `nacam` remains the numeric tax key.

## Changes from the preliminary assignments

Seven previously unique branches now remain unassigned. No previously ambiguous branch became unique.

| Legacy branch | Previous division | Reviewed result | Reason requiring detail |
|---|---|---|---|
| 1 | 01 | 01 / 02 | Legacy 0104 includes wild gathering as well as crop growing. |
| 8 | 10 | Insufficient information: 10 / 15 | Worked-hide wording needs clarification; slaughterhouse by-products alone remain 10. |
| 10 | 10 | 01 / 10 / 21 / 82 | Coffee primary preparation, pharmaceutical confectionery and packaging-only tea services cannot be ruled out from the old definition. These are conditional interpretations, not observed firm activities. |
| 11 | 10 | 10 / 11 / 20 | Explicit chemical modification of oils and brewery/distillery residues require process/principal-activity detail. |
| 17 | 15 | 15 / 16 / 22 / 32 | Old footwear includes parts and all uses/materials; ISIC separates non-leather parts and ski boots. Orthopaedic shoes are expressly excluded by the old definition. |
| 20 | 19 | 19 / 20 / 24 | The full legacy title and 2000 definition include nuclear-material processing. |
| 37 | 68 | 41 / 42 / 68 | Property development can be construction for sale or land improvement; the old code does not distinguish it from rental/agency work. |

Other substantive corrections in the possible-division lists:

- Old **16** includes cotton ginning (01); old **19** includes publishing and sound publishing (58/59); old **21** includes blank recording media (26) and dental compositions (32); old **27** includes ship/aircraft repair (33); old **28** includes transport seats and recycling; old **29** explicitly includes compressed air manufacture (20).
- Old **34** includes travel agencies (79), and excludes courier work. Postal activity enters *new* branch 034 from **old 035**, so 53 is removed from the possible list for old 34. Likewise, 75 is not added to old 38 simply because veterinary services enter new branch 038 from old 041.
- Old **38** explicitly includes advertising (73), security (80) and cleaning (81). Old **42** includes performing arts, libraries/museums, gambling, news agencies and street sweeping, which the preliminary list did not fully represent. Repair division 95 comes into *new* 042 from other old branches, not from old 42 itself.
- Rev1 prints rubber references `0116`/`116`, although UN 0116 is fibre crops and 0129 includes rubber trees. The division 01 possibility is retained, but the printed class is not certified as correct.
- Rev1's old 032002-to-machinery-repair (33) and old 038001-to-travel (79) entries conflict with the narrower RGE explanations. Those divisions remain possible and are explicitly flagged in the corresponding row reasons. Similarly, literal clinker extraction in old 0702 and the third-party meat-packing cross-reference to old 3104 are unresolved source inconsistencies.

The loss of coverage is a consequence of withholding branch-only assignments with unresolved boundary questions; it is not evidence that the affected firms actually changed industry. The accompanying Stata diagnostics calculate how many records and how much employment/revenue these decisions affect. Future detailed assignments should cite activity evidence for the specific firm-year and document any resolution of the source conflicts above.
