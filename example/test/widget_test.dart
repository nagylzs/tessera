import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_example/main.dart';

void main() {
  testWidgets('loads sales.csv and shows the cube', (tester) async {
    // Asset loading is real I/O, which needs runAsync under the test clock.
    await tester.runAsync(() async {
      await tester.pumpWidget(const TesseraExampleApp());
      expect(find.text('Tessera — sales.csv'), findsOneWidget);
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        if (find.text('1000 facts, 11 columns').evaluate().isNotEmpty) break;
      }
    });
    expect(find.text('1000 facts, 11 columns'), findsOneWidget);
    expect(find.text('Europe'), findsOneWidget);
    expect(find.text('Total (all countries)'), findsOneWidget);
    expect(find.text('sum of total'), findsWidgets);
  });
}
