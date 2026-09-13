import 'package:test/test.dart';
import 'package:tessera/tessera.dart';

void main() {
  group('Oklch', () {
    test('white, black and the sRGB primaries', () {
      final white = Oklch.fromArgb(0xFFFFFFFF);
      expect(white.lightness, closeTo(1, 0.001));
      expect(white.chroma, closeTo(0, 0.001));
      final black = Oklch.fromArgb(0xFF000000);
      expect(black.lightness, closeTo(0, 0.001));
      final red = Oklch.fromArgb(0xFFFF0000);
      expect(red.lightness, closeTo(0.628, 0.002));
      expect(red.chroma, closeTo(0.258, 0.002));
      expect(red.hue, closeTo(29.2, 0.5));
      final blue = Oklch.fromArgb(0xFF0000FF);
      expect(blue.lightness, closeTo(0.452, 0.002));
      expect(blue.hue, closeTo(264.1, 0.5));
    });

    test('round-trips sRGB colours', () {
      for (final argb in [
        0xFFFFFFFF,
        0xFF000000,
        0xFF1A73E8,
        0xFF26A69A,
        0xFFE0F2F1,
        0xFF808080,
        0xFFFFCC00,
      ]) {
        expect(Oklch.fromArgb(argb).toArgb(), argb, reason: argb.toString());
      }
    });

    test('clips to the gamut by reducing chroma only', () {
      const wanted = Oklch(0.955, 0.3, 264);
      expect(wanted.inGamut, isFalse);
      final got = Oklch.fromArgb(wanted.toArgb());
      expect(got.lightness, closeTo(0.955, 0.01));
      expect(got.hue, closeTo(264, 6));
      expect(got.chroma, lessThan(0.3));
      expect(got.chroma, greaterThan(0.01));
      expect(const Oklch(0.5, 0.05, 100).inGamut, isTrue);
    });
  });

  group('HueLevels', () {
    test('steps by the golden angle from the hue and wraps', () {
      const levels = HueLevels(hue: 300);
      expect(levels.hueAt(0), 300);
      expect(levels.hueAt(1), closeTo(77.5, 0.1));
      expect(levels.hueAt(2), closeTo(215.0, 0.1));
      const equal = HueLevels(hue: 0, step: 120);
      expect(equal.hueAt(3), 0);
      expect(HueLevels(hue: 10, step: -30).hueAt(1), 340);
    });

    test('every level is equally light; headers share the hue', () {
      for (final levels in const [HueLevels(hue: 20), HueLevels(dark: true)]) {
        for (var i = 0; i < 8; i++) {
          final cell = Oklch.fromArgb(levels.fill(i));
          final header = Oklch.fromArgb(levels.headerFill(i));
          expect(
            cell.lightness,
            closeTo(levels.effectiveLightness, 0.012),
            reason: 'level $i',
          );
          expect(
            header.lightness,
            closeTo(levels.effectiveHeaderLightness, 0.012),
            reason: 'header $i',
          );
          expect(header.chroma, greaterThan(cell.chroma), reason: 'header $i');
          expect(_hueDistance(cell.hue, levels.hueAt(i)), lessThan(8));
          expect(_hueDistance(header.hue, levels.hueAt(i)), lessThan(5));
        }
      }
      expect(const HueLevels(dark: true).fill(0) & 0xFF, lessThan(0x80));
      expect(const HueLevels().fill(0) & 0xFF, greaterThan(0xD0));
    });

    test('fills lists, copyWith, equality', () {
      const levels = HueLevels(hue: 100);
      expect(levels.fills(3), [levels.fill(0), levels.fill(1), levels.fill(2)]);
      expect(levels.headerFills(2, from: 3), [
        levels.headerFill(3),
        levels.headerFill(4),
      ]);
      expect(levels.copyWith(dark: true).hue, 100);
      expect(levels.copyWith(hue: 5), const HueLevels(hue: 5));
      expect(const HueLevels().effectiveHue, HueLevels.defaultHue);
    });
  });
}

double _hueDistance(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}
