import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Warm, dark palette for ⅄music.
class YColors {
  static const bg = Color(0xFF0E0B09);
  static const bgRaised = Color(0xFF17120E);
  static const amber = Color(0xFFF2A65A);
  static const copper = Color(0xFFD9825B);
  static const rose = Color(0xFFE4949B);
  static const ember = Color(0xFFB8573A);
  static const cream = Color(0xFFF6ECDF);
  static const muted = Color(0xFFB5A596);
  static const faint = Color(0xFF7D6F63);
  static const line = Color(0x1FFFF1E0);
}

class YTheme {
  static ThemeData build() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: YColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: YColors.amber,
        secondary: YColors.rose,
        tertiary: YColors.copper,
        surface: YColors.bgRaised,
        onPrimary: Color(0xFF1C120A),
        onSurface: YColors.cream,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
    final text = base.textTheme.apply(
      fontFamily: 'Manrope',
      bodyColor: YColors.cream,
      displayColor: YColors.cream,
    );
    return base.copyWith(
      textTheme: text,
      iconTheme: const IconThemeData(color: YColors.cream),
      sliderTheme: const SliderThemeData(
        activeTrackColor: YColors.amber,
        inactiveTrackColor: Color(0x33FFF1E0),
        thumbColor: YColors.cream,
        overlayColor: Color(0x22F2A65A),
        trackHeight: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xEE231A14),
        contentTextStyle: const TextStyle(fontFamily: 'Manrope', color: YColors.cream, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: YColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x14FFF1E0),
        hintStyle: const TextStyle(color: YColors.faint),
        labelStyle: const TextStyle(color: YColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: YColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: YColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: YColors.amber, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1C1611),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}

String formatTotal(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '$h h $m min';
  return '$m min';
}
