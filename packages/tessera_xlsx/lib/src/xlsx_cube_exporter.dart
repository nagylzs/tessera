import 'dart:typed_data';

import 'package:tessera/tessera.dart';

import 'xlsx_cube_theme.dart';
import 'xlsx_writer.dart';

/// Writes a [CubeLayout] — the rows and columns exactly as expanded — as a
/// formatted worksheet.
///
/// The sheet mirrors `CubeView`: one header row per column dimension plus
/// the aggregate label row, one header column per row dimension, an
/// expanded group's label merged over its subtree in the "rotated L" shape
/// (resolved with [AxisGeometry]), its own row carrying the subtotal, bold
/// summaries, level shading. Every column entry gets one sheet column per
/// exported aggregate. Labels come from [strings], so the export is
/// localized like the widgets.
final class XlsxCubeExporter {
  const XlsxCubeExporter({
    this.strings = const TesseraStringsEn(),
    this.theme = const XlsxCubeTheme(),
    this.emptyGroupLabel,
    this.rowSummaryLabel,
    this.columnSummaryLabel,
  });

  final TesseraStrings strings;
  final XlsxCubeTheme theme;

  /// Overrides of the localized header texts, as on `CubeView`.
  final String? emptyGroupLabel;
  final String? rowSummaryLabel;
  final String? columnSummaryLabel;

  /// The workbook bytes. [aggregates] selects and orders the value
  /// columns under each column entry; default: every aggregate of the spec.
  /// [sheetName] is trimmed to Excel's rules (31 characters, no
  /// `[]:*?/\`).
  Uint8List export(
    CubeLayout layout, {
    List<Aggregate>? aggregates,
    String sheetName = 'Pivot',
  }) {
    final aggs = aggregates ?? layout.spec.aggregates;
    for (final a in aggs) {
      if (!layout.spec.aggregates.contains(a)) {
        throw ArgumentError.value(a.id, 'aggregates', 'not in the spec');
      }
    }
    return _Export(this, layout, aggs, _sheetName(sheetName)).run();
  }

  static String _sheetName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    final short = cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned;
    return short.isEmpty ? 'Pivot' : short;
  }
}

final class _Export {
  _Export(this.exporter, this.layout, this.aggregates, String sheetName)
    : writer = XlsxWriter(
        sheetName: sheetName,
        numberFormat: exporter.theme.numberFormat,
        borderColor: exporter.theme.borderColor,
      ),
      grid = CubeGrid.of(
        layout,
        strings: exporter.strings,
        aggregates: aggregates,
        emptyGroupLabel: exporter.emptyGroupLabel,
        rowSummaryLabel: exporter.rowSummaryLabel,
        columnSummaryLabel: exporter.columnSummaryLabel,
      );

  final XlsxCubeExporter exporter;
  final CubeLayout layout;
  final List<Aggregate> aggregates;
  final XlsxWriter writer;
  final CubeGrid grid;

  XlsxCubeTheme get theme => exporter.theme;

  /// Longest text per sheet column, for the widths.
  final _longest = <int, int>{};

  Uint8List run() {
    for (var r = 0; r < grid.rowCount; r++) {
      for (var c = 0; c < grid.columnCount; c++) {
        final cell = grid.cellAt(r, c);
        final styleIndex = _styleOf(cell);
        if (!cell.isOrigin) {
          writer.cell(r, c, null, styleIndex); // covered by a merge
          continue;
        }
        writer.cell(r, c, cell.value, styleIndex);
        writer.merge(r, c, cell.rowSpan, cell.columnSpan);
        final value = cell.value;
        if (value != null && cell.columnSpan == 1) {
          final n = value.toString().length;
          if (n > (_longest[c] ?? 0)) _longest[c] = n;
        }
      }
    }
    for (final e in _longest.entries) {
      writer.columnWidth(
        e.key,
        (e.value * 1.1 + 2).clamp(theme.minColumnWidth, theme.maxColumnWidth),
      );
    }
    if (theme.freezeHeaders) {
      writer.freeze(rows: grid.headerRows, columns: grid.headerColumns);
    }
    return writer.build();
  }

  /// Header cells on the header fill in the header font, data cells on
  /// their level's fill in the cell font; anything on a summary row or
  /// column takes the summary fill and font.
  int _styleOf(GridCell cell) {
    if (cell.kind == GridCellKind.data) {
      final fills = theme.levelFills;
      final fill = cell.isSummary
          ? theme.summaryFill
          : fills.isEmpty
          ? 0xFFFFFFFF
          : fills[cell.level.clamp(0, fills.length - 1)];
      return writer.style(
        fill,
        font: cell.isSummary ? theme.summaryFont : theme.cellFont,
        right: true,
      );
    }
    return writer.style(
      cell.isSummary ? theme.summaryFill : theme.headerFill,
      font: cell.isSummary ? theme.summaryFont : theme.headerFont,
      right: cell.alignRight,
    );
  }
}
