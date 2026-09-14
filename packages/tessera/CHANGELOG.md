## Unreleased

* `TesseraStrings.expressionError(error)`: localized expression error
  messages, composed per locale by `expressionErrorText(kind, arguments)`
  with type names from `exprTypeName`; and the filter editor's strings
  (`filter`, `noFilter`, `addCondition`, `addGroup`, `addExpression`,
  `matchAll`, `matchAny`, `negate`, the `op…` operator names,
  `customFilter`, `expression`, `selectValues`, `selectedCount`, `clear`,
  `apply`, `column`, `value`) in every locale.
* Layout-relative aggregates ("Show Values As"): `Aggregate.percentOf`
  (`TotalOf.row` / `column` / `grand` / `parentRow` / `parentColumn`),
  `differenceFrom` and `percentDifferenceFrom` (`BaseItem.previous` /
  `next` / `value(v)` along an `AxisSide`), `runningTotal`, `rank`;
  the `LayoutAggregate` base with `LayoutCellContext` for custom ones.
  Computed when a cell is read; sorting by one sorts by its base. JSON
  forms in `CubeJson`; labels through new `TesseraStrings` members
  (`percentOfTotal`, `differenceFrom`, `previousItem`, `nextItem`,
  `runningTotalOf`, `rankOf`) in every locale. `AxisSide` moved to the
  engine (still exported by `tessera_flutter`).
* `TesseraSnapshot`: a `FactTable` (and optionally a `CubeConfig`) as one
  `Uint8List` — magic, version, JSON header, raw little-endian column
  arrays at 8-byte offsets, text codes in the narrowest width — that
  `decode` loads back in a copy after validating every section
  (`FormatException` otherwise, also for a newer format version).
  Documented in `docs/snapshot.md` for other writers. 2 M rows: 106 MB,
  ~40 ms to encode, ~60 ms to decode.
* `CubeJson`: JSON encoding and decoding of `CubeConfig` (a new bundle of
  `CubeSpec`, both `ExpansionState`s and the `Schema`; `CubeConfig.of(cube)`,
  `toCube(facts)`), and of every part on its own — axes, sorts,
  dimensions, measures, aggregates, filters, paths, expansion states,
  schemas, values (dates as `{"date": …}`). `JsonAdapter` for custom
  aggregates, dimensions and filters; `functions` for decoded expressions;
  `FormatException` on malformed input, `UnsupportedError` for members
  without a JSON form. `Measure.explicitLabel`,
  `ExpressionAggregate.explicitLabel`; `ValueFilter`, `AndFilter`,
  `OrFilter` and `NotFilter` compare by value.
* Cell formulas accept row expressions as aggregate arguments:
  `sum(qty * price) / sum(qty)`, `max(price - cost)`,
  `distinct(upper(left(country, 1)))` — the argument becomes an expression
  measure (or dimension) the engine accumulates. `ExpressionAggregate`
  compiles in `prepare(facts)`; `aggregateOfShape` takes the argument
  node, `aggregateReferences` the function registry; `isRowExpression`.
* Statistical aggregates: `Aggregate.stdDev` / `stdDevPopulation` /
  `variance` / `variancePopulation` (Excel's STDEV.S / STDEV.P / VAR.S /
  VAR.P; one Welford accumulator, merged with Chan's formula so parents
  are exact and large means do not cancel), `AggregateKind` entries, cell
  formula names `stdev`, `stdevp`, `var`, `varp`, and strings
  `stdDevOf` … `populationVariance` in every locale.
* Expression language: `Expression` (parse, `check`, `validate`,
  `compile`), `ExpressionScope` (row or cell scope over a `FactTable` or
  `Schema`), `ExpressionError` (kind, source range, arguments),
  `ExprType`, `FunctionRegistry` / `ExpressionFunction` (built-in
  functions plus application ones), the `Expr` syntax tree with
  `toSource`. SQL/Excel-flavoured syntax (`and`, `or`, `not`, `=`, `<>`,
  `in`, `between`, `is empty`, `if()`, `#2024-01-31#` dates, `[quoted
  names]`), static typing, SQL three-valued null handling, day arithmetic
  on dates, closures over the typed column arrays.
