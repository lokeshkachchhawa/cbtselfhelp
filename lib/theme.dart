// lib/theme.dart
// Centralized app ThemeData for the "Trial & observation" teal palette.

import 'package:flutter/material.dart';

/// Palette (from your Home page)
const Color kTeal1 = Color.fromARGB(255, 1, 108, 108); // #016C6C
const Color kTeal2 = Color(0xFF79C2BF);
const Color kTeal3 = Color(0xFF008F89);
const Color kTeal4 = Color(0xFF007A78);
const Color kTeal5 = Color(0xFF005E5C);
const Color kTeal6 = Color(0xFF004E4D);

ThemeData appTheme() {
  // Build a straightforward, compatible ColorScheme
  final ColorScheme colorScheme = ColorScheme.light(
    primary: kTeal4,
    onPrimary: Colors.white,
    secondary: kTeal3,
    onSecondary: Colors.white,
    background: Colors.white,
    surface: Colors.white,
    onBackground: Colors.black87,
    onSurface: Colors.black87,
    error: Colors.red.shade700,
  );

  return ThemeData(
    colorScheme: colorScheme,
    primaryColor: kTeal4,
    scaffoldBackgroundColor: Colors.white,
    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: kTeal4,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),

    // Elevated (primary) buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kTeal4,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // Outlined (secondary) buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kTeal5,
        side: BorderSide(color: kTeal2.withOpacity(0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      ),
    ),

    // Text (link) buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kTeal4,
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),

    // Card
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: TextStyle(color: kTeal5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),

    // Slider
    sliderTheme: SliderThemeData(
      activeTrackColor: kTeal3,
      inactiveTrackColor: kTeal2.withOpacity(0.4),
      thumbColor: kTeal4,
      overlayColor: kTeal4.withOpacity(0.14),
      valueIndicatorColor: kTeal4,
    ),

    // Text styles (compatible names)
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 14),
      bodyMedium: TextStyle(fontSize: 13, color: Colors.black87),
      labelLarge: TextStyle(fontSize: 15, color: Colors.black54),
    ),

    // FAB
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kTeal3,
      foregroundColor: Colors.white,
    ),

    // Dialogs
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: Colors.black87,
      ),
      contentTextStyle: TextStyle(fontSize: 14, color: Colors.black87),
    ),
    // subtle shadow color
    shadowColor: Colors.black.withOpacity(0.12),
  );
}
