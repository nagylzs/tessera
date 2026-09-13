# tessera — project notes for Claude

Pub workspace (not yet published) for analyzing, grouping and aggregating
tabular data: a pivot-table engine plus Flutter widgets. Owner: László
Zsolt Nagy (nagylzs@gmail.com). MIT.

## Repository layout

Pub workspace (root `pubspec.yaml` lists the members; one lock file at
the root, ignored; members carry `resolution: workspace`):

- `packages/tessera` — the engine, **pure Dart** (`environment: sdk`
  only, no Flutter, no deps; `lints` + `test` for dev). Layers 1–3 plus
  `l10n/` (`TesseraStrings`), the pure-Dart renderer helpers
  (`AxisGeometry`, `AggregateKind`) and `export/`: `CubeGrid` (the
  layout as a grid of `GridCell`s — kind, value, summary/leg flags,
  level, merge spans with origin/covered cells that repeat the value)
  and `CsvCubeExporter` (`CsvExportOptions`; `CsvGroupLabels.origin`
  mirrors the sheet, `.repeat` fills groups down for other tools;
  `europeanExcel` preset) and `CubeExportTheme` (+ `ExportFont`,
  `NumberFormat`): the format-neutral look every exporter takes —
  fills, border, fonts per role, decimals/grouping; `brand(primary:)`,
  `gradient`, `mix`; `rowHeaderFills`/`columnHeaderFills` per level,
  `levelBasis` (`combined` = row + column depth, `row`), `fillOf(cell)` /
  `fontOf(cell)` are what exporters call; `hueLevels(levels:)`).
  `color/`: `Oklch` (perceptual colour, ARGB both ways, gamut clipping
  by chroma) and `HueLevels` (levels differ in hue only, golden-angle
  step from a start hue, rows first then columns, header = same hue
  more chroma, light/dark defaults). `GridCell` carries `rowLevel` /
  `columnLevel` besides the summed `level`. Format-specific behaviour
  (frozen panes, widths, native number-format codes, page size) stays
  on each exporter. Every exporter renders from `CubeGrid`, the xlsx one
  included. Tests read `test/data/sales.csv`. `example/main.dart` (+
  `example/sales.csv`) is the CSV → cube → CSV round trip, run by
  `test/example_test.dart` like the other packages' examples.
