import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../core/validators.dart';

class ComputerFormResult {
  ComputerFormResult({
    required this.name,
    required this.host,
    required this.port,
    this.mac,
    this.token,
    this.cpuThreshold,
    this.ramThreshold,
    this.diskThreshold,
    this.tempThreshold,
    this.ntfyTopic,
  });

  final String name;
  final String host;
  final int port;
  final String? mac;
  final String? token;
  final int? cpuThreshold;
  final int? ramThreshold;
  final int? diskThreshold;
  final double? tempThreshold;
  final String? ntfyTopic;
}

/// Одна форма на оба списка. Поля включаются флагами:
/// withMac — для Wake-on-LAN, withToken — для мониторинга.
abstract final class ComputerFormSheet {
  static Future<ComputerFormResult?> show(
    BuildContext context, {
    required String title,
    required String hostLabel,
    required String hostHint,
    required String submitLabel,
    bool withMac = false,
    bool withToken = false,
    bool macOptional = false,
    int defaultPort = 8765,
    ComputerFormResult? initial,
  }) {
    return showModalBottomSheet<ComputerFormResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: _FormBody(
          title: title,
          hostLabel: hostLabel,
          hostHint: hostHint,
          submitLabel: submitLabel,
          withMac: withMac,
          withToken: withToken,
          macOptional: macOptional,
          defaultPort: defaultPort,
          initial: initial,
        ),
      ),
    );
  }
}

class _FormBody extends StatefulWidget {
  const _FormBody({
    required this.title,
    required this.hostLabel,
    required this.hostHint,
    required this.submitLabel,
    required this.withMac,
    required this.withToken,
    required this.macOptional,
    required this.defaultPort,
    required this.initial,
  });

  final String title;
  final String hostLabel;
  final String hostHint;
  final String submitLabel;
  final bool withMac;
  final bool withToken;
  final bool macOptional;
  final int defaultPort;
  final ComputerFormResult? initial;

  @override
  State<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends State<_FormBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _mac;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _token;
  late final TextEditingController _cpuThreshold;
  late final TextEditingController _ramThreshold;
  late final TextEditingController _diskThreshold;
  late final TextEditingController _tempThreshold;
  late final TextEditingController _ntfyTopic;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? '');
    _mac = TextEditingController(text: i?.mac ?? '');
    _host = TextEditingController(text: i?.host ?? '');
    _port = TextEditingController(text: (i?.port ?? widget.defaultPort).toString());
    _token = TextEditingController(text: i?.token ?? '');
    _cpuThreshold = TextEditingController(text: i?.cpuThreshold?.toString() ?? '');
    _ramThreshold = TextEditingController(text: i?.ramThreshold?.toString() ?? '');
    _diskThreshold = TextEditingController(text: i?.diskThreshold?.toString() ?? '');
    _tempThreshold = TextEditingController(text: i?.tempThreshold?.toString() ?? '');
    _ntfyTopic = TextEditingController(text: i?.ntfyTopic ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _mac.dispose();
    _host.dispose();
    _port.dispose();
    _token.dispose();
    _cpuThreshold.dispose();
    _ramThreshold.dispose();
    _diskThreshold.dispose();
    _tempThreshold.dispose();
    _ntfyTopic.dispose();
    super.dispose();
  }

  String? _validateMacField(String? v) {
    if (widget.macOptional && (v == null || v.trim().isEmpty)) return null;
    return validateMac(v);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final macText = _mac.text.trim();
    final ntfyTopicText = _ntfyTopic.text.trim();
    Navigator.of(context).pop(
      ComputerFormResult(
        name: _name.text.trim(),
        host: _host.text.trim(),
        port: int.parse(_port.text.trim()),
        mac: widget.withMac && macText.isNotEmpty ? normalizeMac(macText) : null,
        token: widget.withToken ? _token.text : null,
        cpuThreshold: widget.withToken ? int.tryParse(_cpuThreshold.text.trim()) : null,
        ramThreshold: widget.withToken ? int.tryParse(_ramThreshold.text.trim()) : null,
        diskThreshold: widget.withToken ? int.tryParse(_diskThreshold.text.trim()) : null,
        tempThreshold: widget.withToken ? double.tryParse(_tempThreshold.text.trim()) : null,
        ntfyTopic: widget.withToken && ntfyTopicText.isNotEmpty ? ntfyTopicText : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const mono = TextStyle(fontFamilyFallback: monoFontFallback);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Название', hintText: 'Домашний ПК'),
              textInputAction: TextInputAction.next,
              validator: validateName,
            ),
            if (widget.withMac) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _mac,
                decoration: InputDecoration(
                  labelText: widget.macOptional ? 'MAC-адрес (для включения)' : 'MAC-адрес',
                  hintText: '00:1A:2B:3C:4D:5E',
                ),
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                style: mono,
                validator: _validateMacField,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _host,
                    decoration: InputDecoration(labelText: widget.hostLabel, hintText: widget.hostHint),
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    style: mono,
                    validator: validateHost,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 88,
                  child: TextFormField(
                    controller: _port,
                    decoration: const InputDecoration(labelText: 'Порт'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: validatePort,
                  ),
                ),
              ],
            ),
            if (widget.withToken) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _token,
                decoration: const InputDecoration(
                  labelText: 'Токен агента',
                  hintText: 'PC_AGENT_TOKEN',
                ),
                autocorrect: false,
                obscureText: true,
                style: mono,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Токен нужен для доступа к метрикам' : null,
              ),
              const SizedBox(height: 14),
              Text(
                'Пороги алертов для этой машины. Пусто — не менять текущее значение на агенте.',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cpuThreshold,
                      decoration: const InputDecoration(labelText: 'Порог CPU %', hintText: '90'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: validatePercent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ramThreshold,
                      decoration: const InputDecoration(labelText: 'Порог RAM %', hintText: '90'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: validatePercent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _diskThreshold,
                      decoration: const InputDecoration(labelText: 'Порог диска %', hintText: '90'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: validatePercent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _tempThreshold,
                      decoration: const InputDecoration(labelText: 'Порог темп. °C', hintText: '85'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: validateTempThreshold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ntfyTopic,
                decoration: const InputDecoration(
                  labelText: 'Топик ntfy (для push, необязательно)',
                  hintText: 'nexus-server',
                ),
                autocorrect: false,
                style: mono,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
