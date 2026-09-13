import 'dart:typed_data';

import '../facts/dimension.dart';
import '../facts/fact_table.dart';
import '../facts/fact_table_impl.dart';
import 'aggregate.dart';
import 'cube_layout.dart';
import 'cube_spec.dart';
import 'dimension_path.dart';
import 'expansion_state.dart';
import 'filter.dart';

// Internal implementation of Cube.layout. Not exported.

/// A dimension's values over all facts, dictionary encoded: `codes[row]`
/// indexes into [values], which is sorted by [Dimension.compareValues] so
/// `null` (if present) is code 0.
final class DimensionCodes {
  DimensionCodes._(this.dimension, this.values, this.codes)
    : _index = {for (var i = 0; i < values.length; i++) values[i]: i};

  final Dimension dimension;
  final List<Object?> values;
  final Int32List codes;
  final Map<Object?, int> _index;

  bool get hasNull => values.isNotEmpty && values.first == null;

  int? codeOf(Object? value) => _index[value];

  static DimensionCodes build(FactTable facts, Dimension dimension) {
    final values = facts.distinctValues(dimension);
    final index = {for (var i = 0; i < values.length; i++) values[i]: i};
    final codes = Int32List(facts.rowCount);
    // Fast path: a plain text column is already dictionary encoded.
    if (dimension is ColumnDimension && facts is FactTableImpl) {
      final column = facts.column(dimension.sourceColumn);
      if (column is TextColumn) {
        final remap = Int32List(column.dictionary.length);
        for (var c = 0; c < remap.length; c++) {
          remap[c] = index[column.dictionary[c]]!;
        }
        final nullCode = index[null] ?? -1;
        for (var r = 0; r < codes.length; r++) {
          final c = column.codes[r];
          codes[r] = c < 0 ? nullCode : remap[c];
        }
        return DimensionCodes._(dimension, values, codes);
      }
    }
    for (var r = 0; r < codes.length; r++) {
      codes[r] = index[facts.dimensionValue(r, dimension)]!;
    }
    return DimensionCodes._(dimension, values, codes);
  }
}

/// Per-facts intermediate results shared by every cube derived with
/// `copyWith`.
final class CubeCache {
  final _codes = <Dimension, DimensionCodes>{};
  FactFilter? _filterKey;
  Int32List? _filtered;

  DimensionCodes codesFor(FactTable facts, Dimension dimension) => _codes
      .putIfAbsent(dimension, () => DimensionCodes.build(facts, dimension));

  /// Indices of the facts passing [filter], in table order.
  Int32List filteredRows(FactTable facts, FactFilter? filter) {
    final cached = _filtered;
    if (cached != null && identical(_filterKey, filter)) return cached;
    final Int32List rows;
    if (filter == null) {
      rows = Int32List(facts.rowCount);
      for (var r = 0; r < rows.length; r++) {
        rows[r] = r;
      }
    } else {
      final list = <int>[];
      for (var r = 0; r < facts.rowCount; r++) {
        if (filter.matches(facts, r)) list.add(r);
      }
      rows = Int32List.fromList(list);
    }
    _filterKey = filter;
    return _filtered = rows;
  }
}

/// Accumulated state of one cell.
final class CellData {
  CellData(List<Aggregate> aggregates)
    : accumulators = [for (final a in aggregates) a.createAccumulator()];

  final List<AggregateAccumulator> accumulators;
  int count = 0;

  void add(FactTable facts, int row) {
    count++;
    for (final a in accumulators) {
      a.add(facts, row);
    }
  }

  static CellData merge(List<Aggregate> aggregates, List<CellData> parts) {
    final merged = CellData(aggregates);
    for (final part in parts) {
      merged.count += part.count;
      for (var i = 0; i < aggregates.length; i++) {
        merged.accumulators[i].merge(part.accumulators[i]);
      }
    }
    return merged;
  }
}

/// A group on one axis: a node of the visible tree.
final class AxisNode {
  AxisNode(this.id, this.parent, this.code)
    : depth = parent == null ? 0 : parent.depth + 1;

  final int id;
  final AxisNode? parent;

