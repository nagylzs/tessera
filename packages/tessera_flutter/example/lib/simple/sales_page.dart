import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tessera_flutter/tessera_flutter.dart';

import '../common/workbench.dart';

/// Loads `assets/sales.csv` and opens it in the [CubeWorkbench] with a
/// region/country × year/quarter cube.
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

  late final Future<DataSource> _source = _load();

  Future<DataSource> _load() async {
    final data = await rootBundle.load('assets/sales.csv');
    // fromData (not fromBytes with a closure): closures created in a State
    // method capture `this`, which cannot be sent to the import isolate.
    return CsvDataSource.fromData(data.buffer.asUint8List(), name: 'sales.csv');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _source,
    builder: (context, snapshot) {
      final source = snapshot.data;
      if (source == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Tessera — sales.csv')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return CubeWorkbench(
        source: source,
        title: 'Tessera — sales.csv',
        progressEvery: 250,
        initialSpec: (facts) => CubeSpec(
          rows: CubeAxis.of([region, country]),
          columns: CubeAxis.of([year, quarter]),
          aggregates: [
            Aggregate.sum(const Measure('total')),
            Aggregate.count,
            Aggregate.average(const Measure('unit_price')),
          ],
        ),
        // Everything except the id and the measures makes sense to group by.
        dimensions: (facts) => [
          for (final d in standardDimensions(facts))
            if (!const {
              'id',
              'unit_price',
              'discount',
              'total',
            }.contains(d.sourceColumn))
              d,
        ],
      );
    },
  );
}
