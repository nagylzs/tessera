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
    required this.xlsxTheme,
  });

  final String name;
  final String description;
  final CubeTheme theme;

  /// The Excel counterpart, designed to look like [theme] on paper: an
  /// `CubeExportTheme` is authored with plain ARGB ints and fonts, not
  /// converted from the Flutter theme (which needs a context to resolve
  /// and whose on-screen shading is too subtle for a sheet).
  final CubeExportTheme xlsxTheme;
}

/// The presets offered by the theme menu, first is the default.
final themePresets = <ThemePreset>[
  const ThemePreset(
    name: 'Material',
    description: 'Everything derived from the app theme (the default).',
    theme: CubeTheme(),
    xlsxTheme: CubeExportTheme(),
  ),
  ThemePreset(
    name: 'Spreadsheet',
    description: 'White cells at every level, grey grid, monospace figures.',
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
      cellPadding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    xlsxTheme: const CubeExportTheme(
      headerFill: 0xFFEEEEEE,
      summaryFill: 0xFFE0E0E0,
      levelFills: [0xFFFFFFFF],
      borderColor: 0xFF9E9E9E,
      cellFont: ExportFont(family: 'Courier New'),
      summaryFont: ExportFont(family: 'Courier New', bold: true),
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
    xlsxTheme: CubeExportTheme(
      headerFill: 0xFFB2DFDB, // teal 100
      summaryFill: 0xFFB2DFDB,
      levelFills: CubeExportTheme.gradient(0xFFE0F2F1, 0xFF26A69A, 4),
      borderColor: 0xFF00796B,
      headerFont: const ExportFont(bold: true),
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
    xlsxTheme: CubeExportTheme(
      borderColor: 0xFF000000,
      cellFont: ExportFont(size: 12),
      headerFont: ExportFont(size: 12, bold: true),
      summaryFont: ExportFont(size: 12, bold: true),
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
    xlsxTheme: CubeExportTheme(
      cellFont: ExportFont(size: 8),
      headerFont: ExportFont(size: 8),
      summaryFont: ExportFont(size: 8, bold: true),
    ),
  ),
];

/// Which `CubeExportTheme` the Export menu uses.
enum ExcelTheme {
  /// The preset's own [ThemePreset.xlsxTheme].
  matchPreset,

  /// `CubeExportTheme.brand` from the app's seed colour — the whole bridge
  /// from a Flutter `Color` is `toARGB32()`.
  brand,

  /// The package default.
  plain,
}

/// Resolves [choice] for [preset] and the app's [seed] colour.
CubeExportTheme excelThemeFor(
  ExcelTheme choice,
  ThemePreset preset,
  Color seed,
) => switch (choice) {
  ExcelTheme.matchPreset => preset.xlsxTheme,
  ExcelTheme.brand => CubeExportTheme.brand(primary: seed.toARGB32()),
  ExcelTheme.plain => const CubeExportTheme(),
};

/// Seed colours offered for the app's [ColorScheme].
const seedColors = <String, Color>{
  'Teal': Colors.teal,
  'Indigo': Colors.indigo,
  'Deep orange': Colors.deepOrange,
  'Brown': Colors.brown,
};