  /// Code into the dimension at `depth - 1`; `-1` for the root.
  final int code;
  final int depth;

  bool expanded = false;
  int factCount = 0;
  Map<int, AxisNode>? children;

  /// Children with facts, in display order.
  List<AxisNode> ordered = const [];

  /// Row nodes only: cells by column node id.
  Map<int, CellData>? cells;

  DimensionPath? path;
}

final class AxisTree {
  AxisTree(this.axis, this.dims) : root = AxisNode(0, null, -1) {
    nodes.add(root);
  }

  final CubeAxis axis;
  final List<DimensionCodes> dims;
  final AxisNode root;
  final nodes = <AxisNode>[];

  int get depth => axis.depth;

  /// A node that facts stop at: not expanded, or on the last level.
  bool isLeaf(AxisNode n) => !n.expanded || n.depth >= depth;

  bool isExpandable(AxisNode n) => n.depth < depth;

  AxisNode child(AxisNode parent, int code) =>
      (parent.children ??= {}).putIfAbsent(code, () {
        final n = AxisNode(nodes.length, parent, code);
        nodes.add(n);
        return n;
      });

  /// Marks the nodes named by [state] as expanded, creating them as needed.
  /// Paths that do not fit the axis (wrong dimension, unknown value) are
  /// ignored.
  void applyExpansion(ExpansionState state) {
    for (final path in state.expanded) {
      if (path.length > depth) continue;
      var node = root;
      var valid = true;
      for (var i = 0; i < path.length; i++) {
        final entry = path.entries[i];
        if (entry.dimension != dims[i].dimension) {
          valid = false;
          break;
        }
        final code = dims[i].codeOf(entry.value);
        if (code == null) {
          valid = false;
          break;
        }
        node = child(node, code);
      }
      if (valid) node.expanded = true;
    }
  }

  /// Descends from the root along [row]'s values as far as the tree is
  /// expanded, counting the fact on every node passed. Returns the leaf.
  AxisNode walk(int row) {
    var n = root;
    n.factCount++;
    while (!isLeaf(n)) {
      n = child(n, dims[n.depth].codes[row]);
      n.factCount++;
    }
    return n;
  }

  DimensionPath pathOf(AxisNode n) {
    final cached = n.path;
    if (cached != null) return cached;
    final parent = n.parent;
    final path = parent == null
        ? DimensionPath.root
        : pathOf(parent).child(
            DimensionValue(
              dims[n.depth - 1].dimension,
              dims[n.depth - 1].values[n.code],
            ),
          );
    return n.path = path;
  }

  Object? valueOf(AxisNode n) =>
      n.depth == 0 ? null : dims[n.depth - 1].values[n.code];

  Dimension? dimensionOf(AxisNode n) =>
      n.depth == 0 ? null : dims[n.depth - 1].dimension;

  /// Whether [row] belongs to the group [n].
  bool contains(AxisNode n, int row) {
    for (var m = n; m.depth > 0; m = m.parent!) {
      if (dims[m.depth - 1].codes[row] != m.code) return false;
    }
    return true;
  }

  /// The existing node at [path], or `null` if it is not part of the tree.
  AxisNode? resolve(DimensionPath path) {
    if (path.length > depth) return null;
    var node = root;
    for (var i = 0; i < path.length; i++) {
      final entry = path.entries[i];
      if (entry.dimension != dims[i].dimension) return null;
      final code = dims[i].codeOf(entry.value);
      if (code == null) return null;
      final next = node.children?[code];
      if (next == null) return null;
      node = next;
    }
    return node;
  }

