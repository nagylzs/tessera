import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

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
      const ColumnSpec(
        name: 'country',
        type: ColumnType.text,
        label: 'Country',
      ),
      const ColumnSpec(name: 'date', type: ColumnType.date),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
      const ColumnSpec(name: 'price', type: ColumnType.number),
      const ColumnSpec(name: 'active', type: ColumnType.boolean),
    ]),
  );
  return (await loadFacts(source)).facts;
}

const region = ColumnDimension('region');

void main() {
  late FactTable f;
  setUpAll(() async => f = await facts());

  /// Pumps a page with a button that opens the editor; [result] receives
  /// what the dialog returned.
  Future<void> open(
    WidgetTester tester, {
    FactFilter? initial,
    required void Function(FilterEditorResult?) result,
    TesseraStrings? strings,
  }) async {
    tester.view.physicalSize = const Size(2400, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    Widget app = MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result(
              await showFilterEditor(context, facts: f, initial: initial),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    if (strings != null) {
      app = TesseraLocalizationsScope(strings: strings, child: app);
    }
    await tester.pumpWidget(app);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
  }

  Future<void> pickDropdown<T>(
    WidgetTester tester,
    Finder dropdown,
    String item,
  ) async {
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'an existing filter is shown as rows and applied back unchanged',
    (tester) async {
      final predicate = PredicateFilter((_, _) => true, label: 'server side');
      final initial = AndFilter([
        CompareFilter('qty', CompareOp.greater, 2),
        TextFilter('country', TextMatch.contains, 'an'),
        EmptyFilter('price', negated: true),
        ValueFilter(region, {'Europe', null}),
        RangeFilter(
          'date',
          DateTime.utc(2024, 1, 1),
          DateTime.utc(2024, 12, 31),
        ),
        CompareFilter('active', CompareOp.equal, false),
        OrFilter([ExpressionFilter('qty > 1'), NotFilter(EmptyFilter('qty'))]),
        predicate,
        ValueFilter(const DatePartDimension('date', DatePart.year), {2024}),
      ]);
      FilterEditorResult? result;
      await open(tester, initial: initial, result: (r) => result = r);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('is greater than'), findsOneWidget);
      expect(find.text('contains'), findsOneWidget);
      expect(find.text('is not empty'), findsOneWidget);
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('is between'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '2024-01-01'), findsOneWidget);
      expect(find.text('is false'), findsOneWidget);
      expect(find.text('Country'), findsOneWidget);
      expect(find.text('server side'), findsOneWidget);
      expect(find.text('Custom filter'), findsOneWidget);
      // the expression rows: the explicit one and the date-part value filter
      expect(find.widgetWithText(TextField, 'qty > 1'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'year(date) in (2024)'),
        findsOneWidget,
      );
      // one nested group, "any of", one "not" group inside
      expect(find.byType(Card), findsNWidgets(3));
      // untouched, the dialog returns the very same filter object
      await apply(tester);
      expect(identical(result!.filter, initial), isTrue);
      // edited (a no-op toggle), it returns the rebuilt tree
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not').first);
      await tester.pumpAndSettle();
      await apply(tester);
      final back = result!.filter as AndFilter;
      expect(back.filters.length, 9);
      expect(back.filters[0], CompareFilter('qty', CompareOp.greater, 2));
      expect(back.filters[1], TextFilter('country', TextMatch.contains, 'an'));
      expect(back.filters[2], EmptyFilter('price', negated: true));
      expect(back.filters[3], ValueFilter(region, {'Europe', null}));
      expect(
        back.filters[4],
        RangeFilter(
          'date',
          DateTime.utc(2024, 1, 1),
          DateTime.utc(2024, 12, 31),
        ),
      );
      expect(back.filters[5], CompareFilter('active', CompareOp.equal, false));
      expect(
        back.filters[6],
        OrFilter([ExpressionFilter('qty > 1'), NotFilter(EmptyFilter('qty'))]),
      );
      expect(identical(back.filters[7], predicate), isTrue);
      expect(back.filters[8], ExpressionFilter('year(date) in (2024)'));
      // the same rows survive a cube
      final cube = Cube(
        facts: f,
        spec: CubeSpec(filter: back),
      );
      expect(
        cube.layout.cellAt(0, 0).factCount,
        0,
      ); // Europe rows: qty > 2 → row 2 only, price empty → out
    },
  );

  testWidgets('building a filter from scratch', (tester) async {
    FilterEditorResult? result;
    await open(tester, result: (r) => result = r);
    expect(find.text('No filter'), findsOneWidget);
    // Apply is enabled on an empty editor and yields no filter
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
          .enabled,
      isTrue,
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add condition'));
    await tester.pumpAndSettle();
    // a new condition on the first column (region, text) with "equals" and no value is incomplete
    expect(find.text('equals'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
          .enabled,
      isFalse,
    );
    await tester.enterText(find.byType(TextFormField), 'Asia');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
          .enabled,
      isTrue,
    );
    // switch the column to qty: operators change, the value resets
    await pickDropdown(tester, find.byType(DropdownButton<String>), 'qty');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
          .enabled,
      isFalse,
    );
    await pickDropdown(tester, find.text('equals'), 'is at least');
    await tester.enterText(find.byType(TextFormField), '3');
    await tester.pumpAndSettle();
    // a second condition in a nested "any of" group
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add group'));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNWidgets(2));
    await tester.tap(find.text('Any of the following').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add condition').last);
    await tester.pumpAndSettle();
    await pickDropdown(
      tester,
      find.byType(DropdownButton<String>).last,
      'active',
    );
    expect(find.text('is true'), findsOneWidget);
    await tester.tap(find.text('Not').last);
    await tester.pumpAndSettle();
    await apply(tester);
    expect(
      result!.filter,
      AndFilter([
        CompareFilter('qty', CompareOp.greaterOrEqual, 3),
        NotFilter(CompareFilter('active', CompareOp.equal, true)),
      ]),
    );
  });

  testWidgets('picking values for "is one of"', (tester) async {
    FilterEditorResult? result;
    await open(
      tester,
      initial: ValueFilter(region, {'Asia'}),
      result: (r) => result = r,
    );
    expect(find.text('is one of'), findsOneWidget);
    await tester.tap(find.text('1 selected'));
    await tester.pumpAndSettle();
    expect(
      find.byType(CheckboxListTile),
      findsNWidgets(3),
    ); // (empty), Asia, Europe
    expect(find.text('(empty)'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Europe'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Asia'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'eur');
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await apply(tester);
    expect(result!.filter, ValueFilter(region, {'Europe'}));
  });

  testWidgets('expression rows validate as the user types, localized', (
    tester,
  ) async {
    FilterEditorResult? result;
    await open(
      tester,
      initial: ExpressionFilter('qty > 1'),
      result: (r) => result = r,
      strings: const TesseraStringsDe(),
    );
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Ausdruck'), findsOneWidget);
    final field = find.widgetWithText(TextField, 'qty > 1');
    await tester.enterText(field, 'qty > ');
    await tester.pumpAndSettle();
    expect(find.text('unerwartetes Ende des Ausdrucks'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Anwenden'))
          .enabled,
      isFalse,
    );
    await tester.enterText(find.byType(TextField), 'qty > region');
    await tester.pumpAndSettle();
    expect(
      find.text('> ist auf Zahl und Text nicht anwendbar'),
      findsOneWidget,
    );
    // the controller underlines the error range
    final controller =
        tester.widget<TextField>(find.byType(TextField)).controller
            as ExpressionTextController;
    expect(controller.error!.kind, ExpressionErrorKind.incompatibleTypes);
    final span = controller.buildTextSpan(
      context: tester.element(find.byType(TextField)),
      withComposing: false,
    );
    expect(span.children!.length, 3);
    expect((span.children![1] as TextSpan).text, 'qty > region');
    await tester.enterText(find.byType(TextField), 'nope = 1');
    await tester.pumpAndSettle();
    expect(find.text('unbekannte Spalte „nope“'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'qty > 2 and region = "Asia"',
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExpressionTextController), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Anwenden'));
    await tester.pumpAndSettle();
    expect(result!.filter, ExpressionFilter('qty > 2 and region = "Asia"'));
  });

  testWidgets('clear, cancel and removing rows', (tester) async {
    FilterEditorResult? result;
    var calls = 0;
    await open(
      tester,
      initial: CompareFilter('qty', CompareOp.less, 9),
      result: (r) {
        result = r;
        calls++;
      },
    );
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('No filter'), findsOneWidget);
    await apply(tester);
    expect(calls, 1);
    expect(result, isNotNull);
    expect(result!.filter, isNull);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('is less than'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('No filter'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(result, isNull);
  });

  test('expression errors have a message in every locale', () {
    final errors = [
      for (final s in [
        'qty +',
        'nope',
        'year(qty)',
        'qty + region',
        'round(1, 2, 3)',
        '"x',
        '[x',
        '#x',
        '1x',
        '#2024-13-01#',
        'a ? b',
        'null',
        'sum(qty)',
      ])
        Expression.validate(
          s,
          scope: const ExpressionScope.rows({
            'qty': ExprType.number,
            'region': ExprType.text,
          }),
        )!,
    ];
    expect(errors.map((e) => e.kind).toSet().length, greaterThan(9));
    for (final code in TesseraStrings.supportedLanguages) {
      final strings = TesseraStrings.forLanguage(code)!;
      for (final e in errors) {
        final text = strings.expressionError(e);
        expect(text, isNotEmpty, reason: '$code ${e.kind}');
        expect(text.contains(r'$'), isFalse, reason: '$code ${e.kind}');
        for (final a in e.arguments) {
          if (ExprType.values.any((t) => t.name == a)) continue;
          expect(text, contains(a), reason: '$code ${e.kind}: $text');
        }
      }
      final types = ExprType.values.map(strings.exprTypeName).toSet();
      expect(types.length, 4, reason: code);
      final ops = [
        strings.opEquals,
        strings.opNotEquals,
        strings.opLess,
        strings.opLessOrEqual,
        strings.opGreater,
        strings.opGreaterOrEqual,
        strings.opBetween,
        strings.opContains,
        strings.opStartsWith,
        strings.opEndsWith,
        strings.opIsEmpty,
        strings.opIsNotEmpty,
        strings.opIsOneOf,
        strings.opIsTrue,
        strings.opIsFalse,
      ];
      expect(ops.toSet().length, ops.length, reason: code);
    }
    // the German message localizes the type names
    final de = const TesseraStringsDe();
    expect(
      de.expressionError(
        Expression.validate(
          'year(qty)',
          scope: const ExpressionScope.rows({'qty': ExprType.number}),
        )!,
      ),
      'Argument 1 von year muss Datum sein, nicht Zahl',
    );
  });
}
