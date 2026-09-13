import 'package:flutter/material.dart';

import 'datasets/datasets_page.dart';
import 'simple/sales_page.dart';
import 'theming/theming_page.dart';

/// One entry of the launcher page.
final class Example {
  const Example({
    required this.title,
    required this.description,
    required this.icon,
    required this.build,
  });

  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder build;
}

/// Every example, in the order the launcher lists them. Add new examples
/// as a folder under `lib/` and an entry here.
const examples = [
  Example(
    title: 'Simple pivot',
    description:
        'Load sales.csv, adjust the inferred schema, configure axes and '
        'aggregates, and explore the cube.',
    icon: Icons.table_chart_outlined,
    build: _simple,
  ),
  Example(
    title: 'Theming',
    description:
        'The sales cube under different CubeThemes and app colour schemes: '
        'level colours, borders, sizes, selection and sort tints.',
    icon: Icons.palette_outlined,
    build: _theming,
  ),
  Example(
    title: 'Public datasets',
    description:
        'Download real-world CSV files (60 KB to 70 MB) through a custom '
        'HttpCsvDataSource with progress, and explore them.',
    icon: Icons.cloud_download_outlined,
    build: _datasets,
  ),
];

Widget _simple(BuildContext context) => const SalesPage();
Widget _theming(BuildContext context) => const ThemingPage();
Widget _datasets(BuildContext context) => const DatasetsPage();
