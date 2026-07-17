import 'package:flutter/material.dart';

// ── Beach Bar Summer Palette ──────────────────────────────────────────────────
class AppTheme {
  // Core beach colours
  static const Color sand       = Color(0xFFFFF8F0);   // warm white background
  static const Color sunYellow  = Color(0xFFFFC845);   // golden sun
  static const Color coral      = Color(0xFFFF7043);   // sunset coral/orange
  static const Color ocean      = Color(0xFF0097A7);   // clear ocean teal
  static const Color surf       = Color(0xFF26C6DA);   // bright surf blue
  static const Color seafoam    = Color(0xFF66BB6A);   // seafoam green
  static const Color sky        = Color(0xFF039BE5);   // sky blue

  // Neutral tones (warm, not cold)
  static const Color driftwood  = Color(0xFF8D6E63);   // warm brown
  static const Color shell      = Color(0xFFF5EDE0);   // card background
  static const Color pebble     = Color(0xFFE8D8C8);   // border/divider
  static const Color dune       = Color(0xFFBCA99A);   // secondary text

  // Semantic
  static const Color success    = Color(0xFF43A047);
  static const Color warning    = Color(0xFFFFB300);
  static const Color danger     = Color(0xFFE53935);

  // Text
  static const Color textPrimary   = Color(0xFF2C1A0E);  // dark warm brown
  static const Color textSecondary = Color(0xFF7A5C4A);  // medium warm
  static const Color textLight     = Color(0xFFBCA99A);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',                         // round, friendly, summery
    scaffoldBackgroundColor: sand,
    colorScheme: ColorScheme.light(
      primary: ocean,
      secondary: sunYellow,
      tertiary: coral,
      surface: shell,
      error: danger,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w800,
        fontSize: 20,
        color: Colors.white,
        letterSpacing: 0.2,
      ),
    ),

    // Text theme — warm browns on cream
    textTheme: const TextTheme(
      displayLarge: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w900,
          color: textPrimary, letterSpacing: -0.5),
      displayMedium: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w800,
          color: textPrimary),
      titleLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w800,
          color: textPrimary),
      titleMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700,
          color: textSecondary, letterSpacing: 0.6),
      bodyLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600,
          color: textPrimary),
      bodyMedium: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: textSecondary),
      bodySmall: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500,
          color: textLight),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: shell,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: pebble, width: 1.2),
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: textLight, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: pebble, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: pebble, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ocean, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),

    // Elevated button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ocean,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w800,
          fontSize: 15,
          letterSpacing: 0.3,
        ),
      ),
    ),

    // Text button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ocean,
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // BottomNav
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: ocean,
      unselectedItemColor: dune,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(
          fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 11),
      unselectedLabelStyle: TextStyle(
          fontFamily: 'Nunito', fontWeight: FontWeight.w600, fontSize: 11),
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? success : Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? success.withOpacity(.4)
              : pebble),
    ),

    // Slider
    sliderTheme: const SliderThemeData(
      activeTrackColor: ocean,
      thumbColor: ocean,
      inactiveTrackColor: pebble,
    ),

    // Segmented button
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? ocean : Colors.white),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : textSecondary),
        side: WidgetStateProperty.all(
            const BorderSide(color: pebble, width: 1.2)),
      ),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: pebble,
      thickness: 1,
      space: 1,
    ),
  );
}

// ── Gradients ─────────────────────────────────────────────────────────────────
class AppGradients {
  /// Warm sunset gradient for headers
  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFF0097A7), Color(0xFF0288D1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Golden accent gradient
  static const LinearGradient goldenGradient = LinearGradient(
    colors: [Color(0xFFFFB300), Color(0xFFFF7043)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Seafoam gradient for categories
  static const LinearGradient seafoamGradient = LinearGradient(
    colors: [Color(0xFF0097A7), Color(0xFF26C6DA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Keep old name as alias so existing imports don't break
  static const LinearGradient oceanGradient = sunsetGradient;
}