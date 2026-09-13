import 'dart:convert' show utf8;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tessera_flutter/tessera_flutter.dart';
import 'package:tessera_html/tessera_html.dart';
import 'package:tessera_pdf/tessera_pdf.dart';
import 'package:tessera_svg/tessera_svg.dart';
import 'package:tessera_ods/tessera_ods.dart';
import 'package:tessera_xlsx/tessera_xlsx.dart';

import '../language_menu.dart';
import 'schema_page.dart';

/// The interactive pivot workbench shared by the examples: infers the
/// schema of [source], imports it off the UI isolate with progress, and
/// shows the axis/aggregate editors, the cube and the schema page.
class CubeWorkbench extends StatefulWidget {
  const CubeWorkbench({
    super.key,
    required this.source,
    required this.title,
    this.initialSpec,
    this.dimensions,
    this.adjustSchema,
    this.progressEvery = 5000,
    this.theme = const CubeTheme(),
    this.exportTheme = const CubeExportTheme(),
    this.actions,
  });

  final DataSource source;
  final String title;

  /// The first cube shown; default: rows = the first text column, count.
  final CubeSpec Function(FactTable facts)? initialSpec;

  /// Dimensions offered by the pickers; default: [standardDimensions].
  final List<Dimension> Function(FactTable facts)? dimensions;

  /// Applied to the inferred schema before the first import (labels for
  /// header-less files, type fixes, …).
  final Schema Function(Schema inferred)? adjustSchema;

  final int progressEvery;

  /// Theme of the [CubeView].
  final CubeTheme theme;

  /// Theme of the Excel / OpenDocument exports.
  final CubeExportTheme exportTheme;

  /// Extra AppBar actions, placed before the built-in ones; [controller]
  /// is `null` until the import has finished.
  final List<Widget> Function(BuildContext context, CubeController? controller)?
  actions;

  @override
  State<CubeWorkbench> createState() => _CubeWorkbenchState();
}

class _CubeWorkbenchState extends State<CubeWorkbench> {
  late final Future<void> _ready = _load();
  late final Schema _inferred;
  late final List<String> _columnNames;
  late final List<SourceRow> _sampleRows;
  Schema? _schema;
  ImportResult? _result;
  CubeController? _controller;
  List<Dimension> _dimensions = const [];
  Aggregate? _shown;
  Object? _error;
  ImportProgress? _progress;
  String _stage = 'Reading the first rows…';

  Future<void> _load() async {
    final source = widget.source;
    _columnNames = await source.columnNames();
    _sampleRows = await source.rows().take(5).toList();
    _inferred = await inferSchema(source);
    await _import(widget.adjustSchema?.call(_inferred) ?? _inferred);
  }

