import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tessera_flutter/tessera_flutter.dart';

import '../common/workbench.dart';
import 'presets.dart';

/// The sales cube of the "Simple pivot" example under a choice of
/// [CubeTheme] presets and app colour schemes (seed colour, light/dark),
/// to show which parts of the grid a theme controls and how unset values
/// follow the ambient [ThemeData].
class ThemingPage extends StatefulWidget {
  const ThemingPage({super.key});

  @override
  State<ThemingPage> createState() => _ThemingPageState();
}

class _ThemingPageState extends State<ThemingPage> {
  static const region = ColumnDimension('region');
  static const country = ColumnDimension('country');
  static const year = DatePartDimension('date', DatePart.year);
  static const quarter = DatePartDimension('date', DatePart.quarter);

  late final Future<DataSource> _source = _load();
  ThemePreset _preset = themePresets.first;
  String _seed = seedColors.keys.first;
  bool? _dark; // null follows the platform

  Future<DataSource> _load() async {
    final data = await rootBundle.load('assets/sales.csv');
    return CsvDataSource.fromData(data.buffer.asUint8List(), name: 'sales.csv');
  }

  @override
  Widget build(BuildContext context) {
    final brightness = switch (_dark) {
      null => Theme.of(context).brightness,
      true => Brightness.dark,
      false => Brightness.light,
    };
    // The app theme is overridden locally, so the workbench (AppBar,
    // menus, the CubeView's derived colours) follows the choice.
    return Theme(
      data: ThemeData(
        colorSchemeSeed: seedColors[_seed],
        brightness: brightness,
      ),
      child: FutureBuilder(
        future: _source,
        builder: (context, snapshot) {
          final source = snapshot.data;
          if (source == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Tessera — theming')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          return CubeWorkbench(
            source: source,
            title: 'Tessera — ${_preset.name}',
            progressEvery: 250,
            theme: _preset.theme,
            actions: (context, controller) => [_themeMenu(controller)],
            initialSpec: (facts) => CubeSpec(
              rows: CubeAxis.of([region, country]),
              columns: CubeAxis.of([year, quarter]),
              aggregates: [
                Aggregate.sum(const Measure('total')),
                Aggregate.count,
                Aggregate.average(const Measure('unit_price')),
              ],
            ),
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
      ),
    );
  }

  /// Presets, seed colours, brightness and — spec state rather than
  /// theme, but a visual choice — the summary position of each axis, in
  /// one AppBar menu.
  Widget _themeMenu(CubeController? controller) => controller == null
      ? _menu(null)
      : ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _menu(controller),
        );

  Widget _menu(CubeController? controller) => MenuAnchor(
    builder: (context, menu, _) => IconButton(
      icon: const Icon(Icons.palette_outlined),
      tooltip: 'Theme',
      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
    ),
    menuChildren: [
      for (final p in themePresets)
        MenuItemButton(
          leadingIcon: Icon(p == _preset ? Icons.check : null),
          onPressed: () => setState(() => _preset = p),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name),
              Text(p.description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      const Divider(height: 1),
      for (final e in seedColors.entries)
        MenuItemButton(
          leadingIcon: Icon(
            e.key == _seed ? Icons.check : Icons.circle,
            color: e.key == _seed ? null : e.value,
          ),
          onPressed: () => setState(() => _seed = e.key),
          child: Text(e.key),
        ),
      const Divider(height: 1),
      for (final (label, value) in [
        ('System brightness', null),
        ('Light', false),
        ('Dark', true),
      ])
        MenuItemButton(
          leadingIcon: Icon(value == _dark ? Icons.check : null),
          onPressed: () => setState(() => _dark = value),
          child: Text(label),
        ),
      const Divider(height: 1),
      for (final side in AxisSide.values)
        SubmenuButton(
          menuChildren: [
            for (final (label, position) in [
              ('At the end', SummaryPosition.end),
              ('At the start', SummaryPosition.start),
              ('Hidden', SummaryPosition.hidden),
            ])
              MenuItemButton(
                leadingIcon: Icon(
                  controller != null &&
                          _positionOf(controller, side) == position
                      ? Icons.check
                      : null,
                ),
                onPressed: controller == null
                    ? null
                    : () => _setPosition(controller, side, position),
                child: Text(label),
              ),
          ],
          child: Text(side == AxisSide.rows ? 'Row totals' : 'Column totals'),
        ),
    ],
  );

  static SummaryPosition _positionOf(CubeController c, AxisSide side) =>
      (side == AxisSide.rows ? c.cube.spec.rows : c.cube.spec.columns)
          .summaryPosition;

  static void _setPosition(
    CubeController c,
    AxisSide side,
    SummaryPosition position,
  ) {
    final spec = c.cube.spec;
    c.updateSpec(
      side == AxisSide.rows
          ? spec.copyWith(rows: spec.rows.copyWith(summaryPosition: position))
          : spec.copyWith(
              columns: spec.columns.copyWith(summaryPosition: position),
            ),
    );
  }
}