- `packages/tessera_flutter` — the widgets (layer 4) and
  `TesseraLocalizations` (the Flutter `LocalizationsDelegate` / `of`
  glue). Depends on `tessera` and `two_dimensional_scrollables`;
  `lib/tessera_flutter.dart` re-exports `package:tessera/tessera.dart`
  so apps need one import. Its `example/` is the demo app (a workspace
  member too; pub.dev's Example tab picks it up from here).
- `packages/tessera_xlsx` — pure Dart, depends on `tessera`, `archive`,
  `xml`. Both directions in one package (same OOXML machinery, one
  format = one package): `XlsxDataSource` (streams one worksheet's rows,
  typed cells, `fromData`/`fromBytes`, `XlsxOptions`) and
  `XlsxCubeExporter` (renders a `CubeLayout` from `CubeGrid`,
  the engine's `CubeExportTheme`; `numberFormatCode`, `freezeHeaders`
  and the width bounds are exporter options — `TesseraStrings` labels). Own OOXML
  code on `archive` + `xml`, no third-party spreadsheet layer.
  Reader implemented: `xlsx_workbook.dart` (`XlsxWorkbook.parse`: zip →
  sheets via workbook rels, shared strings incl. rich runs, `cellXfs` →
  date-style flags from built-in ids + `isDateFormat(code)`, `date1904`,
  `dateOf(serial)` with the 1900 gap) and `xlsx_sheet_reader.dart`
  (`readSheetRows`: `parseEvents` over the sheet XML, no DOM; typed
  cells, ints when written integral so inference matches CSV; rows keyed
  by sheet row number so blank title rows count for `skipRows`). The
  whole decompressed sheet XML is in memory (archive has no streaming
  entry read) — known limit. Test data: `test/data/sales.xlsx` is
  `sales.csv` converted by LibreOffice (`soffice --headless --convert-to
  xlsx`); the test compares the two imports value for value. Edge cases
  use mini workbooks built in-test with `ZipEncoder`. `example/main.dart`
  (+ `example/sales.xlsx`, a copy of the test workbook) is the pure-Dart
  round trip — read, infer, cube with regions expanded, export —
  run by `test/example_test.dart` through `dart run`. Exporter implemented:
  `xlsx_writer.dart` (`XlsxWriter`, a minimal package writer — shared
  strings, style registry keyed by (fill, bold, right) with fills 0/1
  reserved and cellXfs 0 the default so indices are offset by one,
  thin borders, one custom numFmt 164, merges, `<cols>`, frozen pane)
  and `_Export` in `xlsx_cube_exporter.dart` mirroring `CubeView`'s
  geometry (`AxisGeometry` areas → merges, a column entry spans
  `aggregates.length` sheet columns, corner titles, cell level = row
  depth + column depth). Tests read the export back with
  `XlsxDataSource`, check merge refs, and round-trip through
  `soffice --convert-to csv` (skipped when soffice is missing; its csv
  filter writes raw values, not formatted ones).
- `packages/tessera_ods` — pure Dart, `tessera` + `archive` + `xml`,
  same shape as tessera_xlsx: `OdsDataSource` (`ods_document.dart`
  unzips and checks the mimetype; `ods_sheet_reader.dart` streams
  `table:table-row`s with `parseEvents` — typed cells from
  `office:value-type`/`value`/`date-value`/`boolean-value`, `text:p`
  paragraphs joined with `\n`, `text:s`/`tab`/`line-break`, annotations
  skipped, `number-columns-repeated` expanded, `number-rows-repeated`
  yielded that many times unless the row is empty — that is how sheets
  pad to 1 M rows; self-closing rows still count for `skipRows`) and
  `OdsCubeExporter` (renders `CubeGrid`: `mimetype` stored first, manifest,
  `content.xml` with automatic styles per (fill, font, align) →
  `ce<n>`, `number:number-style` N1 from `NumberFormat`, column styles
  in cm from the longest text, merges via
  `number-columns/rows-spanned` + `covered-table-cell`, `settings.xml`
  view settings for frozen panes — LibreOffice's documented
  `HorizontalSplitMode=2` layout; unverifiable headless because a
  headless conversion has no view and drops view settings both ways).
  Test data `test/data/sales.ods` = `sales.csv` via `soffice
  --convert-to ods` (LibreOffice's hu locale kept decimals as strings,
  which inference parses like CSV); tests compare with the CSV import,
  hand-build documents with `ZipEncoder`, and round-trip through
  LibreOffice (csv + xlsx for merges). `example/main.dart` mirrors the
  xlsx one.
- `packages/tessera_html` — pure Dart, depends on `tessera` only (the
  owner chose a package over the engine). `HtmlCubeExporter` renders
  `CubeGrid` as a `<table>`: `<thead>` for the header band, `<th>` for
  titles/labels/aggregate names with `scope`, `rowspan`/`colspan` from
  the grid spans (covered cells skipped), classes
  `<prefix>-title/header/leg/aggregate/data/summary/level-N/num` and
  `row-level-N` / `col-level-N` on header cells;
  `HtmlStyling.stylesheet` (a `<style>` from `CubeExportTheme`, sticky
  `thead th`), `.inline` (style attributes, for e-mail) or `.none`;
  `standalone` document or fragment; numbers with the theme's
  decimals/grouping and the locale's separators (`formatNumber`).
  Tests parse the output with `package:xml` (it is well-formed). Example
  on `example/sales.csv`.
- `packages/tessera_svg` — pure Dart, depends on `tessera` only.
  `SvgCubeExporter` draws `CubeGrid` as one image: a `<rect>` per origin
  cell (classes as in html) plus a `<text>`, right-anchored numbers,
  fills/fonts from `fillOf`/`fontOf`, `viewBox` = natural size. Geometry
  from the engine's `GridMetrics` (`export/grid_metrics.dart`: content-
  sized column widths from `estimateWidth` — per-character-class em
  widths × font px, bold +7 % — or a `TextMeasurer` callback
  (`measureText`), merged cells widen their span, row heights = font px ×
  `lineHeight`, cumulative offsets; meant for PDF too). Text is clipped
  by a `clipPath` per column and per merged cell, so a viewer's font may
  differ from the estimate; a merged label sits on its first row like
  `CubeView`. Baseline = row centre + 0.35 em (no `dominant-baseline`,
  for renderer compatibility). Number text from `NumberFormat.format`
  (engine; html delegates to it). Tests parse with `package:xml` and
  render with `rsvg-convert` when installed. `example/main.dart` +
  `example/sales.csv` as in html.
