import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Акцентный градиент (blue → violet) из брендовых цветов текущей темы.
LinearGradient accentGradient(ColorScheme scheme) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [scheme.primary, scheme.tertiary],
    );

/// Градиент для полос заполнения (cyan → violet).
LinearGradient barGradient(ColorScheme scheme) => LinearGradient(
      colors: [scheme.secondary, scheme.tertiary],
    );

/// Кнопка с акцентным градиентом. Внутри — прозрачный [FilledButton], поэтому
/// поведение (размеры, работа в Expanded, ripple, disabled) — как у обычной.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.onPressed, required this.label, this.icon});

  final VoidCallback? onPressed;
  final Widget label;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final style = FilledButton.styleFrom(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.transparent,
      disabledForegroundColor: Colors.white,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: shape,
    );

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: accentGradient(scheme),
        ),
        child: icon != null
            ? FilledButton.icon(onPressed: onPressed, style: style, icon: icon!, label: label)
            : FilledButton(onPressed: onPressed, style: style, child: label),
      ),
    );
  }
}

/// Компактный переключатель в стиле макета: 46×26 пилюля, градиент когда включён,
/// белый бегунок. API совместим со [Switch] (value / onChanged).
class GradientSwitch extends StatelessWidget {
  const GradientSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onChanged != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          width: 46,
          height: 26,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: value ? accentGradient(scheme) : null,
            color: value ? null : scheme.surfaceContainerHighest,
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

/// Тумблер-строка (замена SwitchListTile) с градиентным переключателем.
class GradientSwitchTile extends StatelessWidget {
  const GradientSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.contentPadding = EdgeInsets.zero,
  });

  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: contentPadding,
      title: title,
      subtitle: subtitle,
      trailing: GradientSwitch(value: value, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged!(!value),
    );
  }
}

/// Полоса заполнения с градиентом (cyan → violet); при перегрузке — сплошной
/// предупреждающий цвет.
class GradientBar extends StatelessWidget {
  const GradientBar({super.key, required this.value, this.hot = false, this.height = 6});

  final double value; // 0..1
  final bool hot;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warning = Theme.of(context).extension<StatusColors>()?.warning ?? scheme.error;
    final radius = BorderRadius.circular(height);
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        width: double.infinity,
        color: scheme.surfaceContainerHighest,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: hot ? null : barGradient(scheme),
              color: hot ? warning : null,
            ),
          ),
        ),
      ),
    );
  }
}
