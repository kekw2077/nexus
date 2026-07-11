import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/id.dart';
import '../models/wol_target.dart';
import '../services/agent_client.dart';
import '../services/prefs_store.dart';
import '../services/wol_sender.dart';
import 'settings_controller.dart';

class WakeOutcome {
  const WakeOutcome.ok() : error = null;
  const WakeOutcome.failure(this.error);
  final String? error;
  bool get success => error == null;
}

class WolController extends ChangeNotifier {
  WolController(this._store, {AgentClient? agent}) : _agent = agent ?? AgentClient();

  final PrefsStore _store;
  final AgentClient _agent;
  static const _key = 'wol.targets';

  final List<WolTarget> _items = [];
  String? _wakingId;

  List<WolTarget> get items => List.unmodifiable(_items);
  String? get wakingId => _wakingId;

  void load() {
    final raw = _store.getString(_key);
    _items.clear();
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _items.addAll(list.map(WolTarget.fromJson));
      } catch (_) {
        _items.addAll(_seed());
      }
    } else {
      _items.addAll(_seed());
    }
    notifyListeners();
  }

  void _persist() {
    _store.setString(_key, jsonEncode(_items.map((t) => t.toJson()).toList()));
  }

  void add({required String name, required String mac, required String broadcast, required int port}) {
    _items.add(WolTarget(id: newId(), name: name, mac: mac, broadcast: broadcast, port: port));
    _persist();
    notifyListeners();
  }

  void update(String id, {required String name, required String mac, required String broadcast, required int port}) {
    final i = _items.indexWhere((t) => t.id == id);
    if (i == -1) return;
    _items[i] = _items[i].copyWith(name: name, mac: mac, broadcast: broadcast, port: port);
    _persist();
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((t) => t.id == id);
    _persist();
    notifyListeners();
  }

  /// Прямая отправка с телефона, либо через ретранслятор, если он настроен.
  Future<WakeOutcome> wake(WolTarget target, {RelayConfig? relay}) async {
    _wakingId = target.id;
    notifyListeners();

    WakeOutcome outcome;
    try {
      if (relay != null && relay.usable) {
        final error = await _agent.wake(
          relay.host,
          relay.port,
          relay.token,
          mac: target.mac,
          broadcast: target.broadcast,
          wolPort: target.port,
        );
        outcome = error == null ? const WakeOutcome.ok() : WakeOutcome.failure(error);
      } else {
        await WolSender.send(target.mac, broadcast: target.broadcast, port: target.port);
        outcome = const WakeOutcome.ok();
      }
    } catch (e) {
      outcome = const WakeOutcome.failure('Не удалось отправить пакет');
    }

    if (outcome.success) {
      final i = _items.indexWhere((t) => t.id == target.id);
      if (i != -1) {
        _items[i] = _items[i].copyWith(lastWakeAt: DateTime.now());
        _persist();
      }
    }

    _wakingId = null;
    notifyListeners();
    return outcome;
  }

  List<WolTarget> _seed() => [
        WolTarget(id: 'seed-office', name: 'Компьютер Офис', mac: '00:1A:2B:3C:4D:5E', broadcast: '192.168.1.255'),
        WolTarget(id: 'seed-living', name: 'Компьютер Гостиная', mac: '00:1A:2B:3C:4D:5F', broadcast: '192.168.1.255'),
      ];

  @override
  void dispose() {
    _agent.dispose();
    super.dispose();
  }
}
