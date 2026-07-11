import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Поле, которое само владеет контроллером и не пересоздаёт его при перестройке
/// родителя. Значение берётся из [initialValue] один раз; дальше источник
/// правды — сам контроллер, а наружу уходит [onChanged].
class EditableField extends StatefulWidget {
  const EditableField({
    super.key,
    required this.initialValue,
    required this.label,
    required this.onChanged,
    this.hint,
    this.obscure = false,
    this.mono = false,
    this.digitsOnly = false,
    this.keyboardType,
  });

  final String initialValue;
  final String label;
  final String? hint;
  final ValueChanged<String> onChanged;
  final bool obscure;
  final bool mono;
  final bool digitsOnly;
  final TextInputType? keyboardType;

  @override
  State<EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<EditableField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(labelText: widget.label, hintText: widget.hint),
      obscureText: widget.obscure,
      autocorrect: false,
      keyboardType: widget.digitsOnly ? TextInputType.number : widget.keyboardType,
      inputFormatters: widget.digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: widget.mono
          ? const TextStyle(fontFamilyFallback: ['SF Mono', 'Menlo', 'Roboto Mono', 'monospace'])
          : null,
      onChanged: widget.onChanged,
    );
  }
}
