/// Excel (`.xlsx`) support for the `tessera` pivot-table engine.
///
/// * [XlsxDataSource] reads one worksheet as a [DataSource], so a workbook
///   is inferred and imported like any other source.
/// * [XlsxCubeExporter] writes a [CubeLayout] as a formatted worksheet.
///
/// Pure Dart: no Flutter dependency, usable on servers and in isolates.
library;

import 'package:tessera/tessera.dart';

import 'src/xlsx_cube_exporter.dart';
import 'src/xlsx_data_source.dart';

export 'src/xlsx_cube_exporter.dart';
export 'src/xlsx_data_source.dart';
export 'src/xlsx_workbook.dart' show XlsxWorkbook, XlsxSheet;

// Referenced for the doc comment above.
// ignore: unused_element
const _docs = [XlsxDataSource, XlsxCubeExporter, DataSource, CubeLayout];
