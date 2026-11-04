import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'qty', 'unit price', 'sold'],
    rows: const [
      ['Europe', 1, 2.5, '2025-01-05'],
      ['Asia', 2, 4.0, '2025-02-06'],
    ],
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(
        name: 'qty',
        type: ColumnType.integer,
        label: 'Quantity',
      ),
      const ColumnSpec(name: 'unit price', type: ColumnType.number),
      const ColumnSpec(name: 'sold', type: ColumnType.date),
    ]),
  );
  return (await loadFacts(source)).facts;
}

void main() {
  late FactTable f;
  setUpAll(() async => f = await facts());

  Map<String, String> labels() => {for (final c in f.columns) c.name: c.label};

  /// An [ExpressionField] alone on a page; [values] collects what it
  /// reports.
  Future<void> pumpField(
    WidgetTester tester, {
    required ExpressionScope scope,
    ExprType? expected,
    List<ExpressionFieldValue>? values,
    bool help = true,
    TesseraStrings strings = const TesseraStringsEn(),
  }) => tester.pumpWidget(
    TesseraLocalizationsScope(
      strings: strings,
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ExpressionField(
              scope: scope,
              expected: expected,
              help: help,
              columnLabels: labels(),
              onChanged: (v) => values?.add(v),
            ),
          ),
        ),
      ),
    ),
  );

  Finder helpList() => find.descendant(
    of: find.byType(ExpressionHelp),
    matching: find.byType(Scrollable),
  );

  Future<void> tapInHelp(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: helpList());
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  int cursor(WidgetTester tester) => tester
      .widget<TextField>(find.byType(TextField))
      .controller!
      .selection
      .baseOffset;

  group('ExpressionSnippet', () {
    test('goes over the selection, the cursor where it says', () {
      final v = ExpressionSnippet.call('round').insertInto(
        const TextEditingValue(
          text: 'qty > 2',
          selection: TextSelection(baseOffset: 6, extentOffset: 7),
        ),
      );
      expect(v.text, 'qty > round()');
      expect(v.selection, const TextSelection.collapsed(offset: 12));
    });

    test('goes at the end of a field never focused', () {
      final v = const ExpressionSnippet('qty')
          .insertInto(const TextEditingValue(text: 'sum('));
      expect(v.text, 'sum(qty');
      expect(v.selection.baseOffset, 7);
    });

    test('keeps a space between two names', () {
      final v = const ExpressionSnippet('[unit price]').insertInto(
        const TextEditingValue(
          text: 'qty',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(v.text, 'qty [unit price]');
      expect(v.selection.baseOffset, 16);
    });

    test('a call without parameters leaves the cursor after it', () {
      final v = ExpressionSnippet.call(
        'today',
        hasParameters: false,
      ).insertInto(TextEditingValue.empty);
      expect(v.text, 'today()');
      expect(v.selection.baseOffset, 7);
    });
  });

  group('examples', () {
    test('use the columns and validate', () {
      for (final expected in [ExprType.boolean, ExprType.number, null]) {
        final scope = ExpressionScope.ofFacts(f);
        final examples = expressionExamples(scope, expected);
        expect(examples, isNotEmpty, reason: '$expected');
        expect(examples.length, lessThanOrEqualTo(4));
        for (final e in examples) {
          expect(
            Expression.validate(e, scope: scope, expected: expected),
            isNull,
            reason: e,
          );
        }
      }
      final cells = expressionExamples(
        ExpressionScope.cellsOf(f),
        ExprType.number,
      );
      expect(cells, contains('sum(qty) / count'));
    });

    test('leave out what the columns cannot make', () {
      const scope = ExpressionScope.rows({'name': ExprType.text});
      final examples = expressionExamples(scope, ExprType.boolean);
      expect(examples, ['startswith(name, "A")']);
      expect(expressionExamples(const ExpressionScope.rows({}), null), isEmpty);
    });
  });

  testWidgets('the ? button opens the help for a filter', (tester) async {
    await pumpField(
      tester,
      scope: ExpressionScope.ofFacts(f),
      expected: ExprType.boolean,
    );
    await tester.tap(find.byTooltip('Expression help'));
    await tester.pumpAndSettle();
    const help = ExpressionHelpStringsEn();
    expect(find.text(help.intro(ExpressionHelpUse.filter)), findsOneWidget);
    expect(find.text(help.tapToInsert), findsOneWidget);
    // A column whose label differs shows it beside the name.
    expect(find.text('qty · Quantity', findRichText: true), findsOneWidget);
    expect(find.text('[unit price]', findRichText: true), findsOneWidget);
    final rule = find.text(help.ruleText(ExpressionHelpRule.filters));
    await tester.scrollUntilVisible(rule, 200, scrollable: helpList());
    expect(rule, findsOneWidget);
  });

  testWidgets('a tapped column goes in at the cursor and is checked', (
    tester,
  ) async {
    final values = <ExpressionFieldValue>[];
    await pumpField(
      tester,
      scope: ExpressionScope.ofFacts(f),
      expected: ExprType.boolean,
      values: values,
    );
    await tester.enterText(find.byType(TextField), ' > 2');
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.tap(find.byTooltip('Expression help'));
    await tester.pumpAndSettle();
    await tapInHelp(tester, find.text('[unit price]', findRichText: true));
    expect(find.byType(ExpressionHelp), findsNothing);
    expect(fieldText(tester), '[unit price] > 2');
    expect(cursor(tester), '[unit price]'.length);
    expect(values.last.source, '[unit price] > 2');
    expect(values.last.isValid, isTrue);
  });

  testWidgets('a tapped function goes in with the cursor inside', (
    tester,
  ) async {
    await pumpField(tester, scope: ExpressionScope.ofFacts(f));
    await tester.enterText(find.byType(TextField), 'qty + ');
    await tester.tap(find.byTooltip('Expression help'));
    await tester.pumpAndSettle();
    await tapInHelp(tester, find.text('round(x, digits)'));
    expect(fieldText(tester), 'qty + round()');
    expect(cursor(tester), 'qty + round('.length);
  });

  testWidgets('a tapped example goes in', (tester) async {
    await pumpField(
      tester,
      scope: ExpressionScope.ofFacts(f),
      expected: ExprType.boolean,
    );
    await tester.tap(find.byTooltip('Expression help'));
    await tester.pumpAndSettle();
    await tapInHelp(tester, find.text('qty > 100'));
    expect(fieldText(tester), 'qty > 100');
  });

  testWidgets('a cell formula lists the aggregates', (tester) async {
    await pumpField(
      tester,
      scope: ExpressionScope.cellsOf(f),
      expected: ExprType.number,
    );
    await tester.tap(find.byTooltip('Expression help'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        const ExpressionHelpStringsEn().intro(ExpressionHelpUse.formula),
      ),
      findsOneWidget,
    );
    expect(find.text('Aggregates'), findsOneWidget);
    await tapInHelp(tester, find.text('count'));
    expect(fieldText(tester), 'count');
  });

  testWidgets('functions of the application are listed apart', (tester) async {
    final functions = FunctionRegistry.standard().withFunction(
      ExpressionFunction(
        'vat',
        parameters: const [ExprType.number],
        returns: ExprType.number,
        implementation: (args) => args[0],
      ),
    );
    await pumpField(
      tester,
      scope: ExpressionScope.ofFacts(f, functions: functions),
      expected: ExprType.number,
    );
    await tester.tap(find.byTooltip('Expression help'));
    await tester.pumpAndSettle();
    await tapInHelp(tester, find.text('vat(number) → number'));
    expect(fieldText(tester), 'vat()');
  });

  testWidgets('on a phone the help takes the whole screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpField(tester, scope: ExpressionScope.ofFacts(f));
    await tester.tap(find.byTooltip('Expression help'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Expression help'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(ExpressionHelp), findsNothing);
    expect(fieldText(tester), isEmpty);
  });

  testWidgets('the help speaks the app language', (tester) async {
    await pumpField(
      tester,
      scope: ExpressionScope.ofFacts(f),
      strings: const TesseraStringsHu(),
    );
    final hu = const TesseraStringsHu().expressionHelp;
    await tester.tap(find.byTooltip(hu.title));
    await tester.pumpAndSettle();
    expect(find.text(hu.intro(ExpressionHelpUse.dimension)), findsOneWidget);
    await tapInHelp(tester, find.text('round(x, jegyek)'));
    expect(fieldText(tester), 'round()');
  });

  testWidgets('help: false leaves the button out', (tester) async {
    await pumpField(tester, scope: ExpressionScope.ofFacts(f), help: false);
    expect(find.byTooltip('Expression help'), findsNothing);
  });

  testWidgets('without onPick nothing can be tapped', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExpressionHelp(scope: ExpressionScope.ofFacts(f))),
      ),
    );
    expect(
      find.text(const ExpressionHelpStringsEn().tapToInsert),
      findsNothing,
    );
    await tester.tap(find.text('qty', findRichText: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
