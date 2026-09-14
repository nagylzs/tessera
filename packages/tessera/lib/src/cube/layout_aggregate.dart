import '../facts/fact_table.dart';
import 'aggregate.dart';

/// One of the two axes of a cube.
enum AxisSide { rows, columns }

/// The reference cell of a [PercentOfTotalAggregate].
enum TotalOf {
  /// The row's summary cell (the same row, the column total).
  row,

  /// The column's summary cell (the same column, the row total).
  column,

  /// The cell of the two summaries.
  grand,

  /// The cell of the row group one level up (the same column).
  parentRow,

  /// The cell of the column group one level up (the same row).
  parentColumn,
}

/// Which sibling a [DifferenceFromAggregate] compares with, along one
/// axis: the previous or next group in display order, or the group with a
/// given value.
sealed class BaseItem {
  const BaseItem();

  static const previous = PreviousItem();
  static const next = NextItem();

  /// The sibling whose dimension value is [value] (`null` = the empty
  /// group).
  const factory BaseItem.value(Object? value) = ValueItem;

  /// The item as it appears in an [Aggregate.id].
  String get id;
}

final class PreviousItem extends BaseItem {
  const PreviousItem();

  @override
  String get id => 'previous';
}

final class NextItem extends BaseItem {
  const NextItem();

  @override
  String get id => 'next';
}

final class ValueItem extends BaseItem {
  const ValueItem(this.value);

  final Object? value;

  @override
  String get id => 'value:$value';

  @override
  bool operator ==(Object other) => other is ValueItem && other.value == value;

  @override
  int get hashCode => Object.hash(ValueItem, value);
}

/// What a [LayoutAggregate] sees when it is computed for a cell: the
/// cell's own results and the results of the cells around it in the
/// layout. Every lookup returns `null` when the reference cell does not
/// exist (no parent above the root, no previous sibling for the first
/// group, a value that is not among the siblings) or is empty.
abstract interface class LayoutCellContext {
  /// The result of [aggregate] in this cell.
  Object? value(Aggregate aggregate);

  /// The result of [aggregate] in the reference cell [of].
  Object? total(Aggregate aggregate, TotalOf of);

  /// The result of [aggregate] in the sibling group [item] along [axis]
  /// (same parent, same level, same position on the other axis).
  Object? sibling(Aggregate aggregate, AxisSide axis, BaseItem item);

  /// The results of [aggregate] in every sibling along [axis] with facts,
  /// in display order, this cell's group included, and this group's
  /// index among them (`-1` for a summary, which has no siblings).
  (List<Object?> values, int index) siblings(
    Aggregate aggregate,
    AxisSide axis,
  );
}

/// An aggregate computed per cell from the *layout*: the cell's own
/// result of [base] set against the results of other cells — a total, a
/// parent, a sibling. Excel's "Show Values As".
///
/// The engine computes it when the cell is read; [base] is accumulated
/// (or derived) as usual. Sorting by a layout aggregate sorts by its
/// [base]. [createAccumulator] is never called and throws.
abstract class LayoutAggregate<R> extends Aggregate<R> {
  const LayoutAggregate();

  /// The aggregate the calculation is applied to; its results must be
  /// numbers.
  Aggregate get base;

  R? compute(LayoutCellContext context);

  @override
  AggregateAccumulator<R> createAccumulator() =>
      throw UnsupportedError('$id is computed from the layout');

  @override
  String labelFor(FactTable facts) => label;

  static double? _number(Object? v) => v is num ? v.toDouble() : null;
}

/// [base] as a percentage of the reference cell [of]: `value / total ×
/// 100`; `null` when either is missing or the total is zero.
final class PercentOfTotalAggregate extends LayoutAggregate<double> {
  const PercentOfTotalAggregate(this.base, this.of);

  @override
  final Aggregate base;
  final TotalOf of;

  @override
  String get id => 'percentOf(${of.name}, ${base.id})';

  @override
  String get label => '${base.label} % of ${_ofLabel[of]}';

