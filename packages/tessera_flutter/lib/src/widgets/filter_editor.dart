import 'package:flutter/material.dart';
import 'package:tessera/tessera.dart';

import '../l10n/tessera_localizations.dart';

/// What [FilterEditor] reports on every change: the filter built from the
/// editor's rows (`null` when there are none) and whether every row is
/// complete and valid — an empty value or an expression with an error
/// makes [isValid] false, and [filter] then omits nothing but is not to be
/// applied.
final class FilterEditorValue {
  const FilterEditorValue(this.filter, {required this.isValid});

  final FactFilter? filter;
  final bool isValid;
}

/// The outcome of [showFilterEditor]: [filter] is `null` when the user
/// removed every condition.
final class FilterEditorResult {
  const FilterEditorResult(this.filter);

  final FactFilter? filter;
}

/// Opens the filter editor as a dialog and returns the filter the user
/// applied, or `null` when the dialog was dismissed. Texts default to the
/// [TesseraStrings] of [context].
Future<FilterEditorResult?> showFilterEditor(
  BuildContext context, {
  required FactTable facts,
  FactFilter? initial,
  FunctionRegistry? functions,
  List<String>? columns,
  String? title,
}) => showDialog<FilterEditorResult>(
  context: context,
  builder: (context) => FilterEditorDialog(
    facts: facts,
    initial: initial,
    functions: functions,
    columns: columns,
    title: title,
  ),
);

/// The dialog behind [showFilterEditor]: a [FilterEditor] with Clear,
/// Cancel and Apply; pops with a [FilterEditorResult].
class FilterEditorDialog extends StatefulWidget {
  const FilterEditorDialog({
    super.key,
    required this.facts,
    this.initial,
    this.functions,
    this.columns,
    this.title,
  });

  final FactTable facts;
  final FactFilter? initial;
  final FunctionRegistry? functions;
  final List<String>? columns;
  final String? title;

  @override
  State<FilterEditorDialog> createState() => _FilterEditorDialogState();
}

class _FilterEditorDialogState extends State<FilterEditorDialog> {
  late FilterEditorValue _value = FilterEditorValue(
    widget.initial,
    isValid: true,
  );
  FactFilter? _initial;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _initial = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final strings = TesseraLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title ?? strings.filter),
      content: SizedBox(
        width: 720,
        child: FilterEditor(
          key: ValueKey(_generation),
          facts: widget.facts,
          initial: _initial,
          functions: widget.functions,
          columns: widget.columns,
          onChanged: (v) => setState(() => _value = v),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _initial = null;
            _generation++;
            _value = const FilterEditorValue(null, isValid: true);
          }),
          child: Text(strings.clear),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _value.isValid
              ? () => Navigator.pop(context, FilterEditorResult(_value.filter))
              : null,
          child: Text(strings.apply),
        ),
      ],
    );
  }
}

/// Edits a [FactFilter] as a tree of conditions.
///
/// A group combines its rows with *all of* ([AndFilter]) or *any of*
/// ([OrFilter]) and can be negated ([NotFilter]); a condition row is a
/// column, an operator and a value — [CompareFilter], [RangeFilter],
/// [TextFilter], [EmptyFilter] or, for "is one of", a [ValueFilter] with
/// values picked from the column's distinct values; an expression row is
/// an [ExpressionFilter] validated as the user types, with the error
/// underlined and explained; and a row the editor cannot represent — a
/// [PredicateFilter], or a [ValueFilter] over a dimension without an
/// expression form — is shown read-only and can only be removed.
///
/// [onChanged] fires on every edit with the current [FilterEditorValue].
class FilterEditor extends StatefulWidget {
  const FilterEditor({
    super.key,
    required this.facts,
    required this.onChanged,
    this.initial,
    this.functions,
    this.columns,
  });

  final FactTable facts;
  final FactFilter? initial;
  final ValueChanged<FilterEditorValue> onChanged;

  /// Functions beyond the built-in ones expression rows may use.
  final FunctionRegistry? functions;

  /// The columns offered in condition rows; default: every column.
  final List<String>? columns;

  @override
  State<FilterEditor> createState() => _FilterEditorState();
}

class _FilterEditorState extends State<FilterEditor> {
  late _Group _root;

  List<String> get _columns =>
      widget.columns ?? [for (final c in widget.facts.columns) c.name];

  ColumnType _typeOf(String column) => widget.facts.column(column).type;

  ExpressionScope get _scope =>
      ExpressionScope.ofFacts(widget.facts, functions: widget.functions);

  @override
  void initState() {
    super.initState();
    _root = _rootOf(widget.initial);
    for (final e in _expressions(_root)) {
      _validate(e);
    }
  }

