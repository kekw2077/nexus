import 'package:evs_remote/models/wol_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WolTarget JSON', () {
    test('round-trip сохраняет directSend', () {
      final t = WolTarget(
        id: 'a1',
        name: 'Сервер',
        mac: '00:1A:2B:3C:4D:5E',
        broadcast: 'home.duckdns.org',
        port: 40009,
        directSend: true,
      );
      final back = WolTarget.fromJson(t.toJson());
      expect(back.directSend, isTrue);
      expect(back.broadcast, 'home.duckdns.org');
      expect(back.port, 40009);
    });

    test('directSend по умолчанию false для старых записей без поля', () {
      final back = WolTarget.fromJson({
        'id': 'b2',
        'name': 'ПК',
        'mac': '00:1A:2B:3C:4D:5F',
        'broadcast': '192.168.1.255',
        'port': 9,
      });
      expect(back.directSend, isFalse);
    });

    test('copyWith меняет directSend', () {
      final t = WolTarget(id: 'c3', name: 'ПК', mac: 'AA:BB:CC:DD:EE:FF', broadcast: '192.168.1.255');
      expect(t.copyWith(directSend: true).directSend, isTrue);
    });
  });
}
