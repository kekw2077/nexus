import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/alert_item.dart';
import '../models/host_metrics.dart';
import '../models/monitored_host.dart';
import '../models/nextcloud_status.dart';
import '../services/network_scanner.dart';
import '../state/monitor_controller.dart';
import '../state/settings_controller.dart';
import '../widgets/computer_form_sheet.dart';
import '../widgets/network_scan_sheet.dart';

class ComputerStatusScreen extends StatelessWidget {
  const ComputerStatusScreen({super.key});

  Future<void> _openForm(
    BuildContext context, {
    MonitoredHost? existing,
    ComputerFormResult? prefill,
  }) async {
    final monitor = context.read<MonitorController>();
    final result = await ComputerFormSheet.show(
      context,
      title: existing == null ? 'Добавить компьютер' : 'Изменить компьютер',
      hostLabel: 'Адрес хоста',
      hostHint: 'server.ваш-tailnet.ts.net',
      submitLabel: existing == null ? 'Добавить' : 'Сохранить',
      withToken: true,
      withMac: true,
      withBroadcast: true,
      macOptional: true,
      defaultPort: 8765,
      initial: existing == null
          ? prefill
          : ComputerFormResult(
              name: existing.name,
              host: existing.host,
              port: existing.port,
              token: existing.token,
              mac: existing.mac,
              broadcast: existing.broadcast,
              cpuThreshold: existing.alertCpu,
              ramThreshold: existing.alertRam,
              diskThreshold: existing.alertDisk,
              tempThreshold: existing.alertTemp,
              ntfyTopic: existing.ntfyTopic,
            ),
    );
    if (result == null) return;

    // Broadcast нужен только вместе с MAC (для включения). Пусто → глобальный.
    final broadcast = result.mac != null ? (result.broadcast ?? '255.255.255.255') : null;
    String hostId;
    if (existing == null) {
      monitor.add(
        name: result.name,
        host: result.host,
        port: result.port,
        token: result.token ?? '',
        mac: result.mac,
        broadcast: broadcast,
      );
      hostId = monitor.hosts.last.id;
      _toast(context, '${result.name} добавлен в мониторинг');
    } else {
      monitor.update(
        existing.id,
        name: result.name,
        host: result.host,
        port: result.port,
        token: result.token ?? '',
        mac: result.mac,
        broadcast: broadcast,
      );
      hostId = existing.id;
      _toast(context, '${result.name} сохранён');
    }

    if (result.cpuThreshold != null ||
        result.ramThreshold != null ||
        result.diskThreshold != null ||
        result.tempThreshold != null ||
        result.ntfyTopic != null) {
      final error = await monitor.setAlertConfig(
        hostId,
        cpu: result.cpuThreshold,
        ram: result.ramThreshold,
        disk: result.diskThreshold,
        temperature: result.tempThreshold,
        ntfyTopic: result.ntfyTopic,
      );
      if (error != null && context.mounted) {
        _toast(context, 'Пороги не синхронизированы: $error');
      }
    }
  }

  Future<void> _discover(BuildContext context) async {
    final monitor = context.read<MonitorController>();
    final known = {for (final h in monitor.hosts) h.host};
    final picked = await NetworkScanSheet.show(context, defaultPort: 8765, knownHosts: known);
    if (picked == null || !context.mounted) return;
    await _openForm(
      context,
      prefill: ComputerFormResult(name: picked.label, host: picked.ip, port: picked.port),
    );
  }