- `packages/tessera_pdf` — pure Dart, depends on `tessera` and
  `package:pdf` (accepted for TrueType embedding + subsetting and real
  glyph metrics; the built-in Helvetica is WinAnsi only, so Hungarian
  ő/ű need a TTF). `pdf` pins `archive <4.1.0`, hence tessera_xlsx/ods
  declare `archive: ">=4.0.7 <5.0.0"` (their API use is identical in
  4.0.9 and 4.2). `PdfCubeExporter` (`export` is async → `Uint8List`;
  `plan` returns `PdfPlan` = scale + `GridPagination` without
  rendering): geometry from `GridMetrics` with a `TextMeasurer` from the
  embedded fonts (`stringMetrics().advanceWidth × font px`), page cuts
  from the engine's `GridPagination` (`export/grid_pagination.dart`:
  frozen header rows/columns repeat on every page, greedy whole-row /
  whole-column bands, a too-large row still gets a page, order down then
  across). Scaling: `fitToWidth` (default) down to `minScale` (0.6),
  then tiling. Drawing on the low-level `PdfGraphics` in points with
  `k = 0.75 × scale` (px→pt); origin cells found through covered cells
  in the page's visible rows × columns, visible sub-rectangle per merged
  area, text on the first visible row (so a label crossing a break is
  repeated); text ellipsized with `…` to the cell (exact metrics, so no
  clipping); baseline = row centre − (ascent+descent)/2 × size. Options:
  `PageSetup` (mm; `PageSize` a3/a4/a5/letter/legal/custom,
  `PageOrientation`, margins; default A4 landscape 15 mm), `PdfFonts`
  (regular/bold/italic/boldItalic TTF bytes, `builtIn()`; fallbacks
  bold→regular etc.; `ExportFont.family` ignored), `PdfPageText`
  header/footer (left/center/right, `{title}` `{page}` `{pages}`
  `{date}`; defaults title top-left, `{page} / {pages}` bottom-right;
  a band of `pageTextSize × 1.8` pt is reserved only when non-empty).
  Tests use poppler (`pdfinfo`, `pdftotext -f/-l`, `pdffonts`), `qpdf
  --check` and ghostscript when installed, Noto Sans from
  `/usr/share/fonts/noto` when present. `example/main.dart` takes an
  optional font directory.
- Planned: further exporters the same way.

Why the split: pub resolves `flutter: sdk: flutter` per package, so a
package that depends on Flutter cannot be used with the standalone Dart
SDK at all (servers, `dart:stable` images) — a Flutter-free entrypoint
inside a Flutter package does not help.

`TODO.md` at the root lists the agreed pre-publish work (API decisions,
small fixes, publishing order, the user guide, later features); tick
items there as they are done.

## Commands

```bash
dart pub get                                   # at the root: resolves all members
dart analyze                                   # at the root: all packages, must be clean
(cd packages/tessera && dart test)             # engine tests (package:test, no Flutter)
(cd packages/tessera_xlsx && dart test)        # xlsx package (pure Dart)
(cd packages/tessera_ods && dart test)         # ods package (pure Dart)
(cd packages/tessera_html && dart test)        # html package (pure Dart)
(cd packages/tessera_svg && dart test)         # svg package (pure Dart; rsvg-convert optional)
(cd packages/tessera_pdf && dart test)         # pdf package (poppler/qpdf/gs optional)
(cd packages/tessera_flutter && flutter test)  # widget tests
(cd packages/tessera_flutter/example && flutter test)
dart format packages                           # run before committing
(cd packages/tessera && flutter pub publish --dry-run)          # keep at 0 warnings
(cd packages/tessera_flutter && flutter pub publish --dry-run)  # (uncommitted files count)
cd packages/tessera_flutter/example && dart run tool/gen_sales_csv.dart   # regenerates assets/sales.csv AND packages/tessera/test/data/sales.csv (seeded)
cd packages/tessera_flutter/example && flutter run -d linux   # run the example (X11: xdotool + `import -window` for screenshots; i3 tiles it)
# find the window with `xdotool search --class tessera_example`; stop with
# pkill -f '[f]lutter run -d linux' (the bracket keeps pkill from killing the shell)
```

Paths below are relative to the package (`lib/src/...` means
`packages/tessera/lib/src/...` for layers 1–3 and l10n,
`packages/tessera_flutter/lib/src/...` for widgets; `example/` is
`packages/tessera_flutter/example/`).

## Status

- API skeleton written with doc comments in `lib/src/`; value types are
  implemented.
