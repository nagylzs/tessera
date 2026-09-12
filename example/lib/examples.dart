import 'package:flutter/material.dart';

import 'simple/sales_page.dart';

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
];

Widget _simple(BuildContext context) => const SalesPage();
