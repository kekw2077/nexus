import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/root_shell.dart';
import 'state/settings_controller.dart';

class EvsRemoteApp extends StatelessWidget {
  const EvsRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return MaterialApp(
      title: 'Управление ПК',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(settings.brand, Brightness.light),
      darkTheme: buildTheme(settings.brand, Brightness.dark),
      themeMode: settings.themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')],
      locale: const Locale('ru'),
      home: const RootShell(),
    );
  }
}