- Implemented: `CsvDataSource` (streaming parser in `source/csv_parser.dart`),
  `inferSchema`, and the shared value parsers in `schema/value_parsing.dart`
  (`NumberSyntax`, `parseBoolean`, `DatePattern`) that the importer must
  reuse so import and inference agree.
- Implemented: `FactTableImporter` + `FactTableImpl`
  (`facts/fact_table_impl.dart`, internal, not exported): numbers/dates in
  `Float64List` (NaN = null, ints exact to 2^53, dates as UTC millis), text
  dictionary-encoded (`Int32List` codes, -1 = null), booleans `Uint8List`.
  `loadFacts(source)` works end to end on `sales.csv`.
- Implemented: the cube layer. `cube/cube_engine.dart` (internal) holds
  `CubeCache` (per-dimension `DimensionCodes`, filtered rows; shared across
  `copyWith`), `AxisTree`/`AxisNode` (visible groups only — children exist
  only under expanded nodes), one pass over the facts into leaf cells, then
  row roll-up and column roll-up via `Accumulator.merge`, then ordering
  (`AxisSort`) and summary placement. All built-in accumulators done.
- Widget-prep API (from the reference screenshots in the owner's pivot
  app): `AxisSort.keyPath` (sort by the aggregate in a specific cross-axis
  group; falls back to the summary when not visible), `HeaderEntry.childCount`
  (size of an expansion, for "too many columns" confirmation),
  `AxisLayout.descendantCount` (subtree size for header spans / merged
  cells), `standardDimensions(facts)` (column + date-part dimensions for a
  picker dialog), ISO week.
- Implemented: `CubeView` (`widgets/cube_view.dart`) on `TableView`;
  `cube/axis_geometry.dart` (engine package, exported) resolves the
  merged header areas; `CubeTheme` / `ResolvedCubeTheme`. Dependency:
  `two_dimensional_scrollables`. Nothing throws `UnimplementedError` any
  more.
- Implemented: `AxisEditor` (`widgets/axis_editor.dart`; chips per axis,
  `Draggable`/`DragTarget` with `DimensionDrag` payload — drop on a chip
  inserts before it, drop on the editor appends, works across the two
  editors; delete icon removes; `+` opens the picker) and
  `showDimensionPicker` / `DimensionPickerDialog`
  (`widgets/dimension_picker.dart`; searchable, used dimensions disabled).
  Both verified on Linux desktop. The caption ("Rows"/"Columns") is a
  `MenuAnchor` setting `CubeAxis.summaryPosition` (end/start/hidden;
  strings `totalsAtEnd` …) and `subtotalPosition` (`subtotalsAbove`/`Below` on rows,
  `subtotalsLeft`/`Right` on columns);
  the theming example offers the same in its palette menu (`CubeWorkbench.actions` is a builder receiving the
  controller).
- Implemented: `AggregateEditor` (`widgets/aggregate_editor.dart`; chips
  with delete — never the last one; removing resets any `AxisSort` that
  used it; `selected`/`onSelected` let the app choose what `CubeView`
  shows) and `showAggregatePicker` / `AggregatePickerDialog` /
  `standardMeasures` (`widgets/aggregate_picker.dart`); `AggregateKind`
  is in the engine (`cube/aggregate_kind.dart`).
  `CubeView` falls back to the spec's first aggregate when its `aggregate`
  is not in the spec. Example uses the editor instead of a dropdown.
- Example app: `example/lib/main.dart` is a launcher (`LauncherPage`)
  listing the entries of `example/lib/examples.dart`; each example lives in
  its own folder under `example/lib/` (kept as one project so pub.dev's
  Example tab and `flutter run` cover everything). Shared bits in
  `example/lib/common/`: `CubeWorkbench` (infer → isolate import with
  progress → editors + CubeView + schema page; `initialSpec`,
  `dimensions`, `adjustSchema` hooks), `SchemaPage`, `HttpCsvDataSource`
  (custom DataSource: streaming GET per iteration, early cancel for prefix
  reads, disk cache after one full pass, HEAD Content-Length →
  `estimatedRowCount`; sendable to the import isolate; dart:io so not web);
  `example/lib/language_menu.dart` (`appLocale` + `LanguageMenu`). The
  workbench's "Export…" menu writes the cube (all aggregates) as .xlsx
  (`XlsxCubeExporter`), .ods (`OdsCubeExporter`), .html
  (`HtmlCubeExporter`), .svg (`SvgCubeExporter`), .pdf
  (`PdfCubeExporter` with Noto Sans Regular/Bold from `assets/fonts/`,
  OFL licence alongside; the files are ~90 KB subsets — Latin, Latin-1,
  Extended-A/B, punctuation, currency — made by `tool/subset_fonts.sh`
  with fonttools' `pyftsubset` from the full fonts, because the example
  is published inside `tessera_flutter`) or CSV
  (`CsvCubeExporter`, BOM) — `ExportFormat` — through
  `file_picker`'s `FilePicker.saveFile(bytes:)`, which writes the file
  itself — needed on Android/iOS (document Uri, no path;
  `file_selector` has no save dialog there). Linux goes through the
  xdg-desktop-portal.