  /// Orders the children of every non-leaf node. For aggregate sorting,
  /// [cellOf] returns the cell of a node of this tree against a node of the
  /// [other] tree (the sort's key path, or that tree's root).
  void order(
    List<Aggregate> aggregates,
    AxisTree other,
    CellData? Function(AxisNode self, AxisNode key) cellOf,
  ) {
    for (final n in nodes) {
      final children = n.children;
      if (children == null || isLeaf(n)) continue;
      final level = axis.dimensions[n.depth];
      final sort = level.sort;
      final withFacts = [
        for (final c in children.values)
          if (c.factCount > 0) c,
      ];
      final desc = sort.direction == SortDirection.descending;
      if (sort.by == SortBy.value) {
        final hasNull = dims[n.depth].hasNull;
        AxisNode? nullChild;
        final rest = <AxisNode>[];
        for (final c in withFacts) {
          if (hasNull && c.code == 0) {
            nullChild = c;
          } else {
            rest.add(c);
          }
        }
        rest.sort((a, b) => desc ? b.code - a.code : a.code - b.code);
        n.ordered = [
          if (nullChild != null && sort.nulls == NullPosition.first) nullChild,
          ...rest,
          if (nullChild != null && sort.nulls == NullPosition.last) nullChild,
        ];
      } else {
        final aggregate = sort.aggregate!;
        final index = aggregates.indexOf(aggregate);
        if (index < 0) {
          throw ArgumentError.value(
            aggregate.id,
            'sort.aggregate',
            'not among the cube\'s aggregates',
          );
        }
        final keyPath = sort.keyPath;
        final keyNode =
            (keyPath == null ? null : other.resolve(keyPath)) ?? other.root;
        Object? keyOf(AxisNode c) =>
            cellOf(c, keyNode)?.accumulators[index].result;
        int compare(AxisNode a, AxisNode b) {
          final ka = keyOf(a), kb = keyOf(b);
          if (ka == null) return kb == null ? a.code - b.code : -1;
          if (kb == null) return 1;
          final r = Comparable.compare(ka as Comparable, kb as Comparable);
          return r != 0 ? r : a.code - b.code;
        }

        withFacts.sort(desc ? (a, b) => compare(b, a) : compare);
        n.ordered = withFacts;
      }
    }
  }

  /// Visible nodes in display order.
  List<AxisNode> entries() {
    final out = <AxisNode>[];
    void visit(AxisNode n) {
      out.add(n);
      if (!isLeaf(n)) n.ordered.forEach(visit);
    }

    switch (axis.summaryPosition) {
      case SummaryPosition.start:
        visit(root);
      case SummaryPosition.end:
        if (!isLeaf(root)) root.ordered.forEach(visit);
        out.add(root);
      case SummaryPosition.hidden:
        if (!isLeaf(root)) root.ordered.forEach(visit);
    }
    return out;
  }
}

CubeLayoutImpl computeLayout({
  required FactTable facts,
  required CubeSpec spec,
  required ExpansionState rowExpansion,
  required ExpansionState columnExpansion,
  required CubeCache cache,
}) {
  final rows = cache.filteredRows(facts, spec.filter);
  final rowTree = AxisTree(spec.rows, [
    for (final d in spec.rows.dimensions) cache.codesFor(facts, d.dimension),
  ])..applyExpansion(rowExpansion);
  final colTree = AxisTree(spec.columns, [
    for (final d in spec.columns.dimensions) cache.codesFor(facts, d.dimension),
  ])..applyExpansion(columnExpansion);
  final aggregates = spec.aggregates;

  // Pass over the facts: every fact lands in exactly one leaf cell.
  for (final r in rows) {
    final rn = rowTree.walk(r);
    final cn = colTree.walk(r);
    ((rn.cells ??= {})[cn.id] ??= CellData(aggregates)).add(facts, r);
  }

  // Row roll-up: an expanded row node's cells are the merge of its children's
  // (children have larger ids than parents, so reverse order is post-order).
  for (var i = rowTree.nodes.length - 1; i >= 0; i--) {
    final n = rowTree.nodes[i];
    final children = n.children;
    if (children == null || rowTree.isLeaf(n)) continue;
    final parts = <int, List<CellData>>{};
    for (final c in children.values) {
      final cells = c.cells;
      if (cells == null) continue;
      for (final e in cells.entries) {
        (parts[e.key] ??= []).add(e.value);
      }
    }
    n.cells = {
      for (final e in parts.entries) e.key: CellData.merge(aggregates, e.value),
    };
  }

  // Column roll-up within every row node.
  for (final rn in rowTree.nodes) {
    final cells = rn.cells;
    if (cells == null) continue;
    for (var i = colTree.nodes.length - 1; i >= 0; i--) {
      final cn = colTree.nodes[i];
      final children = cn.children;
      if (children == null || colTree.isLeaf(cn)) continue;
      final parts = [for (final c in children.values) ?cells[c.id]];
      if (parts.isNotEmpty) cells[cn.id] = CellData.merge(aggregates, parts);
    }
  }

  rowTree.order(aggregates, colTree, (n, key) => n.cells?[key.id]);
  colTree.order(aggregates, rowTree, (n, key) => key.cells?[n.id]);

  return CubeLayoutImpl(
    facts: facts,
    spec: spec,
    filteredRows: rows,
    rowTree: rowTree,
    colTree: colTree,
  );
}

