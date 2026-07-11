import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/id.dart';
import '../services/prefs_store.dart';

enum EvsStatus { disconnected, connecting, connected, error }

class EvsCommand {
  EvsCommand(this.text) : id = newId(), at = DateTime.now();
  final String id;
  final String text;
  final DateTime at;
}

/// Состояние связи с десктопным EVS. Пока сторона ПК не готова —
/// подключение имитируется. Реальная версия откроет WebSocket
/// (package:web_socket_channel) на ws://host:port/mobile.
class EvsController extends ChangeNotifier {
  EvsController(this._store);

  final PrefsStore _store;

  EvsStatus _status = EvsStatus.disconnected;
  String _host = '192.168.1.100';
  String _port = '8765';
  bool _autoStart = false;
  String? _error;
  final List<EvsCommand> _history = [];
  Timer? _timer;

  EvsStatus get status => _status;
  String get host => _host;
  String get port => _port;
  bool get autoStart => _autoStart;
  String? get error => _error;
  List<EvsCommand> get history => List.unmodifiable(_history);
  bool get isConnected => _status == EvsStatus.connected;

  void load() {
    _host = _store.getString('evs.host') ?? _host;
    _port = _store.getString('evs.port') ?? _port;
    _autoStart = _store.getBool('evs.autoStart') ?? false;
    notifyListeners();
    if (_autoStart) connect();
  }

  void setHost(String value) {
    _host = value;
    _store.setString('evs.host', value);
    notifyListeners();
  }

  void setPort(String value) {
    _port = value;
    _store.setString('evs.port', value);
    notifyListeners();
  }

  void setAutoStart(bool value) {
    _autoStart = value;
    _store.setBool('evs.autoStart', value);
    notifyListeners();
  }

  void connect() {
    _error = null;
    _status = EvsStatus.connecting;
    notifyListeners();

    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (_host.trim().isEmpty) {
        _status = EvsStatus.error;
        _error = 'Укажите адрес сервера EVS';
      } else {
        _status = EvsStatus.connected;
      }
      notifyListeners();
    });
  }

  void disconnect() {
    _timer?.cancel();
    _status = EvsStatus.disconnected;
    _error = null;
    notifyListeners();
  }

  void pushCommand(String text) {
    _history.insert(0, EvsCommand(text));
    if (_history.length > 10) _history.removeRange(10, _history.length);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
