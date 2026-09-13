import 'package:xml/xml_events.dart';

import 'xlsx_workbook.dart';

/// One row of a worksheet: its 1-based number and its cells by 0-based
/// column index (absent cells are not in the map).
typedef SheetRow = ({int number, Map<int, Object?> cells});

/// Streams the rows of one worksheet's XML as typed cell values: numbers as
/// [int] when integral (as written) else [double], date-styled numbers as
/// UTC [DateTime], booleans as [bool], strings as [String] (empty ones as
/// `null`), errors as `null`. Formulas contribute their cached value.
Iterable<SheetRow> readSheetRows(
  XlsxWorkbook workbook,
  String sheetXml, {
  required bool trim,
}) sync* {
  var rowNumber = 0;
  Map<int, Object?>? cells;
  // state of the cell being read
  var column = -1;
  String? type;
  var style = 0;
  var inValue = false, inInlineText = false;
  final text = StringBuffer();

  Object? cellValue() {
    final raw = text.toString();
    switch (type) {
      case 's':
        final i = int.tryParse(raw);
        return i == null || i < 0 || i >= workbook.sharedStrings.length
            ? null
            : _text(workbook.sharedStrings[i], trim);
      case 'str' || 'inlineStr':
        return _text(raw, trim);
      case 'b':
        return raw.trim() == '1' || raw.trim().toLowerCase() == 'true';
      case 'e':
        return null;
      case 'd':
        return DateTime.tryParse(raw.trim())?.toUtc();
      default: // 'n' or absent
        final s = raw.trim();
        if (s.isEmpty) return null;
        if (workbook.isDateStyle(style)) {
          final v = double.tryParse(s);
          return v == null ? null : workbook.dateOf(v);
        }
        return int.tryParse(s) ?? double.tryParse(s);
    }
  }

  for (final e in parseEvents(sheetXml)) {
    switch (e) {
      case XmlStartElementEvent(localName: 'row'):
        rowNumber = int.tryParse(e.attribute('r') ?? '') ?? rowNumber + 1;
        cells = {};
        column = -1;
      case XmlEndElementEvent(localName: 'row'):
        if (cells != null) yield (number: rowNumber, cells: cells);
        cells = null;
      case XmlStartElementEvent(localName: 'c'):
        final ref = e.attribute('r');
        column = ref == null ? column + 1 : columnIndexOf(ref);
        type = e.attribute('t');
        style = int.tryParse(e.attribute('s') ?? '') ?? 0;
        text.clear();
        if (e.isSelfClosing && cells != null) cells[column] = null;
      case XmlEndElementEvent(localName: 'c'):
        cells?[column] = cellValue();
      case XmlStartElementEvent(localName: 'v'):
        inValue = !e.isSelfClosing;
      case XmlEndElementEvent(localName: 'v'):
        inValue = false;
      case XmlStartElementEvent(localName: 't'):
        // inline strings: <is><t>…</t></is>, possibly rich runs
        inInlineText = !e.isSelfClosing;
      case XmlEndElementEvent(localName: 't'):
        inInlineText = false;
      case XmlTextEvent() when inValue || inInlineText:
        text.write(e.value);
      case XmlCDATAEvent() when inValue || inInlineText:
        text.write(e.value);
    }
  }
}

String? _text(String s, bool trim) {
  final t = trim ? s.trim() : s;
  return t.isEmpty ? null : t;
}

/// 0-based column index of a cell reference or column letters: `A` → 0,
/// `B7` → 1, `AA` → 26.
int columnIndexOf(String ref) {
  var n = 0;
  for (var i = 0; i < ref.length; i++) {
    final c = ref.codeUnitAt(i);
    if (c >= 0x41 && c <= 0x5A) {
      n = n * 26 + (c - 0x40);
    } else if (c >= 0x61 && c <= 0x7A) {
      n = n * 26 + (c - 0x60);
    } else {
      break;
    }
  }
  return n - 1;
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

/// The last row and column (0-based) of a sheet's `dimension` reference
/// such as `A1:K1001`, or `null` when the sheet declares none.
({int lastRow, int lastColumn})? sheetDimension(String sheetXml) {
  for (final e in parseEvents(sheetXml).whereType<XmlStartElementEvent>()) {
    if (e.localName == 'dimension') {
      final ref = e.attribute('ref') ?? '';
      final end = ref.contains(':') ? ref.substring(ref.indexOf(':') + 1) : ref;
      final digits = RegExp(r'\d+').firstMatch(end)?.group(0);
      if (digits == null) return null;
      return (lastRow: int.parse(digits), lastColumn: columnIndexOf(end));
    }
    if (e.localName == 'sheetData') return null; // dimension comes first
  }
  return null;
}
