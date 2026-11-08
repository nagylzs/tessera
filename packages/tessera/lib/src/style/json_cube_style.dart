import 'dart:convert';

import 'cube_style.dart';

/// A [CubeStyle] read from a JSON document, the format of `docs/style.md`:
///
/// ```json
/// {
///   "format": "tessera-style",
///   "version": 1,
///   "id": "teal",
///   "name": {"en": "Teal", "hu": "Kékeszöld"},
///   "metrics": {"rowHeight": 28, "headerRowHeight": 28, "padding": 6},
///   "light": {
///     "border": "#B2DFDB",
///     "cell": {"fill": "#FFFFFF", "text": "#212121", "size": 12},
///     "header": {"fill": "#B2DFDB", "bold": true},
///     "value": {"fill": ["#FFFFFF", "#E0F2F1", "#B2DFDB"]},
///     "total": {"fill": "#80CBC4", "bold": true}
///   },
///   "dark": {
///     "border": "#004D40",
///     "cell": {"fill": "#121212", "text": "#E0E0E0"}
///   }
/// }
/// ```
///
/// Each variant gives looks by [CellRole] (`value`, `total`, `rowLabel`,
/// `columnLabel`, `totalLabel`, `title`, `valueName`, `corner`) and two
/// shared ones, `cell` and `header`. A role takes what it does not set
/// from its parent: `valueName` from `columnLabel`, `totalLabel` from
/// `total`, the other headers from `header`, `header`, `value` and
/// `total` from `cell`. The `dark` variant looks along its own roles first
/// and takes from `light` only what it sets nowhere along them: it must
/// give `cell` a fill and a text colour, so its colours stay its own and
/// match, and it usually leaves the fonts to `light`. A property given as a list is
/// by depth, the last entry for anything deeper: colours by the depth that
/// [DepthColoring] picks, fonts by the cell's own.
///
/// Reading is strict, as styles are written by hand: an unknown key, a
/// wrong type or a malformed colour throws a [FormatException] naming
/// where it is. Keys starting with `_` are comments and skipped.
final class JsonCubeStyle implements CubeStyle {
  JsonCubeStyle._(
    this._json,
    this.id,
    this._names,
    this.metrics,
    this._light,
    this._dark,
  );

  /// Reads a style from its decoded JSON [json].
  factory JsonCubeStyle.fromJson(Map<String, Object?> json) {
    final r = _Reader(json, r'$');
    r.only(const {
      'format',
      'version',
      'id',
      'name',
      'metrics',
      'light',
      'dark',
    });
    if (r.required<String>('format') != format) {
      throw FormatException(
        r'$.format: not "'
        '$format'
        '"',
      );
    }
    final version = r.required<int>('version');
    if (version < 1 || version > formatVersion) {
      throw FormatException(
        r'$.version: '
        '$version is not a version this reader knows',
      );
    }
    final id = r.required<String>('id');
    if (id.isEmpty) throw const FormatException(r'$.id: empty');
    final names = r.child('name', required: true)!;
    final nameMap = <String, String>{
      for (final key in names.keys) key: names.required<String>(key),
    };
    if (!nameMap.containsKey('en')) {
      throw const FormatException(r'$.name: no English ("en") name');
    }
    final m = r.child('metrics');
    m?.only(const {
      'rowHeight',
      'headerRowHeight',
      'padding',
      'minColumnWidth',
      'minRowHeaderWidth',
    });
    final metrics = StyleMetrics(
      rowHeight: m?.number('rowHeight') ?? 28,
      headerRowHeight: m?.number('headerRowHeight') ?? 28,
      padding: m?.number('padding') ?? 6,
      minColumnWidth: m?.number('minColumnWidth') ?? 72,
      minRowHeaderWidth: m?.number('minRowHeaderWidth') ?? 100,
    );
    final light = _Variant.read(r.child('light', required: true)!);
    if (light.chrome.border == null) {
      throw const FormatException(r'$.light.border: missing');
    }
    final darkReader = r.child('dark');
    final dark = darkReader == null ? null : _Variant.read(darkReader);
    return JsonCubeStyle._(
      jsonDecode(jsonEncode(json)) as Map<String, Object?>,
      id,
      nameMap,
      metrics,
      light,
      dark,
    );
  }

