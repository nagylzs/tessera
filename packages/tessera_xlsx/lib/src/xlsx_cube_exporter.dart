import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tessera/tessera.dart';

import 'xlsx_writer.dart';

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
    this.minColumnWidth = 8,
    this.maxColumnWidth = 60,
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

  /// Bounds of the content-sized column widths, in characters.
  final double minColumnWidth;
  final double maxColumnWidth;
}

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
    this.style = const XlsxCubeStyle(),
    this.emptyGroupLabel,
    this.rowSummaryLabel,
    this.columnSummaryLabel,
  });

  final TesseraStrings strings;
  final XlsxCubeStyle style;

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
        numberFormat: exporter.style.numberFormat,
        borderColor: exporter.style.borderColor,
      ),
      rowGeometry = AxisGeometry(layout.rows),
      columnGeometry = AxisGeometry(layout.columns);

  final XlsxCubeExporter exporter;
  final CubeLayout layout;
  final List<Aggregate> aggregates;
  final XlsxWriter writer;
  final AxisGeometry rowGeometry;
  final AxisGeometry columnGeometry;

  XlsxCubeStyle get style => exporter.style;
  TesseraStrings get strings => exporter.strings;
  CubeSpec get spec => layout.spec;
  int get rowDepth => spec.rows.depth;
  int get columnDepth => spec.columns.depth;

  /// Sheet columns per column entry.
  int get perEntry => math.max(aggregates.length, 1);

  int get headerColumns => math.max(rowDepth, 1);
  int get levelRows => math.max(columnDepth, 1);
  int get headerRows => levelRows + 1;

  /// Longest text per sheet column, for the widths.
  final _longest = <int, int>{};

  Uint8List run() {
    _corner();
    _columnHeaders();
    _rowHeaders();
    _cells();
    for (final e in _longest.entries) {
      writer.columnWidth(
        e.key,
        (e.value * 1.1 + 2).clamp(style.minColumnWidth, style.maxColumnWidth),
      );
    }
    if (style.freezeHeaders) {
      writer.freeze(rows: headerRows, columns: headerColumns);
    }
    return writer.build();
  }

  int _headerStyle({bool summary = false, bool right = false}) => writer.style(
    summary ? style.summaryFill : style.headerFill,
    bold: summary,
    right: right,
  );

  void _put(int row, int column, Object? value, int styleIndex) {
    writer.cell(row, column, value, styleIndex);
    if (value != null) {
      final n = value.toString().length;
      if (n > (_longest[column] ?? 0)) _longest[column] = n;
    }
  }

  // ---------------------------------------------------------------- corner

  void _corner() {
    final plain = _headerStyle();
    for (var r = 0; r < levelRows; r++) {
      if (columnDepth == 0) {
        for (var c = 0; c < headerColumns; c++) {
          _put(r, c, null, plain);
        }
        continue;
      }
      final title = strings.dimensionLabel(
        spec.columns.dimensions[r].dimension,
        layout.facts,
      );
      _put(r, 0, title, _headerStyle(right: true));
      for (var c = 1; c < headerColumns; c++) {
        _put(r, c, null, plain);
      }
      writer.merge(r, 0, 1, headerColumns);
    }
    for (var c = 0; c < headerColumns; c++) {
      final title = rowDepth == 0
          ? null
          : strings.dimensionLabel(
              spec.rows.dimensions[c].dimension,
              layout.facts,
            );
      _put(levelRows, c, title, plain);
    }
  }

  // -------------------------------------------------------- column header

  void _columnHeaders() {
    final columns = layout.columns.entries;
    for (var j = 0; j < columns.length; j++) {
      final entry = columns[j];
      final start = headerColumns + j * perEntry;
      final summary = entry.isSummary;
      // aggregate label row
      for (var a = 0; a < perEntry; a++) {
        final label = aggregates.isEmpty
            ? null
            : strings.aggregateLabel(aggregates[a], layout.facts);
        _put(
          levelRows,
          start + a,
          label,
          _headerStyle(summary: summary, right: true),
        );
      }
      if (columnDepth == 0) {
        _put(
          0,
          start,
          _entryText(entry, isRow: false),
          _headerStyle(summary: true),
        );
        for (var a = 1; a < perEntry; a++) {
          _put(0, start + a, null, _headerStyle(summary: true));
        }
        writer.merge(0, start, 1, perEntry);
        continue;
      }
      for (var level = 0; level < columnDepth; level++) {
        final area = columnGeometry.areaAt(level, j);
        final owner = columns[area.entryIndex];
        final isOrigin = area.levelStart == level && area.entryStart == j;
        final s = _headerStyle(summary: owner.isSummary);
        for (var a = 0; a < perEntry; a++) {
          _put(
            level,
            start + a,
            isOrigin && area.isLabel && a == 0
                ? _entryText(owner, isRow: false)
                : null,
            s,
          );
        }
        if (isOrigin) {
          writer.merge(level, start, area.levelSpan, area.entrySpan * perEntry);
        }
      }
    }
  }

  // ------------------------------------------------------------ row header

  void _rowHeaders() {
    final rows = layout.rows.entries;
    for (var i = 0; i < rows.length; i++) {
      final entry = rows[i];
      final sheetRow = headerRows + i;
      if (rowDepth == 0) {
        _put(
          sheetRow,
          0,
          _entryText(entry, isRow: true),
          _headerStyle(summary: true),
        );
        continue;
      }
      for (var level = 0; level < rowDepth; level++) {
        final area = rowGeometry.areaAt(level, i);
        final owner = rows[area.entryIndex];
        final isOrigin = area.levelStart == level && area.entryStart == i;
        _put(
          sheetRow,
          level,
          isOrigin && area.isLabel ? _entryText(owner, isRow: true) : null,
          _headerStyle(summary: owner.isSummary),
        );
        if (isOrigin) {
          writer.merge(sheetRow, level, area.entrySpan, area.levelSpan);
        }
      }
    }
  }

  // ------------------------------------------------------------ data cells

  void _cells() {
    final rows = layout.rows.entries;
    final columns = layout.columns.entries;
    final fills = style.levelFills;
    for (var i = 0; i < rows.length; i++) {
      for (var j = 0; j < columns.length; j++) {
        final summary = rows[i].isSummary || columns[j].isSummary;
        final level = rows[i].depth + columns[j].depth - 2;
        final fill = summary
            ? style.summaryFill
            : fills.isEmpty
            ? 0xFFFFFFFF
            : fills[level.clamp(0, fills.length - 1)];
        final s = writer.style(fill, bold: summary, right: true);
        final cell = layout.cellAt(i, j);
        for (var a = 0; a < perEntry; a++) {
          final value = cell.isEmpty || aggregates.isEmpty
              ? null
              : cell.aggregate<Object?>(aggregates[a]);
          _put(headerRows + i, headerColumns + j * perEntry + a, value, s);
        }
      }
    }
  }

  String _entryText(HeaderEntry entry, {required bool isRow}) => entry.isSummary
      ? (isRow ? exporter.rowSummaryLabel : exporter.columnSummaryLabel) ??
            strings.total
      : entry.value == null
      ? exporter.emptyGroupLabel ?? strings.emptyGroup
      : strings.formatValue(entry.dimension, entry.value);
}
