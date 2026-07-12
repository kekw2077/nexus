import '../core/id.dart';

/// Машина под наблюдением. Требует токен для доступа к агенту.
/// MAC и broadcast опциональны: если заданы, карточка получает кнопку включения
/// (сервер и будят, и мониторят; прочие ПК могут жить только в списке WoL).
///
/// alertCpu/… — последние введённые на этом устройстве пороги (для префилла формы).
/// alertsLocalOnly — пороги применены оверрайдом только для этого устройства
/// (агент шлёт push этому телефону по ним; другим — по общим серверным).
class MonitoredHost {
  MonitoredHost({
    required this.id,
    required this.name,
    required this.host,
    required this.token,
    this.port = 8765,
    this.mac,
    this.broadcast,
    this.alertCpu,
    this.alertRam,
    this.alertDisk,
    this.alertTemp,
    this.alertsLocalOnly = false,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String token;
  final String? mac;
  final String? broadcast;
  final int? alertCpu;
  final int? alertRam;
  final int? alertDisk;
  final double? alertTemp;
  final bool alertsLocalOnly;

  bool get canWake => mac != null && mac!.isNotEmpty;

  MonitoredHost copyWith({
    String? name,
    String? host,
    int? port,
    String? token,
    String? mac,
    String? broadcast,
    int? alertCpu,
    int? alertRam,
    int? alertDisk,
    double? alertTemp,
    bool? alertsLocalOnly,
  }) {
    return MonitoredHost(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      token: token ?? this.token,
      mac: mac ?? this.mac,
      broadcast: broadcast ?? this.broadcast,
      alertCpu: alertCpu ?? this.alertCpu,
      alertRam: alertRam ?? this.alertRam,
      alertDisk: alertDisk ?? this.alertDisk,
      alertTemp: alertTemp ?? this.alertTemp,
      alertsLocalOnly: alertsLocalOnly ?? this.alertsLocalOnly,
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
        'alertCpu': alertCpu,
        'alertRam': alertRam,
        'alertDisk': alertDisk,
        'alertTemp': alertTemp,
        'alertsLocalOnly': alertsLocalOnly,
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
      alertCpu: (json['alertCpu'] as num?)?.toInt(),
      alertRam: (json['alertRam'] as num?)?.toInt(),
      alertDisk: (json['alertDisk'] as num?)?.toInt(),
      alertTemp: (json['alertTemp'] as num?)?.toDouble(),
      alertsLocalOnly: json['alertsLocalOnly'] as bool? ?? false,
    );
  }
}
