import 'package:flutter/material.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import 'chart_widgets.dart';

/// The chart types the panel draws.
enum ChartType {
  bar('Bar'),
  stacked('Stacked'),
  line('Line'),
  pie('Pie'),
  scatter('Scatter');

  const ChartType(this.label);

  final String label;
}

/// Where the data comes from — one per engine producer.
enum ChartSource {
  /// `ChartData.fromLayout`: the cube as displayed.
  layout('Layout', 'the cube as displayed'),

  /// `ChartData.fromFacts`: a cube built for the chart over the filtered
  /// facts, independent of the pivot's axes.
  facts('Facts', 'the facts, grouped for the chart'),

  /// `ChartData.fromCell`: the facts behind the current cell (the grand
  /// total when none is selected).
  cell('Cell', 'the facts behind the current cell');

  const ChartSource(this.label, this.description);

  final String label;
  final String description;
}

/// Which axis entries `fromLayout` charts.
enum _Entries {
  leaves('leaves', ChartEntries.leaves),
  level1('level 1', ChartEntries.level(1)),
  all('all', ChartEntries.all);

  const _Entries(this.label, this.entries);

  final String label;
  final ChartEntries entries;
}

/// Maximum facts a per-fact scatter draws.
const perFactLimit = 2000;

/// A live chart of the cube in [controller]: chart type and data source as
/// chips, the controls that apply to the combination, the chart, and a
/// caption saying what is drawn (or why nothing is).
class ChartPanel extends StatefulWidget {
  const ChartPanel({
    super.key,
    required this.controller,
    required this.dimensions,
  });

  final CubeController controller;

  /// The dimensions offered for categories, series and points.
  final List<Dimension> dimensions;

  @override
  State<ChartPanel> createState() => _ChartPanelState();
}

class _ChartPanelState extends State<ChartPanel> {
  ChartType _type = ChartType.bar;
  ChartSource _source = ChartSource.layout;
  _Entries _entries = _Entries.leaves;
  bool _transpose = false;
  bool _perFact = false;

  // Remembered choices; each is validated against the current spec, cell
  // and dimension list on every build (the pivot changes under the panel).
  Aggregate? _value;
  Aggregate? _x;
  Aggregate? _y;
  Dimension? _category;
  Dimension? _series;
  Measure? _xMeasure;
  Measure? _yMeasure;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final cube = widget.controller.cube;
      final facts = cube.facts;
      final layout = cube.layout;
      final strings = TesseraLocalizations.of(context);
      final aggregates = cube.spec.aggregates;
      final cell =
          widget.controller.currentCell ??
          layout.cellFor(DimensionPath.root, DimensionPath.root)!;

      // --- resolve the choices against the current state
      final value = aggregates.contains(_value) ? _value! : aggregates.first;
      final x = aggregates.contains(_x) ? _x! : aggregates.first;
      final y = aggregates.contains(_y) && _y != x
          ? _y!
          : aggregates.firstWhere((a) => a != x, orElse: () => x);
      // in cell mode a dimension the cell pins has a single value: no use
      // as a category, series or point
      bool pinned(Dimension d) =>
          _source == ChartSource.cell && cell.coordinate.constrains(d);
      final usable = [
        for (final d in widget.dimensions)
          if (!pinned(d)) d,
      ];
      // the default category follows the pivot: its first row dimension
      // (then column dimension) that is still usable, else the first one
      final category = usable.contains(_category)
          ? _category
          : [
                  for (final axis in [cube.spec.rows, cube.spec.columns])
                    for (final d in axis.dimensions)
                      if (usable.contains(d.dimension)) d.dimension,
                ].firstOrNull ??
                usable.firstOrNull;
      final series = usable.contains(_series) && _series != category
          ? _series
          : null;
      final measures = [
        for (final c in facts.columns)
          if (c.type.isNumeric) Measure(c.name),
      ];
      // per-fact X/Y default to the columns the pivot aggregates
      final aggregated = [
        for (final a in aggregates)
          if (a is MeasureAggregate && measures.contains(a.measure)) a.measure,
      ];
      final xMeasure = measures.contains(_xMeasure)
          ? _xMeasure!
          : aggregated.firstOrNull ?? measures.firstOrNull;
      final yMeasure = measures.contains(_yMeasure) && _yMeasure != xMeasure
          ? _yMeasure!
          : [
                  for (final m in [...aggregated, ...measures])
                    if (m != xMeasure) m,
                ].firstOrNull ??
                xMeasure;
      final perFact = _perFact && _source == ChartSource.cell;

