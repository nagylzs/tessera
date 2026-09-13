/// OpenDocument Spreadsheet (`.ods`) support for the `tessera` pivot-table
/// engine.
///
/// * [OdsDataSource] reads one sheet as a [DataSource], so a document is
///   inferred and imported like any other source.
/// * [OdsCubeExporter] writes a [CubeLayout] as a formatted sheet, themed
///   with the engine's [CubeExportTheme].
///
/// Pure Dart: no Flutter dependency, usable on servers and in isolates.
library;

import 'package:tessera/tessera.dart';

import 'src/ods_cube_exporter.dart';
import 'src/ods_data_source.dart';

export 'src/ods_cube_exporter.dart';
export 'src/ods_data_source.dart';

// Referenced for the doc comment above.
// ignore: unused_element
const _docs = [
  OdsDataSource,
  OdsCubeExporter,
  DataSource,
  CubeLayout,
  CubeExportTheme,
];