* `ExpressionFilter`, `Measure.expression` (`ExpressionMeasure`,
  materialized once per fact table), `ExpressionDimension`,
  `Aggregate.expression` (`ExpressionAggregate`, a cell formula over
  `sum(col)`, `count`, … evaluated per cell) and the `DerivedAggregate`
  base for aggregates computed from other aggregates' results.
* Structured filters `CompareFilter`, `RangeFilter`, `TextFilter`,
  `EmptyFilter` over a column, and `FactFilter.toExpressionSource()` on
  every filter (`null` where it cannot be expressed); `FactFilter.compile`
  binds a filter to a table once per scan.
* Breaking: `Measure` is sealed — `Measure('total')` still constructs a
  `ColumnMeasure`, but `Measure.column` moved to `ColumnMeasure`; every
  measure has `id`, `label`, `labelFor` and `columns`. `Dimension` gained
  `sourceColumns`. `CubeCell.aggregate` also accepts the dependencies of a
  derived aggregate.

## 0.1.1

* README: the status note no longer says the package is unpublished.

## 0.1.0

* Initial release: data sources (CSV, lists), schema inference, the fact
  table importer, cubes with expandable row/column hierarchies, built-in
  aggregates, `AxisGeometry` for renderers, and `TesseraStrings` with
  fourteen built-in languages.
* `Cube.expandRowLevel` / `collapseRowLevel` / `expandColumnLevel` /
  `collapseColumnLevel` open or close every group of one level (keeping
  deeper expansions), `rowsAddedByExpandingLevel` /
  `columnsAddedByExpandingLevel` count the effect beforehand;
  `ExpansionState.collapseLevel`. Strings `sortAscending`,
  `sortDescending`, `expandAll`, `collapseAll`, `inheritSort`,
  `totalsAtEnd`, `totalsAtStart`, `totalsHidden`, `subtotalsAbove`,
  `subtotalsBelow`, `subtotalsLeft`, `subtotalsRight`, `subtotalsHidden`.
* `CubeAxis.subtotalPosition` (`SubtotalPosition.top` / `bottom` /
  `hidden`): where an expanded group's own row goes; `AxisLayout.entryFor`
  resolves groups without a row; `HeaderArea.path`.
* `CubeGrid`: a `CubeLayout` as a rectangular grid of typed cells with
  merged areas, the way `CubeView` shows it — what exporters render from.
* `CubeExportTheme` / `ExportFont` / `NumberFormat`: the format-neutral
  look of an exported document (fills, border, fonts per role, number
  format; `brand(primary:)`, `gradient`, `mix`), shared by every exporter.
* `Oklch` (perceptual colour, to/from ARGB, gamut clipping) and
  `HueLevels`: nesting levels coloured by hue alone at one lightness,
  headers the same hue with more chroma, golden-angle steps so adding a
  level keeps the others' colours. `CubeExportTheme.hueLevels`,
  `rowHeaderFills` / `columnHeaderFills` per level, `levelBasis`
  (`combined` / `row`), `fillOf` / `fontOf` for exporters;
  `GridCell.rowLevel` / `columnLevel`.
* `GridMetrics`: pixel geometry of a `CubeGrid` (content-sized column
  widths from an estimate or a `TextMeasurer`, row heights from the
  fonts, offsets) for renderers that lay cells out themselves;
  `GridPagination` cuts it into pages with repeated header rows and
  columns; `NumberFormat.format(value, strings)`.
* `CsvCubeExporter` (`CsvExportOptions`: delimiter, quote, line ending,
  decimal separator, BOM, group labels at the origin or repeated).
* `FactTable.withLabels` relabels columns without a re-import (data is
  shared).
* `AxisDimension.sort` is nullable: `null` inherits the ordering of the
  level above (`CubeAxis.sortAt` resolves it), so an aggregate sort on the
  first level orders every level.
