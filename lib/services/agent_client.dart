import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/host_metrics.dart';

/// Клиент агента на целевой машине.
///   GET  /health   — доступность (без токена)
///   GET  /metrics  — метрики (Bearer-токен)
///   POST /wake     — ретрансляция magic-пакета (Bearer-токен)
class AgentClient {
  AgentClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String host, int port, String path) => Uri.parse('http://$host:$port$path');

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
      return const HostMetrics.offline();
    } catch (_) {
      return const HostMetrics.offline();
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
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final res = await _client
          .post(
            _uri(host, port, '/wake'),
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
