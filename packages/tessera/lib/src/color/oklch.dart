import 'dart:math' as math;

/// A colour in the OKLCH space: perceptual [lightness], [chroma] and
/// [hue]. Pure Dart, converts to and from ARGB ints.
///
/// Unlike HSL, equal [lightness] means equal *perceived* lightness for
/// every hue, so a set of colours that differ in hue only really looks
/// like it, and the contrast against text depends on [lightness] alone.
/// Not every OKLCH colour exists in sRGB; [toArgb] reduces the chroma
/// until the colour fits (the lightness and hue are kept).
final class Oklch {
  const Oklch(this.lightness, this.chroma, this.hue);

  /// `0` black … `1` white.
  final double lightness;

  /// `0` grey; pastels are around `0.05`, the most saturated sRGB colours
  /// reach about `0.3`.
  final double chroma;

  /// In degrees: `0` pink-red, `~90` yellow, `~140` green, `~200` cyan,
  /// `~260` blue, `~320` purple.
  final double hue;

  /// The OKLCH form of an ARGB int (alpha ignored).
  factory Oklch.fromArgb(int argb) {
    final r = _toLinear(((argb >> 16) & 0xFF) / 255);
    final g = _toLinear(((argb >> 8) & 0xFF) / 255);
    final b = _toLinear((argb & 0xFF) / 255);
    final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    final lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
    final a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
    final bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
    final chroma = math.sqrt(a * a + bb * bb);
    var hue = chroma < 1e-6 ? 0.0 : math.atan2(bb, a) * 180 / math.pi;
    if (hue < 0) hue += 360;
    return Oklch(lightness, chroma, hue);
  }

  /// Whether the colour exists in sRGB as is.
  bool get inGamut => _linearRgb().every((c) => c >= -1e-6 && c <= 1 + 1e-6);

  /// The nearest sRGB colour, as an opaque ARGB int: the chroma is
  /// reduced (never the lightness or hue) until the colour fits.
  int toArgb() {
    var c = this;
    if (!c.inGamut) {
      var lo = 0.0, hi = chroma;
      for (var i = 0; i < 20; i++) {
        final mid = (lo + hi) / 2;
        if (Oklch(lightness, mid, hue).inGamut) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      c = Oklch(lightness, lo, hue);
    }
    final rgb = c._linearRgb();
    int channel(double v) =>
        (_toGamma(v.clamp(0.0, 1.0)) * 255).round().clamp(0, 255);
    return 0xFF000000 |
        (channel(rgb[0]) << 16) |
        (channel(rgb[1]) << 8) |
        channel(rgb[2]);
  }

  Oklch copyWith({double? lightness, double? chroma, double? hue}) => Oklch(
    lightness ?? this.lightness,
    chroma ?? this.chroma,
    hue ?? this.hue,
  );

  List<double> _linearRgb() {
    final rad = hue * math.pi / 180;
    final a = chroma * math.cos(rad), b = chroma * math.sin(rad);
    final l = _cube(lightness + 0.3963377774 * a + 0.2158037573 * b);
    final m = _cube(lightness - 0.1055613458 * a - 0.0638541728 * b);
    final s = _cube(lightness - 0.0894841775 * a - 1.2914855480 * b);
    return [
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    ];
  }

  static double _cube(double x) => x * x * x;
  static double _cbrt(double x) =>
      x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
  static double _toLinear(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  static double _toGamma(double c) =>
      c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4) - 0.055;

  @override
  bool operator ==(Object other) =>
      other is Oklch &&
      other.lightness == lightness &&
      other.chroma == chroma &&
      other.hue == hue;

  @override
  int get hashCode => Object.hash(lightness, chroma, hue);

  @override
  String toString() =>
      'Oklch(${lightness.toStringAsFixed(3)}, ${chroma.toStringAsFixed(3)}, '
      '${hue.toStringAsFixed(1)}°)';
}
