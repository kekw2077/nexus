import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/id.dart';
import '../models/host_metrics.dart';
import '../models/monitored_host.dart';
import '../services/agent_client.dart';
import '../services/prefs_store.dart';
import '../services/wol_sender.dart';
import 'settings_controller.dart';

class MonitorController extends ChangeNotifier {
  MonitorController(this._store, {AgentClient? agent}) : _agent = agent ?? AgentClient();

  final PrefsStore _store;
  final AgentClient _agent;
  static const _key = 'monitor.hosts';

  final List<MonitoredHost> _hosts = [];
  final Map<String, HostMetrics> _metrics = {};
  final Set<String> _booting = {};
  Timer? _poll;
  bool _refreshing = false;

  List<MonitoredHost> get hosts => List.unmodifiable(_hosts);
  bool get isRefreshing => _refreshing;

  HostMetrics metricsFor(String id) {
    if (_booting.contains(id)) return const HostMetrics.booting();
    return _metrics[id] ?? const HostMetrics.unknown();
  }

  int get onlineCount => _hosts.where((h) => _metrics[h.id]?.isOnline ?? false).length;

  void load() {
    final raw = _store.getString(_key);
    _hosts.clear();
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _hosts.addAll(list.map(MonitoredHost.fromJson));
      } catch (_) {
        _hosts.addAll(_seed());
      }
    } else {
      _hosts.addAll(_seed());
    }
    notifyListeners();
    _startPolling();
  }

  void _persist() {
    _store.setString(_key, jsonEncode(_hosts.map((h) => h.toJson()).toList()));
  }

  void _startPolling() {
    _poll?.cancel();
    _pollOnce();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    for (final host in List<MonitoredHost>.from(_hosts)) {
      if (_booting.contains(host.id)) continue; // загрузку отслеживает отдельный watcher
      final result = await _agent.metrics(host.host, host.port, host.token);
      _metrics[host.id] = result;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    _refreshing = true;
    notifyListeners();
    await _pollOnce();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _refreshing = false;
    notifyListeners();
  }

  void add({
    required String name,
    required String host,
    required int port,
    required String token,
    String? mac,
    String? broadcast,
  }) {
    _hosts.add(MonitoredHost(
      id: newId(),
      name: name,
      host: host,
      port: port,
      token: token,
      mac: mac,
      broadcast: broadcast,
    ));
    _persist();
    notifyListeners();
    _pollOnce();
  }

  void update(
    String id, {
    required String name,
    required String host,
    required int port,
    required String token,
    String? mac,
    String? broadcast,
  }) {
    final i = _hosts.indexWhere((h) => h.id == id);
    if (i == -1) return;
    _hosts[i] = _hosts[i].copyWith(
      name: name,
      host: host,
      port: port,
      token: token,
      mac: mac,
      broadcast: broadcast,
    );
    _persist();
    notifyListeners();
    _pollOnce();
  }

  void remove(String id) {
    _hosts.removeWhere((h) => h.id == id);
    _metrics.remove(id);
    _booting.remove(id);
    _persist();
    notifyListeners();
  }

  /// Будит машину и следит за загрузкой: раз в 2 секунды пингует /health,
  /// пока не ответит или пока не выйдет минута. Так пользователь видит
  /// реальный факт включения, а не только «пакет отправлен».
  Future<String?> wakeAndWatch(MonitoredHost host, {RelayConfig? relay}) async {
    if (!host.canWake) return 'Для этой машины не задан MAC-адрес';
    final broadcast = host.broadcast ?? '255.255.255.255';

    String? error;
    if (relay != null && relay.usable) {
      error = await _agent.wake(relay.host, relay.port, relay.token, mac: host.mac!, broadcast: broadcast);
    } else {
      try {
        await WolSender.send(host.mac!, broadcast: broadcast);
      } catch (_) {
        error = 'Не удалось отправить пакет';
      }
    }
    if (error != null) return error;

    _booting.add(host.id);
    notifyListeners();
    _watchBoot(host);
    return null;
  }

  void _watchBoot(MonitoredHost host) {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_hosts.any((h) => h.id == host.id)) {
        timer.cancel();
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        timer.cancel();
        _booting.remove(host.id);
        _metrics[host.id] = const HostMetrics.offline();
        notifyListeners();
        return;
      }
      final alive = await _agent.health(host.host, host.port);
      if (alive) {
        timer.cancel();
        _booting.remove(host.id);
        _metrics[host.id] = await _agent.metrics(host.host, host.port, host.token);
        notifyListeners();
      }
    });
  }

  List<MonitoredHost> _seed() => [
        MonitoredHost(id: 'seed-server', name: 'Сервер', host: '192.168.1.10', port: 8765, token: ''),
      ];

  @override
  void dispose() {
    _poll?.cancel();
    _agent.dispose();
    super.dispose();
  }
}
