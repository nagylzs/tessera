import 'package:xml/xml_events.dart';

import 'ods_document.dart';

/// One row of a sheet: its 1-based number and its cells by 0-based column
/// index (empty cells are not in the map).
typedef SheetRow = ({int number, Map<int, Object?> cells});

/// Streams the rows of the sheet named [sheet] (`null`: the first) of
/// [contentXml] as typed cell values: floats as [int] when written
/// integral else [double] (percentages and currencies included), dates as
/// UTC [DateTime], booleans as [bool], strings as [String] (empty ones as
/// `null`), times and anything else as their display text. Repeated
/// columns are expanded; repeated rows are yielded that many times unless
/// they are empty, which is how a sheet pads itself out.
Iterable<SheetRow> readOdsRows(
  String contentXml,
  String? sheet, {
  required bool trim,
}) => readOdsSheets(
  contentXml,
  (index, name) => sheet == null ? index == 0 : name == sheet,
  trim: trim,
  once: true,
).map((r) => r.row);

/// The rows of every sheet [select] accepts — called with each sheet's
/// 0-based position and name — as [readOdsRows] reads them, tagged with
/// the sheet's position. With [once], stops after the first accepted
/// sheet. Tables nested in cells are neither sheets nor read.
Iterable<({int sheet, SheetRow row})> readOdsSheets(
  String contentXml,
  bool Function(int index, String name) select, {
  required bool trim,
  bool once = false,
}) sync* {
  var depth = 0; // of table:table elements; 1 inside a sheet
  var sheets = 0; // seen so far
  var selected = false; // the current sheet is read
  var rowNumber = 0;
  var rowRepeat = 1;
  Map<int, Object?>? cells;
  var column = 0;
  // the cell being read
  var cellRepeat = 1;
  String? type, value, dateValue, boolValue, stringValue;
  var inCell = false, inParagraph = false, inAnnotation = false;
  var paragraphs = 0;
  final text = StringBuffer();

  Object? cellValue() {
    final display = text.toString();
    switch (type) {
      case 'float' || 'percentage' || 'currency':
        final s = (value ?? display).trim();
        return int.tryParse(s) ?? double.tryParse(s);
      case 'date':
        final s = dateValue?.trim();
        if (s == null) return null;
        final d = DateTime.tryParse(s);
        if (d == null) return null;
        // ODS dates carry no zone: take the fields as written, as UTC
        return DateTime.utc(
          d.year,
          d.month,
          d.day,
          d.hour,
          d.minute,
          d.second,
          d.millisecond,
        );
      case 'boolean':
        return (boolValue ?? display).trim().toLowerCase() == 'true';
      case 'string':
        return _text(stringValue ?? display, trim);
      case null:
        return _text(display, trim);
      default: // time, void, …
        return _text(display, trim);
    }
  }

  for (final e in parseEvents(contentXml)) {
    switch (e) {
      case XmlStartElementEvent(name: 'table:table'):
        if (e.isSelfClosing) {
          if (depth == 0) sheets++;
          continue;
        }
        if (depth++ == 0) {
          selected = select(sheets++, e.attribute('name') ?? '');
          rowNumber = 0;
          cells = null;
        }
      case XmlEndElementEvent(name: 'table:table'):
        if (--depth == 0) {
          if (selected && once) return;
          selected = false;
        }
      case XmlStartElementEvent(name: 'table:table-row')
          when depth == 1 && selected:
        rowRepeat =
            int.tryParse(e.attribute('number-rows-repeated') ?? '') ?? 1;
        if (e.isSelfClosing) {
          rowNumber += rowRepeat; // an empty row still counts
          continue;
        }
        cells = {};
        column = 0;
      case XmlEndElementEvent(name: 'table:table-row')
          when depth == 1 && selected:
        if (cells != null) {
          if (cells.isNotEmpty) {
            for (var k = 0; k < rowRepeat; k++) {
              yield (
                sheet: sheets - 1,
                row: (number: rowNumber + 1 + k, cells: cells),
              );
            }
          }
          rowNumber += rowRepeat;
        }
        cells = null;
      case XmlStartElementEvent(
            name: 'table:table-cell' || 'table:covered-table-cell',
          )
          when depth == 1 && selected && cells != null:
        inCell = true;
        cellRepeat =
            int.tryParse(e.attribute('number-columns-repeated') ?? '') ?? 1;
        type = e.attribute('value-type');
        value = e.attribute('value');
        dateValue = e.attribute('date-value');
        boolValue = e.attribute('boolean-value');
        stringValue = e.attribute('string-value');
        text.clear();
        paragraphs = 0;
        if (e.isSelfClosing) {
          final v = cellValue();
          if (v != null) {
            for (var k = 0; k < cellRepeat; k++) {
              cells[column + k] = v;
            }
          }
          column += cellRepeat;
          inCell = false;
        }
      case XmlEndElementEvent(
            name: 'table:table-cell' || 'table:covered-table-cell',
          )
          when depth == 1 && selected && inCell:
        final v = cellValue();
        if (v != null && cells != null) {
          for (var k = 0; k < cellRepeat; k++) {
            cells[column + k] = v;
          }
        }
        column += cellRepeat;
        inCell = false;
      case XmlStartElementEvent(name: 'office:annotation'):
        inAnnotation = true;
      case XmlEndElementEvent(name: 'office:annotation'):
        inAnnotation = false;
      case XmlStartElementEvent(name: 'text:p') when inCell && !inAnnotation:
        if (paragraphs++ > 0) text.write('\n');
        inParagraph = !e.isSelfClosing;
      case XmlEndElementEvent(name: 'text:p') when inCell:
        inParagraph = false;
      case XmlStartElementEvent(name: 'text:s') when inParagraph:
        text.write(' ' * (int.tryParse(e.attribute('c') ?? '') ?? 1));
      case XmlStartElementEvent(name: 'text:tab') when inParagraph:
        text.write('\t');
      case XmlStartElementEvent(name: 'text:line-break') when inParagraph:
        text.write('\n');
      case XmlTextEvent() when inParagraph:
        text.write(e.value);
      case XmlCDATAEvent() when inParagraph:
        text.write(e.value);
    }
  }
}

String? _text(String s, bool trim) {
  final t = trim ? s.trim() : s;
  return t.isEmpty ? null : t;
}

/// Column letters of a 0-based index: 0 → `A`, 26 → `AA`.
String columnLetters(int index) {
  var n = index + 1;
  final out = <int>[];
  while (n > 0) {
    n--;
    out.insert(0, 0x41 + n % 26);
    n ~/= 26;
  }
  return String.fromCharCodes(out);
}