/// Expansion state with every group down to [depth] levels expanded.
ExpansionState expansionToDepth({
  required FactTable facts,
  required CubeAxis axis,
  required FactFilter? filter,
  required int depth,
  required CubeCache cache,
}) {
  if (depth <= 0) return ExpansionState.collapsed();
  final tree = AxisTree(axis, [
    for (final d in axis.dimensions) cache.codesFor(facts, d.dimension),
  ]);
  // Create nodes down to depth - 1 by expanding everything above. Nodes on
  // the last level cannot be expanded, so never go deeper than that.
  final limit = depth - 1 < tree.depth - 1 ? depth - 1 : tree.depth - 1;
  for (final r in cache.filteredRows(facts, filter)) {
    var n = tree.root;
    while (n.depth < limit) {
      n = tree.child(n, tree.dims[n.depth].codes[r]);
    }
  }
  return ExpansionState.of([for (final n in tree.nodes) tree.pathOf(n)]);
}

/// [state] plus every group on [level] (`0` = the first dimension) that
/// has facts after [filter], together with the groups above it: what
/// "expand all" on a dimension title gives. Groups the state already had
/// expanded further down stay expanded. On the last level of [axis] (which
/// cannot be expanded) the state is returned unchanged.
ExpansionState expansionWithLevel({
  required FactTable facts,
  required CubeAxis axis,
  required FactFilter? filter,
  required int level,
  required ExpansionState state,
  required CubeCache cache,
}) {
  if (level < 0 || level >= axis.depth - 1) return state;
  final all = expansionToDepth(
    facts: facts,
    axis: axis,
    filter: filter,
    depth: level + 2,
    cache: cache,
  );
  return ExpansionState.of([...state.expanded, ...all.expanded]);
}

/// Number of entries [axis] shows under [state]: what `AxisLayout.length`
/// would be, without computing the cells.
int countEntries({
  required FactTable facts,
  required CubeAxis axis,
  required FactFilter? filter,
  required ExpansionState state,
  required CubeCache cache,
}) {
  final tree = AxisTree(axis, [
    for (final d in axis.dimensions) cache.codesFor(facts, d.dimension),
  ])..applyExpansion(state);
  for (final r in cache.filteredRows(facts, filter)) {
    tree.walk(r);
  }
  var count = axis.summaryPosition == SummaryPosition.hidden ? 0 : 1;
  for (final n in tree.nodes) {
    if (n.depth > 0 && n.factCount > 0) count++;
  }
  return count;
}

final class HeaderEntryImpl implements HeaderEntry {
  HeaderEntryImpl(this.tree, this.node, this._rows);

  final AxisTree tree;
  final AxisNode node;
  final Int32List _rows;

  @override
  DimensionPath get path => tree.pathOf(node);

  @override
  int get depth => node.depth;

  @override
  bool get isSummary => node.depth == 0;

  @override
  Dimension? get dimension => tree.dimensionOf(node);

  @override
  Object? get value => tree.valueOf(node);

  @override
  String get label {
    final v = value;
    return v == null ? '' : dimension!.formatValue(v);
  }

  @override
  bool get isExpandable => tree.isExpandable(node);

  @override
  bool get isExpanded => isExpandable && node.expanded;

  @override
  int get factCount => node.factCount;

  @override
  late final int childCount = _countChildren();

