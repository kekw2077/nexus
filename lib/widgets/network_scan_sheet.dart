import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../services/network_scanner.dart';

/// Нижняя панель поиска машин в локальной сети. Сканирует подсеть на отклик
/// агента и предлагает добавить найденный хост в мониторинг. Возвращает
/// выбранный [DiscoveredHost] через `Navigator.pop`, либо null при отмене.
class NetworkScanSheet extends StatefulWidget {
  const NetworkScanSheet({super.key, required this.defaultPort, required this.knownHosts});

  final int defaultPort;

  /// Уже добавленные адреса (host), чтобы пометить дубликаты.
  final Set<String> knownHosts;

  static Future<DiscoveredHost?> show(
    BuildContext context, {
    int defaultPort = 8765,
    Set<String> knownHosts = const {},
  }) {
    return showModalBottomSheet<DiscoveredHost>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NetworkScanSheet(defaultPort: defaultPort, knownHosts: knownHosts),
    );
  }

  @override
  State<NetworkScanSheet> createState() => _NetworkScanSheetState();
}

class _NetworkScanSheetState extends State<NetworkScanSheet> {
  late final TextEditingController _port;
  final List<DiscoveredHost> _found = [];
  NetworkScanner? _scanner;
  bool _scanning = false;
  bool _noNetwork = false;

  @override
  void initState() {
    super.initState();
    _port = TextEditingController(text: widget.defaultPort.toString());
    _runScan();
  }

  @override
  void dispose() {
    _port.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  Future<void> _runScan() async {
    final port = int.tryParse(_port.text.trim()) ?? widget.defaultPort;
    _scanner?.dispose();
    final scanner = NetworkScanner();
    _scanner = scanner;

    setState(() {
      _scanning = true;
      _noNetwork = false;
      _found.clear();
    });

    final locals = await scanner.localIPv4();
    if (!mounted) return;
    if (locals.isEmpty) {
      setState(() {
        _scanning = false;
        _noNetwork = true;
      });
      return;
    }

    await scanner.scan(
      port: port,
      onFound: (host) {
        if (!mounted) return;
        setState(() => _found.add(host));
      },
    );
    if (!mounted) return;
    setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Поиск в сети', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Ищем машины с запущенным агентом в вашей Wi-Fi-сети. '
                'Найденный адрес локальный — работает дома; для доступа снаружи '
                'замените его на Tailscale-имя после добавления.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _port,
                      decoration: const InputDecoration(labelText: 'Порт агента', isDense: true),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _scanning ? null : _runScan,
                      icon: _scanning
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.radar, size: 18),
                      label: Text(_scanning ? 'Сканирую…' : 'Сканировать заново'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(child: _results(scheme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _results(ColorScheme scheme) {
    if (_noNetwork) {
      return _hint(scheme, Icons.wifi_off, 'Нет доступа к локальной сети. '
          'Подключитесь к Wi-Fi и разрешите доступ к локальной сети.');
    }
    if (_found.isEmpty) {
      return _hint(
        scheme,
        _scanning ? Icons.radar : Icons.search_off,
        _scanning ? 'Опрашиваю адреса подсети…' : 'Ничего не найдено. Проверьте порт агента и что он запущен.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _found.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final host = _found[i];
        final known = widget.knownHosts.contains(host.ip);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.computer, color: scheme.primary),
          title: Text(host.label, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${host.ip}:${host.port}',
            style: const TextStyle(fontFamilyFallback: monoFontFallback, fontSize: 12),
          ),
          trailing: known
              ? Chip(
                  label: const Text('Добавлен'),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: scheme.outlineVariant),
                )
              : FilledButton(
                  onPressed: () => Navigator.of(context).pop(host),
                  child: const Text('Добавить'),
                ),
        );
      },
    );
  }

  Widget _hint(ColorScheme scheme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
