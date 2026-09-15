import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import 'examples.dart';
import 'language_menu.dart';

void main() => runApp(const TesseraExampleApp());

/// Launcher for the Tessera examples (see `examples.dart`).
class TesseraExampleApp extends StatelessWidget {
  const TesseraExampleApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: appLocale,
    builder: (context, locale, _) => MaterialApp(
      title: 'Tessera examples',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      // `--dart-define=THEME=light|dark` fixes the theme (screenshots)
      themeMode: switch (const String.fromEnvironment('THEME')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      locale: locale,
      localizationsDelegates: const [
        TesseraLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: TesseraLocalizations.supportedLocales,
      home: _initial(context),
    ),
  );

  /// The launcher, or one example straight away when started with
  /// `--dart-define=EXAMPLE=<title>` (handy for screenshots).
  Widget _initial(BuildContext context) {
    const title = String.fromEnvironment('EXAMPLE');
    for (final e in examples) {
      if (e.title == title) return e.build(context);
    }
    return const LauncherPage();
  }
}

class LauncherPage extends StatelessWidget {
  const LauncherPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tessera examples'),
      actions: const [LanguageMenu()],
    ),
    body: ListView(
      children: [
        for (final e in examples)
          ListTile(
            leading: Icon(e.icon),
            title: Text(e.title),
            subtitle: Text(e.description),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: e.build),
            ),
          ),
      ],
    ),
  );
}
