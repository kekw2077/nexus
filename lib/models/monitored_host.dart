import '../core/id.dart';

/// Машина под наблюдением. Требует токен для доступа к агенту.
/// MAC и broadcast опциональны: если заданы, карточка получает кнопку включения
/// (сервер и будят, и мониторят; прочие ПК могут жить только в списке WoL).
class MonitoredHost {
  MonitoredHost({
    required this.id,
    required this.name,
    required this.host,
    required this.token,
    this.port = 8765,
    this.mac,
    this.broadcast,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String token;
  final String? mac;
  final String? broadcast;

  bool get canWake => mac != null && mac!.isNotEmpty;

  MonitoredHost copyWith({
    String? name,
    String? host,
    int? port,
    String? token,
    String? mac,
    String? broadcast,
  }) {
    return MonitoredHost(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      token: token ?? this.token,
      mac: mac ?? this.mac,
      broadcast: broadcast ?? this.broadcast,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'token': token,
        'mac': mac,
        'broadcast': broadcast,
      };

  factory MonitoredHost.fromJson(Map<String, dynamic> json) {
    return MonitoredHost(
      id: json['id'] as String? ?? newId(),
      name: json['name'] as String? ?? 'Без названия',
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 8765,
      token: json['token'] as String? ?? '',
      mac: json['mac'] as String?,
      broadcast: json['broadcast'] as String?,
    );
  }
}
