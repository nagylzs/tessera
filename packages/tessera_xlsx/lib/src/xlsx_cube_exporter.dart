import 'dart:typed_data';

import 'package:tessera/tessera.dart';

/// Colours and formats of an exported worksheet. Colours are ARGB ints
/// (`0xFFEEEEEE`), so no Flutter type is needed.
final class XlsxCubeStyle {
  const XlsxCubeStyle({
    this.headerFill = 0xFFEEEEEE,
    this.summaryFill = 0xFFDDDDDD,
    this.levelFills = const [0xFFFFFFFF, 0xFFF3F8F7, 0xFFE3EFEC, 0xFFD0E5E0],
    this.borderColor = 0xFFBBBBBB,
    this.numberFormat = '#,##0.00',
    this.freezeHeaders = true,
  });

  /// Background of the header band and the row header.
  final int headerFill;

  /// Background of summary rows/columns (headers and cells).
  final int summaryFill;

  /// Backgrounds of data cells by level: row depth + column depth, from
  /// `0`; the last entry repeats for deeper cells.
  final List<int> levelFills;

  final int borderColor;

  /// Excel number format applied to numeric cells.
  final String numberFormat;

  /// Freeze panes at the corner, so headers stay visible while scrolling.
  final bool freezeHeaders;
}

/// Writes a [CubeLayout] — the rows and columns exactly as expanded — as a
/// formatted worksheet.
///
/// The sheet mirrors `CubeView`: one header row per column dimension plus
/// the aggregate label row, one header column per row dimension, an
/// expanded group's label merged over its subtree in the "rotated L" shape
/// (resolved with [AxisGeometry]), its own row carrying the subtotal, bold
/// summaries, level shading. Labels come from [strings], so the export is
/// localized like the widgets.
final class XlsxCubeExporter {
  const XlsxCubeExporter({
    this.strings = const TesseraStringsEn(),
    this.style = const XlsxCubeStyle(),
  });

  final TesseraStrings strings;
  final XlsxCubeStyle style;

  /// The workbook bytes. [aggregates] selects and orders the value
  /// columns under each column entry; default: every aggregate of the spec.
  Uint8List export(
    CubeLayout layout, {
    List<Aggregate>? aggregates,
    String sheetName = 'Pivot',
  }) => throw UnimplementedError('XlsxCubeExporter is not implemented yet');
}
