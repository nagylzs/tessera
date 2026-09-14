/// Tessera: import tabular data, then group and aggregate it in a pivot
/// cube with expandable row and column hierarchies.
///
/// This package is pure Dart — it runs in servers, command-line tools,
/// isolates and the browser alike. `package:tessera_flutter` adds the
/// widgets that display and edit a cube.
///
/// The library is organised in layers:
///
/// 1. **Source & schema** — [DataSource] is the common interface for anything
///    that yields rows; [inferSchema] guesses a [Schema] from a sample of
///    rows, and [ColumnSpec] lets the user override types and parsing.
/// 2. **Facts** — [FactTableImporter] turns a source into an immutable,
///    in-memory [FactTable]. [Dimension]s and [Measure]s are *views* on its
///    columns, not properties of them.
/// 3. **Cube** — [CubeSpec] (row axis, column axis, aggregates, filter) plus
///    an [ExpansionState] per axis define a [Cube], whose [CubeLayout]
///    exposes the visible header entries and a [CubeCell] per intersection.
///    [AxisGeometry] resolves the merged header cells of an axis for
///    renderers (the Flutter grid, exporters).
///
/// Filters, calculated measures, computed dimensions and cell formulas
/// share the expression language: [Expression] parses a formula such as
/// `total > 100 and region = "Europe"`, [ExpressionScope] and
/// [Expression.check] resolve names and types against the schema (errors
/// are [ExpressionError]s with a source range), [FunctionRegistry] adds
/// application functions, and the engine compiles the result to closures
/// over the fact table's columns. [ExpressionFilter], [ExpressionMeasure]
/// (`Measure.expression`), [ExpressionDimension] and [ExpressionAggregate]
/// (`Aggregate.expression`, a [DerivedAggregate] computed per cell) are
/// the plug points; the structured [CompareFilter], [RangeFilter],
/// [TextFilter] and [EmptyFilter] render to expressions too.
///
/// [CubeJson] encodes a [CubeConfig] — spec, expansion states and schema —
/// as JSON data and decodes it again, with [JsonAdapter]s for
/// application-defined aggregates, dimensions and filters.
///
/// [LayoutAggregate]s — [PercentOfTotalAggregate], [DifferenceFromAggregate],
/// [PercentDifferenceFromAggregate], [RunningTotalAggregate], [RankAggregate]
/// — show an aggregate against the cells around it (Excel's "Show Values
/// As"); the engine computes them from the layout through a
/// [LayoutCellContext].
///
/// [TesseraSnapshot] writes a [FactTable] (and a [CubeConfig]) as one
/// buffer of bytes that loads back without parsing — a cache, or a table
/// built on a server and sent to clients; the format is documented in
/// `docs/snapshot.md`.
///
/// [CubeGrid] lays a [CubeLayout] out as a rectangular grid (the way the
/// Flutter `CubeView` shows it) for exporters; [CsvCubeExporter] writes it
/// as CSV, `tessera_xlsx` as a workbook. [CubeExportTheme] is the
/// format-neutral look every exporter takes, [GridMetrics] the pixel
/// geometry for renderers that lay cells out themselves (SVG, PDF) and
/// [GridPagination] cuts it into pages with repeated headers; [HueLevels] colours nesting
/// levels by hue alone (computed in OKLCH, see [Oklch]).
///
/// Every user-facing text and the locale-specific label and number
/// formatting rules live in [TesseraStrings] (fourteen languages built in),
/// so renderers agree on how a cube is labelled.
library;

export 'src/color/hue_levels.dart';
export 'src/color/oklch.dart';
export 'src/cube/aggregate.dart';
export 'src/cube/aggregate_kind.dart';
export 'src/cube/axis_geometry.dart';
export 'src/cube/cube.dart';
export 'src/cube/cube_layout.dart';
export 'src/cube/cube_spec.dart';
export 'src/cube/dimension_path.dart';
export 'src/cube/expansion_state.dart';
export 'src/cube/filter.dart';
export 'src/cube/layout_aggregate.dart';
export 'src/export/csv_cube_exporter.dart';
export 'src/export/cube_export_theme.dart';
export 'src/export/cube_grid.dart';
export 'src/export/grid_metrics.dart';
export 'src/export/grid_pagination.dart';
export 'src/expr/ast.dart';
export 'src/expr/checker.dart';
export 'src/expr/compiler.dart'
    show BoolFn, CompiledExpression, NumberFn, TextFn, datePartOf;
export 'src/expr/expr_type.dart';
export 'src/expr/expression.dart';
export 'src/expr/expression_error.dart';
export 'src/expr/functions.dart';
export 'src/expr/parser.dart' show parseDateLiteral;
export 'src/facts/dimension.dart';
export 'src/facts/fact_table.dart';
export 'src/facts/importer.dart';
export 'src/facts/isolate_import.dart';
export 'src/facts/measure.dart';
export 'src/facts/standard_dimensions.dart';
export 'src/json/cube_json.dart';
export 'src/l10n/locales.dart';
export 'src/l10n/tessera_strings.dart';
export 'src/schema/column_spec.dart';
export 'src/schema/column_type.dart';
export 'src/schema/schema.dart';
export 'src/schema/value_parsing.dart';
export 'src/snapshot/tessera_snapshot.dart';
export 'src/source/csv_data_source.dart';
export 'src/source/data_source.dart';
export 'src/source/list_data_source.dart';
export 'src/source/schema_inference.dart';
