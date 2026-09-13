import 'dart:io';

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';
import 'package:tessera_pdf/tessera_pdf.dart';

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const category = ColumnDimension('category');
const qty = Measure('qty');
final sumQty = Aggregate.sum(qty);

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'category', 'qty'],
    rows: const [
      ['Europe', 'Germany', 'A', 1],
      ['Europe', 'Germany', 'B', 2],
      ['Europe', 'Hungary', 'A', 3],
      ['Europe', null, 'A', 4],
      ['Asia', 'Japan', 'B', 5],
      ['Asia', 'Japan', null, 6],
      [null, 'Iceland', 'A', 7.5],
      [null, null, null, null],
    ],
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'category', type: ColumnType.text),
      const ColumnSpec(name: 'qty', type: ColumnType.number),
    ]),
  );
  return (await loadFacts(source)).facts;
}

/// 300 regions × 3 countries, for pagination.
Future<FactTable> manyFacts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'qty'],
    rows: [
      for (var i = 0; i < 300; i++)
        for (var j = 0; j < 3; j++)
          ['Region ${i.toString().padLeft(3, '0')}', 'Country $j', i + j],
    ],
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'qty', type: ColumnType.number),
    ]),
  );
  return (await loadFacts(source)).facts;
}

final europe = DimensionPath([const DimensionValue(region, 'Europe')]);

bool has(String tool) => Process.runSync('which', [tool]).exitCode == 0;

final noto = File('/usr/share/fonts/noto/NotoSans-Regular.ttf');
final notoBold = File('/usr/share/fonts/noto/NotoSans-Bold.ttf');

PdfFonts fontsOrBuiltIn() => noto.existsSync()
    ? PdfFonts(
        regular: noto.readAsBytesSync(),
        bold: notoBold.existsSync() ? notoBold.readAsBytesSync() : null,
      )
    : const PdfFonts.builtIn();

/// `pdfinfo` page count.
int pages(File pdf) {
  final out = Process.runSync('pdfinfo', [pdf.path]).stdout as String;
  return int.parse(RegExp(r'Pages:\s+(\d+)').firstMatch(out)!.group(1)!);
}

/// `pdftotext` of one page (1-based) or the whole file.
String text(File pdf, [int? page]) =>
    Process.runSync('pdftotext', [
          if (page != null) ...['-f', '$page', '-l', '$page'],
          '-layout',
          pdf.path,
          '-',
        ]).stdout
        as String;

