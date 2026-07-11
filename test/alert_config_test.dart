import 'package:evs_remote/models/alert_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlertConfig', () {
    test('toJson опускает пустые поля', () {
      const config = AlertConfig(cpu: 95);
      expect(config.toJson(), {'cpu': 95});
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'cpu': 95,
        'ram': 90,
        'disk': 85,
        'temperature': 82.5,
        'ntfyTopic': 'nexus-server',
      };
      final config = AlertConfig.fromJson(json);
      expect(config.cpu, 95);
      expect(config.ram, 90);
      expect(config.disk, 85);
      expect(config.temperature, 82.5);
      expect(config.ntfyTopic, 'nexus-server');
      expect(config.toJson(), json);
    });

    test('fromJson с пустым телом даёт все null', () {
      final config = AlertConfig.fromJson(const {});
      expect(config.cpu, isNull);
      expect(config.ram, isNull);
      expect(config.disk, isNull);
      expect(config.temperature, isNull);
      expect(config.ntfyTopic, isNull);
      expect(config.toJson(), <String, dynamic>{});
    });
  });
}
