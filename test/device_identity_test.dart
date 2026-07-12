import 'package:evs_remote/services/device_identity.dart';
import 'package:evs_remote/services/prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DeviceIdentity', () {
    test('генерит id один раз и переиспользует его', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await PrefsStore.create();

      final first = DeviceIdentity.ensure(store);
      final second = DeviceIdentity.ensure(store);

      expect(first.id, isNotEmpty);
      expect(second.id, first.id); // стабилен между вызовами
    });

    test('топик выводится из id', () async {
      SharedPreferences.setMockInitialValues({'device.id': 'abc-123'});
      final store = await PrefsStore.create();

      final device = DeviceIdentity.ensure(store);
      expect(device.id, 'abc-123');
      expect(device.topic, 'nexus-abc-123');
    });
  });
}
