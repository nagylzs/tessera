/// A font for one role of the exported worksheet. Pure Dart: the colour is
/// an ARGB int (`0xFF1A73E8`), the family a name Excel resolves.
final class XlsxFont {
  const XlsxFont({
    this.family = 'Arial',
    this.size = 10,
    this.bold = false,
    this.italic = false,
    this.color = 0xFF000000,
  });

  final String family;
  final double size;
  final bool bold;
  final bool italic;
  final int color;

  XlsxFont copyWith({
    String? family,
    double? size,
    bool? bold,
    bool? italic,
    int? color,
  }) => XlsxFont(
    family: family ?? this.family,
    size: size ?? this.size,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    color: color ?? this.color,
  );

  @override
  bool operator ==(Object other) =>
      other is XlsxFont &&
      other.family == family &&
      other.size == size &&
      other.bold == bold &&
      other.italic == italic &&
      other.color == color;

  @override
  int get hashCode => Object.hash(family, size, bold, italic, color);
}

/// Colours, fonts and formats of an exported worksheet — the Excel
/// counterpart of the Flutter `CubeTheme`, without any Flutter type:
/// colours are ARGB ints, fonts are [XlsxFont]s. Nothing here is derived
/// from an app theme; a workbook looks the same wherever it is opened.
///
/// Start from [XlsxCubeTheme.brand] to build a theme around one company
/// colour, or from the defaults and override what matters.
final class XlsxCubeTheme {
  const XlsxCubeTheme({
    this.headerFill = 0xFFEEEEEE,
    this.summaryFill = 0xFFDDDDDD,
    this.levelFills = const [0xFFFFFFFF, 0xFFF3F8F7, 0xFFE3EFEC, 0xFFD0E5E0],
    this.borderColor = 0xFFBBBBBB,
    this.cellFont = const XlsxFont(),
    this.headerFont = const XlsxFont(),
    this.summaryFont = const XlsxFont(bold: true),
    this.numberFormat = '#,##0.00',
    this.freezeHeaders = true,
    this.minColumnWidth = 8,
    this.maxColumnWidth = 60,
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
  final XlsxFont cellFont;

  /// Font of dimension titles, group labels and aggregate names.
  final XlsxFont headerFont;

  /// Font of summary rows/columns, headers and cells alike.
  final XlsxFont summaryFont;

  /// Excel number format applied to numeric cells.
  final String numberFormat;

  /// Freeze panes at the corner, so headers stay visible while scrolling.
  final bool freezeHeaders;

  /// Bounds of the content-sized column widths, in characters.
  final double minColumnWidth;
  final double maxColumnWidth;

  XlsxCubeTheme copyWith({
    int? headerFill,
    int? summaryFill,
    List<int>? levelFills,
    int? borderColor,
    XlsxFont? cellFont,
    XlsxFont? headerFont,
    XlsxFont? summaryFont,
    String? numberFormat,
    bool? freezeHeaders,
    double? minColumnWidth,
    double? maxColumnWidth,
  }) => XlsxCubeTheme(
    headerFill: headerFill ?? this.headerFill,
    summaryFill: summaryFill ?? this.summaryFill,
    levelFills: levelFills ?? this.levelFills,
    borderColor: borderColor ?? this.borderColor,
    cellFont: cellFont ?? this.cellFont,
    headerFont: headerFont ?? this.headerFont,
    summaryFont: summaryFont ?? this.summaryFont,
    numberFormat: numberFormat ?? this.numberFormat,
    freezeHeaders: freezeHeaders ?? this.freezeHeaders,
    minColumnWidth: minColumnWidth ?? this.minColumnWidth,
    maxColumnWidth: maxColumnWidth ?? this.maxColumnWidth,
  );

  /// A theme built around one brand colour: headers on [primary] with
  /// [onPrimary] text, data cells shading from white towards a light tint
  /// of [primary] with depth, summaries on a stronger tint, borders in a
  /// muted [primary].
  factory XlsxCubeTheme.brand({
    required int primary,
    int onPrimary = 0xFFFFFFFF,
    String fontFamily = 'Arial',
    int levels = 4,
  }) {
    final tint = mix(0xFFFFFFFF, primary, 0.18);
    final strong = mix(0xFFFFFFFF, primary, 0.32);
    return XlsxCubeTheme(
      headerFill: primary,
      summaryFill: strong,
      levelFills: gradient(0xFFFFFFFF, tint, levels),
      borderColor: mix(0xFFFFFFFF, primary, 0.5),
      headerFont: XlsxFont(family: fontFamily, color: onPrimary),
      cellFont: XlsxFont(family: fontFamily),
      summaryFont: XlsxFont(family: fontFamily, bold: true),
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
