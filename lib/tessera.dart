/// Tessera: import tabular data, group and aggregate it in a pivot cube, and
/// display it.
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
/// 4. **Widgets** — [CubeView] renders a cube driven by a [CubeController].
///
/// Layers 1–3 do not import Flutter.
library;

export 'src/cube/aggregate.dart';
export 'src/cube/cube.dart';
export 'src/cube/cube_layout.dart';
export 'src/cube/cube_spec.dart';
export 'src/cube/dimension_path.dart';
export 'src/cube/expansion_state.dart';
export 'src/cube/filter.dart';
export 'src/facts/dimension.dart';
export 'src/facts/fact_table.dart';
export 'src/facts/importer.dart';
export 'src/facts/measure.dart';
export 'src/facts/standard_dimensions.dart';
export 'src/schema/column_spec.dart';
export 'src/schema/column_type.dart';
export 'src/schema/schema.dart';
export 'src/schema/value_parsing.dart';
export 'src/source/csv_data_source.dart';
export 'src/source/data_source.dart';
export 'src/source/list_data_source.dart';
export 'src/source/schema_inference.dart';
export 'src/widgets/cube_controller.dart';
export 'src/widgets/cube_theme.dart';
export 'src/widgets/cube_view.dart';
