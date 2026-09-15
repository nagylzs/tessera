import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tessera_flutter/tessera_flutter.dart';

import '../common/workbench.dart';
import 'chart_panel.dart';

/// The sales cube with a live chart beside it (below it on a tall screen):
/// the engine's `ChartData` / `ScatterData` drawn with fl_chart.
class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key});

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  static const region = ColumnDimension('region');
  static const category = ColumnDimension('category');
  static const year = DatePartDimension('date', DatePart.year);
  static const quarter = DatePartDimension('date', DatePart.quarter);

  late final Future<DataSource> _source = _load();
  bool _showChart = true;

  Future<DataSource> _load() async {
    final data = await rootBundle.load('assets/sales.csv');
    return CsvDataSource.fromData(data.buffer.asUint8List(), name: 'sales.csv');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _source,
    builder: (context, snapshot) {
      final source = snapshot.data;
      if (source == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Tessera — charts')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return CubeWorkbench(
        source: source,
        title: 'Tessera — charts',
        progressEvery: 250,
        initialSpec: (facts) => CubeSpec(
          rows: CubeAxis.of([category, region]),
          columns: CubeAxis.of([year, quarter]),
          aggregates: [
            Aggregate.sum(const Measure('total')),
            Aggregate.sum(const Measure('quantity')),
            Aggregate.average(const Measure('unit_price')),
          ],
        ),
        dimensions: (facts) => [
          for (final d in standardDimensions(facts))
            if (!const {
              'id',
              'quantity',
              'unit_price',
              'discount',
              'total',
            }.contains(d.sourceColumn))
              d,
        ],
        actions: (context, controller) => [
          IconButton(
            icon: Icon(
              _showChart ? Icons.insert_chart : Icons.insert_chart_outlined,
            ),
            tooltip: _showChart ? 'Hide the chart' : 'Show the chart',
            onPressed: () => setState(() => _showChart = !_showChart),
          ),
        ],
        companion: _showChart
            ? (context, controller, dimensions) =>
                  ChartPanel(controller: controller, dimensions: dimensions)
            : null,
      );
    },
  );
}