  /// Imports with [schema] and rebuilds the cube, keeping as much of the
  /// current spec and expansion as the new facts allow.
  Future<void> _import(Schema schema) async {
    setState(() {
      _stage = 'Importing…';
      _progress = null;
    });
    final ImportResult result;
    try {
      result = await loadFactsInIsolate(
        widget.source,
        schema: schema,
        importer: FactTableImporter(progressEvery: widget.progressEvery),
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
          return true;
        },
      );
    } catch (e) {
      setState(() => _error = e);
      return;
    }
    final facts = result.facts;
    final dimensions =
        widget.dimensions?.call(facts) ?? standardDimensions(facts);
    final old = _controller?.cube;
    final spec = old == null
        ? (widget.initialSpec?.call(facts) ?? _defaultSpec(facts))
        : _prune(old.spec, facts);
    final shown = _shown != null && spec.aggregates.contains(_shown)
        ? _shown!
        : spec.aggregates.first;
    final cube = Cube(
      facts: facts,
      spec: spec,
      rowExpansion: old?.rowExpansion,
      columnExpansion: old?.columnExpansion,
    );
    setState(() {
      _error = null;
      _progress = null;
      _schema = schema;
      _result = result;
      _dimensions = dimensions;
      _shown = shown;
      _controller?.dispose();
      _controller = CubeController(cube);
    });
  }

  static CubeSpec _defaultSpec(FactTable facts) {
    final text = facts.columns.where((c) => c.type == ColumnType.text).toList();
    final byDistinct = [...text]
      ..sort((a, b) => a.distinctCount - b.distinctCount);
    // Prefer a low-cardinality text column so the first cube is readable.
    final first =
        byDistinct.where((c) => c.distinctCount > 1).firstOrNull ??
        text.firstOrNull;
    return CubeSpec(
      rows: first == null
          ? const CubeAxis()
          : CubeAxis.of([ColumnDimension(first.name)]),
      aggregates: const [Aggregate.count],
    );
  }

  /// Drops dimensions and aggregates whose columns are gone or changed type.
  static CubeSpec _prune(CubeSpec spec, FactTable facts) {
    bool hasColumn(String name) => facts.columns.any((c) => c.name == name);
    bool dimensionOk(Dimension d) {
      if (!hasColumn(d.sourceColumn)) return false;
      if (d is DatePartDimension) {
        final t = facts.column(d.sourceColumn).type;
        return t == ColumnType.date || t == ColumnType.dateTime;
      }
      return true;
    }

    bool aggregateOk(Aggregate a) => switch (a) {
      MeasureAggregate(:final measure) =>
        hasColumn(measure.column) &&
            facts.column(measure.column).type.isNumeric,
      DistinctCountAggregate(:final dimension) => dimensionOk(dimension),
      _ => true,
    };
    CubeAxis prune(CubeAxis axis) => axis.copyWith(
      dimensions: [
        for (final d in axis.dimensions)
          if (dimensionOk(d.dimension) &&
              (d.sort?.aggregate == null || aggregateOk(d.sort!.aggregate!)))
            d
          else if (dimensionOk(d.dimension))
            AxisDimension(d.dimension),
      ],
    );
    final aggregates = [
      for (final a in spec.aggregates)
        if (aggregateOk(a)) a,
    ];
    return CubeSpec(
      rows: prune(spec.rows),
      columns: prune(spec.columns),
      aggregates: aggregates.isEmpty ? const [Aggregate.count] : aggregates,
      filter: spec.filter,
    );
  }

  Future<void> _editSchema() async {
    final edited = await Navigator.push<Schema>(
      context,
      MaterialPageRoute(
        builder: (_) => SchemaPage(
          schema: _schema ?? _inferred,
          inferred: _inferred,
          sampleRows: _sampleRows,
          columnNames: _columnNames,
        ),
      ),
    );
    final controller = _controller;
    if (edited == null || controller == null) return;
    final current = _schema ?? _inferred;
    if (!_sameExceptLabels(current, edited)) {
      await _import(edited);
      return;
    }
    // Only labels changed (if anything): relabel the facts in place, no
    // re-import; the spec and expansion carry over unchanged.
    final changed = <String, String?>{
      for (final c in edited.columns)
        if (c.label != current[c.name]?.label) c.name: c.label,
    };
    if (changed.isEmpty) return;
    final old = controller.cube;
    setState(() {
      _schema = edited;
      controller.cube = Cube(
        facts: old.facts.withLabels(changed),
        spec: old.spec,
        rowExpansion: old.rowExpansion,
        columnExpansion: old.columnExpansion,
      );
    });
  }

  /// Whether [a] and [b] describe the same import apart from labels.
  static bool _sameExceptLabels(Schema a, Schema b) {
    if (a.columns.length != b.columns.length) return false;
    for (var i = 0; i < a.columns.length; i++) {
      final x = a.columns[i], y = b.columns[i];
      if (x.name != y.name ||
          x.type != y.type ||
          x.include != y.include ||
          x.format != y.format ||
          x.numberSyntax != y.numberSyntax ||
          x.parser != y.parser ||
          !setEquals(x.nullValues, y.nullValues)) {
        return false;
      }
    }
    return true;
  }

  /// Writes the cube as shown (every aggregate of the spec) to a file
  /// chosen in the platform's save dialog: an .xlsx workbook, an .ods
  /// spreadsheet, or CSV. file_picker takes the bytes itself, which is
  /// what Android and iOS need (they hand out a document Uri, not a path).
  Future<void> _export(ExportFormat format) async {
    final controller = _controller;
    if (controller == null) return;
    final base = widget.source.name.replaceFirst(RegExp(r'\.[^.]*$'), '');
    final strings = TesseraLocalizations.of(context);
    final layout = controller.cube.layout;
    final Uint8List bytes;
    switch (format) {
      case ExportFormat.xlsx:
        bytes = XlsxCubeExporter(
          strings: strings,
          theme: widget.exportTheme,
        ).export(layout, sheetName: base);
      case ExportFormat.ods:
        bytes = OdsCubeExporter(
          strings: strings,
          theme: widget.exportTheme,
        ).export(layout, sheetName: base);
      case ExportFormat.html:
        bytes = Uint8List.fromList(
          utf8.encode(
            HtmlCubeExporter(
              strings: strings,
              theme: widget.exportTheme,
            ).export(layout, title: base),
          ),
        );
      case ExportFormat.svg:
        bytes = Uint8List.fromList(
          utf8.encode(
            SvgCubeExporter(
              strings: strings,
              theme: widget.exportTheme,
            ).export(layout, title: base),
          ),
        );
      case ExportFormat.pdf:
        // Noto Sans from the assets: embedded, so accents survive
        final regular = await rootBundle.load(
          'assets/fonts/NotoSans-Regular.ttf',
        );
        final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
        bytes = await PdfCubeExporter(
          strings: strings,
          theme: widget.exportTheme,
          fonts: PdfFonts(
            regular: regular.buffer.asUint8List(),
            bold: bold.buffer.asUint8List(),
          ),
          footer: const PdfPageText(left: '{date}', right: '{page} / {pages}'),
        ).export(layout, title: base);
      case ExportFormat.csv:
        bytes = Uint8List.fromList(
          utf8.encode(
            CsvCubeExporter(
              strings: strings,
              options: const CsvExportOptions(byteOrderMark: true),
            ).export(layout),
          ),
        );
    }
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Export',
      fileName: '$base.${format.extension}',
      bytes: bytes,
      mimeType: format.mimeType,
      type: FileType.custom,
      allowedExtensions: [format.extension],
    );
    if (uri == null || !mounted) return;
    // desktop gives a file path; Android/iOS a content Uri, so name the file
    final where = uri.isScheme('file')
        ? uri.toFilePath()
        : '$base.${format.extension}';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Saved $where')));
  }

  void _showReport() {
    final report = _result!.report;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import report'),
        content: SizedBox(
          width: 480,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('${report.rowsImported} rows imported'),
              for (final e in report.widenedColumns.entries)
                Text('${e.key}: widened to ${e.value.name}'),
              for (final e in report.nullifiedPerColumn.entries)
                Text('${e.key}: ${e.value} values could not be parsed'),
              if (report.issues.isNotEmpty) const Divider(),
              for (final issue in report.issues) Text(issue.toString()),
              if (report.issuesTruncated) const Text('…'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        ...?widget.actions?.call(context, _controller),
        MenuAnchor(
          menuChildren: [
            for (final format in ExportFormat.values)
              MenuItemButton(
                onPressed: _controller == null ? null : () => _export(format),
                child: Text('${format.label} (.${format.extension})…'),
              ),
          ],
          builder: (context, menu, _) => IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export…',
            onPressed: () => menu.isOpen ? menu.close() : menu.open(),
          ),
        ),
        const LanguageMenu(),
        IconButton(
          icon: const Icon(Icons.table_chart_outlined),
          tooltip: 'Schema…',
          onPressed: _schema == null ? null : _editSchema,
        ),
      ],
    ),
    body: FutureBuilder(
      future: _ready,
      builder: (context, snapshot) {
        final error = _error ?? snapshot.error;
        if (error != null) return Center(child: Text('Import failed: $error'));
        final controller = _controller;
        final result = _result;
        final progress = _progress;
        if (controller == null ||
            result == null ||
            (progress != null && !progress.done)) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 240,
                  child: LinearProgressIndicator(value: progress?.fraction),
                ),
                const SizedBox(height: 8),
                Text(
                  progress == null
                      ? _stage
                      : '${progress.rowsRead} rows'
                            '${progress.fraction == null ? '' : ' (${(progress.fraction! * 100).round()}%)'}',
                ),
              ],
            ),
          );
        }
        final facts = controller.cube.facts; // relabelled in place, maybe
        final report = result.report;
        final shown = _shown ?? controller.cube.spec.aggregates.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: InkWell(
                onTap: _showReport,
                child: Text(
                  '${facts.rowCount} facts, ${facts.columns.length} columns'
                  '${report.widenedColumns.isEmpty ? '' : ', ${report.widenedColumns.length} widened'}'
                  '${report.nullifiedPerColumn.isEmpty ? '' : ', ${report.nullifiedPerColumn.values.fold(0, (a, b) => a + b)} values nullified'}'
                  ' — tap for the import report',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AxisEditor(
                      controller: controller,
                      side: AxisSide.rows,
                      available: _dimensions,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AxisEditor(
                      controller: controller,
                      side: AxisSide.columns,
                      available: _dimensions,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AggregateEditor(
                controller: controller,
                selected: shown,
                onSelected: (a) => setState(() => _shown = a),
                dimensions: _dimensions,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CubeView(
                controller: controller,
                aggregate: shown,
                theme: widget.theme,
              ),
            ),
            // the current cell: what an app would chart or drill into
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final cell = controller.currentCell;
                final l10n = TesseraLocalizations.of(context);
                final text = cell == null
                    ? 'No current cell — tap a cell or use the arrow keys.'
                    : cell.coordinate.isEmpty
                    ? 'Current cell: grand total — ${cell.factCount} facts'
                    : 'Current cell: '
                          '${cell.coordinate.values.entries.map((e) => '${l10n.dimensionLabel(e.key, facts)} = ${e.value == null ? l10n.emptyGroup : l10n.formatValue(e.key, e.value)}').join(', ')}'
                          ' — ${cell.factCount} facts';
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ],
        );
      },
    ),
  );
}

/// The formats the workbench exports to.
enum ExportFormat {
  xlsx(
    'Excel workbook',
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ),
  ods(
    'OpenDocument spreadsheet',
    'ods',
    'application/vnd.oasis.opendocument.spreadsheet',
  ),
  html('Web page', 'html', 'text/html'),
  svg('SVG image', 'svg', 'image/svg+xml'),
  pdf('PDF document', 'pdf', 'application/pdf'),
  csv('CSV', 'csv', 'text/csv');

  const ExportFormat(this.label, this.extension, this.mimeType);

  final String label;
  final String extension;
  final String mimeType;
}
