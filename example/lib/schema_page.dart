import 'package:flutter/material.dart';
import 'package:tessera/tessera.dart';

/// Lets the user override an inferred [Schema] before importing: include or
/// exclude columns, change their type and label, and set the date format or
/// number syntax used to parse text.
///
/// Pops with the edited [Schema], or `null` when cancelled.
class SchemaPage extends StatefulWidget {
  const SchemaPage({
    super.key,
    required this.schema,
    required this.inferred,
    required this.sampleRows,
    required this.columnNames,
  });

  /// Schema to start from.
  final Schema schema;

  /// The schema as inferred, for "Reset".
  final Schema inferred;

  /// A few source rows, shown as raw samples next to each column.
  final List<SourceRow> sampleRows;
  final List<String> columnNames;

  @override
  State<SchemaPage> createState() => _SchemaPageState();
}

class _SchemaPageState extends State<SchemaPage> {
  late Schema _schema = widget.schema;

  String _samples(String column) {
    final i = widget.columnNames.indexOf(column);
    if (i < 0) return '';
    return widget.sampleRows
        .map((r) => i < r.length ? r[i]?.toString() ?? '' : '')
        .where((s) => s.isNotEmpty)
        .take(3)
        .join(' · ');
  }

  void _set(ColumnSpec spec) => setState(() => _schema = _schema.replace(spec));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Schema'),
      actions: [
        TextButton(
          onPressed: () => setState(() => _schema = widget.inferred),
          child: const Text('Reset to inferred'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _schema),
          icon: const Icon(Icons.download),
          label: const Text('Import'),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _schema.columns.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _ColumnRow(
        spec: _schema.columns[i],
        samples: _samples(_schema.columns[i].name),
        onChanged: _set,
      ),
    ),
  );
}

class _ColumnRow extends StatelessWidget {
  const _ColumnRow({
    required this.spec,
    required this.samples,
    required this.onChanged,
  });

  final ColumnSpec spec;
  final String samples;
  final ValueChanged<ColumnSpec> onChanged;

  /// [ColumnSpec.copyWith] cannot clear [ColumnSpec.format], so rebuild.
  ColumnSpec _with({
    bool? include,
    ColumnType? type,
    String? label,
    String? format,
    bool clearFormat = false,
    NumberSyntax? numberSyntax,
  }) => ColumnSpec(
    name: spec.name,
    type: type ?? spec.type,
    include: include ?? spec.include,
    label: label ?? spec.label,
    format: clearFormat ? null : format ?? spec.format,
    numberSyntax: numberSyntax ?? spec.numberSyntax,
    parser: spec.parser,
    nullValues: spec.nullValues,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDate =
        spec.type == ColumnType.date || spec.type == ColumnType.dateTime;
    final isNumeric = spec.type.isNumeric;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Switch(
            value: spec.include,
            onChanged: (v) => onChanged(_with(include: v)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spec.name, style: theme.textTheme.titleSmall),
                Text(
                  samples,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<ColumnType>(
              key: ValueKey('type-${spec.name}'),
              isExpanded: true,
              initialValue: spec.type,
              decoration: const InputDecoration(
                labelText: 'Type',
                isDense: true,
              ),
              items: [
                for (final t in ColumnType.values)
                  DropdownMenuItem(value: t, child: Text(t.name)),
              ],
              onChanged: spec.include
                  ? (t) => onChanged(_with(type: t, clearFormat: true))
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 180,
            child: TextFormField(
              key: ValueKey('label-${spec.name}'),
              initialValue: spec.label ?? '',
              enabled: spec.include,
              decoration: InputDecoration(
                labelText: 'Label',
                hintText: spec.name,
                isDense: true,
              ),
              onChanged: (v) => onChanged(_with(label: v.isEmpty ? null : v)),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: isDate
                ? TextFormField(
                    key: ValueKey('format-${spec.name}'),
                    initialValue: spec.format ?? '',
                    enabled: spec.include,
                    decoration: const InputDecoration(
                      labelText: 'Date format',
                      hintText: 'yyyy-MM-dd (defaults)',
                      isDense: true,
                    ),
                    onChanged: (v) => onChanged(
                      v.isEmpty ? _with(clearFormat: true) : _with(format: v),
                    ),
                  )
                : isNumeric
                ? DropdownButtonFormField<NumberSyntax>(
                    key: ValueKey('syntax-${spec.name}'),
                    isExpanded: true,
                    initialValue: spec.numberSyntax,
                    decoration: const InputDecoration(
                      labelText: 'Number syntax',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: NumberSyntax.standard,
                        child: Text('1,234.56'),
                      ),
                      DropdownMenuItem(
                        value: NumberSyntax.european,
                        child: Text('1.234,56'),
                      ),
                    ],
                    onChanged: spec.include
                        ? (s) => onChanged(_with(numberSyntax: s))
                        : null,
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}
