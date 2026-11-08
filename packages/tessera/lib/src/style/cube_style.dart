import '../export/cube_export_theme.dart';
import '../export/cube_grid.dart';

/// What a cell of a pivot table is, for a [CubeStyle].
enum CellRole {
  /// A value inside the table, on no total row or column.
  value,

  /// A value on the total row or the total column.
  total,

  /// A row group's label, and the blank leg beside an expanded group's.
  rowLabel,

  /// A column group's label, and the blank leg below an expanded group's.
  columnLabel,

  /// The label of the total row or column ("Total").
  totalLabel,

  /// A dimension's name, above the row groups or beside the column groups.
  title,

  /// A value's name (an aggregate's label) under a column group.
  valueName,

  /// The unused corner.
  corner,
}

/// One cell as a [CubeStyle] sees it: its [role] and its depth on each
/// axis.
///
/// [rowLevel] is the depth of the row the cell is on (the row group's,
/// from `0` for the first row dimension), [columnLevel] that of its
/// column; `-1` where the cell has none: a total row or column, the
/// column header band for [rowLevel], the row header for [columnLevel].
/// A title takes the level of its dimension on its own axis.
final class StyleCell {
  const StyleCell(this.role, {this.rowLevel = -1, this.columnLevel = -1});

  /// The cell of an exported [CubeGrid] as a style sees it.
  factory StyleCell.ofGrid(GridCell cell) => StyleCell(
    switch (cell.kind) {
      GridCellKind.data => cell.isSummary ? CellRole.total : CellRole.value,
      GridCellKind.rowLabel =>
        cell.isSummary ? CellRole.totalLabel : CellRole.rowLabel,
      GridCellKind.columnLabel =>
        cell.isSummary ? CellRole.totalLabel : CellRole.columnLabel,
      GridCellKind.aggregateLabel =>
        cell.isSummary ? CellRole.totalLabel : CellRole.valueName,
      GridCellKind.rowTitle || GridCellKind.columnTitle => CellRole.title,
      GridCellKind.blank => CellRole.corner,
    },
    rowLevel: cell.kind == GridCellKind.columnTitle ? -1 : cell.rowLevel,
    columnLevel: cell.kind == GridCellKind.rowTitle ? -1 : cell.columnLevel,
  );

  final CellRole role;
  final int rowLevel;
  final int columnLevel;

  /// How deep the cell is, for what a style varies by depth apart from
  /// colours (fonts): a value's row and column depths added, a header's
  /// depth on its axis, `0` for totals and the corner.
  int get depth => switch (role) {
    CellRole.total || CellRole.totalLabel || CellRole.corner => 0,
    // a header has one of the two
    _ => _atLeast0(rowLevel) + _atLeast0(columnLevel),
  };

  /// Whether the cell belongs to the row axis's depths (a row label, a row
  /// dimension's title), for [DepthColoring].
  bool get onRowAxis => rowLevel >= 0 && columnLevel < 0;

  /// Whether the cell belongs to the column axis's depths.
  bool get onColumnAxis => columnLevel >= 0 && rowLevel < 0;

  @override
  bool operator ==(Object other) =>
      other is StyleCell &&
      other.role == role &&
      other.rowLevel == rowLevel &&
      other.columnLevel == columnLevel;

  @override
  int get hashCode => Object.hash(role, rowLevel, columnLevel);

  @override
  String toString() => 'StyleCell(${role.name}, $rowLevel, $columnLevel)';
}

int _atLeast0(int level) => level < 0 ? 0 : level;

/// Which depths pick a cell's colours: the user's choice, whatever the
/// style. A style gives its colours by depth; this decides which depth
/// counts. Fonts follow the cell's own [StyleCell.depth] either way.
enum DepthColoring {
  /// One colour for every depth: the style's first.
  off,

  /// The row's depth: a value takes its row's colour, as its row label.
  rows,

  /// The column's depth, likewise.
  columns,

  /// Both: a value's row and column depths added; each header by its own
  /// axis.
  both;

  bool get byRows => this == rows || this == both;
  bool get byColumns => this == columns || this == both;

  /// The depth that picks [cell]'s colours.
  int colorDepth(StyleCell cell) {
    final row = byRows ? _atLeast0(cell.rowLevel) : 0;
    final column = byColumns ? _atLeast0(cell.columnLevel) : 0;
    return switch (cell.role) {
      CellRole.value => row + column,
      CellRole.total || CellRole.totalLabel || CellRole.corner => 0,
      _ => cell.onRowAxis ? row : column,
    };
  }
}

/// The font families a style may name. Each user of a style maps them to
/// fonts it has: an app to the fonts it bundles, a document to names its
/// readers' machines resolve ([ExportFamilies]).
enum StyleFamily {
  /// Without serifs (Arial, Helvetica, Noto Sans).
  sans,

