import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import '../common/http_csv_data_source.dart';
import '../common/workbench.dart';
import '../language_menu.dart';

/// A public CSV file that can be downloaded and explored.
final class PublicDataset {
  const PublicDataset({
    required this.name,
    required this.description,
    required this.uri,
    required this.approxSize,
    required this.license,
    this.options = const CsvOptions(),
    this.columnLabels,
  });

  final String name;
  final String description;
  final Uri uri;
  final String approxSize;
  final String license;
  final CsvOptions options;

  /// Labels for header-less files, in column order.
  final List<String>? columnLabels;
}

final publicDatasets = [
  PublicDataset(
    name: 'Titanic passengers',
    description: '891 passengers: class, sex, age, fare, survival. A quick sanity check.',
    uri: Uri.parse(
      'https://raw.githubusercontent.com/datasciencedojo/datasets/master/titanic.csv',
    ),
    approxSize: '60 KB',
    license: 'public domain (Kaggle / Data Science Dojo)',
  ),
  PublicDataset(
    name: 'World population (World Bank)',
    description: 'Population by country and year, 1960–today; long format.',
    uri: Uri.parse(
      'https://raw.githubusercontent.com/datasets/population/main/data/population.csv',
    ),
    approxSize: '550 KB',
    license: 'CC BY 4.0 (World Bank via datahub.io)',
  ),
  PublicDataset(
    name: 'OpenFlights routes',
    description:
        '67 000 airline routes: airline, source and destination airport, stops, equipment. '
        'The file has no header row.',
    uri: Uri.parse(
      'https://raw.githubusercontent.com/jpatokal/openflights/master/data/routes.dat',
    ),
    approxSize: '2.4 MB',
    license: 'ODbL (OpenFlights)',
    options: const CsvOptions(hasHeader: false, trimCells: true),
    columnLabels: [
      'airline',
      'airline id',
      'source airport',
      'source airport id',
      'destination airport',
      'destination airport id',
      'codeshare',
      'stops',
      'equipment',
    ],
  ),
  PublicDataset(
    name: 'COVID-19 by country and day',
    description: 'Daily confirmed, recovered and deaths per country (JHU CSSE, 2020–2023).',
    uri: Uri.parse(
      'https://raw.githubusercontent.com/datasets/covid-19/main/data/countries-aggregated.csv',
    ),
    approxSize: '5.5 MB',
    license: 'CC BY 4.0 (JHU CSSE via datahub.io)',
  ),
  PublicDataset(
    name: 'COVID-19 by region and day',
    description:
        'Like the previous one, but per province/state — ~330 000 rows.',
    uri: Uri.parse(
      'https://raw.githubusercontent.com/datasets/covid-19/main/data/time-series-19-covid-combined.csv',
    ),
    approxSize: '8.6 MB',
    license: 'CC BY 4.0 (JHU CSSE via datahub.io)',
  ),
  PublicDataset(
    name: 'Electric vehicles in Washington State',
    description:
        'Every registered EV: county, city, make, model, model year, type, range. '
        'Served chunked without Content-Length, so the row estimate is unknown.',
    uri: Uri.parse(
      'https://data.wa.gov/api/views/f6w7-q2d2/rows.csv?accessType=DOWNLOAD',
    ),
    approxSize: '70 MB, ~250 000 rows',
    license: 'ODbL (Washington State DOL)',
  ),
];

/// Lists [publicDatasets]; picking one downloads it (cached under the
/// system temp directory) and opens it in the [CubeWorkbench].
class DatasetsPage extends StatefulWidget {
  const DatasetsPage({super.key});

  @override
  State<DatasetsPage> createState() => _DatasetsPageState();
}

class _DatasetsPageState extends State<DatasetsPage> {
  Directory get _cacheDir =>
      Directory('${Directory.systemTemp.path}/tessera_examples');

  HttpCsvDataSource _sourceFor(PublicDataset d) => HttpCsvDataSource(
    d.uri,
    cacheFile: File(
      '${_cacheDir.path}/${d.uri.hashCode.toRadixString(16)}.csv',
    ),
    options: d.options,
    name: d.name,
  );

  Future<void> _open(PublicDataset d) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CubeWorkbench(
          source: _sourceFor(d),
          title: d.name,
          adjustSchema: d.columnLabels == null
              ? null
              : (inferred) {
                  final labels = d.columnLabels!;
                  var schema = inferred;
                  for (
                    var i = 0;
                    i < inferred.columns.length && i < labels.length;
                    i++
                  ) {
                    schema = schema.replace(
                      inferred.columns[i].copyWith(label: labels[i]),
                    );
                  }
                  return schema;
                },
        ),
      ),
    );
    setState(() {}); // cache state may have changed
  }

  void _clearCache() {
    if (_cacheDir.existsSync()) _cacheDir.deleteSync(recursive: true);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Public datasets'),
      actions: [
        const LanguageMenu(),
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          tooltip: 'Clear downloaded files',
          onPressed: _clearCache,
        ),
      ],
    ),
    body: ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Each dataset is streamed from its public URL by an HttpCsvDataSource: '
            'schema inference reads only the first rows, the import downloads the '
            'whole file (once — it is cached afterwards). Progress uses Content-Length '
            'when the server sends it.',
          ),
        ),
        for (final d in publicDatasets)
          ListTile(
            leading: Icon(
              _sourceFor(d).isCached
                  ? Icons.download_done
                  : Icons.cloud_download_outlined,
            ),
            title: Text('${d.name} (${d.approxSize})'),
            subtitle: Text('${d.description}\n${d.license}'),
            isThreeLine: true,
            onTap: () => _open(d),
          ),
      ],
    ),
  );
}
