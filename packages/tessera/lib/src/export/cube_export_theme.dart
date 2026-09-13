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
    this.borderColor = 0xFFBBBBBB,
    this.cellFont = const ExportFont(),
    this.headerFont = const ExportFont(),
    this.summaryFont = const ExportFont(bold: true),
    this.numberFormat = const NumberFormat(),
  });

  /// Background of the header band and the row header.
  final int headerFill;

  /// Background of summary rows/columns (headers and cells).
  final int summaryFill;

  /// Backgrounds of data cells by level: row depth + column depth, from
  /// `0`; the last entry repeats for deeper cells. See [gradient].
  final List<int> levelFills;

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

  CubeExportTheme copyWith({
    int? headerFill,
    int? summaryFill,
    List<int>? levelFills,
    int? borderColor,
    ExportFont? cellFont,
    ExportFont? headerFont,
    ExportFont? summaryFont,
    NumberFormat? numberFormat,
  }) => CubeExportTheme(
    headerFill: headerFill ?? this.headerFill,
    summaryFill: summaryFill ?? this.summaryFill,
    levelFills: levelFills ?? this.levelFills,
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
