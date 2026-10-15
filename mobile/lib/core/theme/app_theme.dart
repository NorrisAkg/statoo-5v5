import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Status bar painted with the header color so both read as a single block.
  /// Both headers are dark enough for light system icons.
  static SystemUiOverlayStyle headerOverlayStyle(AppColorsExtension colors) => SystemUiOverlayStyle(
        statusBarColor: colors.header,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      );

  /// For screens whose app bar is transparent over the page background.
  static SystemUiOverlayStyle pageOverlayStyle(Brightness brightness) => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: brightness,
      );

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
        backgroundColor: colors.header,
        foregroundColor: colors.onHeader,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: colors.onHeader),
        actionsIconTheme: IconThemeData(color: colors.onHeader),
        systemOverlayStyle: headerOverlayStyle(colors),
        titleTextStyle: GoogleFonts.poppins(
          color: colors.onHeader,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      extensions: [colors],
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
        titleLarge: GoogleFonts.poppins(color: colors.foreground50, fontSize: 22, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.poppins(color: colors.foreground50, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.poppins(color: colors.foreground50, fontSize: 16),
        bodyMedium: GoogleFonts.poppins(color: colors.foreground50, fontSize: 14),
        bodySmall: GoogleFonts.poppins(color: colors.foreground50, fontSize: 12),
        labelSmall: GoogleFonts.poppins(color: colors.foreground50, fontSize: 11),
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
        onPrimary: Colors.white,
        onSurface: colors.foreground50,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.header,
        foregroundColor: colors.onHeader,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: colors.onHeader),
        actionsIconTheme: IconThemeData(color: colors.onHeader),
        systemOverlayStyle: headerOverlayStyle(colors),
        titleTextStyle: GoogleFonts.poppins(
          color: colors.onHeader,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      extensions: [colors],
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
        titleLarge: GoogleFonts.poppins(color: colors.foreground50, fontSize: 22, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.poppins(color: colors.foreground50, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.poppins(color: colors.foreground50, fontSize: 16),
        bodyMedium: GoogleFonts.poppins(color: colors.foreground50, fontSize: 14),
        bodySmall: GoogleFonts.poppins(color: colors.foreground50, fontSize: 12),
        labelSmall: GoogleFonts.poppins(color: colors.foreground50, fontSize: 11),
      ),
    );
  }
}
