import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/root_shell.dart';

const _channelId = 'nexus_alerts';
const _channelName = 'Алерты Nexus';

final _localNotifications = FlutterLocalNotificationsPlugin();

/// Обязательное требование FCM — функция верхнего уровня, не метод класса:
/// вызывается в отдельном изоляте, который не разделяет состояние с main().
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await _showNotification(message);
}

Future<void> _showNotification(RemoteMessage message) async {
  final title = message.notification?.title ?? message.data['title'] as String? ?? 'Nexus';
  final body = message.notification?.body ?? message.data['message'] as String? ?? '';
  await _localNotifications.show(
    id: message.hashCode,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
      ),
    ),
  );
}

void _openStatusTab() {
  RootShell.selectedTab.value = RootShell.statusTabIndex;
}

/// Push-уведомления об алертах через self-hosted ntfy + собственный
/// Firebase-проект. Только Android — на iOS нет Apple Developer Program,
/// там пользователь ставит официальное приложение ntfy (см. README).
abstract final class PushService {
  static Future<void> init() async {
    if (Platform.isIOS) return;

    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (_) => _openStatusTab(),
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Алерты о проблемах на отслеживаемых машинах',
        importance: Importance.high,
      ),
    );

    // FCM не показывает уведомление сам, пока приложение открыто на переднем
    // плане — показываем его вручную тем же путём, что и фоновый обработчик.
    FirebaseMessaging.onMessage.listen(_showNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _openStatusTab());
  }
}