  _Group _rootOf(FactFilter? filter) {
    if (filter == null) return _Group();
    final node = _nodeOf(filter);
    if (node is _Group) return node;
    return _Group()..children.add(node);
  }

  _Node _nodeOf(FactFilter f) {
    switch (f) {
      case AndFilter(:final filters):
        return _Group()..children.addAll(filters.map(_nodeOf));
      case OrFilter(:final filters):
        return _Group(all: false)..children.addAll(filters.map(_nodeOf));
      case NotFilter(:final filter):
        final inner = _nodeOf(filter);
        if (inner is _Group) return inner..negated = !inner.negated;
        return _Group(negated: true)..children.add(inner);
      case CompareFilter(:final column, :final op, :final value):
        if (!_has(column)) return _fallback(f);
        if (_typeOf(column) == ColumnType.boolean && value is bool) {
          final isTrue = value == (op == CompareOp.equal);
          return _Condition(column, isTrue ? _Op.isTrue : _Op.isFalse);
        }
        return _Condition(column, _Op.ofCompare(op), value: value);
      case RangeFilter(:final column, :final low, :final high):
        if (!_has(column)) return _fallback(f);
        return _Condition(column, _Op.between, value: low, high: high);
      case TextFilter(:final column, :final match, :final text):
        if (!_has(column)) return _fallback(f);
        return _Condition(column, _Op.ofMatch(match), value: text);
      case EmptyFilter(:final column, :final negated):
        if (!_has(column)) return _fallback(f);
        return _Condition(column, negated ? _Op.isNotEmpty : _Op.isEmpty);
      case ValueFilter(:final dimension, :final values):
        if (dimension is ColumnDimension && _has(dimension.sourceColumn)) {
          return _Condition(dimension.sourceColumn, _Op.isOneOf)
            ..values = {...values};
        }
        return _fallback(f);
      case ExpressionFilter(:final source):
        return _ExpressionNode(source);
      case PredicateFilter():
        return _Custom(f);
    }
  }

  bool _has(String column) =>
      widget.facts.findColumn(column) != null && _columns.contains(column);

  _Node _fallback(FactFilter f) {
    final source = f.toExpressionSource();
    return source == null ? _Custom(f) : _ExpressionNode(source);
  }

  Iterable<_ExpressionNode> _expressions(_Node n) sync* {
    switch (n) {
      case _Group(:final children):
        for (final c in children) {
          yield* _expressions(c);
        }
      case _ExpressionNode():
        yield n;
      case _Condition() || _Custom():
        break;
    }
  }

  void _validate(_ExpressionNode e) {
    e.error = Expression.validate(
      e.source,
      scope: _scope,
      expected: ExprType.boolean,
    );
  }

  // ------------------------------------------------------------- building

  FactFilter? _build(_Node n) {
    switch (n) {
      case _Group(:final children, :final all, :final negated):
        final parts = [for (final c in children) ?_build(c)];
        if (parts.isEmpty) return null;
        final combined = parts.length == 1
            ? parts.single
            : all
            ? AndFilter(parts)
            : OrFilter(parts);
        return negated ? NotFilter(combined) : combined;
      case _Condition(:final column, :final op, :final value, :final high):
        final v = value, h = high;
        return switch (op) {
          _Op.equals =>
            v == null ? null : CompareFilter(column, CompareOp.equal, v),
          _Op.notEquals =>
            v == null ? null : CompareFilter(column, CompareOp.notEqual, v),
          _Op.less =>
            v == null ? null : CompareFilter(column, CompareOp.less, v),
          _Op.lessOrEqual =>
            v == null ? null : CompareFilter(column, CompareOp.lessOrEqual, v),
          _Op.greater =>
            v == null ? null : CompareFilter(column, CompareOp.greater, v),
          _Op.greaterOrEqual =>
            v == null
                ? null
                : CompareFilter(column, CompareOp.greaterOrEqual, v),
          _Op.between =>
            v == null || h == null ? null : RangeFilter(column, v, h),
          _Op.contains =>
            v is! String ? null : TextFilter(column, TextMatch.contains, v),
          _Op.startsWith =>
            v is! String ? null : TextFilter(column, TextMatch.startsWith, v),
          _Op.endsWith =>
            v is! String ? null : TextFilter(column, TextMatch.endsWith, v),
          _Op.isEmpty => EmptyFilter(column),
          _Op.isNotEmpty => EmptyFilter(column, negated: true),
          _Op.isOneOf =>
            n.values.isEmpty
                ? null
                : ValueFilter(ColumnDimension(column), n.values),
          _Op.isTrue => CompareFilter(column, CompareOp.equal, true),
          _Op.isFalse => CompareFilter(column, CompareOp.equal, false),
        };
      case _ExpressionNode(:final source, :final error):
        return error == null ? ExpressionFilter(source) : null;
      case _Custom(:final filter):
        return filter;
    }
  }