  static const _ofLabel = {
    TotalOf.row: 'row total',
    TotalOf.column: 'column total',
    TotalOf.grand: 'grand total',
    TotalOf.parentRow: 'parent row',
    TotalOf.parentColumn: 'parent column',
  };

  @override
  double? compute(LayoutCellContext context) {
    final v = LayoutAggregate._number(context.value(base));
    final t = LayoutAggregate._number(context.total(base, of));
    if (v == null || t == null || t == 0) return null;
    return v / t * 100;
  }
}

/// [base] minus its value in the sibling [item] along [axis]; `null` when
/// either is missing.
final class DifferenceFromAggregate extends LayoutAggregate<double> {
  const DifferenceFromAggregate(this.base, this.axis, this.item);

  @override
  final Aggregate base;
  final AxisSide axis;
  final BaseItem item;

  @override
  String get id => 'differenceFrom(${axis.name}.${item.id}, ${base.id})';

  @override
  String get label => '${base.label} difference from ${_itemLabel(item)}';

  @override
  double? compute(LayoutCellContext context) {
    final v = LayoutAggregate._number(context.value(base));
    final r = LayoutAggregate._number(context.sibling(base, axis, item));
    if (v == null || r == null) return null;
    return v - r;
  }
}

/// `(value − reference) / reference × 100` against the sibling [item]
/// along [axis]; `null` when either is missing or the reference is zero.
final class PercentDifferenceFromAggregate extends LayoutAggregate<double> {
  const PercentDifferenceFromAggregate(this.base, this.axis, this.item);

  @override
  final Aggregate base;
  final AxisSide axis;
  final BaseItem item;

  @override
  String get id => 'percentDifferenceFrom(${axis.name}.${item.id}, ${base.id})';

  @override
  String get label => '${base.label} % difference from ${_itemLabel(item)}';

  @override
  double? compute(LayoutCellContext context) {
    final v = LayoutAggregate._number(context.value(base));
    final r = LayoutAggregate._number(context.sibling(base, axis, item));
    if (v == null || r == null || r == 0) return null;
    return (v - r) / r * 100;
  }
}

String _itemLabel(BaseItem item) => switch (item) {
  PreviousItem() => 'previous',
  NextItem() => 'next',
  ValueItem(:final value) => value?.toString() ?? '(empty)',
};

/// The sum of [base] over the siblings along [axis] up to and including
/// this group, in display order; missing values are skipped, `null` when
/// none so far.
final class RunningTotalAggregate extends LayoutAggregate<double> {
  const RunningTotalAggregate(this.base, this.axis);

  @override
  final Aggregate base;
  final AxisSide axis;

  @override
  String get id => 'runningTotal(${axis.name}, ${base.id})';

  @override
  String get label => '${base.label} running total';

  @override
  double? compute(LayoutCellContext context) {
    final (values, index) = context.siblings(base, axis);
    if (index < 0) return LayoutAggregate._number(context.value(base));
    double? sum;
    for (var i = 0; i <= index; i++) {
      final v = LayoutAggregate._number(values[i]);
      if (v != null) sum = (sum ?? 0) + v;
    }
    return sum;
  }
}

/// The rank of [base] among the siblings along [axis]: 1 for the largest
/// (or, with [ascending], the smallest); equal values share a rank, the
/// next rank is skipped (1, 2, 2, 4); `null` for a missing value or a
/// summary.
final class RankAggregate extends LayoutAggregate<int> {
  const RankAggregate(this.base, this.axis, {this.ascending = false});

  @override
  final Aggregate base;
  final AxisSide axis;
  final bool ascending;

  @override
  String get id =>
      'rank(${axis.name}${ascending ? '.ascending' : ''}, ${base.id})';

  @override
  String get label => '${base.label} rank';

  @override
  int? compute(LayoutCellContext context) {
    final (values, index) = context.siblings(base, axis);
    if (index < 0) return null;
    final own = LayoutAggregate._number(values[index]);
    if (own == null) return null;
    var better = 0;
    for (final raw in values) {
      final v = LayoutAggregate._number(raw);
      if (v == null) continue;
      if (ascending ? v < own : v > own) better++;
    }
    return better + 1;
  }
}
