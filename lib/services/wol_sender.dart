import 'dart:io';
import 'dart:typed_data';

/// Прямая отправка magic-пакета с телефона. Работает, когда телефон
/// в той же сети, что и цель (например, дома по Wi-Fi).
///
/// Из внешней сети через Tailscale широковещание не проходит — тогда
/// пакет отправляет агент на сервере (см. AgentClient.wake).
class WolSender {
  static Future<void> send(
    String mac, {
    String broadcast = '255.255.255.255',
    int port = 9,
  }) async {
    final clean = mac.replaceAll(RegExp('[:-]'), '');
    if (clean.length != 12) {
      throw ArgumentError('Некорректный MAC-адрес: $mac');
    }

    final macBytes = <int>[
      for (var i = 0; i < 12; i += 2) int.parse(clean.substring(i, i + 2), radix: 16),
    ];

    // 6 байт 0xFF + MAC, повторённый 16 раз = 102 байта
    final packet = Uint8List.fromList([
      ...List.filled(6, 0xFF),
      for (var i = 0; i < 16; i++) ...macBytes,
    ]);

    // Литеральный IP (broadcast подсети или публичный) — используем как есть.
    // Не-IP (DDNS-имя для WoL из интернета) — резолвим в адрес.
    final target = InternetAddress.tryParse(broadcast) ??
        (await InternetAddress.lookup(broadcast)).firstWhere(
          (a) => a.type == InternetAddressType.IPv4,
          orElse: () => throw ArgumentError('Не удалось разрешить адрес: $broadcast'),
        );

    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.broadcastEnabled = true;
      socket.send(packet, target, port);
    } finally {
      socket.close();
    }
  }
}
