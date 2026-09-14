/// Flutter widgets for the `tessera` pivot-table engine.
///
/// This library re-exports `package:tessera/tessera.dart`, so one import
/// gives you the engine and the widgets:
///
/// * [CubeView] renders a cube driven by a [CubeController], with pinned,
///   merged group headers, expand/collapse and sort gestures, a menu per
///   dimension (sort direction, expand/collapse all) and a keyboard-
///   navigable current cell ([CubeController.selection], [CellAddress]).
/// * [AxisEditor] and [AggregateEditor] edit the axes and aggregates of the
///   controller's spec with drag-and-drop chips; [showDimensionPicker] and
///   [showAggregatePicker] open the dialogs behind their `+` buttons.
/// * [CubeTheme] holds colours, sizes and text styles.
/// * [TesseraLocalizations] connects the engine's [TesseraStrings] to
///   Flutter's `Localizations` (fourteen languages built in).
library;

export 'package:tessera/tessera.dart';

export 'src/l10n/tessera_localizations.dart';
export 'src/widgets/aggregate_editor.dart';
export 'src/widgets/aggregate_picker.dart';
export 'src/widgets/axis_editor.dart';
export 'src/widgets/cube_controller.dart';
export 'src/widgets/cube_theme.dart';
export 'src/widgets/cube_view.dart';
export 'src/widgets/dimension_picker.dart';
export 'src/widgets/expression_field.dart';
export 'src/widgets/filter_editor.dart';
