import 'package:flutter/material.dart';

import '../facts/dimension.dart';

/// Shows a searchable list of [dimensions] and returns the one picked, or
/// `null` if dismissed. Dimensions in [used] are listed but disabled, with
/// [usedHint] as their subtitle.
Future<Dimension?> showDimensionPicker(
  BuildContext context, {
  required List<Dimension> dimensions,
  Set<Dimension> used = const {},
  String title = 'Add dimension',
  String searchHint = 'Search',
  String usedHint = 'already in use',
}) => showDialog<Dimension>(
  context: context,
  builder: (context) => DimensionPickerDialog(
    dimensions: dimensions,
    used: used,
    title: title,
    searchHint: searchHint,
    usedHint: usedHint,
  ),
);

/// The dialog behind [showDimensionPicker]; pops with the chosen
/// [Dimension].
class DimensionPickerDialog extends StatefulWidget {
  const DimensionPickerDialog({
    super.key,
    required this.dimensions,
    this.used = const {},
    this.title = 'Add dimension',
    this.searchHint = 'Search',
    this.usedHint = 'already in use',
  });

  final List<Dimension> dimensions;
  final Set<Dimension> used;
  final String title;
  final String searchHint;
  final String usedHint;

  @override
  State<DimensionPickerDialog> createState() => _DimensionPickerDialogState();
}

class _DimensionPickerDialogState extends State<DimensionPickerDialog> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final d in widget.dimensions)
        if (q.isEmpty ||
            d.label.toLowerCase().contains(q) ||
            d.id.toLowerCase().contains(q))
          d,
    ];
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final d = shown[i];
                  final used = widget.used.contains(d);
                  return ListTile(
                    dense: true,
                    enabled: !used,
                    title: Text(d.label),
                    subtitle: Text(used ? widget.usedHint : d.id),
                    onTap: used ? null : () => Navigator.pop(context, d),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
