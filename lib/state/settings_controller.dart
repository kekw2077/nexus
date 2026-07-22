import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/prefs_store.dart';

/// Параметры ретранслятора WoL: всегда включённая машина в LAN,
/// через которую телефон будит остальные из внешней сети.
class RelayConfig {
  const RelayConfig({
    required this.enabled,
    required this.host,
    required this.port,
    required this.token,
    required this.secure,
  });

  final bool enabled;
  final String host;
  final int port;
  final String token;
  final bool secure;

  bool get usable => enabled && host.trim().isNotEmpty && token.isNotEmpty;
}

class SettingsController extends ChangeNotifier {
  SettingsController(this._store);

  final PrefsStore _store;

  AppBrand _brand = AppBrand.nexus;
  ThemeMode _themeMode = ThemeMode.dark;

  bool _relayEnabled = false;
  String _relayHost = '';
  int _relayPort = 8765;
  String _relayToken = '';
  bool _relaySecure = false;

  AppBrand get brand => _brand;
  ThemeMode get themeMode => _themeMode;

  bool get relayEnabled => _relayEnabled;
  String get relayHost => _relayHost;
  int get relayPort => _relayPort;
  String get relayToken => _relayToken;
  bool get relaySecure => _relaySecure;

  RelayConfig get relay => RelayConfig(
        enabled: _relayEnabled,
        host: _relayHost,
        port: _relayPort,
        token: _relayToken,
        secure: _relaySecure,
      );

  void load() {
    final brandName = _store.getString('settings.brand');
    _brand = AppBrand.values.firstWhere(
      (b) => b.name == brandName,
      orElse: () => AppBrand.nexus,
    );

    final modeName = _store.getString('settings.themeMode');
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => ThemeMode.dark,
    );

    _relayEnabled = _store.getBool('settings.relayEnabled') ?? false;
    _relayHost = _store.getString('settings.relayHost') ?? '';
    _relayPort = int.tryParse(_store.getString('settings.relayPort') ?? '') ?? 8765;
    _relayToken = _store.getString('settings.relayToken') ?? '';
    _relaySecure = _store.getBool('settings.relaySecure') ?? false;

    notifyListeners();
  }

  void setBrand(AppBrand brand) {
    _brand = brand;
    _store.setString('settings.brand', brand.name);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _store.setString('settings.themeMode', mode.name);
    notifyListeners();
  }

  void setRelay({bool? enabled, String? host, int? port, String? token, bool? secure}) {
    if (enabled != null) {
      _relayEnabled = enabled;
      _store.setBool('settings.relayEnabled', enabled);
    }
    if (host != null) {
      _relayHost = host;
      _store.setString('settings.relayHost', host);
    }
    if (port != null) {
      _relayPort = port;
      _store.setString('settings.relayPort', port.toString());
    }
    if (token != null) {
      _relayToken = token;
      _store.setString('settings.relayToken', token);
    }
    if (secure != null) {
      _relaySecure = secure;
      _store.setBool('settings.relaySecure', secure);
    }
    notifyListeners();
  }
}