  bool _isValid(_Node n) => switch (n) {
    _Group(:final children) => children.every(_isValid),
    _Condition() => _build(n) != null,
    _ExpressionNode(:final error) => error == null,
    _Custom() => true,
  };

  void _changed(VoidCallback edit) {
    setState(edit);
    widget.onChanged(
      FilterEditorValue(_build(_root), isValid: _isValid(_root)),
    );
  }

  // --------------------------------------------------------------- widgets

  @override
  Widget build(BuildContext context) {
    final strings = TesseraLocalizations.of(context);
    return SingleChildScrollView(
      child: _group(context, strings, _root, parent: null),
    );
  }

  Widget _group(
    BuildContext context,
    TesseraStrings strings,
    _Group g, {
    required _Group? parent,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: true, label: Text(strings.matchAll)),
                    ButtonSegment(value: false, label: Text(strings.matchAny)),
                  ],
                  selected: {g.all},
                  onSelectionChanged: (s) => _changed(() => g.all = s.single),
                ),
                FilterChip(
                  label: Text(strings.negate),
                  selected: g.negated,
                  onSelected: (v) => _changed(() => g.negated = v),
                ),
                MenuAnchor(
                  menuChildren: [
                    MenuItemButton(
                      onPressed: () => _changed(() {
                        final column = _columns.first;
                        g.children.add(
                          _Condition(
                            column,
                            _Op.forType(_typeOf(column)).first,
                          ),
                        );
                      }),
                      child: Text(strings.addCondition),
                    ),
                    MenuItemButton(
                      onPressed: () => _changed(() => g.children.add(_Group())),
                      child: Text(strings.addGroup),
                    ),
                    MenuItemButton(
                      onPressed: () => _changed(() {
                        final e = _ExpressionNode('');
                        _validate(e);
                        g.children.add(e);
                      }),
                      child: Text(strings.addExpression),
                    ),
                  ],
                  builder: (context, menu, _) => IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: strings.addCondition,
                    onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                  ),
                ),
                if (parent != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: MaterialLocalizations.of(context)
                        .deleteButtonTooltip,
                    onPressed: () => _changed(() => parent.children.remove(g)),
                  ),
              ],
            ),
            if (g.children.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(strings.noFilter, style: theme.textTheme.bodySmall),
              ),
            for (final child in g.children)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: switch (child) {
                  _Group() => _group(context, strings, child, parent: g),
                  _Condition() => _condition(context, strings, g, child),
                  _ExpressionNode() => _expression(context, strings, g, child),
                  _Custom() => _custom(context, strings, g, child),
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _condition(
    BuildContext context,
    TesseraStrings strings,
    _Group parent,
    _Condition c,
  ) {
    final type = _typeOf(c.column);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<String>(
          value: c.column,
          items: [
            for (final name in _columns)
              DropdownMenuItem(
                value: name,
                child: Text(widget.facts.column(name).label),
              ),
          ],
          onChanged: (name) => _changed(() {
            if (name == null) return;
            c.column = name;
            final ops = _Op.forType(_typeOf(name));
            if (!ops.contains(c.op)) c.op = ops.first;
            c.value = null;
            c.high = null;
            c.values = {};
            c.revision++;
          }),
        ),
        DropdownButton<_Op>(
          value: c.op,
          items: [
            for (final op in _Op.forType(type))
              DropdownMenuItem(value: op, child: Text(op.label(strings))),
          ],
          onChanged: (op) => _changed(() {
            if (op == null) return;
            c.op = op;
            c.revision++;
          }),
        ),
        if (c.op == _Op.isOneOf)
          OutlinedButton(
            onPressed: () => _pickValues(context, strings, c),
            child: Text(
              c.values.isEmpty
                  ? strings.selectValues
                  : strings.selectedCount(c.values.length),
            ),
          ),
        if (c.op.needsValue)
          _valueField(context, strings, c, type, high: false),
        if (c.op == _Op.between)
          _valueField(context, strings, c, type, high: true),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
          onPressed: () => _changed(() => parent.children.remove(c)),
        ),
      ],
    );
  }

  Widget _valueField(
    BuildContext context,
    TesseraStrings strings,
    _Condition c,
    ColumnType type, {
    required bool high,
  }) {
    final current = high ? c.high : c.value;
    final isDate = type == ColumnType.date || type == ColumnType.dateTime;
    return SizedBox(
      width: 180,
      child: TextFormField(
        key: ValueKey((c, high, c.revision)),
        initialValue: _formatValue(current),
        decoration: InputDecoration(
          isDense: true,
          labelText: strings.value,
          suffixIcon: isDate
              ? IconButton(
                  icon: const Icon(Icons.calendar_today_outlined),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: current is DateTime
                          ? current
                          : DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                    );
                    if (picked == null) return;
                    _changed(() {
                      final d = DateTime.utc(
                        picked.year,
                        picked.month,
                        picked.day,
                      );
                      if (high) {
                        c.high = d;
                      } else {
                        c.value = d;
                      }
                      c.revision++;
                    });
                  },
                )
              : null,
        ),
        keyboardType: type.isNumeric
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : null,
        onChanged: (text) => _changed(() {
          final v = _parseValue(text, type);
          if (high) {
            c.high = v;
          } else {
            c.value = v;
          }
        }),
      ),
    );
  }

  static String _formatValue(Object? v) => switch (v) {
    null => '',
    DateTime d => DateLiteral.formatDate(d),
    num n =>
      n == n.truncate() && n.abs() < 1e15 ? n.toInt().toString() : n.toString(),
    _ => v.toString(),
  };

  static Object? _parseValue(String text, ColumnType type) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return switch (type) {
      ColumnType.integer || ColumnType.number => double.tryParse(t),
      ColumnType.date || ColumnType.dateTime => parseDateLiteral(t),
      ColumnType.boolean => switch (t.toLowerCase()) {
        'true' => true,
        'false' => false,
        _ => null,
      },
      ColumnType.text => text,
    };
  }

  Future<void> _pickValues(
    BuildContext context,
    TesseraStrings strings,
    _Condition c,
  ) async {
    final dimension = ColumnDimension(c.column);
    final picked = await showDialog<Set<Object?>>(
      context: context,
      builder: (context) => _ValuePickerDialog(
        title: widget.facts.column(c.column).label,
        values: widget.facts.distinctValues(dimension),
        selected: c.values,
        labelOf: (v) =>
            v == null ? strings.emptyGroup : strings.formatValue(dimension, v),
      ),
    );
    if (picked == null) return;
    _changed(() => c.values = picked);
  }

  Widget _expression(
    BuildContext context,
    TesseraStrings strings,
    _Group parent,
    _ExpressionNode e,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _ExpressionField(
          key: ValueKey(e),
          node: e,
          label: strings.expression,
          errorText: e.error == null ? null : strings.expressionError(e.error!),
          onChanged: (text) => _changed(() {
            e.source = text;
            _validate(e);
          }),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
        onPressed: () => _changed(() => parent.children.remove(e)),
      ),
    ],
  );

  Widget _custom(
    BuildContext context,
    TesseraStrings strings,
    _Group parent,
    _Custom c,
  ) {
    final f = c.filter;
    final label = f is PredicateFilter ? f.label : null;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.code),
      title: Text(label ?? strings.customFilter),
      subtitle: label == null ? null : Text(strings.customFilter),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
        onPressed: () => _changed(() => parent.children.remove(c)),
      ),
    );
  }
}