      // --- controls
      final isScatter = _type == ChartType.scatter;
      final needsDimensions = _source != ChartSource.layout;
      final controls = <Widget>[
        if (!isScatter)
          _dropdown<Aggregate>(
            label: 'Value',
            value: value,
            items: aggregates,
            itemLabel: (a) => strings.aggregateLabel(a, facts),
            onChanged: (a) => setState(() => _value = a),
          ),
        if (isScatter && !perFact) ...[
          _dropdown<Aggregate>(
            label: 'X',
            value: x,
            items: aggregates,
            itemLabel: (a) => strings.aggregateLabel(a, facts),
            onChanged: (a) => setState(() => _x = a),
          ),
          _dropdown<Aggregate>(
            label: 'Y',
            value: y,
            items: aggregates,
            itemLabel: (a) => strings.aggregateLabel(a, facts),
            onChanged: (a) => setState(() => _y = a),
          ),
        ],
        if (isScatter && perFact && xMeasure != null) ...[
          _dropdown<Measure>(
            label: 'X',
            value: xMeasure,
            items: measures,
            itemLabel: (m) => m.labelFor(facts),
            onChanged: (m) => setState(() => _xMeasure = m),
          ),
          _dropdown<Measure>(
            label: 'Y',
            value: yMeasure!,
            items: measures,
            itemLabel: (m) => m.labelFor(facts),
            onChanged: (m) => setState(() => _yMeasure = m),
          ),
        ],
        if (needsDimensions) ...[
          _dropdown<Dimension?>(
            label: isScatter ? 'Points' : 'Category',
            value: category,
            items: widget.dimensions,
            itemLabel: (d) => strings.dimensionLabel(d!, facts),
            enabled: (d) => !pinned(d!),
            onChanged: (d) => setState(() => _category = d),
          ),
          _dropdown<Dimension?>(
            label: 'Series',
            value: series,
            items: [null, ...widget.dimensions],
            itemLabel: (d) =>
                d == null ? '(none)' : strings.dimensionLabel(d, facts),
            enabled: (d) => d == null || (!pinned(d) && d != category),
            onChanged: (d) => setState(() => _series = d),
          ),
        ] else ...[
          _dropdown<_Entries>(
            label: 'Entries',
            value: _entries,
            items: _Entries.values,
            itemLabel: (e) => e.label,
            onChanged: (e) => setState(() => _entries = e!),
          ),
          _check(
            'Transpose',
            _transpose,
            (v) => setState(() => _transpose = v),
          ),
        ],
        if (isScatter && _source == ChartSource.cell)
          _check('Per fact', _perFact, (v) => setState(() => _perFact = v)),
      ];

      // --- data
      final (Widget chart, String caption) = _build(
        context,
        layout: layout,
        cell: cell,
        strings: strings,
        value: value,
        x: x,
        y: y,
        category: category,
        series: series,
        xMeasure: xMeasure,
        yMeasure: yMeasure,
        perFact: perFact,
      );

      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final t in ChartType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
                const SizedBox(width: 12),
                for (final s in ChartSource.values)
                  Tooltip(
                    message: s.description,
                    child: ChoiceChip(
                      label: Text(s.label),
                      selected: _source == s,
                      onSelected: (_) => setState(() => _source = s),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: controls,
            ),
            const SizedBox(height: 8),
            Expanded(child: chart),
            const SizedBox(height: 4),
            Text(caption, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    },
  );

