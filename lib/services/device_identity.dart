import '../core/id.dart';
import 'prefs_store.dart';

/// Стабильный идентификатор устройства. Генерится один раз и живёт в prefs.
/// Нужен для per-device push: агент хранит пороги/топик по deviceId, а телефон
/// подписывается на свой топик, чтобы получать только свои уведомления.
class DeviceIdentity {
  const DeviceIdentity(this.id);

  final String id;

  /// Топик ntfy/FCM этого устройства. Символы deviceId (base36 + дефис)
  /// допустимы в именах топиков FCM.
  String get topic => 'nexus-$id';

  static const _key = 'device.id';

  static DeviceIdentity ensure(PrefsStore store) {
    var id = store.getString(_key);
    if (id == null || id.isEmpty) {
      id = newId();
      store.setString(_key, id);
    }
    return DeviceIdentity(id);
  }
}
