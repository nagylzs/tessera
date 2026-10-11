import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_flutter/src/widgets/back_closing_menu_anchor.dart';

/// The system back, as Android's button or the browser's back sends it.
Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Widget menu() => BackClosingMenuAnchor(
  menuChildren: [MenuItemButton(onPressed: () {}, child: const Text('Item'))],
  builder: (context, menu, _) =>
      TextButton(onPressed: menu.open, child: const Text('Open')),
);

/// A first page that pushes a second one holding [second].
Widget twoPages(Widget second) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => Scaffold(body: second))),
        child: const Text('Push'),
      ),
    ),
  ),
);

void main() {
  testWidgets('back closes the open menu, not the route under it', (
    tester,
  ) async {
    await tester.pumpWidget(twoPages(menu()));
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Item'), findsOneWidget);

    await back(tester);
    expect(find.text('Item'), findsNothing);
    expect(find.text('Open'), findsOneWidget); // still on the second page

    await back(tester);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
  });

  testWidgets('a menu closed otherwise leaves back to the route', (
    tester,
  ) async {
    await tester.pumpWidget(twoPages(menu()));
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Item'));
    await tester.pumpAndSettle();
    expect(find.text('Item'), findsNothing);

    await back(tester);
    expect(find.text('Push'), findsOneWidget);
  });

  testWidgets('a PopScope that lets local history through', (tester) async {
    var vetoed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => PopScope(
            canPop: ModalRoute.of(context)!.willHandlePopInternally,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) vetoed++;
            },
            child: Scaffold(body: menu()),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await back(tester);
    expect(find.text('Item'), findsNothing);
    expect(vetoed, 0);

    await back(tester);
    expect(vetoed, 1);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('removed while open, it leaves no entry behind', (tester) async {
    var shown = true;
    late StateSetter setShown;
    await tester.pumpWidget(
      twoPages(
        StatefulBuilder(
          builder: (context, setState) {
            setShown = setState;
            return Column(children: [if (shown) menu(), const Text('Page')]);
          },
        ),
      ),
    );
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    setShown(() => shown = false);
    await tester.pumpAndSettle();
    expect(find.text('Item'), findsNothing);
    expect(tester.takeException(), isNull);

    await back(tester);
    expect(find.text('Push'), findsOneWidget);
  });
}
