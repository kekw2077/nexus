import 'package:flutter/material.dart';

/// Цветовые схемы приложения. Nexus — фирменная (в стиле десктопного EVS
/// «Nexus Sync»), по умолчанию. Discord и Тёплая оставлены как альтернативы.
enum AppBrand {
  nexus('Nexus'),
  discord('Discord'),
  warm('Тёплая');

  const AppBrand(this.label);
  final String label;
}

class _Brand {
  const _Brand({
    required this.primary,
    required this.success,
    required this.warning,
    this.onSuccess = Colors.white,
  });
  final Color primary;
  final Color success;
  final Color warning;
  final Color onSuccess;
}

const _palettes = <AppBrand, _Brand>{
  AppBrand.nexus: _Brand(
    primary: Color(0xFF5E8BFF), // blue
    success: Color(0xFF4ADE80), // green
    warning: Color(0xFFFFB454), // amber
    onSuccess: Color(0xFF06210F),
  ),
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

/// Тёмная схема Nexus — точные цвета макета EVS «Nexus Sync v2».
/// Наложенные полупрозрачные линии/поверхности сведены к непрозрачным.
ColorScheme _nexusDark(ColorScheme seed) => seed.copyWith(
      surface: const Color(0xFF0B0F1B),
      onSurface: const Color(0xFFE8ECFA),
      onSurfaceVariant: const Color(0xFF8A93B4),
      surfaceContainerLowest: const Color(0xFF080B13),
      surfaceContainerLow: const Color(0xFF121A2E), // карточки
      surfaceContainer: const Color(0xFF141D33),
      surfaceContainerHigh: const Color(0xFF18213A),
      surfaceContainerHighest: const Color(0xFF1C2740), // поля ввода / фон полос
      primary: const Color(0xFF5E8BFF),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF1B2748),
      onPrimaryContainer: const Color(0xFFCBD8FF),
      secondary: const Color(0xFF4FD1FF), // cyan
      onSecondary: const Color(0xFF06131C),
      tertiary: const Color(0xFF8B7CFF), // violet
      onTertiary: const Color(0xFF0C0A22),
      error: const Color(0xFFFF7A7A),
      onError: const Color(0xFF2A0A0A),
      outline: const Color(0xFF2A3249),
      outlineVariant: const Color(0xFF1D2336),
    );

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
  var scheme = ColorScheme.fromSeed(
    seedColor: brandColors.primary,
    brightness: brightness,
    primary: brandColors.primary,
  );

  // Nexus в тёмном режиме — фирменные поверхности/акценты из макета.
  if (brand == AppBrand.nexus && brightness == Brightness.dark) {
    scheme = _nexusDark(scheme);
  }

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    extensions: <ThemeExtension<dynamic>>[
      StatusColors(
        success: brandColors.success,
        onSuccess: brandColors.onSuccess,
        warning: brandColors.warning,
      ),
    ],
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
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
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 64,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? scheme.primary.withValues(alpha: 0.16) : Colors.transparent),
      ),
    ),
  );
}