// ------------------------------------------------------------------ model

sealed class _Node {}

final class _Group extends _Node {
  _Group({this.all = true, this.negated = false});

  bool all;
  bool negated;
  final children = <_Node>[];
}

final class _Condition extends _Node {
  _Condition(this.column, this.op, {this.value, this.high});

  String column;
  _Op op;
  Object? value;
  Object? high;
  Set<Object?> values = {};

  /// Bumped when the value fields must be rebuilt with new initial text.
  int revision = 0;
}

final class _ExpressionNode extends _Node {
  _ExpressionNode(this.source);

  String source;
  ExpressionError? error;
}

final class _Custom extends _Node {
  _Custom(this.filter);

  final FactFilter filter;
}

enum _Op {
  equals,
  notEquals,
  less,
  lessOrEqual,
  greater,
  greaterOrEqual,
  between,
  contains,
  startsWith,
  endsWith,
  isOneOf,
  isEmpty,
  isNotEmpty,
  isTrue,
  isFalse;

  static List<_Op> forType(ColumnType type) => switch (type) {
    ColumnType.text => const [
      equals,
      notEquals,
      contains,
      startsWith,
      endsWith,
      isOneOf,
      isEmpty,
      isNotEmpty,
    ],
    ColumnType.boolean => const [isTrue, isFalse, isEmpty, isNotEmpty],
    ColumnType.integer ||
    ColumnType.number ||
    ColumnType.date ||
    ColumnType.dateTime => const [
      equals,
      notEquals,
      less,
      lessOrEqual,
      greater,
      greaterOrEqual,
      between,
      isOneOf,
      isEmpty,
      isNotEmpty,
    ],
  };

