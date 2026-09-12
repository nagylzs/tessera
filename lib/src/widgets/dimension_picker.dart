import 'package:flutter/material.dart';

import '../facts/dimension.dart';
import '../l10n/tessera_localizations.dart';

/// Shows a searchable list of [dimensions] and returns the one picked, or
/// `null` if dismissed. Dimensions in [used] are listed but disabled, with
/// [usedHint] as their subtitle. Texts default to the [TesseraLocalizations]
/// of [context]; [labelOf] overrides how a dimension is named (default:
/// [Dimension.label]).
Future<Dimension?> showDimensionPicker(
  BuildContext context, {
  required List<Dimension> dimensions,
  Set<Dimension> used = const {},
  String? title,
  String? searchHint,
  String? usedHint,
  String Function(Dimension)? labelOf,
}) => showDialog<Dimension>(
  context: context,
  builder: (context) => DimensionPickerDialog(
    dimensions: dimensions,
    used: used,
    title: title,
    searchHint: searchHint,
    usedHint: usedHint,
    labelOf: labelOf,
  ),
);

/// The dialog behind [showDimensionPicker]; pops with the chosen
/// [Dimension].
class DimensionPickerDialog extends StatefulWidget {
  const DimensionPickerDialog({
    super.key,
    required this.dimensions,
    this.used = const {},
    this.title,
    this.searchHint,
    this.usedHint,
    this.labelOf,
  });

  final List<Dimension> dimensions;
  final Set<Dimension> used;
  final String? title;
  final String? searchHint;
  final String? usedHint;
  final String Function(Dimension)? labelOf;

  @override
  State<DimensionPickerDialog> createState() => _DimensionPickerDialogState();
}

class _DimensionPickerDialogState extends State<DimensionPickerDialog> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = TesseraLocalizations.of(context);
    final labelOf = widget.labelOf ?? (Dimension d) => d.label;
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final d in widget.dimensions)
        if (q.isEmpty ||
            labelOf(d).toLowerCase().contains(q) ||
            d.id.toLowerCase().contains(q))
          d,
    ];
    return AlertDialog(
      title: Text(widget.title ?? strings.addDimension),
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
                  hintText: widget.searchHint ?? strings.search,
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
                    title: Text(labelOf(d)),
                    subtitle: Text(
                      used ? widget.usedHint ?? strings.alreadyInUse : d.id,
                    ),
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