  /// The chart widget and its caption for the resolved choices.
  (Widget, String) _build(
    BuildContext context, {
    required CubeLayout layout,
    required CubeCell cell,
    required TesseraStrings strings,
    required Aggregate value,
    required Aggregate x,
    required Aggregate y,
    required Dimension? category,
    required Dimension? series,
    required Measure? xMeasure,
    required Measure? yMeasure,
    required bool perFact,
  }) {
    final facts = layout.facts;
    String where() => switch (_source) {
      ChartSource.layout => 'the layout',
      ChartSource.facts => 'the facts',
      ChartSource.cell =>
        cell.coordinate.isEmpty
            ? 'the grand total (no cell selected)'
            : cell.coordinate.values.entries
                  .map(
                    (e) =>
                        '${strings.dimensionLabel(e.key, facts)} = '
                        '${e.value == null ? strings.emptyGroup : strings.formatValue(e.key, e.value)}',
                  )
                  .join(', '),
    };
    Widget message(String text) =>
        Center(child: Text(text, textAlign: TextAlign.center));

    if (_type == ChartType.scatter) {
      final ScatterData data;
      if (perFact) {
        if (xMeasure == null || yMeasure == null || xMeasure == yMeasure) {
          return (message('Two numeric columns are needed.'), '');
        }
        data = ScatterData.ofFacts(
          facts,
          x: xMeasure,
          y: yMeasure,
          series: series,
          pointLabel: category,
          rows: cell.factRows,
          limit: perFactLimit,
          strings: strings,
        );
        final n = data.points.length;
        return (
          scatterChart(context, data),
          'ScatterData.ofFacts — ${where()} — '
              '${n == perFactLimit && cell.factCount > perFactLimit ? '$perFactLimit of ${cell.factCount}' : n} facts',
        );
      }
      if (x == y) {
        return (
          message('A scatter chart needs two aggregates — add one above.'),
          '',
        );
      }
      switch (_source) {
        case ChartSource.layout:
          data = ScatterData.fromLayout(
            layout,
            x: x,
            y: y,
            points: _entries.entries,
            series: _entries.entries,
            transpose: _transpose,
            strings: strings,
          );
        case ChartSource.facts:
          if (category == null) return (message('No dimension.'), '');
          data = ScatterData.fromFacts(
            facts,
            points: category,
            series: series,
            x: x,
            y: y,
            filter: layout.spec.filter,
            strings: strings,
          );
        case ChartSource.cell:
          if (category == null) {
            return (message('Every dimension is pinned by the cell.'), '');
          }
          data = ScatterData.fromCell(
            layout,
            cell,
            points: category,
            series: series,
            x: x,
            y: y,
            strings: strings,
          );
      }
      return (
        scatterChart(context, data),
        'ScatterData.${_source == ChartSource.layout
                ? 'fromLayout'
                : _source == ChartSource.facts
                ? 'fromFacts'
                : 'fromCell'}'
            ' — ${where()} — ${data.points.length} points, ${data.series.length} series',
      );
    }

    final ChartData data;
    switch (_source) {
      case ChartSource.layout:
        data = ChartData.fromLayout(
          layout,
          aggregate: value,
          rows: _entries.entries,
          columns: _entries.entries,
          transpose: _transpose,
          strings: strings,
        );
      case ChartSource.facts:
        if (category == null) return (message('No dimension.'), '');
        data = ChartData.fromFacts(
          facts,
          category: category,
          series: series,
          aggregate: value,
          filter: layout.spec.filter,
          strings: strings,
        );
      case ChartSource.cell:
        if (category == null) {
          return (message('Every dimension is pinned by the cell.'), '');
        }
        data = ChartData.fromCell(
          layout,
          cell,
          category: category,
          series: series,
          aggregate: value,
          strings: strings,
        );
    }
    if (data.categories.isEmpty || data.series.isEmpty) {
      return (message('Nothing to chart: no entries selected.'), '');
    }
    final chart = switch (_type) {
      ChartType.bar => barChart(context, data, stacked: false),
      ChartType.stacked => barChart(context, data, stacked: true),
      ChartType.line => lineChart(context, data),
      ChartType.pie => pieChart(context, data),
      ChartType.scatter => throw StateError('handled above'),
    };
    final producer = switch (_source) {
      ChartSource.layout => 'ChartData.fromLayout',
      ChartSource.facts => 'ChartData.fromFacts',
      ChartSource.cell => 'ChartData.fromCell',
    };
    return (
      chart,
      '$producer — ${data.aggregateLabel} — ${where()} — '
          '${data.categories.length} categories × ${data.series.length} series'
          '${_type == ChartType.pie && data.series.length > 1 ? ' (pie: ${data.series.first.label})' : ''}',
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    bool Function(T)? enabled,
  }) => DropdownMenu<T>(
    // re-created when the resolved value changes under it (an aggregate
    // removed, a dimension pinned): DropdownMenu keeps its own text
    key: ValueKey((label, value)),
    label: Text(label),
    initialSelection: value,
    onSelected: onChanged,
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
    dropdownMenuEntries: [
      for (final item in items)
        DropdownMenuEntry(
          value: item,
          label: itemLabel(item),
          enabled: enabled?.call(item) ?? true,
        ),
    ],
  );

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Checkbox(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        visualDensity: VisualDensity.compact,
      ),
      Text(label),
    ],
  );
}
