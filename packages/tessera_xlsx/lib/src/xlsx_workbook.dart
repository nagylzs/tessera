import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml_events.dart';

/// The parts of an `.xlsx` package a reader needs: the sheet list, the
/// shared strings, which cell styles are dates, and the date system.
/// Internal to `XlsxDataSource`.
final class XlsxWorkbook {
  XlsxWorkbook._(
    this._archive,
    this.sheets,
    this.sharedStrings,
    this.dateStyles,
    this.date1904,
  );

  /// Unzips [bytes] and parses the workbook, relationship, shared-string
  /// and style parts (the sheets themselves are read on demand).
  factory XlsxWorkbook.parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    String? part(String path) {
      final file = archive.find(path);
      return file == null ? null : utf8.decode(file.content);
    }

    final workbookXml = part('xl/workbook.xml');
    if (workbookXml == null) {
      throw const FormatException('not an .xlsx workbook: xl/workbook.xml');
    }
    final rels = _relationships(part('xl/_rels/workbook.xml.rels') ?? '');
    final sheets = <XlsxSheet>[];
    var date1904 = false;
    for (final e in parseEvents(
      workbookXml,
    ).whereType<XmlStartElementEvent>()) {
      switch (e.localName) {
        case 'workbookPr':
          final v = e.attribute('date1904');
          date1904 = v == '1' || v == 'true';
        case 'sheet':
          final id = e.attributes
              .where((a) => a.localName == 'id')
              .map((a) => a.value)
              .firstOrNull;
          final target = id == null ? null : rels[id];
          if (target != null) {
            sheets.add(XlsxSheet(e.attribute('name') ?? '', _resolve(target)));
          }
      }
    }
    return XlsxWorkbook._(
      archive,
      sheets,
      _sharedStrings(part('xl/sharedStrings.xml') ?? ''),
      _dateStyles(part('xl/styles.xml') ?? ''),
      date1904,
    );
  }

  final Archive _archive;

  /// Worksheets in workbook order.
  final List<XlsxSheet> sheets;

  final List<String> sharedStrings;

  /// Whether the cell style with a given index (`s` attribute) formats its
  /// number as a date or time.
  final List<bool> dateStyles;

  /// `true` when serial dates count from 1904-01-01 (Mac workbooks).
  final bool date1904;

  bool isDateStyle(int style) => style < dateStyles.length && dateStyles[style];

  /// The XML of the sheet named [name], or of the first sheet for `null`.
  String sheetXml(String? name) {
    final sheet = name == null
        ? sheets.firstOrNull
        : sheets.where((s) => s.name == name).firstOrNull;
    if (sheet == null) {
      throw ArgumentError.value(
        name,
        'sheet',
        name == null
            ? 'the workbook has no worksheets'
            : 'no such worksheet (sheets: ${sheets.map((s) => s.name).join(', ')})',
      );
    }
    final file = _archive.find(sheet.path);
    if (file == null) throw FormatException('missing part ${sheet.path}');
    return utf8.decode(file.content);
  }

  /// Converts an Excel serial date to a UTC [DateTime]. Serial 1 is
  /// 1900-01-01 (or 1904-01-02 in the 1904 system); day 60 of 1900 is
  /// Excel's fictitious 29 February, which lands on the 28th here. The time
  /// of day is rounded to the millisecond.
  DateTime dateOf(double serial) {
    final days = serial.floor();
    final epoch = date1904
        ? DateTime.utc(1904, 1, 1)
        : days < 61
        ? DateTime.utc(1899, 12, 31)
        : DateTime.utc(1899, 12, 30);
    final millis = ((serial - days) * Duration.millisecondsPerDay).round();
    return epoch.add(Duration(days: days, milliseconds: millis));
  }

  static Map<String, String> _relationships(String xml) => {
    for (final e in parseEvents(xml).whereType<XmlStartElementEvent>())
      if (e.localName == 'Relationship')
        e.attribute('Id') ?? '': e.attribute('Target') ?? '',
  };

  /// A relationship target is relative to `xl/` unless absolute.
  static String _resolve(String target) =>
      target.startsWith('/') ? target.substring(1) : 'xl/$target';

  /// `<si>` entries: plain `<t>` or rich-text runs `<r><t>` concatenated;
  /// phonetic runs (`<rPh>`) are skipped.
  static List<String> _sharedStrings(String xml) {
    final out = <String>[];
    final buffer = StringBuffer();
    var inText = false, inPhonetic = false;
    for (final e in parseEvents(xml)) {
      switch (e) {
        case XmlStartElementEvent(localName: 'rPh'):
          inPhonetic = true;
        case XmlEndElementEvent(localName: 'rPh'):
          inPhonetic = false;
        case XmlStartElementEvent(localName: 't'):
          inText = !inPhonetic;
        case XmlEndElementEvent(localName: 't'):
          inText = false;
        case XmlTextEvent() when inText:
          buffer.write(e.value);
        case XmlCDATAEvent() when inText:
          buffer.write(e.value);
        case XmlEndElementEvent(localName: 'si'):
          out.add(buffer.toString());
          buffer.clear();
      }
    }
    return out;
  }

  /// One flag per `cellXfs` entry: whether its number format is a date.
  static List<bool> _dateStyles(String xml) {
    final custom = <int, String>{};
    final styles = <bool>[];
    var inCellXfs = false;
    for (final e in parseEvents(xml).whereType<XmlStartElementEvent>()) {
      switch (e.localName) {
        case 'numFmt':
          final id = int.tryParse(e.attribute('numFmtId') ?? '');
          if (id != null) custom[id] = e.attribute('formatCode') ?? '';
        case 'cellXfs':
          inCellXfs = true;
        case 'xf' when inCellXfs:
          final id = int.tryParse(e.attribute('numFmtId') ?? '') ?? 0;
          final code = custom[id];
          styles.add(
            code == null ? _builtInDateFormat(id) : isDateFormat(code),
          );
      }
    }
    return styles;
  }

  static bool _builtInDateFormat(int id) =>
      (id >= 14 && id <= 22) ||
      (id >= 27 && id <= 36) ||
      (id >= 45 && id <= 47) ||
      (id >= 50 && id <= 58);

  /// Whether a number format code renders dates or times: it contains a
  /// day/month/year/hour/second code outside quoted text, `[...]`
  /// sections (colours, conditions, elapsed `[h]` counts as time though)
  /// and backslash escapes.
  static bool isDateFormat(String code) {
    var quoted = false, bracket = false;
    for (var i = 0; i < code.length; i++) {
      final c = code[i];
      if (quoted) {
        if (c == '"') quoted = false;
        continue;
      }
      if (bracket) {
        if (c == ']') bracket = false;
        continue;
      }
      switch (c) {
        case '"':
          quoted = true;
        case '[':
          // [h], [mm], [ss] are elapsed times; colours and conditions are not
          final close = code.indexOf(']', i);
          final inner = close < 0
              ? ''
              : code.substring(i + 1, close).toLowerCase();
          if (RegExp(r'^[hms]+$').hasMatch(inner)) return true;
          bracket = true;
        case '\\':
          i++;
        case 'y' || 'Y' || 'd' || 'D' || 'h' || 'H' || 's' || 'S' || 'm' || 'M':
          return true;
        // 'General' contains no date letters once its case is considered,
        // but be explicit for the common built-in names.
      }
    }
    return false;
  }
}

/// A worksheet's name and the path of its part inside the package.
final class XlsxSheet {
  const XlsxSheet(this.name, this.path);

  final String name;
  final String path;
}

extension XlsxStartElement on XmlStartElementEvent {
  /// Value of the attribute with local name [name], or `null`.
  String? attribute(String name) {
    for (final a in attributes) {
      if (a.localName == name) return a.value;
    }
    return null;
  }
}