  static _Op ofCompare(CompareOp op) => switch (op) {
    CompareOp.equal => equals,
    CompareOp.notEqual => notEquals,
    CompareOp.less => less,
    CompareOp.lessOrEqual => lessOrEqual,
    CompareOp.greater => greater,
    CompareOp.greaterOrEqual => greaterOrEqual,
  };

  static _Op ofMatch(TextMatch match) => switch (match) {
    TextMatch.contains => contains,
    TextMatch.startsWith => startsWith,
    TextMatch.endsWith => endsWith,
  };

  bool get needsValue => switch (this) {
    equals ||
    notEquals ||
    less ||
    lessOrEqual ||
    greater ||
    greaterOrEqual ||
    between ||
    contains ||
    startsWith ||
    endsWith => true,
    isOneOf || isEmpty || isNotEmpty || isTrue || isFalse => false,
  };

  String label(TesseraStrings s) => switch (this) {
    equals => s.opEquals,
    notEquals => s.opNotEquals,
    less => s.opLess,
    lessOrEqual => s.opLessOrEqual,
    greater => s.opGreater,
    greaterOrEqual => s.opGreaterOrEqual,
    between => s.opBetween,
    contains => s.opContains,
    startsWith => s.opStartsWith,
    endsWith => s.opEndsWith,
    isOneOf => s.opIsOneOf,
    isEmpty => s.opIsEmpty,
    isNotEmpty => s.opIsNotEmpty,
    isTrue => s.opIsTrue,
    isFalse => s.opIsFalse,
  };
}

// ------------------------------------------------------- expression field

/// A text field whose controller underlines the range of the current
/// [ExpressionError].
class _ExpressionField extends StatefulWidget {
  const _ExpressionField({
    super.key,
    required this.node,
    required this.label,
    required this.errorText,
    required this.onChanged,
  });

  final _ExpressionNode node;
  final String label;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  State<_ExpressionField> createState() => _ExpressionFieldState();
}

class _ExpressionFieldState extends State<_ExpressionField> {
  late final _controller = ExpressionTextController(text: widget.node.source);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _controller.error = widget.node.error;
    return TextField(
      controller: _controller,
      style: const TextStyle(fontFamily: 'monospace'),
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.label,
        errorText: widget.errorText,
        errorMaxLines: 3,
      ),
      onChanged: widget.onChanged,
    );
  }
}

/// A [TextEditingController] that renders the source range of an
/// [ExpressionError] with a wavy red underline, the way code editors mark
/// a problem. Set [error] before each build.
class ExpressionTextController extends TextEditingController {
  ExpressionTextController({super.text});

  ExpressionError? error;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final e = error;
    final t = text;
    if (e == null || e.length == 0 || e.offset >= t.length) {
      return TextSpan(text: t, style: style);
    }
    final end = (e.offset + e.length).clamp(0, t.length);
    final color = Theme.of(context).colorScheme.error;
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: t.substring(0, e.offset)),
        TextSpan(
          text: t.substring(e.offset, end),
          style: TextStyle(
            decoration: TextDecoration.underline,
            decorationColor: color,
            decorationStyle: TextDecorationStyle.wavy,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
        TextSpan(text: t.substring(end)),
      ],
    );
  }
}

// ----------------------------------------------------------- value picker

class _ValuePickerDialog extends StatefulWidget {
  const _ValuePickerDialog({
    required this.title,
    required this.values,
    required this.selected,
    required this.labelOf,
  });

  final String title;
  final List<Object?> values;
  final Set<Object?> selected;
  final String Function(Object?) labelOf;

  @override
  State<_ValuePickerDialog> createState() => _ValuePickerDialogState();
}

class _ValuePickerDialogState extends State<_ValuePickerDialog> {
  late final Set<Object?> _selected = {...widget.selected};
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = TesseraLocalizations.of(context);
    final q = _query.toLowerCase();
    final shown = [
      for (final v in widget.values)
        if (q.isEmpty || widget.labelOf(v).toLowerCase().contains(q)) v,
    ];
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        height: 480,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: strings.search,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final v in shown)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _selected.contains(v),
                      title: Text(widget.labelOf(v)),
                      onChanged: (on) => setState(() {
                        if (on == true) {
                          _selected.add(v);
                        } else {
                          _selected.remove(v);
                        }
                      }),
                    ),
                ],
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
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