- "Theming" (`example/lib/theming/`): the sales cube with an AppBar
  palette menu — `ThemePreset`s in `presets.dart` (`themePresets`:
  Material/default, Spreadsheet, Gradient, Hue levels, High contrast,
  Compact), seed colours and light/dark, applied by wrapping the
  workbench in a local `Theme`; "Hue levels" is
  `CubeTheme(hueLevels: HueLevels())` with `CubeExportTheme.hueLevels`
  for Excel. `CubeWorkbench` gained `theme` and `actions` for it.
  This is the place to demonstrate new `CubeTheme` features; each
  preset must resolve in light and dark (`test/theming_test.dart`).
  Each preset also carries a hand-authored `xlsxTheme`
  (`CubeExportTheme`); the menu's "Excel export theme" picks it,
  `CubeExportTheme.brand(seed.toARGB32())`
  or the package default (`ExcelTheme`, `excelThemeFor`) and passes it
  as `CubeWorkbench.exportTheme` (used by the .xlsx and .ods exports). No `CubeTheme → CubeExportTheme`
  converter on purpose (needs a context; screen shading is too subtle
  on paper) — Excel themes are authored.
- "Public datasets" (`example/lib/datasets/`): six real CSVs (GitHub raw
  with Content-Length; data.wa.gov chunked without) listed in
  `publicDatasets`, cached under `systemTemp/tessera_examples/`; "Clear
  downloaded files" action. Tested with a local HttpServer in
  `example/test/http_csv_data_source_test.dart`.
- "Simple pivot" (`example/lib/simple/`) loads `assets/sales.csv` via
  `rootBundle`, infers the schema, imports, shows rows `[region, country]`
  × columns `[date.year, date.quarter]`, axis + aggregate editors,
  language menu (TesseraLocalizations + flutter_localizations). AppBar "Schema…"
  opens `example/lib/schema_page.dart` (include switch, type, label, date
  format / number syntax per column, sample raw values, reset) and
  applies on "Apply" and on back alike: label-only edits relabel the
  facts in place (`FactTable.withLabels`, spec and expansion kept),
  anything else re-imports; `_prune` drops spec dimensions/aggregates
  whose columns vanished or changed type, expansion state is carried
  over. The
  info line summarises the `ImportReport` and opens it in a dialog.
  Verified visually on Linux desktop.

## Widget plan (agreed)

- Three widgets: `CubeView` (grid only), `AxisEditor` (chips per axis,
  drag-and-drop within and between axes), `DimensionPickerDialog` fed by
  `standardDimensions`. `CubeController` is the single mutable object.
  All three exist; the example app composes them.
- `CubeView` is built on `TableView` from `two_dimensional_scrollables`
  (lazy cells, pinned headers, merged cells for the L-shaped group
  headers). Expanded parent = first entry of its span (its own subtotal),
  children follow; header band = one row per column dimension + aggregate
  label row; row header = one column per row dimension; top-left corner
  shows column-dimension names.
