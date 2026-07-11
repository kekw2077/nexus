import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/evs_controller.dart';
import '../state/settings_controller.dart';
import '../widgets/editable_field.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: const [
        _AppearanceSection(),
        SizedBox(height: 16),
        _EvsSection(),
        SizedBox(height: 16),
        _RelaySection(),
        SizedBox(height: 16),
        _AboutSection(),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return _SectionCard(
      title: 'Оформление',
      children: [
        const Align(alignment: Alignment.centerLeft, child: Text('Цветовая схема')),
        const SizedBox(height: 8),
        SegmentedButton<AppBrand>(
          segments: [
            for (final b in AppBrand.values) ButtonSegment(value: b, label: Text(b.label)),
          ],
          selected: {settings.brand},
          onSelectionChanged: (s) => settings.setBrand(s.first),
        ),
        const SizedBox(height: 20),
        const Align(alignment: Alignment.centerLeft, child: Text('Тема')),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Авто')),
            ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Свет')),
            ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Тьма')),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (s) => settings.setThemeMode(s.first),
        ),
      ],
    );
  }
}

class _EvsSection extends StatelessWidget {
  const _EvsSection();

  @override
  Widget build(BuildContext context) {
    final evs = context.watch<EvsController>();
    final status = Theme.of(context).extension<StatusColors>()!;
    final scheme = Theme.of(context).colorScheme;

    final (Color color, String label) = switch (evs.status) {
      EvsStatus.connected => (status.success, 'Подключено'),
      EvsStatus.connecting => (status.warning, 'Подключение…'),
      EvsStatus.error => (scheme.error, 'Ошибка'),
      EvsStatus.disconnected => (scheme.outline, 'Отключено'),
    };

    return _SectionCard(
      title: 'Подключение к EVS',
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            if (evs.status == EvsStatus.connected)
              TextButton(onPressed: evs.disconnect, child: const Text('Отключить'))
            else
              FilledButton(
                onPressed: evs.status == EvsStatus.connecting ? null : evs.connect,
                child: const Text('Подключить'),
              ),
          ],
        ),
        if (evs.error != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(evs.error!, style: TextStyle(color: scheme.error, fontSize: 13)),
          ),
        ],
        const Divider(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: EditableField(
                key: const ValueKey('evs-host'),
                initialValue: evs.host,
                label: 'Адрес',
                mono: true,
                onChanged: evs.setHost,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 88,
              child: EditableField(
                key: const ValueKey('evs-port'),
                initialValue: evs.port,
                label: 'Порт',
                digitsOnly: true,
                onChanged: evs.setPort,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Подключаться при запуске'),
          value: evs.autoStart,
          onChanged: evs.setAutoStart,
        ),
      ],
    );
  }
}

class _RelaySection extends StatelessWidget {
  const _RelaySection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return _SectionCard(
      title: 'Ретранслятор Wake-on-LAN',
      children: [
        Text(
          'Всегда включённая машина в LAN, через которую телефон будит остальные '
          'из внешней сети. Обычно это ваш сервер.',
          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Использовать ретранслятор'),
          value: settings.relayEnabled,
          onChanged: (v) => settings.setRelay(enabled: v),
        ),
        if (settings.relayEnabled) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('HTTPS (публичный адрес)'),
            value: settings.relaySecure,
            onChanged: (v) => settings.setRelay(secure: v),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: EditableField(
                  key: const ValueKey('relay-host'),
                  initialValue: settings.relayHost,
                  label: 'Адрес сервера',
                  mono: true,
                  onChanged: (v) => settings.setRelay(host: v),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 88,
                child: EditableField(
                  key: const ValueKey('relay-port'),
                  initialValue: settings.relayPort.toString(),
                  label: 'Порт',
                  digitsOnly: true,
                  onChanged: (v) => settings.setRelay(port: int.tryParse(v) ?? 8765),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          EditableField(
            key: const ValueKey('relay-token'),
            initialValue: settings.relayToken,
            label: 'Токен агента',
            mono: true,
            obscure: true,
            onChanged: (v) => settings.setRelay(token: v),
          ),
        ],
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k, style: TextStyle(color: scheme.onSurfaceVariant)),
              Text(v),
            ],
          ),
        );
    return _SectionCard(
      title: 'О приложении',
      children: [
        row('Версия', '0.1.0'),
        row('Платформы', 'Android 7.0+, iOS'),
      ],
    );
  }
}
