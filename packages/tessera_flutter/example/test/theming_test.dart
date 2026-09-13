import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessera_example/theming/presets.dart';

void main() {
  testWidgets('every preset resolves under light and dark themes', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        Theme(
          data: ThemeData(brightness: brightness),
          child: Builder(
            builder: (context) {
              for (final p in themePresets) {
                final t = p.theme.resolve(context);
                expect(t.rowHeight, greaterThan(0), reason: p.name);
                expect(t.levelColor(0, 2), isA<Color>(), reason: p.name);
                expect(t.levelColor(2, 2), isA<Color>(), reason: p.name);
              }
              return const SizedBox();
            },
          ),
        ),
      );
    }
    expect(themePresets.map((p) => p.name).toSet().length, themePresets.length);
  });
}
