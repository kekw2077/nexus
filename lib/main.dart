import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/prefs_store.dart';
import 'state/evs_controller.dart';
import 'state/monitor_controller.dart';
import 'state/settings_controller.dart';
import 'state/wol_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await PrefsStore.create();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsController(store)..load()),
        ChangeNotifierProvider(create: (_) => EvsController(store)..load()),
        ChangeNotifierProvider(create: (_) => WolController(store)..load()),
        ChangeNotifierProvider(create: (_) => MonitorController(store)..load()),
      ],
      child: const EvsRemoteApp(),
    ),
  );
}
