import 'package:flutter/material.dart';

/// Две цветовые схемы. Discord — по умолчанию, Warm — терракотовая,
/// как в исходном макете.
enum AppBrand {
  discord('Discord'),
  warm('Тёплая');

  const AppBrand(this.label);
  final String label;
}

class _Brand {
  const _Brand({required this.primary, required this.success, required this.warning});
  final Color primary;
  final Color success;
  final Color warning;
}

const _palettes = <AppBrand, _Brand>{
  AppBrand.discord: _Brand(
    primary: Color(0xFF5865F2),
    success: Color(0xFF23A55A),
    warning: Color(0xFFF0B232),
  ),
  AppBrand.warm: _Brand(
    primary: Color(0xFFCC785C),
    success: Color(0xFF3F8F5F),
    warning: Color(0xFFB8792F),
  ),
};

/// Success/warning не входят в ColorScheme Material — держим их в расширении темы.
/// Доступ: Theme.of(context).extension<StatusColors>()!
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
  });

  final Color success;
  final Color onSuccess;
  final Color warning;

  @override
  StatusColors copyWith({Color? success, Color? onSuccess, Color? warning}) => StatusColors(
        success: success ?? this.success,
        onSuccess: onSuccess ?? this.onSuccess,
        warning: warning ?? this.warning,
      );

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

/// Моноширинный стиль для MAC-адресов, IP и числовых метрик —
/// сетевые данные читаются выровненными по разрядам.
const monoFontFallback = ['SF Mono', 'Menlo', 'Roboto Mono', 'monospace'];

ThemeData buildTheme(AppBrand brand, Brightness brightness) {
  final brandColors = _palettes[brand]!;
  final scheme = ColorScheme.fromSeed(
    seedColor: brandColors.primary,
    brightness: brightness,
    primary: brandColors.primary,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    extensions: <ThemeExtension<dynamic>>[
      StatusColors(
        success: brandColors.success,
        onSuccess: Colors.white,
        warning: brandColors.warning,
      ),
    ],
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 64,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5)),
  );
}
