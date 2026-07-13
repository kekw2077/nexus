import '../core/id.dart';

/// Машина, которую только будят по сети. Свой список, независимый от мониторинга.
class WolTarget {
  WolTarget({
    required this.id,
    required this.name,
    required this.mac,
    required this.broadcast,
    this.port = 9,
    this.directSend = false,
    this.lastWakeAt,
  });

  final String id;
  final String name;
  final String mac;
  final String broadcast;
  final int port;

  /// Отправлять пакет напрямую с телефона, минуя ретранслятор, даже если он
  /// включён. Нужно для WAN-цели: адрес — DDNS/публичный, порт — проброшенный
  /// на роутере; такую цель нельзя гнать через релей (он бродкастит в свою LAN).
  final bool directSend;

  final DateTime? lastWakeAt;

  WolTarget copyWith({
    String? name,
    String? mac,
    String? broadcast,
    int? port,
    bool? directSend,
    DateTime? lastWakeAt,
  }) {
    return WolTarget(
      id: id,
      name: name ?? this.name,
      mac: mac ?? this.mac,
      broadcast: broadcast ?? this.broadcast,
      port: port ?? this.port,
      directSend: directSend ?? this.directSend,
      lastWakeAt: lastWakeAt ?? this.lastWakeAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mac': mac,
        'broadcast': broadcast,
        'port': port,
        'directSend': directSend,
        'lastWakeAt': lastWakeAt?.toIso8601String(),
      };

  factory WolTarget.fromJson(Map<String, dynamic> json) {
    return WolTarget(
      id: json['id'] as String? ?? newId(),
      name: json['name'] as String? ?? 'Без названия',
      mac: json['mac'] as String? ?? '',
      broadcast: json['broadcast'] as String? ?? '255.255.255.255',
      port: (json['port'] as num?)?.toInt() ?? 9,
      directSend: json['directSend'] as bool? ?? false,
      lastWakeAt: json['lastWakeAt'] != null
          ? DateTime.tryParse(json['lastWakeAt'] as String)
          : null,
    );
  }
}
