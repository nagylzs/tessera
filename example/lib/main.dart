import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:tessera/tessera.dart';

import 'schema_page.dart';

void main() => runApp(const TesseraExampleApp());

class TesseraExampleApp extends StatelessWidget {
  const TesseraExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tessera example',
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.dark,
    ),
    home: const SalesPage(),
  );
}

/// Loads `assets/sales.csv`, lets the user adjust the inferred schema, and
/// shows the imported facts as a pivot cube.
class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  static const region = ColumnDimension('region');
  static const country = ColumnDimension('country');
  static const year = DatePartDimension('date', DatePart.year);
  static const quarter = DatePartDimension('date', DatePart.quarter);
  static final sumTotal = Aggregate.sum(const Measure('total'));
  static final avgPrice = Aggregate.average(const Measure('unit_price'));

  final _numbers = NumberFormat.decimalPatternDigits(
    locale: 'hu',
    decimalDigits: 2,
  );

  late final Future<void> _ready = _load();
  late final CsvDataSource _source;
  late final Schema _inferred;
  late final List<String> _columnNames;
  late final List<SourceRow> _sampleRows;
  Schema? _schema;
  ImportResult? _result;
  CubeController? _controller;
  List<Dimension> _dimensions = const [];
  Aggregate _shown = sumTotal;
  Object? _error;
  ImportProgress? _progress;

  Future<void> _load() async {
    final data = await rootBundle.load('assets/sales.csv');
    final bytes = data.buffer.asUint8List();
    // fromData (not fromBytes with a closure): closures created in a State
    // method capture `this`, which cannot be sent to the import isolate.
    _source = CsvDataSource.fromData(bytes, name: 'sales.csv');
    _columnNames = await _source.columnNames();
    _sampleRows = await _source.rows().take(5).toList();
    _inferred = await inferSchema(_source);
    await _import(_inferred);
  }

  /// Imports with [schema] and rebuilds the cube, keeping as much of the
  /// current spec and expansion as the new facts allow.
  Future<void> _import(Schema schema) async {
    final ImportResult result;
    try {
      // Off the UI isolate, with progress; the source only captures bytes,
      // so it can be sent over.
      result = await loadFactsInIsolate(
        _source,
        schema: schema,
        importer: const FactTableImporter(progressEvery: 250),
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
    // Everything except the id and the measures makes sense to group by.
    final dimensions = [
      for (final d in standardDimensions(facts))
        if (!const {
          'id',
          'unit_price',
          'discount',
          'total',
        }.contains(d.sourceColumn))
          d,
    ];
    final old = _controller?.cube;
    final spec = old == null
        ? CubeSpec(
            rows: CubeAxis.of([region, country]),
            columns: CubeAxis.of([year, quarter]),
            aggregates: [sumTotal, Aggregate.count, avgPrice],
          )
        : _prune(old.spec, facts);
    final shown = spec.aggregates.contains(_shown)
        ? _shown
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
              (d.sort.aggregate == null || aggregateOk(d.sort.aggregate!)))
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
    if (edited != null) await _import(edited);
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

  String _format(CubeCell cell, Object? value) =>
      value is num ? _numbers.format(value) : value?.toString() ?? '';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tessera — sales.csv'),
      actions: [
        IconButton(
          icon: const Icon(Icons.table_chart_outlined),
          tooltip: 'Schema…',
          onPressed: _schema == null ? null : _editSchema,
        ),
        IconButton(
          icon: const Icon(Icons.unfold_more),
          tooltip: 'Expand all rows',
          onPressed: () =>
              _controller?.cube = _controller!.cube.expandRowsToDepth(2),
        ),
        IconButton(
          icon: const Icon(Icons.unfold_less),
          tooltip: 'Collapse rows',
          onPressed: () =>
              _controller?.cube = _controller!.cube.expandRowsToDepth(1),
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
        if (progress != null && !progress.done) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 240,
                  child: LinearProgressIndicator(value: progress.fraction),
                ),
                const SizedBox(height: 8),
                Text(
                  '${progress.rowsRead} rows'
                  '${progress.fraction == null ? '' : ' (${(progress.fraction! * 100).round()}%)'}',
                ),
              ],
            ),
          );
        }
        if (controller == null || result == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final facts = result.facts;
        final report = result.report;
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
                selected: _shown,
                onSelected: (a) => setState(() => _shown = a),
                dimensions: _dimensions,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CubeView(
                controller: controller,
                aggregate: _shown,
                formatCell: _format,
                theme: const CubeTheme(columnWidth: 130, rowHeaderWidth: 170),
                rowSummaryLabel: 'Total (all countries)',
                columnSummaryLabel: 'Total (all dates)',
              ),
            ),
          ],
        );
      },
    ),
  );
}
