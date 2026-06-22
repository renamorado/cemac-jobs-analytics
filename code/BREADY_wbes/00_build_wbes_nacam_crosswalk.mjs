import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputPath = "docs/reference/cmr_wbes_isic4_nacam_crosswalk.xlsx";

// Observed main-product ISIC Rev. 4 codes in the Cameroon 2024 latest-wave
// WBES sample. Counts are included so changes in the source extract are visible.
const observed = new Map(`
1040 2
1050 1
1061 1
1062 2
1071 30
1074 3
1079 8
1080 2
1102 1
1104 1
1399 2
1410 9
1520 2
1610 6
1621 4
1622 2
1629 3
1701 2
1702 1
1709 2
1811 10
1812 6
1920 1
2022 3
2023 9
2029 1
2100 1
2220 4
2310 1
2394 1
2395 4
2399 1
2511 3
2512 1
2599 7
2732 1
2790 1
2819 1
2825 1
2829 1
2930 1
3100 10
3250 2
3290 3
3320 3
4100 26
4210 4
4220 6
4290 7
4321 10
4330 3
4390 4
4520 14
4530 10
4540 2
4610 1
4620 2
4630 41
4641 2
4649 7
4651 1
4652 3
4659 3
4661 2
4662 1
4663 14
4690 5
4711 10
4719 4
4721 21
4722 11
4730 3
4741 6
4752 17
4759 11
4761 3
4771 12
4772 22
4773 5
4782 1
4921 13
4922 1
4923 14
5012 3
5210 1
5224 1
5229 8
5320 1
5510 36
5610 27
5621 3
6110 1
6120 1
6130 1
6190 3
6201 2
6202 3
6209 2
6910 1
6920 5
7020 3
7110 6
7320 2
7410 2
7490 4
7911 4
7912 1
9511 3
9512 2
9521 1
9522 4
9529 1
`.trim().split("\n").map((line) => {
  const [code, count] = line.trim().split(/\s+/).map(Number);
  return [code, count];
}));

const nacamLabels = new Map([
  [9, "Grains & starch"], [11, "Oilseeds & feed"],
  [12, "Cereal products"], [13, "Dairy/fruit/other food"],
  [16, "Textiles & apparel"], [17, "Leather & footwear"],
  [18, "Wood products"], [19, "Paper, print & pub."],
  [20, "Petroleum refining"], [21, "Chemicals & pharma"],
  [22, "Rubber & plastics"], [23, "Non-metallic minerals"],
  [24, "Metals & metal products"], [27, "Transport equipment"],
  [28, "Furniture & other mfg."], [30, "Construction"],
  [31, "Wholesale/retail"], [32, "Repairs"],
  [33, "Accommodation/food services"], [34, "Transport & storage"],
  [35, "Post/telecommunications"], [38, "Services mainly to enterprises"],
]);

const groups = [
  [11, [1040, 1080]], [13, [1050]], [9, [1061, 1062]],
  [12, [1071, 1074]], [16, [1399, 1410]], [17, [1520]],
  [18, [1610, 1621, 1622, 1629]], [19, [1701, 1702, 1709, 1811, 1812]],
  [20, [1920]], [21, [2022, 2023, 2029, 2100]], [22, [2220]],
  [23, [2310, 2394, 2395, 2399]], [24, [2511, 2512, 2599]],
  [27, [2930]], [28, [3100, 3250, 3290]],
  [30, [4100, 4210, 4220, 4290, 4321, 4330, 4390]],
  [32, [4520, 9511, 9512, 9521, 9522, 9529]],
  [31, [4530, 4610, 4620, 4630, 4641, 4649, 4651, 4652, 4659,
    4661, 4662, 4663, 4690, 4711, 4719, 4721, 4722, 4730, 4741,
    4752, 4759, 4761, 4771, 4772, 4773, 4782]],
  [34, [4921, 4922, 4923, 5012, 5210, 5224, 5229]],
  [35, [5320, 6110, 6120, 6130, 6190]],
  [33, [5510, 5610, 5621]],
  [38, [6201, 6202, 6209, 6910, 6920, 7020, 7110, 7320, 7410,
    7490, 7911, 7912]],
];

const mapping = new Map();
for (const [nacam, codes] of groups) {
  for (const code of codes) mapping.set(code, nacam);
}

const reviewNotes = new Map([
  [1079, "ISIC 1079 spans multiple legacy food-processing branches in the source bridge."],
  [1102, "Beverage manufacturing is outside the current administrative elasticity-sector support."],
  [1104, "Beverage manufacturing is outside the current administrative elasticity-sector support."],
  [2732, "Electrical equipment maps to a Census-only machinery branch absent from the elasticity ranking."],
  [2790, "Electrical equipment maps to a Census-only machinery branch absent from the elasticity ranking."],
  [2819, "Machinery maps to a Census-only branch absent from the elasticity ranking."],
  [2825, "Machinery maps to a Census-only branch absent from the elasticity ranking."],
  [2829, "Machinery maps to a Census-only branch absent from the elasticity ranking."],
  [3320, "Installation of machinery cannot be assigned uniquely between manufacturing and repair branches."],
  [4540, "Motorcycle sales and repair cannot be separated at the available four-digit code."],
]);

