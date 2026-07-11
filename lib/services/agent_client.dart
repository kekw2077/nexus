import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/alert_config.dart';
import '../models/alert_item.dart';
import '../models/host_metrics.dart';

/// Клиент агента на целевой машине.
///   GET  /health         — доступность (без токена)
///   GET  /metrics        — метрики (Bearer-токен)
///   GET  /alerts         — превышенные пороги cpu/ram/disk/temperature (Bearer-токен)
///   PUT  /alert-config   — задать пороги/топик ntfy для этого хоста (Bearer-токен)
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
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final res = await _client.get(
        _uri(host, port, '/alerts'),
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

  /// Сохраняет пороги/топик ntfy на агенте — телефон источник истины,
  /// агент просто исполняет присланное.
  Future<String?> setAlertConfig(
    String host,
    int port,
    String token,
    AlertConfig config, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final res = await _client
          .put(
            _uri(host, port, '/alert-config'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(config.toJson()),
          )
          .timeout(timeout);

      if (res.statusCode == 200) return null;
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['error'] as String? ?? 'Ошибка ${res.statusCode}';
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
