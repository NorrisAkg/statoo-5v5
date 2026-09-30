import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    const colors = AppColors.dark;
    return base.copyWith(
      scaffoldBackgroundColor: colors.background950,
      primaryColor: colors.primary500,
      colorScheme: ColorScheme.dark(
        primary: colors.primary500,
        secondary: colors.secondary500,
        surface: colors.background900,
        error: colors.danger,
        onPrimary: AppColors.onPrimaryDark,
        onSurface: colors.foreground50,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background950,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: colors.foreground50),
        titleTextStyle: GoogleFonts.inter(
          color: colors.foreground50,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      extensions: [colors],
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        titleLarge: GoogleFonts.inter(color: colors.foreground50, fontSize: 22, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.inter(color: colors.foreground50, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: colors.foreground50, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: colors.foreground50, fontSize: 14),
        bodySmall: GoogleFonts.inter(color: colors.foreground50, fontSize: 12),
        labelSmall: GoogleFonts.inter(color: colors.foreground50, fontSize: 11),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light();
    const colors = AppColors.light;
    return base.copyWith(
      scaffoldBackgroundColor: colors.background950,
      primaryColor: colors.primary500,
      colorScheme: ColorScheme.light(
        primary: colors.primary500,
        secondary: colors.secondary500,
        surface: colors.background900,
        error: colors.danger,
        onPrimary: AppColors.onPrimaryDark,
        onSurface: colors.foreground50,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background950,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: colors.foreground50),
        titleTextStyle: GoogleFonts.inter(
          color: colors.foreground50,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      extensions: [colors],
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        titleLarge: GoogleFonts.inter(color: colors.foreground50, fontSize: 22, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.inter(color: colors.foreground50, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: colors.foreground50, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: colors.foreground50, fontSize: 14),
        bodySmall: GoogleFonts.inter(color: colors.foreground50, fontSize: 12),
        labelSmall: GoogleFonts.inter(color: colors.foreground50, fontSize: 11),
      ),
    );
  }
}
