import 'dimension_path.dart';

/// Which groups of one axis are expanded.
///
/// Stored as the set of expanded [DimensionPath]s, kept *prefix-closed*: a
/// path can only be expanded if its parent is. The root is expanded in the
/// initial state, which is what makes the first level visible; collapsing
/// the root leaves only the summary row/column.
///
/// The state references paths, not rows/columns, so it survives data
/// changes: a path that no longer matches any group is simply ignored when
/// the layout is computed. Use [retainWhere] to drop such paths explicitly
/// (e.g. after the axis definition changed).
final class ExpansionState {
  ExpansionState._(Set<DimensionPath> expanded)
    : _expanded = Set.unmodifiable(expanded);

  /// Root expanded, everything else collapsed.
  factory ExpansionState.initial() => ExpansionState._({DimensionPath.root});

  /// Nothing expanded, not even the root.
  factory ExpansionState.collapsed() => ExpansionState._(const {});

  /// Expanded set built from [paths], closed under taking parents.
  factory ExpansionState.of(Iterable<DimensionPath> paths) {
    var state = ExpansionState.collapsed();
    for (final p in paths) {
      state = state.expand(p);
    }
    return state;
  }

  final Set<DimensionPath> _expanded;

  Set<DimensionPath> get expanded => _expanded;

  bool isExpanded(DimensionPath path) => _expanded.contains(path);

  bool get isRootExpanded => isExpanded(DimensionPath.root);

  /// Expands [path] and all its ancestors.
  ExpansionState expand(DimensionPath path) {
    final next = {..._expanded};
    var p = path;
    while (true) {
      next.add(p);
      if (p.isRoot) break;
      p = p.parent;
    }
    return ExpansionState._(next);
  }

  /// Collapses [path] and everything below it.
  ExpansionState collapse(DimensionPath path) => ExpansionState._({
    for (final p in _expanded)
      if (!p.startsWith(path)) p,
  });

  ExpansionState toggle(DimensionPath path) =>
      isExpanded(path) ? collapse(path) : expand(path);

  /// Collapses every group on [level] (`0` = the first dimension of the
  /// axis): drops the paths longer than [level], so the levels below stay
  /// hidden while the groups on [level] remain visible. `collapseLevel(0)`
  /// leaves only the root expanded. The counterpart of `Cube.expandRowLevel`
  /// / `Cube.expandColumnLevel`, which need the facts to know the groups.
  ExpansionState collapseLevel(int level) => ExpansionState._({
    for (final p in _expanded)
      if (p.length <= level) p,
  });

  /// Keeps only the paths for which [keep] returns true (and re-closes the
  /// set under parents, so dropping a path drops its subtree).
  ExpansionState retainWhere(bool Function(DimensionPath path) keep) {
    var state = this;
    for (final p in _expanded) {
      if (!keep(p)) state = state.collapse(p);
    }
    return state;
  }

  @override
  bool operator ==(Object other) =>
      other is ExpansionState &&
      other._expanded.length == _expanded.length &&
      other._expanded.containsAll(_expanded);

  @override
  int get hashCode => Object.hashAllUnordered(_expanded);

  @override
  String toString() => 'ExpansionState(${_expanded.join(', ')})';
}
