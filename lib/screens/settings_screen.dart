import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/update_service.dart';
import '../state/evs_controller.dart';
import '../state/settings_controller.dart';
import '../widgets/editable_field.dart';
import '../widgets/gradient.dart';

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
        _UpdateSection(),
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
              GradientButton(
                onPressed: evs.status == EvsStatus.connecting ? null : evs.connect,
                label: const Text('Подключить'),
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
        GradientSwitchTile(
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
        GradientSwitchTile(
          title: const Text('Использовать ретранслятор'),
          value: settings.relayEnabled,
          onChanged: (v) => settings.setRelay(enabled: v),
        ),
        if (settings.relayEnabled) ...[
          GradientSwitchTile(
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
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (_, snap) => row('Версия', snap.hasData ? snap.data!.version : '…'),
        ),
        row('Платформы', 'Android 7.0+, iOS'),
      ],
    );
  }
}

/// Проверка и установка обновлений из GitHub Releases. Скачивание+установка —
/// только Android (iOS обновляется через AltStore, там показываем ссылку).
class _UpdateSection extends StatefulWidget {
  const _UpdateSection();

  @override
  State<_UpdateSection> createState() => _UpdateSectionState();
}

enum _UpdateState { idle, checking, upToDate, available, downloading, error }

class _UpdateSectionState extends State<_UpdateSection> {
  final _service = UpdateService();
  _UpdateState _state = _UpdateState.idle;
  String _current = '…';
  UpdateInfo? _update;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service.currentVersion().then((v) {
      if (mounted) setState(() => _current = v);
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _state = _UpdateState.checking;
      _error = null;
      _update = null;
    });
    try {
      final info = await _service.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _update = info;
        _state = info == null ? _UpdateState.upToDate : _UpdateState.available;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _UpdateState.error;
        _error = 'Не удалось проверить: $e';
      });
    }
  }

  Future<void> _downloadAndInstall() async {
    final info = _update;
    if (info?.apkUrl == null) return;
    setState(() {
      _state = _UpdateState.downloading;
      _progress = 0;
    });
    try {
      final path = await _service.downloadApk(
        info!.apkUrl!,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _state = _UpdateState.available);
      // Открываем APK — система показывает установщик (нужно разрешение
      // «Установка неизвестных приложений» для Nexus).
      final result = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done && mounted) {
        setState(() {
          _state = _UpdateState.error;
          _error = 'Не удалось открыть установщик: ${result.message}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _UpdateState.error;
        _error = 'Ошибка загрузки: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[
      Row(
        children: [
          Text('Текущая версия', style: TextStyle(color: scheme.onSurfaceVariant)),
          const Spacer(),
          Text(_current, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
      const SizedBox(height: 12),
    ];

    switch (_state) {
      case _UpdateState.idle:
        children.add(_checkButton('Проверить обновления'));
      case _UpdateState.checking:
        children.add(const Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Проверяю…'),
          ],
        ));
      case _UpdateState.upToDate:
        children
          ..add(Row(children: [
            Icon(Icons.check_circle, color: Theme.of(context).extension<StatusColors>()!.success, size: 20),
            const SizedBox(width: 8),
            const Text('У вас последняя версия'),
          ]))
          ..add(const SizedBox(height: 12))
          ..add(_checkButton('Проверить ещё раз'));
      case _UpdateState.available:
        children.addAll(_availableBody(scheme));
      case _UpdateState.downloading:
        children.addAll([
          Text('Скачиваю ${(_progress * 100).round()}%'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: _progress > 0 ? _progress : null, minHeight: 6),
          ),
        ]);
      case _UpdateState.error:
        children
          ..add(Text(_error ?? 'Ошибка', style: TextStyle(color: scheme.error, fontSize: 13)))
          ..add(const SizedBox(height: 12))
          ..add(_checkButton('Повторить'));
    }

    return _SectionCard(title: 'Обновления', children: children);
  }

  Widget _checkButton(String label) => Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: _check,
          icon: const Icon(Icons.system_update, size: 18),
          label: Text(label),
        ),
      );

  List<Widget> _availableBody(ColorScheme scheme) {
    final info = _update!;
    final sizeMb = info.apkSize > 0 ? ' · ${(info.apkSize / 1024 / 1024).toStringAsFixed(1)} МБ' : '';
    return [
      Row(
        children: [
          Icon(Icons.new_releases, color: scheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Доступна версия ${info.version}$sizeMb',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      if (info.notes.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SingleChildScrollView(
            child: Text(info.notes, style: const TextStyle(fontSize: 12.5)),
          ),
        ),
      ],
      const SizedBox(height: 12),
      if (Platform.isAndroid && info.hasApk)
        Align(
          alignment: Alignment.centerLeft,
          child: GradientButton(
            onPressed: _downloadAndInstall,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Скачать и установить'),
          ),
        )
      else
        Text(
          Platform.isIOS
              ? 'Обновление на iOS ставится через AltStore. Откройте страницу релиза:\n${info.pageUrl}'
              : 'APK для этой версии не найден. Страница релиза:\n${info.pageUrl}',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
    ];
  }
}