- Hooks: `CellFormatter`, `CellStyler` (zero/negative colours),
  `CubeTheme.levelColor(CellLevel)` (`row`/`column` depth from 0,
  `rowLevels`/`columnLevels`, `depth` = sum, `maxDepth`) +
  `CubeTheme.gradient(colors)` (by `depth`), `headerLevelColor(HeaderLevel)`
  (`isRow`, `level`, `index` = rows first then columns; default: the
  plain `headerColor`), `hueLevels: HueLevels?` (resolve fills the hue
  from the primary and the light/dark defaults from the brightness;
  cells take their row level's hue, column headers continue after the
  row levels, summaries stay neutral — the owner's decision after the
  "darker = highlighted" complaint about gradients),
  `CubeTheme.headerIconColor` (default: `headerTextStyle.color`, applied
  with an `IconTheme.merge` around the `TableView`),
  separate row/column summary labels, `expansionLimit` +
  `confirmExpansion` (default: AlertDialog), `onCellTap`. Sort UI rule:
  `AxisDimension.sort` is nullable — `null` inherits the level above
  (`CubeAxis.sortAt(level)` resolves; the engine and the widget only use
  that). Tapping the first level's title toggles asc/desc; a deeper
  level cycles opposite-of-inherited → same explicit → inherit (`null`),
  inherited icons are drawn faded. Tapping the aggregate name under a
  column sets aggregate sort with that `keyPath` on the FIRST row level
  and resets the deeper ones to inherit (tap again flips direction).
  Sort-key column is tinted with `sortKeyColor`. Every dimension title also carries a
  `MenuAnchor` (`▾` button always shown, long press, secondary click):
  sort ascending/descending (checked), expand all / collapse all for that
  level (`Cube.expandRowLevel` keeps deeper expansions, unlike
  `expandRowsToDepth`; `collapseRowLevel`; column twins). "Expand all"
  goes through `expansionLimit` with `confirmLevelExpansion` (dimension +
  `rowsAddedByExpandingLevel`, one count-only pass); the default dialog
  reuses `largeExpansion`. Titles reserve 2 × icon width.
- Current cell: `CubeController.selection` (`CellAddress` = row path +
  column path, kept when invisible) and `currentCell` (resolved against
  the layout, null when not visible). `CubeView.selectable` (default
  true), `focusNode`, `autofocus`; a `Focus` around the `TableView`
  requests focus on cell tap; `onKeyEvent` handles arrows, Home/End (Ctrl: first/last row),
  PageUp/Down (page = rows under the header band; the number block's
  KP_Home etc. arrive as `numpad7` … without a character while NumLock
  is off and are translated), Enter/Space (toggle
  the row group), Escape; `_scrollIntoView` uses the fixed extents and
  the two internal `ScrollController`s. `CellBorder.outline` draws the
  2 px inset outline (`CubeTheme.selectionColor`, default primary); the
  row/column label areas of the current cell are tinted 15 %. The
  example shows the current cell's coordinate and fact count under the
  grid.
- Grid geometry: `levelRows = max(columnDepth, 1)` header rows for group
  labels + 1 aggregate row; `headerColumns = max(rowDepth, 1)`. Pinned
  rows/columns = those. Cells draw their own right/bottom borders.
