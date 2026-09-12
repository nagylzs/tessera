import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:tessera/tessera.dart';

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

/// Loads `assets/sales.csv` and shows it as a pivot cube.
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
  late final Future<ImportResult> _import = _load();
  CubeController? _controller;
  Aggregate _shown = sumTotal;

  Future<ImportResult> _load() async {
    final data = await rootBundle.load('assets/sales.csv');
    final bytes = data.buffer.asUint8List();
    final source = CsvDataSource.fromBytes(
      () => Stream.value(bytes),
      name: 'sales.csv',
    );
    final result = await loadFacts(source);
    _controller = CubeController(
      Cube(
        facts: result.facts,
        spec: CubeSpec(
          rows: CubeAxis.of([region, country]),
          columns: CubeAxis.of([year, quarter]),
          aggregates: [sumTotal, Aggregate.count, avgPrice],
        ),
      ),
    );
    return result;
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
        ListenableBuilder(
          listenable: _controller ?? ValueNotifier(null),
          builder: (context, _) {
            final controller = _controller;
            if (controller == null) return const SizedBox();
            return DropdownButton<Aggregate>(
              value: _shown,
              underline: const SizedBox(),
              items: [
                for (final a in controller.cube.spec.aggregates)
                  DropdownMenuItem(value: a, child: Text(a.label)),
              ],
              onChanged: (a) => setState(() => _shown = a!),
            );
          },
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
      future: _import,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Import failed: ${snapshot.error}'));
        }
        final result = snapshot.data;
        if (result == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final facts = result.facts;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${facts.rowCount} facts, ${facts.columns.length} columns'
                '${result.report.hasIssues ? ', ${result.report.issues.length} issues' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: CubeView(
                controller: _controller!,
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
