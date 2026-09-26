import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Color tokens taken from the Huella GPS marketing site, so the app shares
// its brand identity end to end.
abstract class AppColors {
  static const bg = Color(0xFF10141A);
  static const panel = Color(0xFF171D26);
  static const panel2 = Color(0xFF1E2630);
  static const line = Color(0xFF2A3340);
  static const text = Color(0xFFEDEEF0);
  static const textDim = Color(0xFF8B94A3);
  static const textFaint = Color(0xFF5B6472);
  static const amber = Color(0xFFE8873D);
  static const amberDim = Color(0xFFB96A2E);
  static const cyan = Color(0xFF2FD6C0);
  static const olive = Color(0xFF7C8A5C);
  static const danger = Color(0xFFE0654F);
  static const dangerContainer = Color(0xFF35282C);
  static const onAmber = Color(0xFF171203);
}

// OpenStreetMap's free tile server only serves light tiles, and dark tile
// providers (e.g. CARTO) now require signing up for an API key. This filter
// fakes a dark basemap client-side instead, so the map matches the app's
// theme without depending on a third-party key.
// ignore: constant_identifier_names
const darkTileColorFilter = ColorFilter.matrix(<double>[
  -0.2126, -0.7152, -0.0722, 0, 255,
  -0.7152, -0.2126, -0.0722, 0, 255,
  -0.0722, -0.7152, -0.2126, 0, 255,
  0, 0, 0, 1, 0,
]);

abstract class AppTheme {
  static ThemeData get dark {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );
    final displayTextTheme = GoogleFonts.bigShouldersDisplayTextTheme(baseTextTheme);

    final textTheme = baseTextTheme.copyWith(
      headlineLarge: displayTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium: displayTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: displayTextTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: displayTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: displayTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );

    const colorScheme = ColorScheme.dark(
      primary: AppColors.amber,
      onPrimary: AppColors.onAmber,
      secondary: AppColors.cyan,
      onSecondary: AppColors.onAmber,
      tertiary: AppColors.olive,
      onTertiary: AppColors.onAmber,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerContainer,
      onErrorContainer: AppColors.danger,
      surface: AppColors.panel,
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.panel2,
      onSurfaceVariant: AppColors.textDim,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
    );

    final roundedBorder = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(9),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: textTheme,
      dividerColor: AppColors.line,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: displayTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      cardTheme: CardThemeData(
        color: AppColors.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textDim,
        textColor: AppColors.text,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg,
        labelStyle: const TextStyle(color: AppColors.textDim),
        hintStyle: const TextStyle(color: AppColors.textFaint),
        helperStyle: const TextStyle(color: AppColors.textFaint),
        border: inputBorder(AppColors.line),
        enabledBorder: inputBorder(AppColors.line),
        focusedBorder: inputBorder(AppColors.amber, 1.6),
        errorBorder: inputBorder(AppColors.danger),
        focusedErrorBorder: inputBorder(AppColors.danger, 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.onAmber,
          disabledBackgroundColor: AppColors.amber.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 26),
          shape: roundedBorder,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.line),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 24),
          shape: roundedBorder,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textDim,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textDim),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.panel2,
        side: BorderSide(color: AppColors.line),
        labelStyle: TextStyle(color: AppColors.textDim, fontSize: 12),
        shape: StadiumBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.panel2,
        contentTextStyle: const TextStyle(color: AppColors.text),
        actionTextColor: AppColors.amber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.amber),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.amber,
        unselectedLabelColor: AppColors.textDim,
        indicatorColor: AppColors.amber,
      ),
    );
  }
}
