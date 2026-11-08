import 'package:flutter/material.dart';
import 'package:tessera/tessera.dart';

import '../l10n/tessera_localizations.dart';
import 'cube_theme.dart';

/// A small pivot table drawn in [theme], to show what a style looks like —
/// a tile of a style gallery. Not a [CubeView]: a fixed sample of two
/// levels on each axis, so that every role at both depths shows (titles,
/// labels, a group's leg, value names, values, totals), with the expand
/// icons and the current cell's outline; light enough for a page of them.
///
/// The texts are the localized date parts, months, weekdays and quarters
/// of [TesseraLocalizations], so it reads in the app's language. It is
/// laid out at the theme's own sizes, whatever the system's text size,
/// and [fit] into its constraints; a gallery that wants its styles' sizes
/// to compare gives every preview the same box and [BoxFit.none].
class CubeStylePreview extends StatelessWidget {
  const CubeStylePreview({
    super.key,
    required this.theme,
    this.brightness,
    this.fit = BoxFit.contain,
  });

  /// The look to show, usually `CubeTheme.fromStyle`.
  final CubeTheme theme;

  /// The variant to show, whatever the app's: [Brightness.dark] for a
  /// style's dark variant. `null`: the app's.
  final Brightness? brightness;

  /// How the sample fits its constraints.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    if (brightness != null && brightness != appTheme.brightness) {
      return Theme(
        data: ThemeData(
          brightness: brightness,
          colorSchemeSeed: appTheme.colorScheme.primary,
        ),
        child: Builder(builder: (context) => _grid(context)),
      );
    }
    return _grid(context);
  }

  Widget _grid(BuildContext context) {
    final t = theme.resolve(context);
    final strings = TesseraLocalizations.of(context);
    final ambient = DefaultTextStyle.of(context).style;
    ScreenLook look(StyleCell cell) =>
        t.lookOf(cell, rowLevels: 2, columnLevels: 2);
    String number(num v) => const NumberFormat(decimals: 0).format(v, strings);
    // date parts are named for use inside labels ("Date year")
    String title(String s) =>
        s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

    // two header columns and four value columns (2025's own, Q1, Q2,
    // Total); three header rows and five rows
    final cells = <_Cell>[];
    void cell(
      int r,
      int c,
      StyleCell styleCell, {
      String text = '',
      int rowSpan = 1,
      int columnSpan = 1,
      bool right = false,
      IconData? icon,
      bool selected = false,
    }) => cells.add(
      _Cell(
        r,
        c,
        look(styleCell),
        text: text,
        rowSpan: rowSpan,
        columnSpan: columnSpan,
        right: right,
        icon: icon,
        selected: selected,
      ),
    );

    const title0 = StyleCell(CellRole.title, columnLevel: 0);
    const title1 = StyleCell(CellRole.title, columnLevel: 1);
    const column0 = StyleCell(CellRole.columnLabel, columnLevel: 0);
    const column1 = StyleCell(CellRole.columnLabel, columnLevel: 1);
    const row0 = StyleCell(CellRole.rowLabel, rowLevel: 0);
    const row1 = StyleCell(CellRole.rowLabel, rowLevel: 1);
    const totalLabel = StyleCell(CellRole.totalLabel);
    StyleCell value(int row, int column) =>
        StyleCell(CellRole.value, rowLevel: row, columnLevel: column);
    StyleCell total(int row) => StyleCell(CellRole.total, rowLevel: row);
    final count = title(strings.countLabel);

    // the column header band
    cell(
      0,
      0,
      title0,
      text: title(strings.datePartName(DatePart.year)),
      columnSpan: 2,
      right: true,
    );
    cell(
      1,
      0,
      title1,
      text: title(strings.datePartName(DatePart.quarter)),
      columnSpan: 2,
      right: true,
    );
    cell(
      2,
      0,
      const StyleCell(CellRole.title, rowLevel: 0),
      text: title(strings.datePartName(DatePart.month)),
    );
    cell(
      2,
      1,
      const StyleCell(CellRole.title, rowLevel: 1),
      text: title(strings.datePartName(DatePart.weekday)),
    );
    cell(0, 2, column0, text: '2025', columnSpan: 3, icon: Icons.remove);
    cell(1, 2, column0); // the leg over 2025's own column
    cell(1, 3, column1, text: strings.quarter(1));
    cell(1, 4, column1, text: strings.quarter(2));
    cell(0, 5, totalLabel, text: strings.total, rowSpan: 2);
    cell(
      2,
      2,
      const StyleCell(CellRole.valueName, columnLevel: 0),
      text: count,
      right: true,
    );
    for (final c in [3, 4]) {
      cell(
        2,
        c,
        const StyleCell(CellRole.valueName, columnLevel: 1),
        text: count,
        right: true,
      );
    }
    cell(2, 5, totalLabel, text: count, right: true);

    // the rows: January open with two weekdays, February closed, the total
    const rows = [
      (1250, 560, 690),
      (420, 190, 230),
      (380, 170, 210),
      (1120, 500, 620),
      (2370, 1060, 1310),
    ];
    cell(
      3,
      0,
      row0,
      text: strings.monthName(1),
      rowSpan: 3,
      icon: Icons.remove,
    );
    cell(3, 1, row0); // the leg beside January's own row
    cell(4, 1, row1, text: strings.weekdayName(1));
    cell(5, 1, row1, text: strings.weekdayName(2));
    cell(
      6,
      0,
      row0,
      text: strings.monthName(2),
      columnSpan: 2,
      icon: Icons.add,
    );
    cell(7, 0, totalLabel, text: strings.total, columnSpan: 2);
    for (var i = 0; i < rows.length; i++) {
      final r = 3 + i;
      final (all, q1, q2) = rows[i];
      final isTotal = i == rows.length - 1;
      final level = i == 1 || i == 2 ? 1 : 0;
      cell(
        r,
        2,
        isTotal ? total(-1) : value(level, 0),
        text: number(all),
        right: true,
      );
      cell(
        r,
        3,
        isTotal ? total(-1) : value(level, 1),
        text: number(q1),
        right: true,
        selected: i == 1,
      );
      cell(
        r,
        4,
        isTotal ? total(-1) : value(level, 1),
        text: number(q2),
        right: true,
      );
      cell(r, 5, total(isTotal ? -1 : level), text: number(all), right: true);
    }

    // each column as wide as its widest text, in its own font, at the
    // style's size: the system's text size tells nothing about a style
    const iconRoom = 18.0;
    final widths = List.filled(6, 32.0);
    for (final c in cells) {
      if (c.columnSpan > 1 || c.text.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: c.text, style: ambient.merge(c.look.text)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final need =
          painter.width +
          t.cellPadding.horizontal +
          (c.icon == null ? 0 : iconRoom) +
          2;
      painter.dispose();
      if (need > widths[c.column]) widths[c.column] = need;
    }
    final heights = [
      for (var i = 0; i < 3; i++) t.headerRowHeight,
      for (var i = 0; i < 5; i++) t.rowHeight,
    ];
    double x(int c) => widths.take(c).fold(0.0, (a, b) => a + b);
    double y(int r) => heights.take(r).fold(0.0, (a, b) => a + b);

    final width = x(widths.length) + 1, height = y(heights.length) + 1;
    return MediaQuery.withNoTextScaling(
      child: FittedBox(
        fit: fit,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: t.borderColor),
              top: BorderSide(color: t.borderColor),
            ),
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                for (final c in cells)
                  Positioned(
                    left: x(c.column),
                    top: y(c.row),
                    width: x(c.column + c.columnSpan) - x(c.column),
                    height: y(c.row + c.rowSpan) - y(c.row),
                    child: _box(t, c, heights[c.row]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _box(ResolvedCubeTheme t, _Cell c, double firstRow) => DecoratedBox(
    decoration: BoxDecoration(
      color: c.look.fill,
      border: Border(
        right: BorderSide(color: t.borderColor),
        bottom: BorderSide(color: t.borderColor),
      ),
    ),
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: c.selected
            ? Border.all(color: t.selectionColor, width: 2)
            : null,
      ),
      child: Padding(
        padding: t.cellPadding,
        // a spanned cell's text stays in its first row
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: firstRow,
            child: Row(
              mainAxisAlignment: c.right
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (c.icon != null) ...[
                  Icon(c.icon, size: 14, color: t.iconColorOf(c.look)),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    c.text,
                    style: c.look.text,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// One cell of the sample, before it is placed.
final class _Cell {
  const _Cell(
    this.row,
    this.column,
    this.look, {
    required this.text,
    required this.rowSpan,
    required this.columnSpan,
    required this.right,
    required this.icon,
    required this.selected,
  });

  final int row;
  final int column;
  final ScreenLook look;
  final String text;
  final int rowSpan;
  final int columnSpan;
  final bool right;
  final IconData? icon;
  final bool selected;
}
