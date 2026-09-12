import 'package:flutter_test/flutter_test.dart';
import 'package:tessera/tessera.dart';

void main() {
  const region = ColumnDimension('region');
  const country = ColumnDimension('country');
  const month = DatePartDimension('date', DatePart.month);

  group('ColumnType.canWidenTo', () {
    test('widens along integer → number → text', () {
      expect(ColumnType.integer.canWidenTo(ColumnType.number), isTrue);
      expect(ColumnType.number.canWidenTo(ColumnType.text), isTrue);
      expect(ColumnType.number.canWidenTo(ColumnType.integer), isFalse);
      expect(ColumnType.date.canWidenTo(ColumnType.dateTime), isTrue);
      expect(ColumnType.boolean.canWidenTo(ColumnType.number), isFalse);
    });
  });

  group('Dimension', () {
    test('identity is the id', () {
      expect(const ColumnDimension('region'), equals(region));
      expect(
        month,
        isNot(equals(const DatePartDimension('date', DatePart.year))),
      );
      expect(month.id, 'date.month');
    });

    test('date parts sort chronologically and format as names', () {
      final march = DateTime.utc(2025, 3, 5);
      expect(month.valueOf(march), 3);
      expect(month.formatValue(3), 'March');
      expect(
        const DatePartDimension('date', DatePart.quarter).valueOf(march),
        1,
      );
      expect(month.valueOf(null), isNull);
    });
  });

  group('DimensionPath', () {
    final europe = DimensionPath.root.child(
      const DimensionValue(region, 'Europe'),
    );
    final noCountry = europe.child(const DimensionValue(country, null));

    test('root, parent, child', () {
      expect(DimensionPath.root.isRoot, isTrue);
      expect(europe.length, 1);
      expect(noCountry.parent, equals(europe));
      expect(noCountry.dimensions, [region, country]);
    });

    test('value equality', () {
      expect(
        DimensionPath([const DimensionValue(region, 'Europe')]),
        equals(europe),
      );
      expect(
        europe.hashCode,
        DimensionPath([const DimensionValue(region, 'Europe')]).hashCode,
      );
      expect(europe, isNot(equals(noCountry)));
    });

    test('prefix relations', () {
      expect(noCountry.startsWith(europe), isTrue);
      expect(europe.startsWith(noCountry), isFalse);
      expect(europe.isAncestorOf(noCountry), isTrue);
      expect(europe.isAncestorOf(europe), isFalse);
      expect(DimensionPath.root.isAncestorOf(europe), isTrue);
    });

    test('coordinate merges row and column paths', () {
      final coord = Coordinate.fromPaths(
        noCountry,
        DimensionPath([const DimensionValue(month, 3)]),
      );
      expect(coord[region], 'Europe');
      expect(coord[country], isNull);
      expect(coord.constrains(country), isTrue);
      expect(coord.constrains(month), isTrue);
      expect(coord.constrains(const ColumnDimension('category')), isFalse);
    });
  });

  group('ExpansionState', () {
    final europe = DimensionPath.root.child(
      const DimensionValue(region, 'Europe'),
    );
    final hungary = europe.child(const DimensionValue(country, 'Hungary'));

    test('initial state has only the root expanded', () {
      final s = ExpansionState.initial();
      expect(s.isRootExpanded, isTrue);
      expect(s.isExpanded(europe), isFalse);
    });

    test('expand closes under parents', () {
      final s = ExpansionState.collapsed().expand(hungary);
      expect(s.expanded, {DimensionPath.root, europe, hungary});
    });

    test('collapse removes the subtree', () {
      final s = ExpansionState.of([hungary]).collapse(europe);
      expect(s.expanded, {DimensionPath.root});
      expect(s.toggle(europe).isExpanded(europe), isTrue);
    });

    test('value equality', () {
      expect(
        ExpansionState.of([hungary]),
        equals(ExpansionState.collapsed().expand(hungary)),
      );
    });
  });

  group('CubeSpec', () {
    test('rejects a dimension on both axes', () {
      expect(
        () => CubeSpec(
          rows: CubeAxis.of([region]),
          columns: CubeAxis.of([region]),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a dimension twice on one axis', () {
      expect(
        () => CubeSpec(rows: CubeAxis.of([region, region])),
        throwsArgumentError,
      );
    });

    test('allows different derived dimensions of one column on both axes', () {
      final spec = CubeSpec(
        rows: CubeAxis.of([const DatePartDimension('date', DatePart.year)]),
        columns: CubeAxis.of([month]),
        aggregates: [Aggregate.sum(const Measure('total'))],
      );
      expect(spec.rows.depth, 1);
      expect(spec.columns.dimensionAt(1), month);
      expect(spec.aggregates.single.id, 'sum(total)');
    });
  });
}
