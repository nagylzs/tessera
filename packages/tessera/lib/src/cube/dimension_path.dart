import '../facts/dimension.dart';

/// One dimension pinned to one of its values.
final class DimensionValue {
  const DimensionValue(this.dimension, this.value);

  final Dimension dimension;

  /// `null` denotes the empty group (facts that lack a value).
  final Object? value;

  @override
  bool operator ==(Object other) =>
      other is DimensionValue &&
      other.dimension == dimension &&
      other.value == value;

  @override
  int get hashCode => Object.hash(dimension, value);

  @override
  String toString() => '${dimension.id}=${value ?? '∅'}';
}

/// The position of a group within one axis of a [Cube], root first.
///
/// With the axis `[region, country]`, `[]` is the summary (all facts),
/// `[region=Europe]` is the Europe group and `[region=Europe, country=∅]`
/// the facts in Europe that have no country. Paths are ordered like the
/// axis, so the dimension at depth *d* is the axis's *d*-th dimension.
final class DimensionPath {
  const DimensionPath(this.entries);

  static const root = DimensionPath([]);

  final List<DimensionValue> entries;

  int get length => entries.length;

  bool get isRoot => entries.isEmpty;

  /// The deepest entry. Throws on [root].
  DimensionValue get last => entries.last;

  /// The path one level up. Throws on [root].
  DimensionPath get parent =>
      DimensionPath(entries.sublist(0, entries.length - 1));

  DimensionPath child(DimensionValue entry) =>
      DimensionPath([...entries, entry]);

  List<Dimension> get dimensions => [for (final e in entries) e.dimension];

  /// Whether this path is [prefix] or lies below it.
  bool startsWith(DimensionPath prefix) {
    if (prefix.length > length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (entries[i] != prefix.entries[i]) return false;
    }
    return true;
  }

  /// Strict ancestor test: `other` lies below this path.
  bool isAncestorOf(DimensionPath other) =>
      other.length > length && other.startsWith(this);

  @override
  bool operator ==(Object other) =>
      other is DimensionPath &&
      other.startsWith(this) &&
      other.length == length;

  @override
  int get hashCode => Object.hashAll(entries);

  @override
  String toString() => isRoot ? '/' : '/${entries.join('/')}';
}

/// The set of dimension filters identifying a [CubeCell]: the union of its
/// row path and column path. Unordered, unlike [DimensionPath].
final class Coordinate {
  Coordinate(Map<Dimension, Object?> values)
    : values = Map.unmodifiable(values);

  factory Coordinate.fromPaths(DimensionPath row, DimensionPath column) =>
      Coordinate({
        for (final e in row.entries) e.dimension: e.value,
        for (final e in column.entries) e.dimension: e.value,
      });

  final Map<Dimension, Object?> values;

  bool get isEmpty => values.isEmpty;

  bool constrains(Dimension dimension) => values.containsKey(dimension);

  /// Value the coordinate pins [dimension] to. Distinguish "pinned to the
  /// empty group" from "not pinned" with [constrains].
  Object? operator [](Dimension dimension) => values[dimension];

  @override
  bool operator ==(Object other) {
    if (other is! Coordinate || other.values.length != values.length) {
      return false;
    }
    for (final entry in values.entries) {
      if (!other.values.containsKey(entry.key) ||
          other.values[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered([
    for (final e in values.entries) Object.hash(e.key, e.value),
  ]);

  @override
  String toString() =>
      '{${values.entries.map((e) => '${e.key.id}=${e.value ?? '∅'}').join(', ')}}';
}
