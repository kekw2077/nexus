import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/id.dart';
import '../services/prefs_store.dart';

enum EvsStatus { disconnected, connecting, connected, error }

class EvsCommand {
  EvsCommand(this.text) : id = newId(), at = DateTime.now();
  final String id;
  final String text;
  final DateTime at;
}

/// Состояние связи с десктопным EVS через WebSocket (ws://host:port/mobile).
/// Формат сообщений провизорный — {"type": "command"|"recognized", "text": ...} —
/// и финализируется вместе с функцией приёма на стороне десктопного EVS.
class EvsController extends ChangeNotifier {
  EvsController(this._store);

  final PrefsStore _store;

  EvsStatus _status = EvsStatus.disconnected;
  String _host = '192.168.1.100';
  String _port = '8765';
  bool _autoStart = false;
  String? _error;
  final List<EvsCommand> _history = [];
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  int _connectAttempt = 0;

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

  Future<void> connect() async {
    if (_host.trim().isEmpty) {
      _status = EvsStatus.error;
      _error = 'Укажите адрес сервера EVS';
      notifyListeners();
      return;
    }

    final port = int.tryParse(_port);
    if (port == null) {
      _status = EvsStatus.error;
      _error = 'Некорректный порт';
      notifyListeners();
      return;
    }

    await _teardown();

    _status = EvsStatus.connecting;
    _error = null;
    notifyListeners();

    final attempt = _connectAttempt;
    final uri = Uri.parse('ws://$_host:$port/mobile');

    try {
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      if (attempt != _connectAttempt) {
        unawaited(channel.sink.close());
        return;
      }
      _channel = channel;
      _status = EvsStatus.connected;
      notifyListeners();

      _sub = channel.stream.listen(
        _handleMessage,
        onError: (_) => _fail(attempt, 'Обрыв связи с EVS'),
        onDone: () => _fail(attempt, null),
      );
    } catch (_) {
      if (attempt != _connectAttempt) return;
      _status = EvsStatus.error;
      _error = 'Не удалось подключиться к EVS';
      notifyListeners();
    }
  }

  void _fail(int attempt, String? message) {
    if (attempt != _connectAttempt) return;
    _status = message == null ? EvsStatus.disconnected : EvsStatus.error;
    _error = message;
    notifyListeners();
  }

  void _handleMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final text = data['text'] as String?;
      if (data['type'] == 'recognized' && text != null) {
        _addHistory(text);
      }
    } catch (_) {
      // Не JSON или неизвестный формат — игнорируем, пока протокол не финализирован.
    }
  }

  Future<void> _teardown() async {
    _connectAttempt++;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void disconnect() {
    unawaited(_teardown());
    _status = EvsStatus.disconnected;
    _error = null;
    notifyListeners();
  }

  void pushCommand(String text) {
    _addHistory(text);
    _channel?.sink.add(jsonEncode({'type': 'command', 'text': text}));
  }

  void _addHistory(String text) {
    _history.insert(0, EvsCommand(text));
    if (_history.length > 10) _history.removeRange(10, _history.length);
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_teardown());
    super.dispose();
  }
}
