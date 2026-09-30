import 'package:flutter/material.dart';

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({
    required this.background950,
    required this.background900,
    required this.background800,
    required this.background700,
    required this.foreground50,
    required this.foreground100,
    required this.foreground200,
    required this.foreground300,
    required this.foreground400,
    required this.foreground500,
    required this.foreground600,
    required this.primary500,
    required this.primary400,
    required this.primary300,
    required this.secondary500,
    required this.secondary400,
    required this.accent500,
    required this.accent400,
    required this.accent300,
    required this.card,
    required this.danger,
    required this.warning,
  });

  final Color background950;
  final Color background900;
  final Color background800;
  final Color background700;

  final Color foreground50;
  final Color foreground100;
  final Color foreground200;
  final Color foreground300;
  final Color foreground400;
  final Color foreground500;
  final Color foreground600;

  final Color primary500;
  final Color primary400;
  final Color primary300;

  final Color secondary500;
  final Color secondary400;

  final Color accent500;
  final Color accent400;
  final Color accent300;

  final Color card;
  final Color danger;
  final Color warning;

  @override
  AppColorsExtension copyWith({
    Color? background950,
    Color? background900,
    Color? background800,
    Color? background700,
    Color? foreground50,
    Color? foreground100,
    Color? foreground200,
    Color? foreground300,
    Color? foreground400,
    Color? foreground500,
    Color? foreground600,
    Color? primary500,
    Color? primary400,
    Color? primary300,
    Color? secondary500,
    Color? secondary400,
    Color? accent500,
    Color? accent400,
    Color? accent300,
    Color? card,
    Color? danger,
    Color? warning,
  }) {
    return AppColorsExtension(
      background950: background950 ?? this.background950,
      background900: background900 ?? this.background900,
      background800: background800 ?? this.background800,
      background700: background700 ?? this.background700,
      foreground50: foreground50 ?? this.foreground50,
      foreground100: foreground100 ?? this.foreground100,
      foreground200: foreground200 ?? this.foreground200,
      foreground300: foreground300 ?? this.foreground300,
      foreground400: foreground400 ?? this.foreground400,
      foreground500: foreground500 ?? this.foreground500,
      foreground600: foreground600 ?? this.foreground600,
      primary500: primary500 ?? this.primary500,
      primary400: primary400 ?? this.primary400,
      primary300: primary300 ?? this.primary300,
      secondary500: secondary500 ?? this.secondary500,
      secondary400: secondary400 ?? this.secondary400,
      accent500: accent500 ?? this.accent500,
      accent400: accent400 ?? this.accent400,
      accent300: accent300 ?? this.accent300,
      card: card ?? this.card,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      background950: Color.lerp(background950, other.background950, t)!,
      background900: Color.lerp(background900, other.background900, t)!,
      background800: Color.lerp(background800, other.background800, t)!,
      background700: Color.lerp(background700, other.background700, t)!,
      foreground50: Color.lerp(foreground50, other.foreground50, t)!,
      foreground100: Color.lerp(foreground100, other.foreground100, t)!,
      foreground200: Color.lerp(foreground200, other.foreground200, t)!,
      foreground300: Color.lerp(foreground300, other.foreground300, t)!,
      foreground400: Color.lerp(foreground400, other.foreground400, t)!,
      foreground500: Color.lerp(foreground500, other.foreground500, t)!,
      foreground600: Color.lerp(foreground600, other.foreground600, t)!,
      primary500: Color.lerp(primary500, other.primary500, t)!,
      primary400: Color.lerp(primary400, other.primary400, t)!,
      primary300: Color.lerp(primary300, other.primary300, t)!,
      secondary500: Color.lerp(secondary500, other.secondary500, t)!,
      secondary400: Color.lerp(secondary400, other.secondary400, t)!,
      accent500: Color.lerp(accent500, other.accent500, t)!,
      accent400: Color.lerp(accent400, other.accent400, t)!,
      accent300: Color.lerp(accent300, other.accent300, t)!,
      card: Color.lerp(card, other.card, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColorsExtension get colors => Theme.of(this).extension<AppColorsExtension>()!;
}

class AppColors {
  AppColors._();

  static const Color onPrimaryDark = Color(0xFF0B0F14);

  static const AppColorsExtension dark = AppColorsExtension(
    background950: Color(0xFF0B0F14),
    background900: Color(0xFF141A22),
    background800: Color(0xFF1A222C),
    background700: Color(0xFF1F2733),
    foreground50: Color(0xFFF8FAFC),
    foreground100: Color(0xFFEEF2F7),
    foreground200: Color(0xFFE2E8F0),
    foreground300: Color(0xFFCBD5E1),
    foreground400: Color(0xFF94A3B8),
    foreground500: Color(0xFF8391A7), // Enhanced contrast (5.47:1 vs 3.68:1)
    foreground600: Color(0xFF475569),
    primary500: Color(0xFF22C55E),
    primary400: Color(0xFF4ADE80),
    primary300: Color(0xFF86EFAC),
    secondary500: Color(0xFFF97316),
    secondary400: Color(0xFFFB923C),
    accent500: Color(0xFF3B82F6),
    accent400: Color(0xFF60A5FA),
    accent300: Color(0xFF93C5FD),
    card: Color(0xFFFACC15),
    danger: Color(0xFFEF4444),
    warning: Color(0xFFF59E0B),
  );

  static const AppColorsExtension light = AppColorsExtension(
    background950: Color(0xFFF8FAFC), // very light
    background900: Color(0xFFFFFFFF), // pure white for cards
    background800: Color(0xFFF1F5F9),
    background700: Color(0xFFE2E8F0),
    foreground50: Color(0xFF0F172A),  // very dark text
    foreground100: Color(0xFF1E293B),
    foreground200: Color(0xFF334155),
    foreground300: Color(0xFF475569),
    foreground400: Color(0xFF475569), // WCAG AAA compliant
    foreground500: Color(0xFF64748B),
    foreground600: Color(0xFF475569),
    primary500: Color(0xFF15803D), // High-contrast green (≥ 4.9:1)
    primary400: Color(0xFF16A34A),
    primary300: Color(0xFF22C55E),
    secondary500: Color(0xFFC2410C), // High-contrast orange
    secondary400: Color(0xFFEA580C),
    accent500: Color(0xFF1D4ED8), // High-contrast blue
    accent400: Color(0xFF2563EB),
    accent300: Color(0xFF3B82F6),
    card: Color(0xFFA16207),
    danger: Color(0xFFB91C1C),
    warning: Color(0xFFB45309),
  );
}