const rows = [...observed.entries()].sort((a, b) => a[0] - b[0]).map(([code, firms]) => {
  const nacam = mapping.get(code) ?? null;
  const mapped = nacam !== null;
  return [
    code,
    firms,
    nacam,
    mapped ? nacamLabels.get(nacam) : "",
    mapped ? "unique_source_backed" : "review_excluded",
    mapped ? 0 : 1,
    "INS Cameroon NACAM Rev.1/CITI Rev.4 bridge; reviewed against Census crosswalk",
    mapped
      ? "Unique mapping at the observed four-digit ISIC level."
      : reviewNotes.get(code),
  ];
});

if (rows.length !== 112) throw new Error(`Expected 112 observed codes; found ${rows.length}.`);
if (rows.reduce((sum, row) => sum + row[1], 0) !== 615) {
  throw new Error("Observed-firm counts do not sum to the 615-firm Cameroon sample.");
}

const workbook = Workbook.create();
const sheet = workbook.worksheets.add("isic4_nacam_crosswalk");
sheet.showGridLines = false;

sheet.getRange("A1:H1").merge();
sheet.getRange("A1").values = [["Cameroon WBES 4-digit ISIC Rev. 4 to NACAM crosswalk"]];
sheet.getRange("A2:H2").merge();
sheet.getRange("A2").values = [[
  "Primary analysis keeps only unique source-backed mappings; review-excluded codes remain visible for audit."
]];
sheet.getRange("A4:H4").values = [[
  "isic4_code", "cameroon_firms", "nacam", "nacam_label_short_display",
  "mapping_status", "review_flag", "mapping_source", "mapping_note"
]];
sheet.getRange(`A5:H${rows.length + 4}`).values = rows;

sheet.getRange("A1:H1").format = {
  fill: "#1F4E78", font: { bold: true, color: "#FFFFFF", size: 16 },
  horizontalAlignment: "center", verticalAlignment: "center",
};
sheet.getRange("A2:H2").format = {
  fill: "#D9EAF7", font: { color: "#1F2937", italic: true },
  wrapText: true, horizontalAlignment: "left",
};
sheet.getRange("A4:H4").format = {
  fill: "#5B9BD5", font: { bold: true, color: "#FFFFFF" },
  wrapText: true, horizontalAlignment: "center",
  borders: { preset: "all", style: "thin", color: "#D9E2F3" },
};
sheet.getRange(`A5:H${rows.length + 4}`).format = {
  borders: { preset: "all", style: "thin", color: "#E5E7EB" },
  verticalAlignment: "top",
};
sheet.getRange(`D5:H${rows.length + 4}`).format.wrapText = true;
sheet.getRange(`A5:C${rows.length + 4}`).format.numberFormat = "0";
sheet.getRange("A:A").format.columnWidth = 12;
sheet.getRange("B:B").format.columnWidth = 16;
sheet.getRange("C:C").format.columnWidth = 10;
sheet.getRange("D:D").format.columnWidth = 28;
sheet.getRange("E:F").format.columnWidth = 20;
sheet.getRange("G:G").format.columnWidth = 42;
sheet.getRange("H:H").format.columnWidth = 55;
sheet.getRange("1:1").format.rowHeight = 28;
sheet.getRange("2:2").format.rowHeight = 34;
sheet.freezePanes.freezeRows(4);
sheet.tables.add(`A4:H${rows.length + 4}`, true, "WbesNacamCrosswalk");

sheet.getRange(`F5:F${rows.length + 4}`).conditionalFormats.add("cellIs", {
  operator: "equal", formula: 1,
  format: { fill: "#FDE9E7", font: { color: "#9C0006", bold: true } },
});

const checks = workbook.worksheets.add("checks");
checks.showGridLines = false;
checks.getRange("A1:D1").merge();
checks.getRange("A1").values = [["Crosswalk checks"]];
checks.getRange("A3:B7").values = [
  ["Check", "Value"],
  ["Observed four-digit codes", rows.length],
  ["Cameroon firms", rows.reduce((sum, row) => sum + row[1], 0)],
  ["Mapped codes", rows.filter((row) => row[5] === 0).length],
  ["Review-excluded codes", rows.filter((row) => row[5] === 1).length],
];
checks.getRange("A1:D1").format = {
  fill: "#1F4E78", font: { bold: true, color: "#FFFFFF", size: 15 },
  horizontalAlignment: "center",
};
checks.getRange("A3:B3").format = {
  fill: "#5B9BD5", font: { bold: true, color: "#FFFFFF" },
};
checks.getRange("A3:B7").format.borders = {
  preset: "all", style: "thin", color: "#D9E2F3",
};
checks.getRange("A:A").format.columnWidth = 30;
checks.getRange("B:B").format.columnWidth = 18;

await fs.mkdir("docs/reference", { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
console.log(`Wrote ${outputPath}`);
