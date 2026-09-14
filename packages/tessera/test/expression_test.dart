import 'dart:io';

import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

/// region, country, date, qty, price, active
const _rows = <List<Object?>>[
  ['Europe', 'Germany', '2024-01-05', 1, 10.0, true],
  ['Europe', 'Hungary', '2024-03-05', 2, 20.0, false],
  ['Europe', null, '2025-01-05', 3, null, null],
  ['Asia', 'Japan', '2025-06-05', 5, 50.0, true],
  [null, 'Iceland', null, null, 70.0, false],
];

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'date', 'qty', 'price', 'active'],
    rows: _rows,
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'date', type: ColumnType.date),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
      const ColumnSpec(name: 'price', type: ColumnType.number),
      const ColumnSpec(name: 'active', type: ColumnType.boolean),
    ]),
  );
  return (await loadFacts(source)).facts;
}

const _types = {
  'region': ExprType.text,
  'country': ExprType.text,
  'date': ExprType.date,
  'qty': ExprType.number,
  'price': ExprType.number,
  'active': ExprType.boolean,
};
const rows = ExpressionScope.rows(_types);
const cells = ExpressionScope.cells(_types);

ExpressionError? err(
  String s, {
  ExpressionScope scope = rows,
  ExprType? expected,
}) => Expression.validate(s, scope: scope, expected: expected);

