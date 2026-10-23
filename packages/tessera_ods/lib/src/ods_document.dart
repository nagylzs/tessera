import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml_events.dart';

/// The parts of an `.ods` package a reader needs. Internal.
final class OdsDocument {
  OdsDocument._(this.contentXml, this._settingsXml);

  /// Unzips [bytes] and checks the mimetype.
  factory OdsDocument.parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final mime = archive.find('mimetype');
    if (mime != null &&
        !utf8
            .decode(mime.content)
            .startsWith('application/vnd.oasis.opendocument.spreadsheet')) {
      throw const FormatException('not an OpenDocument spreadsheet');
    }
    final content = archive.find('content.xml');
    if (content == null) {
      throw const FormatException('not an .ods document: content.xml');
    }
    final settings = archive.find('settings.xml');
    return OdsDocument._(
      utf8.decode(content.content),
      settings == null ? null : utf8.decode(settings.content),
    );
  }

  final String contentXml;
  final String? _settingsXml;

  /// Sheet names in document order.
  List<String> get sheetNames => [for (final s in sheets) s.name];

  /// The sheets in document order, with whether each is hidden: its
  /// table style says `table:display="false"`. Tables nested in cells
  /// are not sheets.
  List<({String name, bool hidden})> get sheets {
    final hiddenStyles = <String>{};
    final tables = <({String name, String? style})>[];
    String? style; // the table style being read
    var depth = 0;
    for (final e in parseEvents(contentXml)) {
      switch (e) {
        case XmlStartElementEvent(name: 'style:style'):
          style = e.attribute('family') == 'table' ? e.attribute('name') : null;
        case XmlEndElementEvent(name: 'style:style'):
          style = null;
        case XmlStartElementEvent(name: 'style:table-properties')
            when style != null && e.attribute('display') == 'false':
          hiddenStyles.add(style);
        case XmlStartElementEvent(name: 'table:table'):
          if (depth == 0) {
            tables.add((
              name: e.attribute('name') ?? '',
              style: e.attribute('style-name'),
            ));
          }
          if (!e.isSelfClosing) depth++;
        case XmlEndElementEvent(name: 'table:table'):
          depth--;
      }
    }
    return [
      for (final t in tables)
        (name: t.name, hidden: hiddenStyles.contains(t.style)),
    ];
  }

  /// The name of the sheet the document was saved on (the first view's
  /// `ActiveTable` in `settings.xml`), `null` when it does not say.
  String? get activeSheet {
    final xml = _settingsXml;
    if (xml == null) return null;
    var inActive = false;
    final text = StringBuffer();
    for (final e in parseEvents(xml)) {
      switch (e) {
        case XmlStartElementEvent(name: 'config:config-item'):
          inActive = e.attribute('name') == 'ActiveTable' && !e.isSelfClosing;
        case XmlTextEvent() when inActive:
          text.write(e.value);
        case XmlEndElementEvent(name: 'config:config-item') when inActive:
          return text.toString();
      }
    }
    return null;
  }
}

extension OdsStartElement on XmlStartElementEvent {
  /// Value of the attribute with local name [name] (any prefix), or `null`.
  String? attribute(String name) {
    for (final a in attributes) {
      if (a.localName == name) return a.value;
    }
    return null;
  }
}
