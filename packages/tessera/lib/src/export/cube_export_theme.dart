import '../color/hue_levels.dart';
import 'cube_grid.dart';

/// A font for one role of an exported document. Pure Dart: the colour is
/// an ARGB int (`0xFF1A73E8`), the family a name the target application
/// resolves.
final class ExportFont {
  const ExportFont({
    this.family = 'Arial',
    this.size = 10,
    this.bold = false,
    this.italic = false,
    this.color = 0xFF000000,
  });

  final String family;

  /// In points.
  final double size;
  final bool bold;
  final bool italic;
  final int color;

  ExportFont copyWith({
    String? family,
    double? size,
    bool? bold,
    bool? italic,
    int? color,
  }) => ExportFont(
    family: family ?? this.family,
    size: size ?? this.size,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    color: color ?? this.color,
  );

  @override
  bool operator ==(Object other) =>
      other is ExportFont &&
      other.family == family &&
      other.size == size &&
      other.bold == bold &&
      other.italic == italic &&
      other.color == color;

  @override
  int get hashCode => Object.hash(family, size, bold, italic, color);
}

/// How numbers are shown, in terms every format can express; each
/// exporter translates it (`#,##0.00` in Excel, a `number:number-style`
/// in ODS, formatted text in PDF) and may offer its native form as an
/// override.
final class NumberFormat {
  const NumberFormat({this.decimals = 2, this.grouping = true})
    : assert(decimals >= 0);

  /// Digits after the decimal mark.
  final int decimals;

  /// Thousands separators.
  final bool grouping;

  @override
  bool operator ==(Object other) =>
      other is NumberFormat &&
      other.decimals == decimals &&
      other.grouping == grouping;

  @override
  int get hashCode => Object.hash(decimals, grouping);
}

/// Which nesting level picks a data cell's fill from
/// [CubeExportTheme.levelFills].
enum LevelBasis {
  /// Row depth + column depth ([GridCell.level]): deeper cells on both
  /// axes get later fills — suits a gradient.
  combined,

  /// The row level only ([GridCell.rowLevel]): a cell takes its row
  /// group's fill whatever column it is in — suits per-level hues, where a
  /// cell should match its row header.
  row,
}

/// Colours, fonts and the number format of an exported document — what
/// every renderer of a [CubeGrid] needs (Excel, ODS, PDF, …), without any
/// Flutter type: colours are ARGB ints, fonts are [ExportFont]s. Nothing is
/// derived from an app theme; a document looks the same wherever it is
/// opened. Format-specific behaviour (frozen panes, column widths, page
/// size) lives on the exporters.
///
/// Start from [CubeExportTheme.brand] to build a theme around one company
/// colour, or from the defaults and override what matters.
final class CubeExportTheme {
  const CubeExportTheme({
    this.headerFill = 0xFFEEEEEE,
    this.summaryFill = 0xFFDDDDDD,
    this.levelFills = const [0xFFFFFFFF, 0xFFF3F8F7, 0xFFE3EFEC, 0xFFD0E5E0],
    this.levelBasis = LevelBasis.combined,
    this.rowHeaderFills = const [],
    this.columnHeaderFills = const [],
    this.borderColor = 0xFFBBBBBB,
    this.cellFont = const ExportFont(),
    this.headerFont = const ExportFont(),
    this.summaryFont = const ExportFont(bold: true),
    this.numberFormat = const NumberFormat(),
  });

  /// Background of the header band and the row header, where
  /// [rowHeaderFills] / [columnHeaderFills] do not apply (titles, labels
  /// and aggregate names of a level beyond the lists, the blank corner).
  final int headerFill;

  /// Backgrounds of the row header by row level (the dimension's title,
  /// its group labels and legs); empty (the default) means [headerFill],
  /// the last entry repeats for deeper levels.
  final List<int> rowHeaderFills;

  /// Backgrounds of the column header band by column level, likewise; an
  /// aggregate name takes its column entry's level.
  final List<int> columnHeaderFills;

  /// Background of summary rows/columns (headers and cells).
  final int summaryFill;

  /// Backgrounds of data cells by level, from `0`; the last entry repeats
  /// for deeper cells. Which level indexes the list is [levelBasis]. See
  /// [gradient] and [HueLevels].
  final List<int> levelFills;

  /// Which nesting level indexes [levelFills].
  final LevelBasis levelBasis;

  final int borderColor;

  /// Font of data cells.
  final ExportFont cellFont;

  /// Font of dimension titles, group labels and aggregate names.
  final ExportFont headerFont;

  /// Font of summary rows/columns, headers and cells alike.
  final ExportFont summaryFont;

  final NumberFormat numberFormat;

  /// The fill of a data cell at [level] (`-1` or a summary → [summaryFill]).
  int levelFill(int level, {bool summary = false}) {
    if (summary) return summaryFill;
    if (levelFills.isEmpty) return 0xFFFFFFFF;
    return levelFills[level.clamp(0, levelFills.length - 1)];
  }

  /// The fill of a row header cell at row [level].
  int rowHeaderFill(int level) => _headerFill(rowHeaderFills, level);

  /// The fill of a column header cell at column [level].
  int columnHeaderFill(int level) => _headerFill(columnHeaderFills, level);

  int _headerFill(List<int> fills, int level) => fills.isEmpty || level < 0
      ? headerFill
      : fills[level.clamp(0, fills.length - 1)];

