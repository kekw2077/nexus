import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../state/evs_controller.dart';
import '../widgets/waveform.dart';

class VoiceControlScreen extends StatefulWidget {
  const VoiceControlScreen({super.key});

  @override
  State<VoiceControlScreen> createState() => _VoiceControlScreenState();
}

class _VoiceControlScreenState extends State<VoiceControlScreen> {
  bool _listening = false;
  bool _enabled = true;
  double _sensitivity = 70;
  double _volume = 80;

  void _toggle(EvsController evs) {
    if (!_enabled || !evs.isConnected) return;
    if (_listening) {
      // TODO: остановить запись, отправить буфер в EVS, получить распознанный текст
      evs.pushCommand('Показать статус систем');
    }
    setState(() => _listening = !_listening);
  }

  @override
  Widget build(BuildContext context) {
    final evs = context.watch<EvsController>();
    final connected = evs.isConnected;
    final canListen = _enabled && connected;

    // Обрыв связи не оставляет экран в состоянии «Слушаю».
    if (!connected && _listening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _listening = false);
      });
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (!connected) const _EvsBanner(),
        const SizedBox(height: 8),
        _MicButton(
          listening: _listening,
          enabled: canListen,
          onTap: () => _toggle(evs),
        ),
        const SizedBox(height: 20),
        Text(
          !connected ? 'EVS не подключён' : (_listening ? 'Слушаю…' : 'Нажмите, чтобы начать'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _listening
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Waveform(active: _listening, sensitivity: _sensitivity / 100),
        const SizedBox(height: 24),
        _EnableTile(
          value: _enabled,
          onChanged: (v) => setState(() {
            _enabled = v;
            if (!v) _listening = false;
          }),
        ),
        const SizedBox(height: 16),
        _SlidersCard(
          sensitivity: _sensitivity,
          volume: _volume,
          enabled: _enabled,
          onSensitivity: (v) => setState(() => _sensitivity = v),
          onVolume: (v) => setState(() => _volume = v),
        ),
        const SizedBox(height: 16),
        _HistoryCard(history: evs.history),
      ],
    );
  }
}

class _EvsBanner extends StatelessWidget {
  const _EvsBanner();

  @override
  Widget build(BuildContext context) {
    final status = Theme.of(context).extension<StatusColors>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: status.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: status.warning, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Нет связи с EVS', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text(
                  'Голосовые команды уходят на десктоп. Подключитесь во вкладке «Настройки».',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.enabled, required this.onTap});

  final bool listening;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: listening ? 128 : 116,
          height: listening ? 128 : 116,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: listening ? scheme.primary : scheme.surfaceContainerHighest,
            boxShadow: listening
                ? [
                    BoxShadow(color: scheme.primary.withValues(alpha: 0.20), blurRadius: 0, spreadRadius: 8),
                    BoxShadow(color: scheme.primary.withValues(alpha: 0.10), blurRadius: 0, spreadRadius: 18),
                  ]
                : null,
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Icon(
              listening ? Icons.mic : Icons.mic_off,
              size: 44,
              color: listening ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _EnableTile extends StatelessWidget {
  const _EnableTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        title: const Text('Голосовой ввод'),
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
    );
  }
}

class _SlidersCard extends StatelessWidget {
  const _SlidersCard({
    required this.sensitivity,
    required this.volume,
    required this.enabled,
    required this.onSensitivity,
    required this.onVolume,
  });

  final double sensitivity;
  final double volume;
  final bool enabled;
  final ValueChanged<double> onSensitivity;
  final ValueChanged<double> onVolume;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          children: [
            _LabeledSlider(
              icon: Icons.bolt,
              label: 'Чувствительность',
              value: sensitivity,
              enabled: enabled,
              onChanged: onSensitivity,
            ),
            const Divider(height: 24),
            _LabeledSlider(
              icon: Icons.volume_up,
              label: 'Громкость ответа',
              value: volume,
              enabled: enabled,
              onChanged: onVolume,
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Text(label),
            const Spacer(),
            Text('${value.round()}%', style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
          ],
        ),
        Slider(
          value: value,
          max: 100,
          divisions: 100,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});

  final List<EvsCommand> history;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ПОСЛЕДНИЕ КОМАНДЫ',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Здесь появятся команды, которые вы продиктуете.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              ...history.map(
                (cmd) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(cmd.text, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Icon(Icons.schedule, size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          formatRelative(cmd.at),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