  /// Reads a style from the JSON text [source].
  factory JsonCubeStyle.parse(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('not JSON: ${e.message}');
    }
    if (json is! Map<String, Object?>) {
      throw const FormatException(r'$: not a JSON object');
    }
    return JsonCubeStyle.fromJson(json);
  }

  /// The value of `"format"`.
  static const format = 'tessera-style';

  /// The newest `"version"` this reader knows.
  static const formatVersion = 1;

  final Map<String, Object?> _json;
  final Map<String, String> _names;
  final _Variant _light;
  final _Variant? _dark;
  final _looks = <(StyleCell, bool, DepthColoring), CellLook>{};

  @override
  final String id;

  @override
  final StyleMetrics metrics;

  /// The names it has, by language code.
  Map<String, String> get names => Map.unmodifiable(_names);

  @override
  String name(String languageCode) => _names[languageCode] ?? _names['en']!;

  @override
  bool get hasDark => _dark != null;

  /// The document it was read from, for writing it back.
  Map<String, Object?> toJson() =>
      jsonDecode(jsonEncode(_json)) as Map<String, Object?>;

  @override
  CellLook lookOf(
    StyleCell cell, {
    bool dark = false,
    DepthColoring coloring = DepthColoring.both,
  }) {
    final useDark = dark && _dark != null;
    return _looks.putIfAbsent((cell, useDark, coloring), () {
      final colorDepth = coloring.colorDepth(cell);
      final depth = cell.depth;
      T get<T>(_Property<T> p, int at, T fallback) {
        final values =
            (useDark ? _dark.find(cell.role, p) : null) ??
            _light.find(cell.role, p);
        return values == null ? fallback : values[_index(values, at)];
      }

      return CellLook(
        fill: get(_Property.fill, colorDepth, 0xFFFFFFFF),
        text: get(_Property.text, colorDepth, 0xFF000000),
        family:
            (useDark ? _dark.family(cell.role) : null) ??
            _light.family(cell.role),
        size: get(_Property.size, depth, 12.0),
        bold: get(_Property.bold, depth, false),
        italic: get(_Property.italic, depth, false),
      );
    });
  }

  @override
  StyleChrome chrome({bool dark = false}) {
    final light = _light.chrome;
    final variant = dark ? _dark?.chrome : null;
    return StyleChrome(
      border: variant?.border ?? light.border!,
      selection: variant?.selection ?? light.selection,
      sortKey: variant?.sortKey ?? light.sortKey,
      icon: variant?.icon ?? light.icon,
    );
  }

  @override
  String toString() => 'JsonCubeStyle($id)';
}

int _index(List<Object?> values, int depth) =>
    depth < values.length ? depth : values.length - 1;

/// What a look may set, each with how it is read.
final class _Property<T> {
  const _Property(this.key);

  final String key;

  static const fill = _Property<int>('fill');
  static const text = _Property<int>('text');
  static const size = _Property<double>('size');
  static const bold = _Property<bool>('bold');
  static const italic = _Property<bool>('italic');
}

/// The parent a role takes what it does not set from.
const _parents = <String, String?>{
  'cell': null,
  'header': 'cell',
  'value': 'cell',
  'total': 'cell',
  'rowLabel': 'header',
  'columnLabel': 'header',
  'title': 'header',
  'corner': 'header',
  'valueName': 'columnLabel',
  'totalLabel': 'total',
};

final class _Chrome {
  const _Chrome(this.border, this.selection, this.sortKey, this.icon);

  final int? border;
  final int? selection;
  final int? sortKey;
  final int? icon;
}

/// One variant, `light` or `dark`: its chrome and its looks by role.
final class _Variant {
  _Variant(this.chrome, this.looks);

  factory _Variant.read(_Reader r) {
    r.only({'border', 'selection', 'sortKey', 'icon', ..._parents.keys});
    final looks = <String, _Look>{
      for (final role in _parents.keys)
        if (r.child(role) case final look?) role: _Look.read(look),
    };
    final cell = looks['cell'];
    if (cell?.values['fill'] == null || cell?.values['text'] == null) {
      throw FormatException('${r.path}.cell: no "fill" or no "text"');
    }
    return _Variant(
      _Chrome(
        r.color('border'),
        r.color('selection'),
        r.color('sortKey'),
        r.color('icon'),
      ),
      looks,
    );
  }

