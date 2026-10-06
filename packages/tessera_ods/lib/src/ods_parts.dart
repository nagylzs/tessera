/// The package parts and XML helpers both ODS exporters share. Internal.
library;

const odsMimeType = 'application/vnd.oasis.opendocument.spreadsheet';

/// The opening of `content.xml`, every namespace the exporters use declared.
const odsContentStart =
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<office:document-content '
    'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
    'xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" '
    'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
    'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
    'xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" '
    'xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0" '
    'xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0" '
    'office:version="1.3">';

String odsManifest({required bool withSettings}) =>
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3">'
    '<manifest:file-entry manifest:full-path="/" manifest:version="1.3" manifest:media-type="$odsMimeType"/>'
    '<manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>'
    '<manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>'
    '${withSettings ? '<manifest:file-entry manifest:full-path="settings.xml" manifest:media-type="text/xml"/>' : ''}'
    '</manifest:manifest>';

const odsStylesXml =
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<office:document-styles xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
    'office:version="1.3"><office:styles/></office:document-styles>';

/// `settings.xml` freezing [rows] rows and [columns] columns of
/// [sheetName] — LibreOffice's view settings (`HorizontalSplitMode=2`).
String odsFreezeSettings(String sheetName, {int rows = 0, int columns = 0}) {
  String item(String name, String type, Object value) =>
      '<config:config-item config:name="$name" config:type="$type">$value</config:config-item>';
  final cols = columns;
  return '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<office:document-settings xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
      'xmlns:config="urn:oasis:names:tc:opendocument:xmlns:config:1.0" office:version="1.3">'
      '<office:settings><config:config-item-set config:name="ooo:view-settings">'
      '<config:config-item-map-indexed config:name="Views"><config:config-item-map-entry>'
      '${item('ViewId', 'string', 'view1')}'
      '<config:config-item-map-named config:name="Tables">'
      '<config:config-item-map-entry config:name="${odsEscape(sheetName)}">'
      '${item('CursorPositionX', 'int', cols)}${item('CursorPositionY', 'int', rows)}'
      '${item('HorizontalSplitMode', 'short', cols > 0 ? 2 : 0)}'
      '${item('VerticalSplitMode', 'short', rows > 0 ? 2 : 0)}'
      '${item('HorizontalSplitPosition', 'int', cols)}${item('VerticalSplitPosition', 'int', rows)}'
      '${item('ActiveSplitRange', 'short', 2)}'
      '${item('PositionLeft', 'int', 0)}${item('PositionRight', 'int', cols)}'
      '${item('PositionTop', 'int', 0)}${item('PositionBottom', 'int', rows)}'
      '</config:config-item-map-entry></config:config-item-map-named>'
      '${item('ActiveTable', 'string', odsEscape(sheetName))}'
      '</config:config-item-map-entry></config:config-item-map-indexed>'
      '</config:config-item-set></office:settings></office:document-settings>';
}

String odsRgb(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String odsPt(double size) =>
    size == size.truncateToDouble() ? size.toInt().toString() : size.toString();

/// XML-escapes [s], dropping the characters XML 1.0 does not allow at all
/// (control characters other than tab, line feed and carriage return,
/// unpaired surrogates, U+FFFE and U+FFFF) — one would make the whole
/// document unreadable.
String odsEscape(String s) => s
    .replaceAll(_illegal, '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

final _illegal = RegExp(
  r'[\x00-\x08\x0B\x0C\x0E-\x1F￾￿]|'
  r'[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]',
);
