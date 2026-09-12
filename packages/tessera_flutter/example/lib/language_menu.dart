import 'package:flutter/material.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

/// The app's locale, switchable from any AppBar; `null` follows the system.
final appLocale = ValueNotifier<Locale?>(null);

/// AppBar action listing Tessera's built-in languages.
class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton<Locale>(
    icon: const Icon(Icons.language),
    tooltip: 'Language',
    initialValue: Localizations.localeOf(context),
    onSelected: (l) => appLocale.value = l,
    itemBuilder: (context) => [
      for (final l in TesseraLocalizations.supportedLocales)
        PopupMenuItem(value: l, child: Text(l.languageCode)),
    ],
  );
}
