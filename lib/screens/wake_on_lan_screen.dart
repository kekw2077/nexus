import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/wol_target.dart';
import '../state/settings_controller.dart';
import '../state/wol_controller.dart';
import '../widgets/computer_form_sheet.dart';

class WakeOnLanScreen extends StatelessWidget {
  const WakeOnLanScreen({super.key});

  Future<void> _openForm(BuildContext context, {WolTarget? existing}) async {
    final wol = context.read<WolController>();
    final result = await ComputerFormSheet.show(
      context,
      title: existing == null ? 'Добавить компьютер' : 'Изменить компьютер',
      hostLabel: 'Broadcast / внешний адрес',
      hostHint: '192.168.1.255 или host.duckdns.org',
      hostHelper: 'Дома — broadcast подсети. Из интернета — DDNS/публичный адрес '
          'и проброшенный на роутере порт (проброс на IP машины + статический ARP).',
      submitLabel: existing == null ? 'Добавить' : 'Сохранить',
      withMac: true,
      withDirectToggle: true,
      defaultPort: 9,
      initial: existing == null
          ? null
          : ComputerFormResult(
              name: existing.name,
              host: existing.broadcast,
              port: existing.port,
              mac: existing.mac,
              directSend: existing.directSend,
            ),
    );
    if (result == null) return;

    if (existing == null) {
      wol.add(
        name: result.name,
        mac: result.mac!,
        broadcast: result.host,
        port: result.port,
        directSend: result.directSend,
      );
      _toast(context, '${result.name} добавлен');
    } else {
      wol.update(
        existing.id,
        name: result.name,
        mac: result.mac!,
        broadcast: result.host,
        port: result.port,
        directSend: result.directSend,
      );
      _toast(context, '${result.name} сохранён');
    }
  }

  Future<void> _wake(BuildContext context, WolTarget target) async {
    final wol = context.read<WolController>();
    final relay = context.read<SettingsController>().relay;
    final outcome = await wol.wake(target, relay: relay);
    if (!context.mounted) return;
    _toast(
      context,
      outcome.success ? 'Пакет отправлен на ${target.name}' : (outcome.error ?? 'Ошибка'),
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final wol = context.watch<WolController>();
    final items = wol.items;

    return Scaffold(
      body: items.isEmpty
          ? _Empty(onAdd: () => _openForm(context))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final target = items[i];
                return _WolCard(
                  target: target,
                  waking: wol.wakingId == target.id,
                  onWake: () => _wake(context, target),
                  onEdit: () => _openForm(context, existing: target),
                  onDelete: () {
                    wol.remove(target.id);
                    _toast(context, '${target.name} удалён');
                  },
                );
              },
            ),
      floatingActionButton: items.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _openForm(context),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _WolCard extends StatelessWidget {
  const _WolCard({
    required this.target,
    required this.waking,
    required this.onWake,
    required this.onEdit,
    required this.onDelete,
  });

  final WolTarget target;
  final bool waking;
  final VoidCallback onWake;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<StatusColors>()!;
    final last = formatRelative(target.lastWakeAt);
    const mono = TextStyle(fontFamilyFallback: monoFontFallback, fontSize: 12);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(target.name, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.wifi, size: 13, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(target.mac, style: mono.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: waking ? null : onWake,
                  style: FilledButton.styleFrom(
                    backgroundColor: status.success,
                    foregroundColor: status.onSuccess,
                  ),
                  icon: waking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.power_settings_new, size: 18),
                  label: const Text('Включить'),
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
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Адрес: ${target.broadcast}:${target.port}',
                    style: mono.copyWith(color: scheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (target.directSend) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'WAN · напрямую',
                      style: TextStyle(fontSize: 11, color: scheme.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.schedule, size: 13, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  target.lastWakeAt == null ? 'ещё не включался' : 'включён $last',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.power_settings_new, size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Список пуст', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Добавьте компьютер с MAC-адресом, чтобы включать его по сети',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAdd, child: const Text('Добавить компьютер')),
          ],
        ),
      ),
    );
  }
}
