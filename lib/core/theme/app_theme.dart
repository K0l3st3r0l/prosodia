import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  // Paleta vibrante e infantil — colores vivos y amigables para niños
  static const Color primary = Color(0xFF7C3AED);      // Violeta vibrante
  static const Color primaryDark = Color(0xFF5B21B6);  // Violeta profundo
  static const Color secondary = Color(0xFFF97316);    // Naranja vivo
  static const Color tertiary = Color(0xFF10B981);     // Verde esmeralda
  static const Color surface = Color(0xFFFAF8FF);      // Blanco lavanda suave
  static const Color surfaceAlt = Color(0xFFEDE9FE);   // Morado claro
  static const Color surfaceStrong = Color(0xFFDDD6FE); // Morado medio
  static const Color ink = Color(0xFF1E1155);          // Azul-morado profundo
  static const Color muted = Color(0xFF6E5FA6);        // Morado grisáceo

  // Solid colors instead of gradients — older Android GPUs (and some panels with
  // limited color depth) render LinearGradient with severe banding/garbage that
  // looks like pixel corruption. Solid colors render correctly everywhere.
  static const Color appBackground = Color(0xFFF4F0FF); // Lavanda muy suave
  static const Color headerBackground = primary;

  static List<BoxShadow> get softShadow => const [
    BoxShadow(
      color: Color(0x207C3AED),
      blurRadius: 32,
      offset: Offset(0, 18),
    ),
  ];

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      tertiary: tertiary,
      onTertiary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      error: Color(0xFFE53E3E),
      onError: Colors.white,
      outline: Color(0xFFCEC7F0),
      outlineVariant: Color(0xFFEDE9FE),
      shadow: Color(0x207C3AED),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
    );

    // Nunito: tipografía redondeada y amigable, ideal para aplicaciones infantiles
    final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme)
        .copyWith(
          displaySmall: GoogleFonts.nunito(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: ink,
          ),
          headlineMedium: GoogleFonts.nunito(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: ink,
          ),
          headlineSmall: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: ink,
          ),
          titleLarge: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            color: ink,
          ),
          titleMedium: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          bodyLarge: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.5,
            color: ink,
          ),
          bodyMedium: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.5,
            color: ink,
          ),
          bodySmall: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.45,
            color: muted,
          ),
          labelLarge: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
          labelMedium: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
            color: muted,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shadowColor: const Color(0x207C3AED),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFFDDD6FE)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEDE9FE),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: muted),
        prefixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFCEC7F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFCEC7F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE53E3E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE53E3E), width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceStrong,
          disabledForegroundColor: muted,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: Color(0xFFCEC7F0)),
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceAlt,
        selectedColor: const Color(0xFFDDD6FE),
        disabledColor: const Color(0xFFEDE9FE),
        secondarySelectedColor: const Color(0xFFDDD6FE),
        side: const BorderSide(color: Color(0xFFCEC7F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelStyle: textTheme.labelMedium?.copyWith(color: ink),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: primary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static TextStyle readingTextStyle(
    TextTheme textTheme, {
    double fontSize = 24,
    double height = 1.9,
    Color color = ink,
  }) {
    return GoogleFonts.sourceSerif4(
      textStyle: textTheme.bodyLarge?.copyWith(
        fontSize: fontSize,
        height: height,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        color: color,
      ),
    );
  }
}