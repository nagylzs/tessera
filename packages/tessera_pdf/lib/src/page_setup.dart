import 'dart:typed_data';

/// Portrait or landscape.
enum PageOrientation { portrait, landscape }

/// A paper size in millimetres (portrait).
final class PageSize {
  const PageSize(this.width, this.height, {this.name = 'custom'})
    : assert(width > 0 && height > 0);

  static const a3 = PageSize(297, 420, name: 'A3');
  static const a4 = PageSize(210, 297, name: 'A4');
  static const a5 = PageSize(148, 210, name: 'A5');
  static const letter = PageSize(215.9, 279.4, name: 'Letter');
  static const legal = PageSize(215.9, 355.6, name: 'Legal');

  /// In millimetres, portrait.
  final double width;
  final double height;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is PageSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => '$name ($width×$height mm)';
}

/// Paper, orientation and margins, in millimetres. The default is A4
/// landscape with 15 mm margins — pivots are wide.
final class PageSetup {
  const PageSetup({
    this.size = PageSize.a4,
    this.orientation = PageOrientation.landscape,
    this.marginTop = 15,
    this.marginRight = 15,
    this.marginBottom = 15,
    this.marginLeft = 15,
  });

  final PageSize size;
  final PageOrientation orientation;
  final double marginTop;
  final double marginRight;
  final double marginBottom;
  final double marginLeft;

  /// Page width in millimetres, oriented.
  double get pageWidth =>
      orientation == PageOrientation.portrait ? size.width : size.height;

  /// Page height in millimetres, oriented.
  double get pageHeight =>
      orientation == PageOrientation.portrait ? size.height : size.width;

  /// Printable width / height in millimetres.
  double get bodyWidth => pageWidth - marginLeft - marginRight;
  double get bodyHeight => pageHeight - marginTop - marginBottom;

  PageSetup copyWith({
    PageSize? size,
    PageOrientation? orientation,
    double? marginTop,
    double? marginRight,
    double? marginBottom,
    double? marginLeft,
  }) => PageSetup(
    size: size ?? this.size,
    orientation: orientation ?? this.orientation,
    marginTop: marginTop ?? this.marginTop,
    marginRight: marginRight ?? this.marginRight,
    marginBottom: marginBottom ?? this.marginBottom,
    marginLeft: marginLeft ?? this.marginLeft,
  );
}

/// The texts of a page header or footer: up to three, left, centred and
/// right. Placeholders: `{title}` (the export's title), `{page}`,
/// `{pages}` and `{date}` (`yyyy-mm-dd`). Empty texts are left out; a
/// header or footer with no text takes no space.
final class PdfPageText {
  const PdfPageText({this.left = '', this.center = '', this.right = ''});

  static const none = PdfPageText();

  final String left;
  final String center;
  final String right;

  bool get isEmpty => left.isEmpty && center.isEmpty && right.isEmpty;

  /// [template] with the placeholders filled in.
  static String resolve(
    String template, {
    required String title,
    required int page,
    required int pages,
    required DateTime date,
  }) => template
      .replaceAll('{title}', title)
      .replaceAll('{page}', page.toString())
      .replaceAll('{pages}', pages.toString())
      .replaceAll(
        '{date}',
        '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
      );
}

/// TrueType font files to embed, one per face. Missing faces fall back:
/// bold italic → bold, italic → regular, bold → regular. [PdfFonts.builtIn]
/// uses the PDF standard Helvetica faces, which need no file but cover
/// WinAnsi characters only (no Central European accents).
///
/// `ExportFont.family` from the theme is ignored: the faces here are the
/// document's fonts. Size, bold, italic and colour are honoured.
final class PdfFonts {
  const PdfFonts({
    required Uint8List this.regular,
    this.bold,
    this.italic,
    this.boldItalic,
  });

  const PdfFonts.builtIn()
    : regular = null,
      bold = null,
      italic = null,
      boldItalic = null;

  final Uint8List? regular;
  final Uint8List? bold;
  final Uint8List? italic;
  final Uint8List? boldItalic;

  bool get isBuiltIn => regular == null;
}
