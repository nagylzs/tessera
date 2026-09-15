import 'dart:convert';

import '../facts/fact_table.dart';
import '../schema/column_type.dart';

/// Writes a [FactTable] — the imported, typed rows — as JSON records: one
/// object per fact with a field per column. What [JsonlDataSource] and
/// [JsonDataSource] read, so a table survives the round trip with its
/// types: integers stay integers, dates become ISO 8601 text that
/// inference recognizes, missing values are `null`.
///
/// [writeLines] streams row by row and is the way to write a large table;
/// [records] is lazy too. [export] builds the whole array as text.
final class JsonFactExporter {
  const JsonFactExporter({this.columns, this.useLabels = false, this.indent});

  /// The columns to write, in this order; default: every column.
  final List<String>? columns;

  /// Name the fields after the columns' labels instead of their names.
  /// Names are what a re-import expects; labels read better elsewhere.
  final bool useLabels;

  /// Pretty-print the JSON array with this indentation; `null` writes it
  /// compact. JSON Lines are always one record per line.
  final String? indent;

  /// The records, produced on demand.
  Iterable<Map<String, Object?>> records(FactTable facts) sync* {
    final names = columns ?? [for (final c in facts.columns) c.name];
    final keys = [for (final n in names) useLabels ? facts.column(n).label : n];
    final types = [for (final n in names) facts.column(n).type];
    for (var r = 0; r < facts.rowCount; r++) {
      yield {
        for (var i = 0; i < names.length; i++)
          keys[i]: _value(facts.valueAt(r, names[i]), types[i]),
      };
    }
  }

  /// The JSON array text.
  String export(FactTable facts) {
    final list = records(facts).toList(growable: false);
    final indent = this.indent;
    return indent == null
        ? jsonEncode(list)
        : JsonEncoder.withIndent(indent).convert(list);
  }

  /// The JSON Lines text: one record per line, `\n` after each.
  String exportLines(FactTable facts) {
    final out = StringBuffer();
    writeLines(out, facts);
    return out.toString();
  }

  /// Like [exportLines], into [sink], one row at a time.
  void writeLines(StringSink sink, FactTable facts) {
    for (final r in records(facts)) {
      sink.write(jsonEncode(r));
      sink.write('\n');
    }
  }

  static Object? _value(Object? v, ColumnType type) => switch (v) {
    null => null,
    final DateTime d =>
      type == ColumnType.date
          ? d.toIso8601String().substring(0, 10)
          : d.toIso8601String(),
    _ => v,
  };
}
