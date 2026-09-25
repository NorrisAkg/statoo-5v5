import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    final colors = AppColors.dark;
    return base.copyWith(
      scaffoldBackgroundColor: colors.background950,
      primaryColor: colors.primary500,
      colorScheme: ColorScheme.dark(
        primary: colors.primary500,
        secondary: colors.secondary500,
        surface: colors.background900,
        error: colors.danger,
        onPrimary: colors.foreground50,
        onSurface: colors.foreground50,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background950,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.foreground50),
      ),
      extensions: [colors],
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        titleLarge: GoogleFonts.inter(color: colors.foreground50, fontSize: 22, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.inter(color: colors.foreground50, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: colors.foreground50, fontSize: 14),
        bodyMedium: GoogleFonts.inter(color: colors.foreground50, fontSize: 12),
        labelSmall: GoogleFonts.inter(color: colors.foreground50, fontSize: 11),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light();
    final colors = AppColors.light;
    return base.copyWith(
      scaffoldBackgroundColor: colors.background950,
      primaryColor: colors.primary500,
      colorScheme: ColorScheme.light(
        primary: colors.primary500,
        secondary: colors.secondary500,
        surface: colors.background900,
        error: colors.danger,
        onPrimary: colors.background950,
        onSurface: colors.foreground50,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background950,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.foreground50),
        titleTextStyle: GoogleFonts.inter(color: colors.foreground50, fontSize: 20, fontWeight: FontWeight.w500),
      ),
      extensions: [colors],
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        titleLarge: GoogleFonts.inter(color: colors.foreground50, fontSize: 22, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.inter(color: colors.foreground50, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: colors.foreground50, fontSize: 14),
        bodyMedium: GoogleFonts.inter(color: colors.foreground50, fontSize: 12),
        labelSmall: GoogleFonts.inter(color: colors.foreground50, fontSize: 11),
      ),
    );
  }
}
