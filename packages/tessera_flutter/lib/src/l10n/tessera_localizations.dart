import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:tessera/tessera.dart';

/// Flutter plumbing for [TesseraStrings]: the [delegate] that resolves the
/// app's locale to one of the built-in languages, and [of] for widgets.
///
/// ```dart
/// MaterialApp(
///   localizationsDelegates: const [TesseraLocalizations.delegate, ...],
///   supportedLocales: TesseraLocalizations.supportedLocales,
/// )
/// ```
///
/// Widgets resolve texts with [of]; without a delegate they fall back to
/// English. [TesseraLocalizationsScope] injects a [TesseraStrings] directly,
/// for apps that do not use the delegate mechanism or that provide their
/// own language.
abstract final class TesseraLocalizations {
  /// The locales with built-in strings; pass to `MaterialApp.supportedLocales`.
  static final List<Locale> supportedLocales = List.unmodifiable([
    for (final code in TesseraStrings.supportedLanguages) Locale(code),
  ]);

  /// Register in `MaterialApp.localizationsDelegates`.
  static const LocalizationsDelegate<TesseraStrings> delegate =
      _TesseraLocalizationsDelegate();

  /// The texts for [context]: a [TesseraLocalizationsScope] if there is
  /// one, else the [delegate]'s, else English.
  static TesseraStrings of(BuildContext context) =>
      maybeOf(context) ?? const TesseraStringsEn();

  /// Like [of], but `null` when neither a scope nor the delegate is present.
  static TesseraStrings? maybeOf(BuildContext context) =>
      TesseraLocalizationsScope.maybeOf(context) ??
      Localizations.of<TesseraStrings>(context, TesseraStrings);
}

class _TesseraLocalizationsDelegate
    extends LocalizationsDelegate<TesseraStrings> {
  const _TesseraLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      TesseraStrings.forLanguage(locale.languageCode) != null;

  @override
  Future<TesseraStrings> load(Locale locale) => SynchronousFuture(
    TesseraStrings.forLanguage(locale.languageCode) ?? const TesseraStringsEn(),
  );

  @override
  bool shouldReload(_TesseraLocalizationsDelegate old) => false;
}

/// Provides a [TesseraStrings] to the widgets below it, bypassing the
/// delegate mechanism. Place it above [MaterialApp] (or in its `builder`)
/// so dialogs see it too.
class TesseraLocalizationsScope extends InheritedWidget {
  const TesseraLocalizationsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final TesseraStrings strings;

  static TesseraStrings? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TesseraLocalizationsScope>()
      ?.strings;

  @override
  bool updateShouldNotify(TesseraLocalizationsScope oldWidget) =>
      strings != oldWidget.strings;
}
