import 'oklch.dart';

/// Backgrounds for the nesting levels of a cube that differ in *hue*
/// only: every level is equally light and equally saturated, so no level
/// looks emphasised (a darker shade reads as "highlighted"), yet each is
/// told apart at a glance. Header cells take the same hue as their level
/// with more chroma, so a header and the cells of its level visibly
/// belong together. Lightness is left alone on purpose: it is what the
/// text contrast depends on, so a high-contrast setting only has to move
/// [lightness].
///
/// Level `i` gets the hue `hue + i × step`. The default [step] is the
/// golden angle rather than an equal division of the wheel, so adding a
/// level (a new dimension) leaves the existing levels' colours alone and
/// the new one is as far from its neighbours as possible.
///
/// Rows come first: a cube with `r` row levels uses indices `0 … r - 1`
/// for them and `r …` for the column levels, and a data cell takes its
/// *row* level's hue (its column header identifies itself by position).
/// Summary rows and columns get no hue; they are the one thing meant to
/// stand out, which a neutral fill among coloured cells does.
///
/// Unset values ([hue], [lightness], …) fall back to defaults for a light
/// or a [dark] document; `CubeTheme` in `tessera_flutter` fills them from
/// the app theme instead. Colours are computed in OKLCH ([Oklch]) so the
/// equal-lightness promise holds perceptually, and clipped to sRGB by
/// reducing the chroma.
final class HueLevels {
  const HueLevels({
    this.hue,
    this.step = goldenAngle,
    this.lightness,
    this.chroma,
    this.headerLightness,
    this.headerChroma,
    this.dark = false,
  });

  /// `360 / φ²` degrees: consecutive hues are spread as evenly as possible
  /// however many levels there are.
  static const double goldenAngle = 137.50776405;

  /// The hue of level `0`, in degrees. `null`: [defaultHue] (a cyan), or
  /// the app's primary colour under `CubeTheme`.
  final double? hue;

  /// Degrees between consecutive levels.
  final double step;

  /// OKLCH lightness of data cells; `null` picks `0.955` (`0.30` when
  /// [dark]).
  final double? lightness;

  /// OKLCH chroma of data cells; `null` picks `0.035` (`0.045` when
  /// [dark]).
  final double? chroma;

  /// OKLCH lightness of header cells; `null` picks `0.90` (`0.38` when
  /// [dark]), a small step from the cells so a header stays readable
  /// where a hue cannot carry much chroma (blues near white). Set it equal
  /// to [lightness] for chroma-only headers.
  final double? headerLightness;

  /// OKLCH chroma of header cells; `null` picks `0.09`.
  final double? headerChroma;

  /// Pick the dark defaults for unset values.
  final bool dark;

  static const double defaultHue = 200;

  double get effectiveHue => hue ?? defaultHue;
  double get effectiveLightness => lightness ?? (dark ? 0.30 : 0.955);
  double get effectiveChroma => chroma ?? (dark ? 0.045 : 0.035);
  double get effectiveHeaderLightness =>
      headerLightness ?? (dark ? 0.38 : 0.90);
  double get effectiveHeaderChroma => headerChroma ?? 0.09;

  /// The hue of level [index], in `[0, 360)`.
  double hueAt(int index) {
    final h = (effectiveHue + index * step) % 360;
    return h < 0 ? h + 360 : h;
  }

  /// The data-cell colour of level [index], ARGB.
  int fill(int index) =>
      Oklch(effectiveLightness, effectiveChroma, hueAt(index)).toArgb();

  /// The header colour of level [index], ARGB.
  int headerFill(int index) => Oklch(
    effectiveHeaderLightness,
    effectiveHeaderChroma,
    hueAt(index),
  ).toArgb();

  /// [count] data-cell fills from level [from].
  List<int> fills(int count, {int from = 0}) => [
    for (var i = 0; i < count; i++) fill(from + i),
  ];

  /// [count] header fills from level [from].
  List<int> headerFills(int count, {int from = 0}) => [
    for (var i = 0; i < count; i++) headerFill(from + i),
  ];

  /// A copy with the given values replaced (`null` keeps the current
  /// one; to unset [hue] build a new [HueLevels]).
  HueLevels copyWith({
    double? hue,
    double? step,
    double? lightness,
    double? chroma,
    double? headerLightness,
    double? headerChroma,
    bool? dark,
  }) => HueLevels(
    hue: hue ?? this.hue,
    step: step ?? this.step,
    lightness: lightness ?? this.lightness,
    chroma: chroma ?? this.chroma,
    headerLightness: headerLightness ?? this.headerLightness,
    headerChroma: headerChroma ?? this.headerChroma,
    dark: dark ?? this.dark,
  );

  @override
  bool operator ==(Object other) =>
      other is HueLevels &&
      other.hue == hue &&
      other.step == step &&
      other.lightness == lightness &&
      other.chroma == chroma &&
      other.headerLightness == headerLightness &&
      other.headerChroma == headerChroma &&
      other.dark == dark;

  @override
  int get hashCode => Object.hash(
    hue,
    step,
    lightness,
    chroma,
    headerLightness,
    headerChroma,
    dark,
  );
}
