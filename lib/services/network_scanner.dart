import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Машина, найденная в локальной сети по отклику агента на `/health`.
class DiscoveredHost {
  DiscoveredHost({required this.ip, required this.port, this.hostname});

  final String ip;
  final int port;
  final String? hostname;

  /// Имя для показа/подстановки: hostname агента либо сам IP.
  String get label => (hostname != null && hostname!.isNotEmpty) ? hostname! : ip;
}

/// Вычисляет базу /24 из IPv4 («192.168.1.37» → «192.168.1.»). null, если не IPv4.
String? subnetBase24(String ipv4) {
  final parts = ipv4.split('.');
  if (parts.length != 4) return null;
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0 || n > 255) return null;
  }
  return '${parts[0]}.${parts[1]}.${parts[2]}.';
}

/// Числовой ключ IPv4 для сортировки по возрастанию.
int ipSortKey(String ipv4) =>
    ipv4.split('.').fold(0, (acc, o) => acc * 256 + (int.tryParse(o) ?? 0));

/// Сканирует /24-подсети всех локальных интерфейсов телефона на отклик агента
/// (`GET /health` → 200). Находит ровно те машины, где запущен `agent_slim.py`.
///
/// С мобильной песочницы ARP/ICMP недоступны, поэтому ищем именно по агенту —
/// это и есть мониторимые хосты. MAC отсюда не добыть (нет доступа к ARP).
class NetworkScanner {
  NetworkScanner({http.Client? client, this.concurrency = 32})
      : _client = client ?? http.Client();

  final http.Client _client;
  final int concurrency;

  /// Локальные IPv4-адреса устройства (без loopback).
  Future<List<String>> localIPv4() async {
    final result = <String>[];
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) result.add(addr.address);
        }
      }
    } catch (_) {
      // Нет доступа к интерфейсам — вернём пусто, сканирование не начнётся.
    }
    return result;
  }

  /// Запускает сканирование. `onFound` вызывается по мере обнаружения хостов —
  /// удобно для живого обновления списка в UI. Возвращает итоговый список.
  Future<List<DiscoveredHost>> scan({
    int port = 8765,
    Duration timeout = const Duration(milliseconds: 700),
    void Function(DiscoveredHost)? onFound,
  }) async {
    final locals = await localIPv4();
    final bases = <String>{};
    for (final ip in locals) {
      final base = subnetBase24(ip);
      if (base != null) bases.add(base);
    }
    if (bases.isEmpty) return const [];

    final candidates = <String>[];
    for (final base in bases) {
      for (var host = 1; host <= 254; host++) {
        final ip = '$base$host';
        if (!locals.contains(ip)) candidates.add(ip);
      }
    }

    final found = <DiscoveredHost>[];
    for (var i = 0; i < candidates.length; i += concurrency) {
      final slice = candidates.sublist(i, min(i + concurrency, candidates.length));
      final results = await Future.wait(slice.map((ip) => _probe(ip, port, timeout)));
      for (final host in results) {
        if (host != null) {
          found.add(host);
          onFound?.call(host);
        }
      }
    }

    found.sort((a, b) => ipSortKey(a.ip).compareTo(ipSortKey(b.ip)));
    return found;
  }

  Future<DiscoveredHost?> _probe(String ip, int port, Duration timeout) async {
    try {
      final res = await _client
          .get(Uri.parse('http://$ip:$port/health'))
          .timeout(timeout);
      if (res.statusCode != 200) return null;

      String? hostname;
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['hostname'] is String) {
          hostname = body['hostname'] as String;
        }
      } catch (_) {
        // Старый агент отдаёт только {"status":"ok"} — имя опционально.
      }
      return DiscoveredHost(ip: ip, port: port, hostname: hostname);
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
