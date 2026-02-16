import 'package:flutter/material.dart';

class AppColors {
  // Light Mode Colors
  static const Color lightBackground = Color(0xFFE7F0FA);
  static const Color lightSurface = Colors.white;
  static const Color lightText = Color(0xFF0D2440);

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF0D2440);
  static const Color darkSurface = Color(
    0xFF1A365D,
  ); // Slightly lighter than bg
  static const Color darkText = Colors.white;

  // Primary Palette
  static const Color primary = Color(0xFF2E5E99);
  static const Color primaryLight = Color(0xFF7BA4D0);
  static const Color primaryDark = Color(0xFF1E3A5F);

  // Accents
  static const Color accent = Color(0xFF7BA4D0);
  static const Color secondary = accent;
  static const Color success = Color(0xFF28A745);
  static const Color error = Color(0xFFDC3545);
  static const Color warning = Color(0xFFFFC107);

  // Neutral
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Colors.grey;
  static const Color transparent = Colors.transparent;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [darkBackground, Color(0xFF1A365D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
