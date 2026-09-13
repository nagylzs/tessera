/// PDF export for the `tessera` pivot-table engine: [PdfCubeExporter]
/// writes a [CubeLayout] as paginated pages with repeated headers, themed
/// with the engine's [CubeExportTheme]. Pure Dart on `package:pdf`.
library;

import 'package:tessera/tessera.dart';

import 'src/pdf_cube_exporter.dart';

export 'src/page_setup.dart';
export 'src/pdf_cube_exporter.dart';

// Referenced for the doc comment above.
// ignore: unused_element
const _docs = [PdfCubeExporter, CubeLayout, CubeExportTheme];
