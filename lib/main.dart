import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/device_identity.dart';
import 'services/prefs_store.dart';
import 'services/push_service.dart';
import 'state/evs_controller.dart';
import 'state/monitor_controller.dart';
import 'state/settings_controller.dart';
import 'state/wol_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await PrefsStore.create();
  final device = DeviceIdentity.ensure(store);
  // Push — не критичен для запуска: если Firebase не сконфигурирован или
  // недоступен, приложение всё равно должно стартовать (метрики/WoL/облако
  // работают без него).
  try {
    await PushService.init(topic: device.topic);
  } catch (_) {}

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