  /// With serifs (Times New Roman, Noto Serif).
  serif,

  /// Every character as wide as the others (Courier New, Noto Sans Mono),
  /// which lines up the digits of a column.
  mono,
}

/// How one cell looks: plain values, no Flutter types.
final class CellLook {
  const CellLook({
    required this.fill,
    required this.text,
    this.family,
    this.size = 12,
    this.bold = false,
    this.italic = false,
  });

  /// The background, ARGB (`0xFFFFFFFF`).
  final int fill;

  /// The text's colour, ARGB.
  final int text;

  /// `null`: what the surroundings use (the app's own font on a screen,
  /// [StyleFamily.sans] in a document).
  final StyleFamily? family;

  /// In logical pixels, as on a screen. Documents take five sixths of it
  /// in points, to the nearest half point ([exportFont]): 12 on the screen
  /// is 10 in a spreadsheet, as their defaults go, 11 is 9, 14 is 11.5.
  final double size;

  final bool bold;
  final bool italic;

  /// The font of a document cell that looks like this.
  ExportFont exportFont([ExportFamilies families = const ExportFamilies()]) =>
      ExportFont(
        family: families.of(family),
        size: (size * 5 / 6 * 2).roundToDouble() / 2,
        bold: bold,
        italic: italic,
        color: text,
      );

  @override
  bool operator ==(Object other) =>
      other is CellLook &&
      other.fill == fill &&
      other.text == text &&
      other.family == family &&
      other.size == size &&
      other.bold == bold &&
      other.italic == italic;

  @override
  int get hashCode => Object.hash(fill, text, family, size, bold, italic);

  @override
  String toString() =>
      'CellLook(${fill.toRadixString(16)} / ${text.toRadixString(16)}, '
      '${family?.name ?? 'default'} $size${bold ? ' bold' : ''}'
      '${italic ? ' italic' : ''})';
}

/// The font names a document gives each [StyleFamily]: ones its readers'
/// machines have. A PDF embeds the fonts it is given under these names.
final class ExportFamilies {
  const ExportFamilies({
    this.sans = 'Arial',
    this.serif = 'Times New Roman',
    this.mono = 'Courier New',
  });

  final String sans;
  final String serif;
  final String mono;

  /// The name for [family]; `null` is [sans].
  String of(StyleFamily? family) => switch (family) {
    StyleFamily.serif => serif,
    StyleFamily.mono => mono,
    StyleFamily.sans || null => sans,
  };
}

/// The colours around the cells. `null`: what the app's theme gives.
final class StyleChrome {
  const StyleChrome({
    required this.border,
    this.selection,
    this.sortKey,
    this.icon,
  });

  /// The grid lines, ARGB.
  final int border;

  /// The current cell's outline.
  final int? selection;

  /// Laid over the column whose values sort the rows; translucent.
  final int? sortKey;

  /// The headers' icons (expand, collapse, sort, the menu button); by
  /// default the header text's colour.
  final int? icon;
}

/// Sizes of the grid, in logical pixels.
final class StyleMetrics {
  const StyleMetrics({
    this.rowHeight = 28,
    this.headerRowHeight = 28,
    this.padding = 6,
    this.minColumnWidth = 72,
    this.minRowHeaderWidth = 100,
  });

  /// A row of values or row labels.
  final double rowHeight;

  /// A row of the column header band.
  final double headerRowHeight;

  /// Space at each side of a cell's text.
  final double padding;

  /// The narrowest a column of values gets, however short its texts.
  final double minColumnWidth;

  /// The narrowest a column of row labels gets.
  final double minRowHeaderWidth;
}

/// How a pivot table looks, cell by cell: on a screen (`tessera_flutter`'s
/// `CubeTheme.fromStyle`) and in every exported document
/// ([CubeExportTheme.fromStyle]) alike.
///
/// A style answers for each [StyleCell] — its role and depth — with a
/// [CellLook], in a light and, where it has one, a dark variant; the
/// [DepthColoring] the user chose decides which depth picks the colours.
/// [JsonCubeStyle] reads one from a JSON document; implement this for
/// styles computed in code.
abstract interface class CubeStyle {
  /// Unique among the styles an app offers; what it stores as the choice.
  String get id;

  /// The style's name in the language [languageCode] (`en`, `hu`, …),
  /// English where it has none.
  String name(String languageCode);

  /// Whether it has a dark variant of its own. A style without one looks
  /// the same in dark mode, like paper.
  bool get hasDark;

  /// How [cell] looks, in the dark variant when [dark] (and [hasDark]).
  CellLook lookOf(
    StyleCell cell, {
    bool dark = false,
    DepthColoring coloring = DepthColoring.both,
  });

  /// The colours around the cells.
  StyleChrome chrome({bool dark = false});

  StyleMetrics get metrics;
}