void main() {
  late FactTable f;
  late Directory dir;
  setUpAll(() async {
    f = await facts();
    dir = Directory.systemTemp.createTempSync('tessera_pdf');
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  Cube cube() => Cube(
    facts: f,
    spec: CubeSpec(
      rows: CubeAxis.of([region, country]),
      columns: CubeAxis.of([category]),
      aggregates: [sumQty, Aggregate.count],
    ),
  ).toggleRow(europe);

  test('a PDF with one page, title metadata, plan', () async {
    const exporter = PdfCubeExporter();
    final bytes = await exporter.export(cube().layout, title: 'Sales');
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final plan = exporter.plan(cube().layout);
    expect(plan.scale, 1);
    expect(plan.pageCount, 1);
    expect(plan.pagination.pages.single.rowStart, 2);
  });

  test('page texts resolve placeholders', () {
    expect(
      PdfPageText.resolve(
        '{title} — {page}/{pages} {date}',
        title: 'T',
        page: 2,
        pages: 5,
        date: DateTime(2026, 9, 3),
      ),
      'T — 2/5 2026-09-03',
    );
    expect(const PdfPageText().isEmpty, isTrue);
    expect(const PdfPageText(center: 'x').isEmpty, isFalse);
  });

  test('page setup: sizes, orientation, margins', () {
    const setup = PageSetup();
    expect(setup.pageWidth, 297);
    expect(setup.pageHeight, 210);
    expect(setup.bodyWidth, 297 - 30);
    final portrait = setup.copyWith(
      orientation: PageOrientation.portrait,
      size: PageSize.letter,
      marginLeft: 10,
    );
    expect(portrait.pageWidth, 215.9);
    expect(portrait.bodyWidth, closeTo(215.9 - 25, 1e-9));
  });

  test('content: labels, numbers, header and footer (pdftotext)', () async {
    final file = File('${dir.path}/content.pdf');
    final bytes = await PdfCubeExporter(
      strings: TesseraStrings.forLanguage('hu')!,
      fonts: fontsOrBuiltIn(),
      header: const PdfPageText(left: '{title}', right: '{date}'),
      footer: const PdfPageText(center: 'Page {page} of {pages}'),
    ).export(cube().layout, title: 'Sales report', date: DateTime(2026, 9, 3));
    file.writeAsBytesSync(bytes);
    expect(pages(file), 1);
    final t = text(file);
    expect(t, contains('Sales report'));
    expect(t, contains('2026-09-03'));
    expect(t, contains('Page 1 of 1'));
    expect(t, contains('Germany'));
    expect(t, contains('7,50')); // Hungarian decimal comma
    if (noto.existsSync()) {
      expect(t, contains('Összesen'));
      final fonts = Process.runSync('pdffonts', [file.path]).stdout as String;
      expect(fonts, contains('NotoSans'));
    }
  }, skip: has('pdfinfo') && has('pdftotext') ? null : 'poppler not installed');

  test(
    'pagination: headers on every page, labels repeated across breaks',
    () async {
      final many = await manyFacts();
      final big = Cube(
        facts: many,
        spec: CubeSpec(
          rows: CubeAxis.of([region, country]),
          aggregates: [sumQty],
        ),
      ).expandRowLevel(0);
      final exporter = PdfCubeExporter(
        fonts: fontsOrBuiltIn(),
        pageSetup: const PageSetup(orientation: PageOrientation.portrait),
      );
      final plan = exporter.plan(big.layout);
      expect(plan.pageCount, greaterThan(10));
      expect(plan.pagination.columnBands.length, 1);
      final file = File('${dir.path}/many.pdf')
        ..writeAsBytesSync(await exporter.export(big.layout, title: 'Many'));
      expect(pages(file), plan.pageCount);
      // the header band (dimension titles, aggregate name) on every page
      for (final p in [1, 2, plan.pageCount]) {
        final t = text(file, p);
        expect(t, contains('region'), reason: 'page $p');
        expect(t, contains('sum of qty'), reason: 'page $p');
        expect(t, contains('$p / ${plan.pageCount}'), reason: 'page $p');
      }
      // a region whose rows straddle the first break shows on both pages
      final firstBreak = plan.pagination.rowBands.first.$2;
      final grid = CubeGrid.of(big.layout, strings: const TesseraStringsEn());
      final straddling = grid.cellAt(firstBreak, 0);
      expect(straddling.isOrigin, isFalse); // covered by a merged label
      final label = grid.cellAt(straddling.originRow!, 0).value as String;
      expect(text(file, 1), contains(label));
      expect(text(file, 2), contains(label));
    },
    skip: has('pdfinfo') && has('pdftotext') ? null : 'poppler not installed',
  );

  test('fit to width vs tiling', () async {
    final wide = Cube(
      facts: f,
      spec: CubeSpec(
        rows: CubeAxis.of([region]),
        columns: CubeAxis.of([country, category]),
        aggregates: [sumQty, Aggregate.count, Aggregate.average(qty)],
      ),
    ).expandColumnLevel(0);
    const narrow = PageSetup(
      size: PageSize.a5,
      orientation: PageOrientation.portrait,
    );
    final fitted = const PdfCubeExporter(
      pageSetup: narrow,
      minScale: 0.1,
    ).plan(wide.layout);
    expect(fitted.scale, lessThan(1));
    expect(fitted.pagination.columnBands.length, 1);
    final tiled = const PdfCubeExporter(
      pageSetup: narrow,
      fitToWidth: false,
    ).plan(wide.layout);
    expect(tiled.scale, 1);
    expect(tiled.pagination.columnBands.length, greaterThan(1));
    final floored = const PdfCubeExporter(
      pageSetup: narrow,
      minScale: 0.9,
    ).plan(wide.layout);
    expect(floored.scale, 0.9);
    expect(floored.pagination.columnBands.length, greaterThan(1));
    // every tile repeats the row header and the corner titles
    if (has('pdfinfo') && has('pdftotext')) {
      final file = File('${dir.path}/tiled.pdf')
        ..writeAsBytesSync(
          await const PdfCubeExporter(
            pageSetup: narrow,
            fitToWidth: false,
          ).export(wide.layout),
        );
      final count = pages(file);
      expect(count, tiled.pageCount);
      for (final p in [1, count]) {
        final t = text(file, p);
        expect(t, contains('region'), reason: 'page $p');
        expect(t, contains('country'), reason: 'page $p');
        expect(t, contains('Europe'), reason: 'page $p');
      }
    }
  });

  test('structurally valid (qpdf --check, ghostscript)', () async {
    final file = File('${dir.path}/valid.pdf')
      ..writeAsBytesSync(
        await PdfCubeExporter(fonts: fontsOrBuiltIn()).export(cube().layout),
      );
    if (has('qpdf')) {
      final r = Process.runSync('qpdf', ['--check', file.path]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    }
    if (has('gs')) {
      final r = Process.runSync('gs', [
        '-dNOPAUSE',
        '-dBATCH',
        '-dQUIET',
        '-sDEVICE=nullpage',
        file.path,
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    }
  }, skip: has('qpdf') || has('gs') ? null : 'no PDF validator installed');
}
