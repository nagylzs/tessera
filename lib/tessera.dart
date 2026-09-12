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
/// 4. **Widgets** — [CubeView] renders a cube driven by a [CubeController];
///    [AxisEditor], [AggregateEditor] and the picker dialogs let the user
///    configure the axes and aggregates.
///
/// Layers 1–3 do not import Flutter; `package:tessera/core.dart` exports
/// just those.
library;

export 'core.dart';
export 'src/widgets/aggregate_editor.dart';
export 'src/widgets/aggregate_picker.dart';
export 'src/widgets/axis_editor.dart';
export 'src/widgets/cube_controller.dart';
export 'src/widgets/cube_theme.dart';
export 'src/widgets/cube_view.dart';
export 'src/widgets/dimension_picker.dart';