void main() {
  group('parser', () {
    String canon(String s) => Expression.parse(s).canonicalSource;

    test('precedence and associativity', () {
      expect(
        canon('a or b and not c = d + e * f'),
        'a or b and not c = d + e * f',
      );
      expect(canon('(a or b) and c'), '(a or b) and c');
      expect(canon('a - b - c'), 'a - b - c');
      expect(canon('a - (b - c)'), 'a - (b - c)');
      expect(canon('(a + b) * c'), '(a + b) * c');
      expect(canon('a + b * c'), 'a + b * c');
      expect(canon('-(a + b)'), '-(a + b)');
      expect(canon('not (a = b)'), 'not a = b');
      expect(canon('not (a and b)'), 'not (a and b)');
      expect(canon('(a = b) = c'), '(a = b) = c');
    });

    test('operators, keywords and case', () {
      expect(canon('A == B AND c != d'), 'A = B and c <> d');
      expect(canon('x NOT IN (1, 2)'), 'x not in (1, 2)');
      expect(canon('x Between 1 And 2'), 'x between 1 and 2');
      expect(canon('x is not null'), 'x is not empty');
      expect(canon('x IS EMPTY'), 'x is empty');
      expect(canon('IF(a, b, NULL)'), 'if(a, b, null)');
      expect(canon('TRUE or False'), 'true or false');
      expect(canon('+3'), '3');
      expect(canon('-3'), '-3');
      expect(canon('- x'), '-x');
    });

    test('literals', () {
      expect(canon('1.50'), '1.5');
      expect(canon('1e3'), '1000');
      expect(canon('.5'), '0.5');
      expect(canon("'it''s'"), '"it\'s"');
      expect(canon('"say ""hi"""'), '"say ""hi"""');
      expect(canon('#2024-01-31#'), '#2024-01-31#');
      expect(canon('#2024-01-31 10:30#'), '#2024-01-31 10:30:00#');
      expect(canon('#2024-01-31T10:30:15.5#'), '#2024-01-31 10:30:15.500#');
      final d = Expression.parse('#2024-01-31 10:30#').root as DateLiteral;
      expect(d.value, DateTime.utc(2024, 1, 31, 10, 30));
    });

    test('column names', () {
      expect(canon('[unit price] * 2'), '[unit price] * 2');
      expect(canon('[qty]'), 'qty');
      expect(canon('[and]'), '[and]');
      expect(canon('[a]]b]'), '[a]]b]');
      expect(canon('árvíztűrő + 1'), 'árvíztűrő + 1');
      expect(
        (Expression.parse('[unit price]').root as NameRef).name,
        'unit price',
      );
      expect(Expression.parse('a + b * year(c)').names, {'a', 'b', 'c'});
    });

    test('positions', () {
      final e = Expression.parse(' qty * (price + 1) ').root as BinaryExpr;
      expect((e.offset, e.length), (1, 16));
      expect((e.left.offset, e.left.length), (1, 3));
      expect((e.right.offset, e.right.length), (8, 9));
      final call = Expression.parse('year(date)').root as CallExpr;
      expect((call.offset, call.length, call.nameLength), (0, 10, 4));
      expect(
        (call.arguments.single.offset, call.arguments.single.length),
        (5, 4),
      );
    });

    test('errors with positions', () {
      ExpressionError e(String s) {
        try {
          Expression.parse(s);
        } on ExpressionError catch (err) {
          return err;
        }
        fail('parsed: $s');
      }

      expect(e('a = b = c').kind, ExpressionErrorKind.unexpectedToken);
      expect(e('a = b = c').offset, 6);
      expect(e('a +').kind, ExpressionErrorKind.unexpectedEnd);
      expect(e('a +').offset, 3);
      expect(e('1abc').kind, ExpressionErrorKind.invalidNumber);
      expect(e('"open').kind, ExpressionErrorKind.unterminatedText);
      expect(e('[open').kind, ExpressionErrorKind.unterminatedName);
      expect(e('#2024-01').kind, ExpressionErrorKind.unterminatedDate);
      expect(e('#2024-02-30#').kind, ExpressionErrorKind.invalidDate);
      expect(e('a ? b').kind, ExpressionErrorKind.unexpectedCharacter);
      expect(e('a ? b').arguments, ['?']);
      expect(e('a ? b').offset, 2);
      expect(e('f(a,').kind, ExpressionErrorKind.unexpectedEnd);
      expect(e('a in 1').kind, ExpressionErrorKind.unexpectedToken);
      expect(e('a is b').kind, ExpressionErrorKind.unexpectedToken);
      expect(e('').kind, ExpressionErrorKind.unexpectedEnd);
      expect(Expression.tryParse('a +'), isNull);
    });
  });

  group('checker', () {
    ExprType type(String s, {ExpressionScope scope = rows}) =>
        Expression.parse(s).check(scope).type;

    test('types of expressions', () {
      expect(type('qty * price + 1'), ExprType.number);
      expect(type('qty > 1 and active'), ExprType.boolean);
      expect(type('region = "Europe"'), ExprType.boolean);
      expect(type('date + 1'), ExprType.date);
      expect(type('1 + date'), ExprType.date);
      expect(type('date - 1'), ExprType.date);
      expect(type('date - date'), ExprType.number);
      expect(type('date >= #2024-01-01#'), ExprType.boolean);
      expect(type('year(date)'), ExprType.number);
      expect(type('if(active, "y", "n")'), ExprType.text);
      expect(type('if(active, null, "n")'), ExprType.text);
      expect(type('coalesce(price, 0)'), ExprType.number);
      expect(type('coalesce(null, price)'), ExprType.number);
      expect(type('null + qty'), ExprType.number);
      expect(type('qty = null'), ExprType.boolean);
      expect(type('qty in (1, null)'), ExprType.boolean);
      expect(type('region is empty'), ExprType.boolean);
      expect(type('isempty(date)'), ExprType.boolean);
      expect(type('text(qty)'), ExprType.text);
      expect(type('text(date)'), ExprType.text);
      expect(type('text(active)'), ExprType.text);
      expect(type('date("2024-01-01")'), ExprType.date);
      expect(type('date(2024, 1, 1)'), ExprType.date);
      expect(type('today()'), ExprType.date);
      expect(type('ROUND(price)'), ExprType.number);
      expect(type('round(price, 2)'), ExprType.number);
      expect(type('min(qty, price, 3)'), ExprType.number);
      expect(type('substring(region, 2)'), ExprType.text);
      expect(type('substring(region, 2, 3)'), ExprType.text);
      expect(type('date - null'), ExprType.date);
    });

    test('errors', () {
      (ExpressionErrorKind, String) e(
        String s, {
        ExpressionScope scope = rows,
        ExprType? expected,
      }) {
        final err = Expression.validate(s, scope: scope, expected: expected)!;
        return (err.kind, err.arguments.join(','));
      }

      expect(e('foo + 1'), (ExpressionErrorKind.unknownColumn, 'foo'));
      expect(e('nope(1)'), (ExpressionErrorKind.unknownFunction, 'nope'));
      expect(e('year()'), (ExpressionErrorKind.argumentCount, 'year,1,0'));
      expect(e('round(1, 2, 3)'), (
        ExpressionErrorKind.argumentCount,
        'round,1-2,3',
      ));
      expect(e('concat()'), (
        ExpressionErrorKind.argumentCount,
        'concat,at least 1,0',
      ));
      expect(e('if(1, 2)'), (ExpressionErrorKind.argumentCount, 'if,3,2'));
      expect(e('year(qty)'), (
        ExpressionErrorKind.argumentType,
        'year,1,date,number',
      ));
      expect(e('text(region)'), (
        ExpressionErrorKind.argumentType,
        'text,1,number,text',
      ));
      expect(e('qty + region'), (
        ExpressionErrorKind.operandType,
        '+,number,text',
      ));
      expect(e('-region'), (ExpressionErrorKind.operandType, '-,number,text'));
      expect(e('not qty'), (
        ExpressionErrorKind.operandType,
        'not,boolean,number',
      ));
      expect(e('qty and active'), (
        ExpressionErrorKind.operandType,
        'and,boolean,number',
      ));
      expect(e('qty = region'), (
        ExpressionErrorKind.incompatibleTypes,
        '=,number,text',
      ));
      expect(e('active < true'), (
        ExpressionErrorKind.incompatibleTypes,
        '<,boolean,boolean',
      ));
      expect(e('date * 2'), (
        ExpressionErrorKind.incompatibleTypes,
        '*,date,number',
      ));
      expect(e('date + date'), (
        ExpressionErrorKind.incompatibleTypes,
        '+,date,date',
      ));
      expect(e('1 - date'), (
        ExpressionErrorKind.incompatibleTypes,
        '-,number,date',
      ));
      expect(e('if(active, 1, "a")'), (
        ExpressionErrorKind.incompatibleTypes,
        'if,number,text',
      ));
      expect(e('if(qty, 1, 2)'), (
        ExpressionErrorKind.operandType,
        'if,boolean,number',
      ));
      expect(e('qty in (1, "a")'), (
        ExpressionErrorKind.incompatibleTypes,
        'in,number,text',
      ));
      expect(
        e('active between true and false').$1,
        ExpressionErrorKind.operandType,
      );
      expect(e('null'), (ExpressionErrorKind.unknownType, ''));
      expect(e('if(active, null, null)').$1, ExpressionErrorKind.unknownType);
      expect(e('qty', expected: ExprType.boolean), (
        ExpressionErrorKind.resultType,
        'boolean,number',
      ));
      expect(e('sum(qty)'), (ExpressionErrorKind.unknownFunction, 'sum'));
      expect(e('qty', scope: cells), (
        ExpressionErrorKind.notAllowedHere,
        'qty',
      ));
      expect(e('sum(region)', scope: cells), (
        ExpressionErrorKind.argumentType,
        'sum,1,number,text',
      ));
      expect(e('sum(nope)', scope: cells), (
        ExpressionErrorKind.unknownColumn,
        'nope',
      ));
      expect(
        e('sum(qty + 1)', scope: cells).$1,
        ExpressionErrorKind.argumentType,
      );
      expect(
        e('sum(qty, price)', scope: cells).$1,
        ExpressionErrorKind.argumentCount,
      );
      expect(err('qty', expected: ExprType.number), isNull);
      // error range of an unknown function is the name only
      final u = err('nope(qty)')!;
      expect((u.offset, u.length), (0, 4));
      expect(u.message, 'unknown function "nope"');
    });

    test('cell scope resolves aggregates', () {
      final c = Expression.parse(
        'sum(qty) / count + avg(price) - MIN(qty) * max(price) + count(price) + distinct(region) + count()',
      ).check(cells);
      expect(c.type, ExprType.number);
      expect(c.dependencies, [
        Aggregate.sum(const Measure('qty')),
        Aggregate.count,
        Aggregate.average(const Measure('price')),
        Aggregate.min(const Measure('qty')),
        Aggregate.max(const Measure('price')),
        Aggregate.countNonNull(const Measure('price')),
        Aggregate.distinctCount(const ColumnDimension('region')),
      ]);
      expect(c.columns, {'qty', 'price', 'region'});
      // plain functions still work in cell scope
      expect(
        Expression.parse('round(sum(price) / count, 2)').check(cells).type,
        ExprType.number,
      );
      expect(Expression.parse('min(1, 2)').check(cells).dependencies, isEmpty);
    });

    test('custom functions and overloads', () {
      final fns = FunctionRegistry.standard().withFunctions([
        ExpressionFunction(
          'twice',
          parameters: [ExprType.number],
          returns: ExprType.number,
          implementation: (a) =>
              (a[0] as double?) == null ? null : (a[0] as double) * 2,
        ),
        ExpressionFunction(
          'twice',
          parameters: [ExprType.text],
          returns: ExprType.text,
          implementation: (a) => '${a[0]}${a[0]}',
        ),
      ]);
      final scope = ExpressionScope.rows(_types, functions: fns);
      expect(Expression.parse('twice(qty)').check(scope).type, ExprType.number);
      expect(
        Expression.parse('twice(region)').check(scope).type,
        ExprType.text,
      );
      expect(
        err('twice(date)', scope: scope)!.kind,
        ExpressionErrorKind.argumentType,
      );
      expect(fns.lookup('TWICE').length, 2);
      expect(FunctionRegistry.standard().contains('twice'), isFalse);
      // replacing a built-in signature
      final replaced = FunctionRegistry.standard().withFunction(
        ExpressionFunction(
          'abs',
          parameters: [ExprType.number],
          returns: ExprType.number,
          implementation: (a) => 42.0,
        ),
      );
      expect(replaced.lookup('abs').single.implementation, isNotNull);
      expect(FunctionRegistry.empty().functions, isEmpty);
    });
  });

  group('compiler', () {
    late FactTable f;
    setUpAll(() async => f = await facts());

    List<Object?> eval(String s) {
      final c = Expression.parse(s).compile(f);
      return [for (var i = 0; i < f.rowCount; i++) c.evaluate(i)];
    }

    test('columns and arithmetic with nulls', () {
      expect(eval('qty'), [1.0, 2.0, 3.0, 5.0, null]);
      expect(eval('qty * price'), [10.0, 40.0, null, 250.0, null]);
      expect(eval('price / qty'), [10.0, 10.0, null, 10.0, null]);
      expect(eval('qty / 0'), [null, null, null, null, null]);
      expect(eval('qty % 2'), [1.0, 0.0, 1.0, 1.0, null]);
      expect(eval('-qty + 1'), [0.0, -1.0, -2.0, -4.0, null]);
      expect(eval('coalesce(price, qty, 0)'), [10.0, 20.0, 3.0, 50.0, 70.0]);
      expect(eval('null + qty'), [null, null, null, null, null]);
    });

    test('comparisons and logic (three-valued)', () {
      expect(eval('qty > 1'), [false, true, true, true, null]);
      expect(eval('qty >= 2 and price > 10'), [false, true, null, true, null]);
      expect(eval('qty >= 2 or price > 10'), [false, true, true, true, true]);
      expect(eval('price > 100 or qty > 100'), [
        false,
        false,
        null,
        false,
        null,
      ]);
      expect(eval('not (qty > 1)'), [true, false, false, false, null]);
      expect(eval('qty = null'), [null, null, null, null, null]);
      expect(eval('qty is empty'), [false, false, false, false, true]);
      expect(eval('price is not empty'), [true, true, false, true, true]);
      expect(eval('isempty(active)'), [false, false, true, false, false]);
      expect(eval('active'), [true, false, null, true, false]);
      expect(eval('not active'), [false, true, null, false, true]);
      expect(eval('active = false'), [false, true, null, false, true]);
      expect(eval('qty between 2 and 3'), [false, true, true, false, null]);
      expect(eval('qty not between 2 and 3'), [true, false, false, true, null]);
      expect(eval('qty in (1, 5)'), [true, false, false, true, null]);
      expect(eval('qty not in (1, 5)'), [false, true, true, false, null]);
      expect(eval('qty in (1, null)'), [true, null, null, null, null]);
      expect(eval('qty in ()'), [false, false, false, false, null]);
      expect(eval('if(qty > 2, "big", "small")'), [
        'small',
        'small',
        'big',
        'big',
        'small',
      ]);
      expect(eval('if(qty > 2, qty, null)'), [null, null, 3.0, 5.0, null]);
    });

    test('text', () {
      expect(eval('region = "Europe"'), [true, true, true, false, null]);
      expect(eval('"Europe" = region'), [true, true, true, false, null]);
      expect(eval('region <> "Europe"'), [false, false, false, true, null]);
      expect(eval('region = "nowhere"'), [false, false, false, false, null]);
      expect(eval('region = country'), [false, false, null, false, null]);
      expect(eval('region = "europe"'), [false, false, false, false, null]);
      expect(eval('country in ("Germany", "Iceland", "x")'), [
        true,
        false,
        null,
        false,
        true,
      ]);
      expect(eval('country not in ("Germany")'), [
        false,
        true,
        null,
        true,
        true,
      ]);
      expect(eval('lower(region) in ("europe")'), [
        true,
        true,
        true,
        false,
        null,
      ]);
      expect(eval('region < country'), [true, true, null, true, null]);
      expect(eval('region between "A" and "B"'), [
        false,
        false,
        false,
        true,
        null,
      ]);
      expect(eval('lower(region)'), [
        'europe',
        'europe',
        'europe',
        'asia',
        null,
      ]);
      expect(eval('upper(left(region, 2))'), ['EU', 'EU', 'EU', 'AS', null]);
      expect(eval('right(region, 10)'), [
        'Europe',
        'Europe',
        'Europe',
        'Asia',
        null,
      ]);
      expect(eval('substring(region, 2, 3)'), [
        'uro',
        'uro',
        'uro',
        'sia',
        null,
      ]);
      expect(eval('substring(region, 5)'), ['pe', 'pe', 'pe', '', null]);
      expect(eval('len(region)'), [6.0, 6.0, 6.0, 4.0, null]);
      expect(eval('trim("  x ")').first, 'x');
      expect(eval('concat(region, "-", country)'), [
        'Europe-Germany',
        'Europe-Hungary',
        'Europe-',
        'Asia-Japan',
        '-Iceland',
      ]);
      expect(eval('replace(region, "u", "U")'), [
        'EUrope',
        'EUrope',
        'EUrope',
        'Asia',
        null,
      ]);
      expect(eval('contains(region, "rop")'), [true, true, true, false, null]);
      expect(eval('startswith(country, "G")'), [
        true,
        false,
        null,
        false,
        false,
      ]);
      expect(eval('endswith(country, "y")'), [true, true, null, false, false]);
      expect(eval('text(qty)'), ['1', '2', '3', '5', null]);
      expect(eval('text(price)'), ['10', '20', null, '50', '70']);
      expect(eval('text(1.5)').first, '1.5');
      expect(eval('text(date)'), [
        '2024-01-05',
        '2024-03-05',
        '2025-01-05',
        '2025-06-05',
        null,
      ]);
      expect(eval('text(active)'), ['true', 'false', null, 'true', 'false']);
      expect(eval('number("12.5")').first, 12.5);
      expect(eval('number("x")').first, isNull);
      expect(eval('number(text(qty)) = qty'), [true, true, true, true, null]);
    });

    test('dates', () {
      expect(eval('year(date)'), [2024.0, 2024.0, 2025.0, 2025.0, null]);
      expect(eval('month(date)'), [1.0, 3.0, 1.0, 6.0, null]);
      expect(eval('quarter(date)'), [1.0, 1.0, 1.0, 2.0, null]);
      expect(eval('day(date)'), [5.0, 5.0, 5.0, 5.0, null]);
      expect(eval('weekday(date)'), [5.0, 2.0, 7.0, 4.0, null]);
      expect(eval('week(date)'), [1.0, 10.0, 1.0, 23.0, null]);
      expect(eval('hour(date)'), [0.0, 0.0, 0.0, 0.0, null]);
      expect(eval('date >= #2024-03-05#'), [false, true, true, true, null]);
      expect(eval('date = #2024-01-05#'), [true, false, false, false, null]);
      expect(eval('date in (#2024-01-05#, #2025-06-05#)'), [
        true,
        false,
        false,
        true,
        null,
      ]);
      expect(eval('date between #2024-01-01# and #2024-12-31#'), [
        true,
        true,
        false,
        false,
        null,
      ]);
      expect(eval('date + 1'), [
        DateTime.utc(2024, 1, 6),
        DateTime.utc(2024, 3, 6),
        DateTime.utc(2025, 1, 6),
        DateTime.utc(2025, 6, 6),
        null,
      ]);
      expect(eval('1 + date').first, DateTime.utc(2024, 1, 6));
      expect(eval('date - 5').first, DateTime.utc(2023, 12, 31));
      expect(eval('date - #2024-01-01#'), [4.0, 64.0, 370.0, 521.0, null]);
      expect(eval('#2024-01-05# - date'), [0.0, -60.0, -366.0, -517.0, null]);
      expect(eval('date("2024-02-29")').first, DateTime.utc(2024, 2, 29));
      expect(eval('date("2024-02-30")').first, isNull);
      expect(eval('date(2024, 12, 31)').first, DateTime.utc(2024, 12, 31));
      expect(eval('date(2024, 1, qty)'), [
        DateTime.utc(2024, 1, 1),
        DateTime.utc(2024, 1, 2),
        DateTime.utc(2024, 1, 3),
        DateTime.utc(2024, 1, 5),
        null,
      ]);
      final today = eval('today()').first as DateTime;
      final now = DateTime.now();
      expect(today, DateTime.utc(now.year, now.month, now.day));
      expect(eval('year(today()) >= 2026').first, isTrue);
      expect(eval('date("x") is empty').first, isTrue);
    });

    test('numeric functions', () {
      expect(eval('abs(-qty)'), [1.0, 2.0, 3.0, 5.0, null]);
      expect(eval('round(price / 3)'), [3.0, 7.0, null, 17.0, 23.0]);
      expect(eval('round(price / 3, 2)'), [3.33, 6.67, null, 16.67, 23.33]);
      expect(eval('round(1234.5, -2)').first, 1200.0);
      expect(eval('floor(price / 3)'), [3.0, 6.0, null, 16.0, 23.0]);
      expect(eval('ceil(price / 3)'), [4.0, 7.0, null, 17.0, 24.0]);
      expect(eval('sqrt(price * 10)'), [
        10.0,
        closeTo(14.142, 0.001),
        null,
        closeTo(22.36, 0.01),
        closeTo(26.457, 0.001),
      ]);
      expect(eval('sqrt(-1)').first, isNull);
      expect(eval('min(qty, price)'), [1.0, 2.0, 3.0, 5.0, 70.0]);
      expect(eval('max(qty, price, 25)'), [25.0, 25.0, 25.0, 50.0, 70.0]);
      expect(eval('min(null, null)').first, isNull);
    });

    test('custom functions get boxed arguments', () {
      final calls = <List<Object?>>[];
      final fns = FunctionRegistry.standard().withFunctions([
        ExpressionFunction(
          'tag',
          parameters: [
            ExprType.text,
            ExprType.number,
            ExprType.date,
            ExprType.boolean,
          ],
          returns: ExprType.text,
          implementation: (a) {
            calls.add(a);
            return a[0] == null
                ? null
                : '${a[0]}:${a[1]}:${(a[2] as DateTime?)?.year}:${a[3]}';
          },
        ),
        ExpressionFunction(
          'nextday',
          parameters: [ExprType.date],
          returns: ExprType.date,
          implementation: (a) =>
              (a[0] as DateTime?)?.add(const Duration(days: 1)),
        ),
        ExpressionFunction(
          'big',
          parameters: [ExprType.number],
          returns: ExprType.boolean,
          implementation: (a) => a[0] == null ? null : (a[0] as double) > 2,
        ),
        ExpressionFunction(
          'half',
          parameters: [ExprType.number],
          returns: ExprType.number,
          implementation: (a) => a[0] == null ? null : (a[0] as double) / 2,
        ),
      ]);
      final scope = ExpressionScope.ofFacts(f, functions: fns);
      List<Object?> ev(String s) {
        final c = Expression.parse(s).compile(f, scope: scope);
        return [for (var i = 0; i < f.rowCount; i++) c.evaluate(i)];
      }

      expect(ev('tag(region, qty, date, active)'), [
        'Europe:1.0:2024:true',
        'Europe:2.0:2024:false',
        'Europe:3.0:2025:null',
        'Asia:5.0:2025:true',
        null,
      ]);
      expect(calls[2], ['Europe', 3.0, DateTime.utc(2025, 1, 5), null]);
      expect(calls[4], [null, null, null, false]);
      expect(ev('nextday(date)').first, DateTime.utc(2024, 1, 6));
      expect(ev('year(nextday(date))').last, isNull);
      expect(ev('big(qty)'), [false, false, true, true, null]);
      expect(ev('half(price) + 1'), [6.0, 11.0, null, 26.0, 36.0]);
    });

    test('typed accessors', () {
      final n = Expression.parse('qty * 2').compile(f);
      expect(n.type, ExprType.number);
      expect(n.asNumber(0), 2.0);
      expect(n.asNumber(4).isNaN, isTrue);
      final b = Expression.parse('qty > 1')
          .compile(f, expected: ExprType.boolean);
      expect(b.asBoolean(0), isFalse);
      expect(b.asBoolean(4), isNull);
      final t = Expression.parse('region').compile(f);
      expect(t.asText(0), 'Europe');
      final d = Expression.parse('date').compile(f);
      expect(
        d.asNumber(0),
        DateTime.utc(2024, 1, 5).millisecondsSinceEpoch.toDouble(),
      );
      expect(
        () => Expression.parse('qty').compile(f, expected: ExprType.text),
        throwsA(isA<ExpressionError>()),
      );
    });
  });

  group('on sales.csv', () {
    late FactTable sales;
    setUpAll(() async {
      final bytes = File('test/data/sales.csv').readAsBytesSync();
      sales = (await loadFacts(CsvDataSource.fromData(bytes))).facts;
    });

    test('a filter matches the same rows as a Dart predicate', () {
      final c = Expression.parse(
        'total > 100 and region = "Europe" and year(date) = 2024',
      ).compile(sales);
      var expected = 0, got = 0;
      for (var r = 0; r < sales.rowCount; r++) {
        final total = sales.valueAt(r, 'total') as num?;
        final region = sales.valueAt(r, 'region');
        final date = sales.valueAt(r, 'date') as DateTime?;
        final want =
            total != null &&
            total > 100 &&
            region == 'Europe' &&
            date != null &&
            date.year == 2024;
        if (want) expected++;
        if (c.asBoolean(r) == true) got++;
        expect(c.asBoolean(r) == true, want, reason: 'row $r');
      }
      expect(got, expected);
      expect(got, greaterThan(0));
    });

    test('a calculated measure agrees with the total column', () {
      final c = Expression.parse(
        'round(quantity * unit_price * (1 - coalesce(discount, 0)), 2)',
      ).compile(sales);
      for (var r = 0; r < sales.rowCount; r++) {
        final total = sales.valueAt(r, 'total') as num?;
        final v = c.asNumber(r);
        if (total == null) {
          expect(v.isNaN, isTrue, reason: 'row $r');
        } else {
          expect(v, closeTo(total.toDouble(), 0.11), reason: 'row $r');
        }
      }
    });
  });
}