  /// The index into [levelFills] a data [cell] uses under [levelBasis]
  /// (`-1` for summaries and header cells).
  int levelOf(GridCell cell) {
    if (cell.kind != GridCellKind.data || cell.isSummary) return -1;
    return switch (levelBasis) {
      LevelBasis.combined => cell.level,
      LevelBasis.row => cell.rowLevel,
    };
  }

  /// The background of any [cell] of a `CubeGrid`: summaries take
  /// [summaryFill], data cells their level's fill, row header cells
  /// [rowHeaderFill], column header cells (titles, labels, aggregate
  /// names) [columnHeaderFill], the blank corner [headerFill].
  int fillOf(GridCell cell) {
    if (cell.isSummary) return summaryFill;
    return switch (cell.kind) {
      GridCellKind.data => levelFill(levelOf(cell)),
      GridCellKind.rowTitle ||
      GridCellKind.rowLabel => rowHeaderFill(cell.rowLevel),
      GridCellKind.columnTitle ||
      GridCellKind.columnLabel ||
      GridCellKind.aggregateLabel => columnHeaderFill(cell.columnLevel),
      GridCellKind.blank => headerFill,
    };
  }

  /// The font of any [cell]: [summaryFont] on summaries, [cellFont] on
  /// data cells, [headerFont] elsewhere.
  ExportFont fontOf(GridCell cell) => cell.isSummary
      ? summaryFont
      : cell.kind == GridCellKind.data
      ? cellFont
      : headerFont;

  CubeExportTheme copyWith({
    int? headerFill,
    int? summaryFill,
    List<int>? levelFills,
    LevelBasis? levelBasis,
    List<int>? rowHeaderFills,
    List<int>? columnHeaderFills,
    int? borderColor,
    ExportFont? cellFont,
    ExportFont? headerFont,
    ExportFont? summaryFont,
    NumberFormat? numberFormat,
  }) => CubeExportTheme(
    headerFill: headerFill ?? this.headerFill,
    summaryFill: summaryFill ?? this.summaryFill,
    levelFills: levelFills ?? this.levelFills,
    levelBasis: levelBasis ?? this.levelBasis,
    rowHeaderFills: rowHeaderFills ?? this.rowHeaderFills,
    columnHeaderFills: columnHeaderFills ?? this.columnHeaderFills,
    borderColor: borderColor ?? this.borderColor,
    cellFont: cellFont ?? this.cellFont,
    headerFont: headerFont ?? this.headerFont,
    summaryFont: summaryFont ?? this.summaryFont,
    numberFormat: numberFormat ?? this.numberFormat,
  );

  /// A theme built around one brand colour: headers on [primary] with
  /// [onPrimary] text, data cells shading from white towards a light tint
  /// of [primary] with depth, summaries on a stronger tint, borders in a
  /// muted [primary].
  factory CubeExportTheme.brand({
    required int primary,
    int onPrimary = 0xFFFFFFFF,
    String fontFamily = 'Arial',
    int levels = 4,
  }) {
    final tint = mix(0xFFFFFFFF, primary, 0.18);
    final strong = mix(0xFFFFFFFF, primary, 0.32);
    return CubeExportTheme(
      headerFill: primary,
      summaryFill: strong,
      levelFills: gradient(0xFFFFFFFF, tint, levels),
      borderColor: mix(0xFFFFFFFF, primary, 0.5),
      headerFont: ExportFont(family: fontFamily, color: onPrimary),
      cellFont: ExportFont(family: fontFamily),
      summaryFont: ExportFont(family: fontFamily, bold: true),
    );
  }

  /// A theme whose nesting levels differ in hue only ([HueLevels]): the
  /// row levels take the first [rowLevels] hues, the column levels the
  /// next [columnLevels] ones, data cells follow their row level
  /// ([LevelBasis.row]), headers are the same hues with more chroma, and
  /// summaries stay a neutral grey. Cubes deeper than the counts repeat
  /// the last fill.
  factory CubeExportTheme.hueLevels({
    HueLevels levels = const HueLevels(),
    int rowLevels = 4,
    int columnLevels = 4,
    int summaryFill = 0xFFDDDDDD,
    int borderColor = 0xFFBBBBBB,
    String fontFamily = 'Arial',
  }) => CubeExportTheme(
    headerFill: levels.headerFill(0),
    summaryFill: summaryFill,
    levelFills: levels.fills(rowLevels),
    levelBasis: LevelBasis.row,
    rowHeaderFills: levels.headerFills(rowLevels),
    columnHeaderFills: levels.headerFills(columnLevels, from: rowLevels),
    borderColor: borderColor,
    headerFont: ExportFont(family: fontFamily),
    cellFont: ExportFont(family: fontFamily),
    summaryFont: ExportFont(family: fontFamily, bold: true),
  );

  /// [steps] colours interpolated from [from] to [to] (both inclusive),
  /// for [levelFills].
  static List<int> gradient(int from, int to, int steps) {
    if (steps <= 1) return [from];
    return [for (var i = 0; i < steps; i++) mix(from, to, i / (steps - 1))];
  }

  /// [a] blended towards [b] by [t] (`0` = [a], `1` = [b]), per ARGB
  /// channel.
  static int mix(int a, int b, double t) {
    int channel(int shift) {
      final x = (a >> shift) & 0xFF, y = (b >> shift) & 0xFF;
      return (x + (y - x) * t).round().clamp(0, 255);
    }

    return (channel(24) << 24) |
        (channel(16) << 16) |
        (channel(8) << 8) |
        channel(0);
  }
}
