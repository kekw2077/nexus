import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/nextcloud_status.dart';
import '../state/monitor_controller.dart';

/// Отдельная вкладка с дашбордом Nextcloud. Показывает облако тех хостов, чей
/// агент сообщил `configured==true` (обычно это сервер). Данные обновляются тем
/// же 4-сек опросом MonitorController; само состояние NC агент кэширует и
/// обновляет раз в PC_AGENT_NC_INTERVAL (по умолчанию 60 сек).
class CloudStatusScreen extends StatelessWidget {
  const CloudStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<MonitorController>();
    final clouds = [
      for (final host in monitor.hosts)
        if (monitor.nextcloudFor(host.id).configured) (host.name, monitor.nextcloudFor(host.id)),
    ];

    if (clouds.isEmpty) return const _Empty();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: monitor.isRefreshing ? null : monitor.refresh,
            icon: monitor.isRefreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ),
        for (final (name, nc) in clouds) ...[
          _CloudCard(hostName: name, nc: nc),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CloudCard extends StatelessWidget {
  const _CloudCard({required this.hostName, required this.nc});
  final String hostName;
  final NextcloudStatus nc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<StatusColors>()!;

    final (Color badgeColor, String badgeLabel) = !nc.reachable
        ? (scheme.error, 'Недоступно')
        : nc.maintenance
            ? (status.warning, 'Обслуживание')
            : (status.success, 'Онлайн');

    final issues = _issues();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud, size: 22, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nc.version != null ? '${nc.productName ?? 'Nextcloud'} · ${nc.version}' : (nc.productName ?? 'Nextcloud'),
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(hostName, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(badgeLabel, style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            if (issues.isNotEmpty) ...[
              const SizedBox(height: 12),
              _IssuesBox(issues: issues),
            ],
            if (nc.reachable && nc.hasServerinfo) ...[
              const Divider(height: 28),
              _UsageGrid(nc: nc),
              if (nc.phpVersion != null || nc.database != null || nc.webserver != null) ...[
                const Divider(height: 28),
                _TechInfo(nc: nc),
              ],
            ] else if (nc.reachable) ...[
              const SizedBox(height: 10),
              Text('Подробная статистика недоступна (не задан токен serverinfo на агенте).',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
            if (nc.warnings.isNotEmpty) ...[
              const Divider(height: 28),
              _WarningsList(warnings: nc.warnings),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _issues() {
    final out = <String>[];
    if (!nc.reachable) return out; // статус уже в бейдже
    if (nc.maintenance) out.add('Включён режим обслуживания');
    if (nc.needsDbUpgrade) out.add('Требуется апгрейд базы данных');
    if (nc.coreUpdateAvailable) {
      out.add('Доступно обновление Nextcloud${nc.coreUpdateVersion != null ? ' ${nc.coreUpdateVersion}' : ''}');
    }
    if (nc.updateAvailable) out.add('Доступно обновлений приложений: ${nc.appUpdates}');
    if ((nc.warningsCount ?? 0) > 0) out.add('Предупреждений настройки/безопасности: ${nc.warningsCount}');
    return out;
  }
}

class _IssuesBox extends StatelessWidget {
  const _IssuesBox({required this.issues});
  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).extension<StatusColors>()!.warning;
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
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 15, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(issue, style: TextStyle(fontSize: 13, color: color))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UsageGrid extends StatelessWidget {
  const _UsageGrid({required this.nc});
  final NextcloudStatus nc;

  @override
  Widget build(BuildContext context) {
    final tiles = <(IconData, String, String)>[
      if (nc.numUsers != null) (Icons.group, 'Пользователи', '${nc.numUsers}'),
      if (nc.activeUsers24h != null)
        (Icons.person, 'Активны 5м/1ч/24ч', '${nc.activeUsers5min ?? 0}/${nc.activeUsers1h ?? 0}/${nc.activeUsers24h ?? 0}'),
      if (nc.numFiles != null) (Icons.description, 'Файлы', '${nc.numFiles}'),
      if (nc.numShares != null) (Icons.share, 'Общие ресурсы', '${nc.numShares}'),
      if (nc.freeSpaceBytes != null) (Icons.sd_storage, 'Свободно', formatBytes(nc.freeSpaceBytes!)),
    ];

    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: _StatTile(icon: tiles[i].$1, label: tiles[i].$2, value: tiles[i].$3)),
                const SizedBox(width: 8),
                if (i + 1 < tiles.length)
                  Expanded(child: _StatTile(icon: tiles[i + 1].$1, label: tiles[i + 1].$2, value: tiles[i + 1].$3))
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TechInfo extends StatelessWidget {
  const _TechInfo({required this.nc});
  final NextcloudStatus nc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('СЕРВЕР', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.4, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        if (nc.phpVersion != null) row('PHP', nc.phpVersion!),
        if (nc.database != null)
          row('База данных', nc.dbSizeBytes != null ? '${nc.database} · ${formatBytes(nc.dbSizeBytes!)}' : nc.database!),
        if (nc.webserver != null) row('Веб-сервер', nc.webserver!),
      ],
    );
  }
}

class _WarningsList extends StatelessWidget {
  const _WarningsList({required this.warnings});
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ПРЕДУПРЕЖДЕНИЯ НАСТРОЙКИ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.4, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (final w in warnings)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text(w, style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Nextcloud не настроен', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Задайте на агенте PC_AGENT_NC_URL (адрес облака), чтобы видеть здесь '
              'его состояние. Токен serverinfo и occ включают подробную статистику '
              'и проверки обновлений/безопасности — см. SERVER_DEPLOY.md.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
