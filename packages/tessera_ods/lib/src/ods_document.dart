import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml_events.dart';

/// The parts of an `.ods` package a reader needs. Internal.
final class OdsDocument {
  OdsDocument._(this.contentXml);

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
    return OdsDocument._(utf8.decode(content.content));
  }

  final String contentXml;

  /// Sheet names in document order.
  List<String> get sheetNames => [
    for (final e in parseEvents(contentXml).whereType<XmlStartElementEvent>())
      if (e.localName == 'table' && e.namespaceUri == null ||
          e.name == 'table:table')
        e.attribute('name') ?? '',
  ];
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
