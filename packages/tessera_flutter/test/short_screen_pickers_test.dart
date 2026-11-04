import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

/// The pickers on a phone in landscape: full screen, the keyboard closed
/// until the search field is tapped, the list below the bar.

const region = ColumnDimension('region');
const country = ColumnDimension('country');
const qty = Measure('qty');

Future<FactTable> facts() async {
  final source = ListDataSource(
    columns: ['region', 'country', 'qty'],
    rows: const [
      ['Europe', 'Germany', 1],
      ['Asia', 'Japan', 2],
    ],
    declaredSchema: Schema([
      const ColumnSpec(name: 'region', type: ColumnType.text),
      const ColumnSpec(name: 'country', type: ColumnType.text),
      const ColumnSpec(name: 'qty', type: ColumnType.integer),
    ]),
  );
  return (await loadFacts(source)).facts;
}

void main() {
  late FactTable f;
  setUpAll(() async => f = await facts());

  /// An iPhone 14 in landscape, in logical pixels.
  void landscapePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Pumps a page whose button runs [open]; returns after the tap.
  Future<void> pumpOpener(
    WidgetTester tester,
    Future<void> Function(BuildContext) open,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  bool searchFocused(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

  testWidgets('dimension picker: full screen, keyboard closed, list shown', (
    tester,
  ) async {
    landscapePhone(tester);
    Dimension? picked;
    await pumpOpener(
      tester,
      (context) async => picked = await showDimensionPicker(
        context,
        dimensions: const [region, country],
        used: {region},
      ),
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Add dimension'), findsOneWidget);
    expect(searchFocused(tester), isFalse);
    expect(find.byType(ListTile).hitTestable(), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), 'coun');
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'country').first);
    await tester.pumpAndSettle();
    expect(picked, country);
    expect(find.text('Add dimension'), findsNothing);
  });

  testWidgets('dimension picker: the close button cancels', (tester) async {
    landscapePhone(tester);
    var done = false;
    Dimension? picked;
    await pumpOpener(tester, (context) async {
      picked = await showDimensionPicker(context, dimensions: const [region]);
      done = true;
    });
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(picked, isNull);
  });

  testWidgets('dimension picker: a dialog with the keyboard open elsewhere', (
    tester,
  ) async {
    await pumpOpener(
      tester,
      (context) => showDimensionPicker(context, dimensions: const [region]),
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(searchFocused(tester), isTrue);
  });

  testWidgets('aggregate picker: the function in the bar, measures below', (
    tester,
  ) async {
    landscapePhone(tester);
    Aggregate? picked;
    await pumpOpener(
      tester,
      (context) async => picked = await showAggregatePicker(context, facts: f),
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Add aggregate'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Sum')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(ListTile, 'qty').first);
    await tester.pumpAndSettle();
    expect(picked, Aggregate.sum(qty));
  });

  testWidgets('aggregate picker: a formula form scrolls above the keyboard', (
    tester,
  ) async {
    landscapePhone(tester);
    await pumpOpener(
      tester,
      (context) => showAggregatePicker(context, facts: f),
    );
    await tester.tap(find.text('Sum'));
    await tester.pumpAndSettle();
    final formula = find.text('Formula', skipOffstage: false).last;
    await tester.ensureVisible(formula);
    await tester.pumpAndSettle();
    await tester.tap(formula);
    await tester.pumpAndSettle();
    // the keyboard takes about half the height
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, 'Add aggregate').hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('filter values: full screen with OK in the bar', (tester) async {
    landscapePhone(tester);
    FilterEditorResult? result;
    await pumpOpener(
      tester,
      (context) async => result = await showFilterEditor(
        context,
        facts: f,
        initial: ValueFilter(region, {'Asia'}),
      ),
    );
    await tester.tap(find.text('1 selected'));
    await tester.pumpAndSettle();
    expect(searchFocused(tester), isFalse);
    expect(find.byType(CheckboxListTile).hitTestable(), findsNWidgets(2));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Europe'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AppBar), matching: find.text('OK')),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(AppBar), matching: find.text('Apply')),
    );
    await tester.pumpAndSettle();
    expect(result!.filter, ValueFilter(region, {'Asia', 'Europe'}));
  });

  /// The Android emulator's Medium Phone in landscape, where the cramped
  /// forms were found (2026-11-04): 411 dp high under a 24 dp status bar,
  /// and a keyboard that leaves 152 dp.
  void landscapeAndroid(WidgetTester tester) {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.reset);
  }

  const keyboard = 235.0;

  /// The message [ExpressionField] shows for [source].
  String errorOf(String source, {ExprType? expected}) =>
      const TesseraStringsEn().expressionError(
        Expression.validate(
          source,
          scope: ExpressionScope.ofFacts(f),
          expected: expected,
        )!,
      );

  /// [finder] lies between the bar and the keyboard, not clipped away by
  /// its scroll view.
  void expectAboveKeyboard(WidgetTester tester, Finder finder) {
    expect(finder.hitTestable(), findsOneWidget);
    final rect = tester.getRect(finder);
    expect(
      rect.top,
      greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
    );
    expect(rect.bottom, lessThanOrEqualTo(411 - keyboard));
  }

  testWidgets('filter editor: full screen, the expression above the keyboard', (
    tester,
  ) async {
    landscapeAndroid(tester);
    FilterEditorResult? result;
    await pumpOpener(
      tester,
      (context) async => result = await showFilterEditor(
        context,
        facts: f,
        // two rows above it: scrolled to the caret, the field must bring
        // its error line along
        initial: AndFilter([
          ValueFilter(region, {'Asia'}),
          ValueFilter(country, {'Japan'}),
          ExpressionFilter('qty > 1'),
        ]),
      ),
    );
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(find.byType(ExpressionField), 'qty >');
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expectAboveKeyboard(tester, find.byType(EditableText));
    expectAboveKeyboard(
      tester,
      find.text(errorOf('qty >', expected: ExprType.boolean)),
    );
    await tester.enterText(find.byType(ExpressionField), 'qty > 1');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AppBar), matching: find.text('Apply')),
    );
    await tester.pumpAndSettle();
    expect(result!.filter, isA<AndFilter>());
  });

  testWidgets('dimension picker: the expression form above the keyboard', (
    tester,
  ) async {
    landscapeAndroid(tester);
    await pumpOpener(
      tester,
      (context) =>
          showDimensionPicker(context, dimensions: const [region], facts: f),
    );
    await tester.tap(find.text('Expression…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(ExpressionField), 'qty >');
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expectAboveKeyboard(
      tester,
      find.descendant(
        of: find.byType(ExpressionField),
        matching: find.byType(EditableText),
      ),
    );
    expectAboveKeyboard(tester, find.text(errorOf('qty >')));
    // the entry heads the form and still swaps it back for the list
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expression…'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpressionField), findsNothing);
    // label and id: both "region"
    expect(find.widgetWithText(ListTile, 'region'), findsWidgets);
  });

  testWidgets('an insert that errors at once shows the whole error line', (
    tester,
  ) async {
    landscapeAndroid(tester);
    await pumpOpener(
      tester,
      (context) =>
          showDimensionPicker(context, dimensions: const [region], facts: f),
    );
    await tester.tap(find.text('Expression…'));
    await tester.pumpAndSettle();
    // the help hides the keyboard; it comes back with the insert
    await tester.tap(find.byTooltip('Expression help'));
    await tester.pumpAndSettle();
    final max = find.text('min(x, y, …)');
    await tester.scrollUntilVisible(
      max,
      200,
      scrollable: find.descendant(
        of: find.byType(ExpressionHelp),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(max);
    await tester.pump();
    for (var inset = 0.0; inset < keyboard; inset += 47) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
    }
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();
    expectAboveKeyboard(tester, find.text(errorOf('min()')));
  });

  // Crossing 480 dp swaps a dialog for a full-screen page around the same
  // content; a phone rotated mid-edit must keep what is on it (found on
  // the Android emulator, 2026-11-04: the filter forgot its rows while
  // Apply still applied them, and the help inserted nothing).
  group('rotation keeps what is being edited', () {
    const portrait = Size(411, 914);
    const landscape = Size(914, 411);

    void start(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.reset);
    }

    Future<void> rotate(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
    }

    Finder applyButton() => find.byWidgetPredicate(
      (w) =>
          w is ButtonStyleButton &&
          w.child is Text &&
          (w.child! as Text).data == 'Apply',
    );

    Future<void> addExpressionRow(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add expression'));
      await tester.pumpAndSettle();
    }

    String fieldText(WidgetTester tester) => tester
        .widget<EditableText>(
          find.descendant(
            of: find.byType(ExpressionField),
            matching: find.byType(EditableText),
          ),
        )
        .controller
        .text;

    /// Opens the help of the only expression field, rotates to [size],
    /// taps [entry].
    Future<void> insertAcrossRotation(
      WidgetTester tester,
      Size size,
      String entry,
    ) async {
      await tester.tap(find.byTooltip('Expression help'));
      await tester.pumpAndSettle();
      await rotate(tester, size);
      final target = find.text(entry);
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.descendant(
          of: find.byType(ExpressionHelp),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    testWidgets('filter: an unapplied row survives portrait to landscape', (
      tester,
    ) async {
      start(tester, portrait);
      FilterEditorResult? result;
      await pumpOpener(
        tester,
        (context) async => result = await showFilterEditor(context, facts: f),
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      await addExpressionRow(tester);
      await tester.enterText(find.byType(ExpressionField), 'qty > 1');
      await tester.pumpAndSettle();
      await rotate(tester, landscape);
      expect(find.byType(AlertDialog), findsNothing);
      expect(fieldText(tester), 'qty > 1');
      await tester.tap(applyButton());
      await tester.pumpAndSettle();
      expect(
        result!.filter,
        isA<ExpressionFilter>().having((e) => e.source, 'source', 'qty > 1'),
      );
    });

    testWidgets('filter: a removed row stays removed landscape to portrait', (
      tester,
    ) async {
      start(tester, landscape);
      FilterEditorResult? result;
      await pumpOpener(
        tester,
        (context) async => result = await showFilterEditor(
          context,
          facts: f,
          initial: ExpressionFilter('qty > 1'),
        ),
      );
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('No filter'), findsOneWidget);
      await rotate(tester, portrait);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('No filter'), findsOneWidget);
      expect(find.byType(ExpressionField), findsNothing);
      await tester.tap(applyButton());
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.filter, isNull);
    });

    testWidgets('filter: Clear still starts afresh', (tester) async {
      start(tester, landscape);
      FilterEditorResult? result;
      await pumpOpener(
        tester,
        (context) async => result = await showFilterEditor(
          context,
          facts: f,
          initial: ExpressionFilter('qty > 1'),
        ),
      );
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.byType(ExpressionField), findsNothing);
      await rotate(tester, portrait);
      expect(find.byType(ExpressionField), findsNothing);
      await tester.tap(applyButton());
      await tester.pumpAndSettle();
      expect(result!.filter, isNull);
    });

    testWidgets('filter: the help inserts after a rotation', (tester) async {
      start(tester, portrait);
      await pumpOpener(
        tester,
        (context) => showFilterEditor(context, facts: f),
      );
      await addExpressionRow(tester);
      await insertAcrossRotation(tester, landscape, 'qty > 100');
      expect(fieldText(tester), 'qty > 100');
    });

    testWidgets('dimension picker: the form keeps its texts and its help', (
      tester,
    ) async {
      start(tester, portrait);
      await pumpOpener(
        tester,
        (context) =>
            showDimensionPicker(context, dimensions: const [region], facts: f),
      );
      await tester.tap(find.text('Expression…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(ExpressionField), 'qty % 2');
      await tester.enterText(find.widgetWithText(TextField, 'Label'), 'odd');
      await tester.pumpAndSettle();
      await rotate(tester, landscape);
      expect(fieldText(tester), 'qty % 2');
      expect(find.widgetWithText(TextField, 'odd'), findsOneWidget);
      await tester.enterText(find.byType(ExpressionField), '');
      await insertAcrossRotation(tester, portrait, 'left(text, n)');
      expect(fieldText(tester), 'left()');
      expect(find.widgetWithText(TextField, 'odd'), findsOneWidget);
    });

    testWidgets('aggregate picker: the form keeps its texts and its help', (
      tester,
    ) async {
      start(tester, portrait);
      await pumpOpener(
        tester,
        (context) => showAggregatePicker(context, facts: f),
      );
      await tester.tap(find.text('Expression…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(ExpressionField), 'qty * 2');
      await tester.enterText(find.widgetWithText(TextField, 'Label'), 'double');
      await tester.pumpAndSettle();
      await rotate(tester, landscape);
      expect(fieldText(tester), 'qty * 2');
      expect(find.widgetWithText(TextField, 'double'), findsOneWidget);
      await tester.enterText(find.byType(ExpressionField), '');
      await insertAcrossRotation(tester, portrait, 'abs(x)');
      expect(fieldText(tester), 'abs()');
    });
  });
}