  int _countChildren() {
    if (!isExpandable) return 0;
    if (isExpanded) return node.ordered.length;
    final codes = tree.dims[node.depth].codes;
    final seen = <int>{};
    for (final r in _rows) {
      if (tree.contains(node, r)) seen.add(codes[r]);
    }
    return seen.length;
  }

  @override
  String toString() => 'HeaderEntry($path, $factCount facts)';
}

final class AxisLayoutImpl implements AxisLayout {
  AxisLayoutImpl(this.tree, Int32List rows)
    : entries = List.unmodifiable([
        for (final n in tree.entries()) HeaderEntryImpl(tree, n, rows),
      ]);

  final AxisTree tree;

  @override
  final List<HeaderEntryImpl> entries;

  late final List<int> _descendants = _countDescendants();

  List<int> _countDescendants() {
    final counts = List<int>.filled(entries.length, 0);
    final ancestors = <int>[]; // indices of open entries, shallow to deep
    for (var i = 0; i < entries.length; i++) {
      final depth = entries[i].depth;
      while (ancestors.isNotEmpty && entries[ancestors.last].depth >= depth) {
        ancestors.removeLast();
      }
      for (final a in ancestors) {
        counts[a]++;
      }
      ancestors.add(i);
    }
    return counts;
  }

  @override
  int descendantCount(int index) => _descendants[index];

  late final Map<DimensionPath, int> _index = {
    for (var i = 0; i < entries.length; i++) entries[i].path: i,
  };

  @override
  CubeAxis get axis => tree.axis;

  @override
  int get length => entries.length;

  @override
  int indexOf(DimensionPath path) => _index[path] ?? -1;
}

final class CubeCellImpl implements CubeCell {
  CubeCellImpl(this.layout, this.rowNode, this.colNode, this.data);

  final CubeLayoutImpl layout;
  final AxisNode rowNode;
  final AxisNode colNode;
  final CellData? data;

  @override
  late final Coordinate coordinate = Coordinate.fromPaths(
    layout.rowTree.pathOf(rowNode),
    layout.colTree.pathOf(colNode),
  );

  @override
  int get factCount => data?.count ?? 0;

  @override
  bool get isEmpty => factCount == 0;

  @override
  R? aggregate<R>(Aggregate<R> aggregate) {
    final index = layout.spec.aggregates.indexOf(aggregate);
    if (index < 0) {
      throw ArgumentError.value(
        aggregate.id,
        'aggregate',
        'not among the cube\'s aggregates',
      );
    }
    final d = data;
    if (d == null) return aggregate.createAccumulator().result;
    return d.accumulators[index].result as R?;
  }

  @override
  Map<Aggregate, Object?> get aggregates => {
    for (final a in layout.spec.aggregates) a: aggregate<Object?>(a),
  };

  @override
  Iterable<int> get factRows {
    if (data == null) return const Iterable.empty();
    final rows = layout.rowTree, cols = layout.colTree;
    return layout.filteredRows.where(
      (r) => rows.contains(rowNode, r) && cols.contains(colNode, r),
    );
  }

  @override
  String toString() => 'CubeCell($coordinate, $factCount facts)';
}

final class CubeLayoutImpl implements CubeLayout {
  CubeLayoutImpl({
    required this.facts,
    required this.spec,
    required this.filteredRows,
    required this.rowTree,
    required this.colTree,
  }) : rows = AxisLayoutImpl(rowTree, filteredRows),
       columns = AxisLayoutImpl(colTree, filteredRows);

  @override
  final FactTable facts;

  final Int32List filteredRows;
  final AxisTree rowTree;
  final AxisTree colTree;

  @override
  final CubeSpec spec;

  @override
  final AxisLayoutImpl rows;

  @override
  final AxisLayoutImpl columns;

  @override
  CubeCell cellAt(int row, int column) {
    final rn = rows.entries[row].node;
    final cn = columns.entries[column].node;
    return CubeCellImpl(this, rn, cn, rn.cells?[cn.id]);
  }

  @override
  CubeCell? cellFor(DimensionPath row, DimensionPath column) {
    final i = rows.indexOf(row), j = columns.indexOf(column);
    if (i < 0 || j < 0) return null;
    return cellAt(i, j);
  }
}