  Future<void> _wake(BuildContext context, MonitoredHost host) async {
    final monitor = context.read<MonitorController>();
    final relay = context.read<SettingsController>().relay;
    final error = await monitor.wakeAndWatch(host, relay: relay);
    if (!context.mounted) return;
    _toast(context, error ?? 'Включаем ${host.name}…');
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<MonitorController>();
    final hosts = monitor.hosts;

    return Scaffold(
      body: hosts.isEmpty
          ? _Empty(onAdd: () => _openForm(context), onDiscover: () => _discover(context))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => _discover(context),
                        icon: const Icon(Icons.wifi_find),
                        tooltip: 'Найти в сети',
                      ),
                      IconButton(
                        onPressed: monitor.isRefreshing ? null : monitor.refresh,
                        icon: monitor.isRefreshing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh),
                        tooltip: 'Обновить',
                      ),
                    ],
                  ),
                ),
                for (final host in hosts) ...[
                  _StatusCard(
                    host: host,
                    metrics: monitor.metricsFor(host.id),
                    alerts: monitor.alertsFor(host.id),
                    nextcloud: monitor.nextcloudFor(host.id),
                    onWake: host.canWake ? () => _wake(context, host) : null,
                    onEdit: () => _openForm(context, existing: host),
                    onDelete: () {
                      monitor.remove(host.id);
                      _toast(context, '${host.name} удалён');
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _SummaryCard(total: hosts.length, online: monitor.onlineCount),
              ],
            ),
      floatingActionButton: hosts.isEmpty
          ? null
          : FloatingActionButton(onPressed: () => _openForm(context), child: const Icon(Icons.add)),
    );
  }
}


class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.host,
    required this.metrics,
    required this.alerts,
    required this.nextcloud,
    required this.onWake,
    required this.onEdit,
    required this.onDelete,
  });

  final MonitoredHost host;
  final HostMetrics metrics;
  final List<AlertItem> alerts;
  final NextcloudStatus nextcloud;
  final VoidCallback? onWake;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final online = metrics.state == HostState.online;
    const mono = TextStyle(fontFamilyFallback: monoFontFallback, fontSize: 12);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor, size: 20, color: scheme.onSurface),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(host.name, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                      Text('${host.host}:${host.port}', style: mono.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                _StateBadge(state: metrics.state),
                if (onWake != null)
                  IconButton(
                    onPressed: metrics.state == HostState.booting ? null : onWake,
                    icon: const Icon(Icons.power_settings_new),
                    tooltip: 'Включить',
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Изменить'), contentPadding: EdgeInsets.zero)),
                    PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Удалить'), contentPadding: EdgeInsets.zero)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (online) ...[
              if (alerts.isNotEmpty) ...[
                _AlertsBanner(alerts: alerts),
                const SizedBox(height: 12),
              ],
              _Metrics(metrics: metrics),
              if (nextcloud.configured) ...[
                const Divider(height: 28),
                _NextcloudCard(nc: nextcloud),
              ],
            ] else
              _Placeholder(state: metrics.state),
          ],
        ),
      ),
    );
  }
}

class _AlertsBanner extends StatelessWidget {
  const _AlertsBanner({required this.alerts});
  final List<AlertItem> alerts;

