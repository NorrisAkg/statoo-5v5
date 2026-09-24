import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background950,
      primaryColor: AppColors.primary500,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary500,
        secondary: AppColors.secondary500,
        surface: AppColors.background900,
        error: AppColors.danger,
        onPrimary: AppColors.foreground50,
        onSurface: AppColors.foreground50,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background950,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.foreground50),
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        titleLarge: GoogleFonts.inter(
          color: AppColors.foreground50,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: GoogleFonts.inter(
          color: AppColors.foreground50,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(
          color: AppColors.foreground50,
          fontSize: 14,
        ),
        bodyMedium: GoogleFonts.inter(
          color: AppColors.foreground50,
          fontSize: 12,
        ),
        labelSmall: GoogleFonts.inter(
          color: AppColors.foreground50,
          fontSize: 11,
        ),
      ),
    );
  }
}