- Column widths are content-sized (`widgets/column_widths.dart`,
  `ColumnWidthMeasurer`, internal): `TableView` needs every extent before
  any cell exists, so `_CubeGridState` measures up front from the layout —
  values of the first `CubeView.measuredRows` rows (default 1000) plus
  summary rows, entry labels (column labels only when they stay in one
  column, i.e. not expanded), titles, the aggregate label — keeps the 4
  longest strings per column (length as proxy), lays those out with
  `TextPainter` using the theme styles merged onto the ambient
  `DefaultTextStyle` (as `Text` renders them — a bare style without a
  family measures in the engine's default font and truncates), adds padding + border + 2 px slack + 18 px for icons, and
  clamps to `CubeTheme.min/maxColumnWidth` (72/320) and
  `min/maxRowHeaderWidth` (100/400); equal min and max = fixed widths.
  Cached per (layout, aggregate, strings, theme text bits, text scaler…),
  so it reruns only on toggle/spec change. `CubeView.keepColumnWidths`
  (default true): a column never shrinks while the state lives —
  remembered by `HeaderEntry.path` (data) / dimension id (row headers),
  memory dropped when anything but the layout changes. Rows stay
  fixed-height. Test
  font renders every glyph 1 em wide, so widths in widget tests are large
  (tests set `tester.view.physicalSize` where that matters).
- The library must NOT depend on `intl`. Localization is split: the
  engine's `l10n/` has the abstract `TesseraStrings` (every member
  abstract so built-in locales are compiler-checked for completeness;
  concrete helpers `aggregateLabel`, `dimensionLabel`, `formatValue`,
  `formatNumber`, `aggregateKindLabel`; `forLanguage(code)`,
  `supportedLanguages`), fourteen built-in locales in `l10n_xx.dart`
  (`TesseraStringsHu` …), registry `locales.dart` (`builtInStrings`).
  `tessera_flutter`'s `l10n/tessera_localizations.dart` adds the static
  namespace `TesseraLocalizations` (`delegate` matching on language code
  with `SynchronousFuture`, `supportedLocales`, `of(context)` /
  `maybeOf`) and `TesseraLocalizationsScope` (InheritedWidget override,
  checked first by `of`), English fallback. Exporters use
  `TesseraStrings` directly. Label composition is a method per locale
  (inflected languages use "suma: X"); `Dimension.explicitLabel` tells the
  localization whether to compose. Core keeps English `label`/`labelFor`
  for plain-Dart use; widgets never call them for built-in types.
  `standardDimensions` sets no explicit labels on purpose. Widget string
  params are nullable overrides. `Accumulator` was renamed
  `AggregateAccumulator` (clashed with Flutter's). The example uses
  `flutter_localizations` (not intl any more) and has a language menu.
- Each package has its own README, CHANGELOG and LICENSE copy (pub
  requires them per package); the root README is the repo overview.

## Architecture (see `packages/tessera/lib/tessera.dart` doc for the long version)

Four layers, one directory each under `lib/src/` (1–3 in
`packages/tessera`, 4 in `packages/tessera_flutter`):

1. `schema/` + `source/` — `DataSource` (column names + re-openable
   `Stream<SourceRow>`), `inferSchema` samples a prefix of rows,
   `ColumnSpec` carries user overrides (type, include, format, parser).
2. `facts/` — `FactTableImporter` → immutable `FactTable` (columnar,
   dictionary-encoded, typed lists so it can move to an isolate).
   `Dimension` (sealed: `ColumnDimension`, `DatePartDimension`,
   `MappedDimension`) and `Measure` are *views on columns*, not column
   properties — any column can be grouped by, numeric ones aggregated.
3. `cube/` — `CubeSpec` (row/column `CubeAxis`, `aggregates`, `filter`) +
   one `ExpansionState` per axis → `Cube` (immutable, `late final layout`)
   → `CubeLayout` / `AxisLayout` / `HeaderEntry` / `CubeCell`.
4. `widgets/` — `CubeController extends ChangeNotifier` holds the cube;
   `CubeView` renders one aggregate per cell.

Layers 1–3 must not import Flutter — enforced now by the package split
(the engine's pubspec has no Flutter dependency).

## Key design decisions (agreed with the owner)

- **Summary = root path.** `DimensionPath.root` (empty) is the summary
  row/column. `ExpansionState.initial()` has only the root expanded, which
  makes the first level visible. Expanded parent rows double as subtotals
  (outline/tree-grid model, no separate subtotal rows); where that row
  goes is `CubeAxis.subtotalPosition` (`top` default, `bottom`, `hidden`)
  — independent of `summaryPosition`, like Excel's subtotal vs grand
  total settings. `AxisTree.entries()` orders accordingly; a hidden
  group has no entry but `AxisLayout.entryFor(path)` still returns a
  `HeaderEntry` for its label/toggle; `AxisGeometry` works from paths
  and contiguous runs (`HeaderArea.path`, `entryIndex` -1 when hidden),
  so `CubeView` and the xlsx exporter follow automatically. The
  hairline-free L (`CellBorder.rightFrom/rightUntil`,
  `bottomFrom/bottomUntil`) follows the leg's position
  (`_legAt(area)`: first row/column, last, or none when hidden).
  `descendantCount` = subtree size excluding itself, summary 0. Both
  hidden → a flat leaf table (nothing counted twice), handy for export.
- **Nesting order is the hierarchy.** `[region, country]` groups by region
  then country; no hierarchy declarations. A dimension may appear on at most
  one axis; different derived dimensions of the same column (`date.year`,
  `date.month`) may be on different axes.
- **Empty values are groups, not dropped.** `null` dimension value = the
  "(empty)" group, distinct from the summary. Measures: `sum` ignores nulls,
  `avg` divides by non-null count, `count` ≠ `countNonNull`. A cell with
  `factCount == 0` renders blank.
- **Cells never store row lists.** Aggregation is a single pass over facts
  updating accumulators for every visible (row-prefix, col-prefix) pair;
  `CubeCell.factRows` is a lazy filter. `Accumulator` is
  `add / merge / result` so parents merge from children (avg carries
  sum+count).
- **Type inference is a proposal.** `inferSchema` reads `sampleRows`;
  `TypeMismatchPolicy` (`widen` default / `nullify` / `fail`) resolves
  contradictions during import. Widening order in `ColumnType.canWidenTo`.
- **Filter is separate from axes** (pivot "filter area"), sorting lives on
  `AxisDimension.sort` (by value or by aggregate, null position).
- **Labels resolve against the fact table.** `Dimension`, `Measure` and
  `Aggregate` have `label` (standalone) and `labelFor(facts)` (explicit
  label, else the column's `FactColumn.label` from the schema). Widgets
  always use `labelFor`, so relabelling a column in the schema shows up in
  chips, corner titles and the aggregate header. `FactTable.findColumn`
  is the null-safe column lookup.
- **Immutable values everywhere**; `CubeController` is the only mutable
  object. `copyWith` for derived versions; equality by value (`Dimension`
  and `Aggregate` by `id`).
- **Naming avoids Flutter clashes**: never `Row`, `Column`, `Axis`, `Table`,
  `Cell` — use `CubeAxis`, `HeaderEntry`, `CubeCell`, etc.
- Web support matters: no `dart:io` in the library; sources are byte/stream
  based.
- **Large data.** Measured (2 M rows / 172 MB, desktop, JIT ≈ AOT):
  parse 2.7 s, import 5.9 s (~3 µs/row; was 10 s before the fast paths),
  first cube 1.2–1.7 s, toggle 0.3–0.4 s, ~220 MB RSS.
  `example/tool/bench.dart` reproduces it. Parse breakdown: decode 0.35 s,
  bare char loop 0.28 s, +substrings 0.9 s, stream delivery ~0.5 s, the
  rest is the state machine. Fast paths in place: `NumberSyntax` digit
  scan before regex/normalize, parser hot loop only tests the 4 special
  chars (BOM/skip-lines/pending-CR handled at chunk starts), unquoted
  fields are a single `substring`, text dictionary without closure
  allocation. Hence:
  `DataSource.estimatedRowCount()` (exact for lists; CSV = length /
  average of the first 200 records, needs `length:` for `fromBytes`),
  `FactTableImporter.import(onProgress:)` with `ImportProgress`
  (`rowsRead`, `estimatedTotal`, `fraction` capped at 0.99 until `done`),
  return `false` to cancel → `ImportCancelled`; the importer yields to the
  event loop at every report (`progressEvery`, default 10 000).
  `loadFactsInIsolate` runs infer + import via `Isolate.run`, forwards
  progress and cancellation over ports, falls back to `loadFacts` on the
  web. Sources must be sendable (plain data or a `File`; not live
  streams). Gotcha: Dart closures capture their whole scope, so a
  `fromBytes(() => ...)` callback written in a `State` method (captures
  `this`) or the worker closure sharing scope with the caller's ports is
  unsendable ("object is unsendable - _Future") — hence
  `CsvDataSource.fromData(bytes)` and the separate `_runWorker` function.
  Isolate import of 2 M rows: 9.9 s, i.e. no measurable overhead; the CSV
  row estimate was 5 % high (fraction is capped at 0.99 anyway). Import conversion has headroom (regex per numeric cell) — a
  tryParse fast path is a known TODO. Cube layout still runs on the caller.

## Test data

`example/assets/sales.csv` (identical copy at
`packages/tessera/test/data/sales.csv`, both written by the generator) —
1000 rows, columns `id,date,region,country,
category,product,salesperson,quantity,unit_price,discount,total`.
Deliberate edge cases (probabilities in `example/tool/gen_sales_csv.dart`):
rows with region but no country/category/product; category without product;
missing quantity or unit_price (then total is empty too); countries with no
region (Iceland, Singapore); products with no category (Gift Card, Extended
Warranty, Shipping); some empty discounts and salespeople. Hierarchies are
consistent otherwise.

## Conventions

- `pubspec.yaml` has no `author` field on purpose (deprecated, pub warns);
  author lives in README and LICENSE.
- Widgets import `package:tessera/tessera.dart` (never
  `package:tessera/src/...`); the engine package must stay Flutter-free.
- Example app org id: `eu.nagylzs` (`eu.nagylzs.tessera_example`).
- Icon: `icon/*.svg` at the repo root are the sources (the "Band"
  design: a teal L header band and nine tiles in the level hues on
  paper; `-foreground`/`-monochrome` are the layers, `-adaptive-*`
  the same scaled to 85 % for Android's 66 dp safe zone). The example
  rasterizes them into `assets/icon/*.png` (not bundled) and
  `flutter_launcher_icons` (config in its pubspec) writes every
  platform's icons: `dart run flutter_launcher_icons`. Re-rasterize
  with `rsvg-convert -w 1024 -h 1024` after editing an SVG.
- Doc comments on every public type; keep the library-level docs in
  `packages/tessera/lib/tessera.dart` and
  `packages/tessera_flutter/lib/tessera_flutter.dart` in sync with the
  layer list above.
- Test the pure-Dart layers with `package:test` in `packages/tessera`;
  widget tests (`flutter_test`) only in `packages/tessera_flutter`.
