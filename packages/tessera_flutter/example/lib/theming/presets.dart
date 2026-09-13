import 'package:flutter/material.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

/// A named [CubeTheme] for the theming example.
///
/// Values a theme leaves unset are derived from the ambient [ThemeData]
/// when the view is built, so the "Material" preset follows the app's
/// colour scheme and brightness while the others pin some of them.
final class ThemePreset {
  const ThemePreset({
    required this.name,
    required this.description,
    required this.theme,
  });

  final String name;
  final String description;
  final CubeTheme theme;
}

/// The presets offered by the theme menu, first is the default.
final themePresets = <ThemePreset>[
  const ThemePreset(
    name: 'Material',
    description: 'Everything derived from the app theme (the default).',
    theme: CubeTheme(),
  ),
  ThemePreset(
    name: 'Spreadsheet',
    description:
        'White cells at every level, grey grid, fixed column widths, '
        'monospace figures.',
    theme: CubeTheme(
      levelColor: (depth, maxDepth) => Colors.white,
      headerColor: Colors.grey.shade200,
      summaryColor: Colors.grey.shade300,
      borderColor: Colors.grey.shade500,
      sortKeyColor: Colors.yellow.withValues(alpha: 0.35),
      selectionColor: Colors.green.shade800,
      cellTextStyle: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: Colors.black87,
      ),
      headerTextStyle: const TextStyle(fontSize: 12, color: Colors.black),
      minColumnWidth: 112,
      maxColumnWidth: 112,
      minRowHeaderWidth: 140,
      maxRowHeaderWidth: 140,
      cellPadding: const EdgeInsets.symmetric(horizontal: 4),
    ),
  ),
  ThemePreset(
    name: 'Gradient',
    description:
        'CubeTheme.gradient: deeper cells go from a pale to a saturated '
        'teal; orange selection.',
    theme: CubeTheme(
      levelColor: CubeTheme.gradient([
        Colors.teal.shade50,
        Colors.teal.shade200,
        Colors.teal.shade400,
      ]),
      summaryColor: Colors.teal.shade100,
      headerColor: Colors.teal.shade100,
      borderColor: Colors.teal.shade700,
      selectionColor: Colors.deepOrange,
      sortKeyColor: Colors.deepOrange.withValues(alpha: 0.25),
      cellTextStyle: const TextStyle(fontSize: 12, color: Colors.black87),
      headerTextStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    ),
  ),
  const ThemePreset(
    name: 'High contrast',
    description: 'Black grid, larger bold text, taller rows.',
    theme: CubeTheme(
      borderColor: Colors.black,
      cellTextStyle: TextStyle(fontSize: 14),
      headerTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      rowHeight: 34,
      headerRowHeight: 34,
      selectionColor: Colors.red,
      cellPadding: EdgeInsets.symmetric(horizontal: 8),
    ),
  ),
  const ThemePreset(
    name: 'Compact',
    description: 'Small text, 20 px rows, narrow columns and padding.',
    theme: CubeTheme(
      cellTextStyle: TextStyle(fontSize: 11),
      headerTextStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      rowHeight: 20,
      headerRowHeight: 20,
      minColumnWidth: 56,
      minRowHeaderWidth: 80,
      cellPadding: EdgeInsets.symmetric(horizontal: 3),
    ),
  ),
];

/// Seed colours offered for the app's [ColorScheme].
const seedColors = <String, Color>{
  'Teal': Colors.teal,
  'Indigo': Colors.indigo,
  'Deep orange': Colors.deepOrange,
  'Brown': Colors.brown,
};