  final _Chrome chrome;
  final Map<String, _Look> looks;

  /// [property]'s values for [role] from it or its parents, if any sets it.
  List<T>? find<T>(CellRole role, _Property<T> property) {
    for (String? r = role.name; r != null; r = _parents[r]) {
      if (looks[r]?.values[property.key] case final List<Object?> values) {
        return values.cast<T>();
      }
    }
    return null;
  }

  StyleFamily? family(CellRole role) {
    for (String? r = role.name; r != null; r = _parents[r]) {
      if (looks[r]?.family case final family?) return family;
    }
    return null;
  }
}

/// One look as written: each property's values by depth, as given.
final class _Look {
  _Look(this.values, this.family);

  factory _Look.read(_Reader r) {
    r.only(const {'fill', 'text', 'family', 'size', 'bold', 'italic'});
    final family = r.optional<String>('family');
    return _Look(
      {
        'fill': r.list('fill', r.parseColor),
        'text': r.list('text', r.parseColor),
        'size': r.list('size', (v, path) {
          if (v is! num || v <= 0) throw FormatException('$path: not a size');
          return v.toDouble();
        }),
        'bold': r.list('bold', _bool),
        'italic': r.list('italic', _bool),
      },
      family == null
          ? null
          : StyleFamily.values.firstWhere(
              (f) => f.name == family,
              orElse: () => throw FormatException(
                '${r.path}.family: "$family" is none of '
                '${StyleFamily.values.map((f) => f.name).join(', ')}',
              ),
            ),
    );
  }

  final Map<String, List<Object?>?> values;
  final StyleFamily? family;
}

bool _bool(Object? v, String path) =>
    v is bool ? v : throw FormatException('$path: not true or false');

/// Reads one JSON object, naming the path of anything wrong in it.
final class _Reader {
  _Reader(this.json, this.path);

  final Map<String, Object?> json;
  final String path;

  Iterable<String> get keys => json.keys.where((k) => !k.startsWith('_'));

  /// Throws on a key outside [allowed] (comments aside).
  void only(Set<String> allowed) {
    for (final key in keys) {
      if (!allowed.contains(key)) {
        throw FormatException('$path.$key: unknown key');
      }
    }
  }

  T required<T>(String key) {
    final v = json[key];
    if (v == null) throw FormatException('$path.$key: missing');
    if (v is! T) throw FormatException('$path.$key: not a $T');
    return v as T;
  }

  T? optional<T>(String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is! T) throw FormatException('$path.$key: not a $T');
    return v as T;
  }

  double? number(String key) {
    final v = optional<num>(key);
    if (v != null && v <= 0) throw FormatException('$path.$key: not positive');
    return v?.toDouble();
  }

  _Reader? child(String key, {bool required = false}) {
    final v = json[key];
    if (v == null) {
      if (required) throw FormatException('$path.$key: missing');
      return null;
    }
    if (v is! Map<String, Object?>) {
      throw FormatException('$path.$key: not an object');
    }
    return _Reader(v, '$path.$key');
  }

  int? color(String key) {
    final v = json[key];
    return v == null ? null : parseColor(v, '$path.$key');
  }

  /// A colour: `#RRGGBB`, or `#AARRGGBB` with the alpha first.
  int parseColor(Object? v, String at) {
    if (v is String && v.startsWith('#')) {
      final hex = v.substring(1);
      final value = int.tryParse(hex, radix: 16);
      if (value != null && !hex.startsWith('-') && !hex.startsWith('+')) {
        if (hex.length == 6) return 0xFF000000 | value;
        if (hex.length == 8) return value;
      }
    }
    throw FormatException('$at: not a colour ("#RRGGBB" or "#AARRGGBB")');
  }

  /// [key]'s value as a list by depth: one value, or a non-empty list.
  List<Object?>? list(String key, Object Function(Object? v, String at) read) {
    final v = json[key];
    if (v == null) return null;
    if (v is List) {
      if (v.isEmpty) throw FormatException('$path.$key: an empty list');
      return [for (var i = 0; i < v.length; i++) read(v[i], '$path.$key[$i]')];
    }
    return [read(v, '$path.$key')];
  }
}
