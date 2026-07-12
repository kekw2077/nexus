import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/alert_config.dart';
import '../models/alert_item.dart';
import '../models/host_metrics.dart';
import '../models/nextcloud_status.dart';

/// Клиент агента на целевой машине.
///   GET  /health         — доступность (без токена)
///   GET  /metrics        — метрики (Bearer-токен)
///   GET  /alerts         — превышенные пороги машины + проблемы Nextcloud (Bearer-токен)
///   PUT  /alert-config   — задать пороги/топик ntfy для этого хоста (Bearer-токен)
///   GET  /nextcloud      — состояние Nextcloud, если настроен на агенте (Bearer-токен)
///   POST /wake           — ретрансляция magic-пакета (Bearer-токен)
class AgentClient {
  AgentClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String host, int port, String path, {String scheme = 'http'}) =>
      Uri.parse('$scheme://$host:$port$path');

  Future<bool> health(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final res = await _client.get(_uri(host, port, '/health')).timeout(timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<HostMetrics> metrics(
    String host,
    int port,
    String token, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final res = await _client.get(
        _uri(host, port, '/metrics'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(timeout);

      if (res.statusCode == 200) {
        return HostMetrics.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      // 401 и прочее трактуем как «недоступна» — детали в state не помещаются,
      // но неверный токен виден по тому, что онлайновый хост не отдаёт метрики.
      return HostMetrics.offline();
    } catch (_) {
      return HostMetrics.offline();
    }
  }

  Future<List<AlertItem>> alerts(
    String host,
    int port,
    String token, {
    String? deviceId,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final path = deviceId != null ? '/alerts?device=$deviceId' : '/alerts';
      final res = await _client.get(
        _uri(host, port, path),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(timeout);

      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['alerts'] as List?) ?? const [];
      return list.cast<Map<String, dynamic>>().map(AlertItem.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Состояние Nextcloud с агента. Если облако у агента не настроено или запрос
  /// не удался — возвращает NextcloudStatus.notConfigured() (карточка скрыта).
  Future<NextcloudStatus> nextcloud(
    String host,
    int port,
    String token, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final res = await _client.get(
        _uri(host, port, '/nextcloud'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(timeout);

      if (res.statusCode != 200) return NextcloudStatus.notConfigured();
      return NextcloudStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return NextcloudStatus.notConfigured();
    }
  }

  /// Отправляет на агент пороги/регистрацию устройства (multi-tenant).
  ///   scope 'all'      — общие пороги (для всех устройств);
  ///   scope 'device'   — оверрайд только для этого deviceId;
  ///   scope 'clear'    — снять оверрайд устройства (вернуть на общие);
  ///   scope 'register' — только зарегистрировать топик (чтобы получать push).
  /// deviceId/topic — идентичность устройства; телефон источник истины.
  Future<String?> setAlertConfig(
    String host,
    int port,
    String token, {
    required String deviceId,
    required String topic,
    required String scope,
    AlertConfig thresholds = const AlertConfig(),
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final body = <String, dynamic>{
        'deviceId': deviceId,
        'topic': topic,
        'scope': scope,
        ...thresholds.toJson(),
      };
      final res = await _client
          .put(
            _uri(host, port, '/alert-config'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (res.statusCode == 200) return null;
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        return err['error'] as String? ?? 'Ошибка ${res.statusCode}';
      } catch (_) {
        return 'Ошибка ${res.statusCode}';
      }
    } catch (_) {
      return 'Агент недоступен';
    }
  }

  /// Просит агент отправить magic-пакет в свою локальную сеть.
  /// Возвращает текст ошибки или null при успехе.
  Future<String?> wake(
    String host,
    int port,
    String token, {
    required String mac,
    required String broadcast,
    int wolPort = 9,
    bool secure = false,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final res = await _client
          .post(
            _uri(host, port, '/wake', scheme: secure ? 'https' : 'http'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'mac': mac, 'broadcast': broadcast, 'port': wolPort}),
          )
          .timeout(timeout);

      if (res.statusCode == 200) return null;
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['error'] as String? ?? 'Ошибка ${res.statusCode}';
      } catch (_) {
        return 'Ошибка ${res.statusCode}';
      }
    } catch (e) {
      return 'Ретранслятор недоступен';
    }
  }

  void dispose() => _client.close();
}
