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
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(result!.filter, ValueFilter(region, {'Asia', 'Europe'}));
  });
}