  @override
  Widget build(BuildContext context) {
    final status = Theme.of(context).extension<StatusColors>()!;
    final scheme = Theme.of(context).colorScheme;
    final color = alerts.any((a) => a.level == AlertLevel.critical) ? scheme.error : status.warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final alert in alerts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 15, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(alert.message, style: TextStyle(fontSize: 13, color: color))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.metrics});
  final HostMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timelapse, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('Работает ${formatUptime(metrics.uptimeSec)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 12),
        _MetricBar(icon: Icons.memory, label: 'Процессор', value: metrics.cpu),
        const SizedBox(height: 10),
        _MetricBar(icon: Icons.dashboard, label: 'Память', value: metrics.ram),
        const SizedBox(height: 10),
        _MetricBar(icon: Icons.sd_storage, label: 'Диск', value: metrics.disk),
        if (metrics.hasTemperature) ...[
          const Divider(height: 24),
          Row(
            children: [
              Icon(Icons.device_thermostat, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              const Text('Температура'),
              const Spacer(),
              Text(
                '${metrics.temperature.toStringAsFixed(0)}°C',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: metrics.temperature >= 70
                      ? Theme.of(context).extension<StatusColors>()!.warning
                      : scheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _NextcloudCard extends StatelessWidget {
  const _NextcloudCard({required this.nc});
  final NextcloudStatus nc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<StatusColors>()!;

    final (Color badgeColor, String badgeLabel) = !nc.reachable
        ? (scheme.error, 'Недоступен')
        : nc.maintenance
            ? (status.warning, 'Обслуживание')
            : (status.success, 'Онлайн');

    Widget stat(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(icon, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              const Spacer(),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cloud, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                nc.version != null ? '${nc.productName ?? 'Nextcloud'} · ${nc.version}' : (nc.productName ?? 'Nextcloud'),
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(badgeLabel, style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        if (nc.reachable && nc.hasServerinfo) ...[
          const SizedBox(height: 8),
          if (nc.activeUsers24h != null)
            stat(Icons.person, 'Активны (5м / 1ч / 24ч)',
                '${nc.activeUsers5min ?? 0} / ${nc.activeUsers1h ?? 0} / ${nc.activeUsers24h ?? 0}'),
          if (nc.numUsers != null) stat(Icons.group, 'Пользователи', '${nc.numUsers}'),
          if (nc.numFiles != null) stat(Icons.description, 'Файлы', '${nc.numFiles}'),
          if (nc.numShares != null) stat(Icons.share, 'Общие ресурсы', '${nc.numShares}'),
          if (nc.freeSpaceBytes != null)
            stat(Icons.sd_storage, 'Свободно', formatBytes(nc.freeSpaceBytes!)),
          if (nc.updateAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Доступно обновлений приложений: ${nc.appUpdates}',
                  style: TextStyle(fontSize: 13, color: status.warning)),
            ),
        ] else if (nc.reachable) ...[
          const SizedBox(height: 6),
          Text('Подробная статистика недоступна (не задан токен serverinfo).',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warning = Theme.of(context).extension<StatusColors>()!.warning;
    final hot = value >= 80;
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            const Spacer(),
            Text('$value%',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: hot ? warning : scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(hot ? warning : scheme.primary),
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.state});
  final HostState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = switch (state) {
      HostState.booting => 'Включается, ждём ответа…',
      HostState.unknown => 'Опрашиваем агент…',
      _ => 'Агент не отвечает',
    };
    return Row(
      children: [
        if (state == HostState.booting) ...[
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
        ],
        Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});
  final HostState state;

  @override
  Widget build(BuildContext context) {
    final status = Theme.of(context).extension<StatusColors>()!;
    final scheme = Theme.of(context).colorScheme;

    final (Color bg, Color fg, IconData icon, String label) = switch (state) {
      HostState.online => (status.success, status.onSuccess, Icons.wifi, 'Онлайн'),
      HostState.booting => (status.warning, Colors.white, Icons.hourglass_top, 'Загрузка'),
      HostState.offline => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, Icons.wifi_off, 'Оффлайн'),
      HostState.unknown => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, Icons.help_outline, 'Проверка'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total, required this.online});
  final int total;
  final int online;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final success = Theme.of(context).extension<StatusColors>()!.success;

    Widget cell(String label, String value, Color color) => Expanded(
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
        );

    return Card(
      color: scheme.primary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            cell('Всего', '$total', scheme.onSurface),
            cell('Онлайн', '$online', success),
            cell('Оффлайн', '${total - online}', scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd, required this.onDiscover});
  final VoidCallback onAdd;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monitor, size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Нечего отслеживать', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Укажите адрес компьютера с запущенным агентом, чтобы видеть его нагрузку',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAdd, child: const Text('Добавить компьютер')),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onDiscover,
              icon: const Icon(Icons.wifi_find, size: 18),
              label: const Text('Найти в сети'),
            ),
          ],
        ),
      ),
    );
  }
}
