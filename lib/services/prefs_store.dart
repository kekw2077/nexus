import 'package:shared_preferences/shared_preferences.dart';

/// Тонкая обёртка над SharedPreferences, чтобы контроллеры не зависели
/// от пакета напрямую и легко подменялись в тестах.
class PrefsStore {
  PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<PrefsStore> create() async {
    return PrefsStore(await SharedPreferences.getInstance());
  }

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  Future<void> remove(String key) => _prefs.remove(key);
}
