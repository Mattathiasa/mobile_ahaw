import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  // Default to light mode (the app no longer starts in dark mode).
  ThemeMode themeMode = ThemeMode.light;

  ThemeProvider() {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('app-theme');
      if (stored == 'dark') {
        themeMode = ThemeMode.dark;
      } else if (stored == 'light') {
        themeMode = ThemeMode.light;
      }
      notifyListeners();
    } catch (_) {}
  }

  bool get isDarkMode {
    if (themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return themeMode == ThemeMode.dark;
  }

  void toggleTheme(bool isOn) {
    themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app-theme', themeMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  ThemeData get lightTheme => ThemeData(
    scaffoldBackgroundColor: AppColors.lightBackground,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      background: AppColors.lightBackground,
      surface: AppColors.lightSurface,
      onBackground: AppColors.lightText,
    ),
    textTheme: GoogleFonts.notoSansEthiopicTextTheme(
      ThemeData.light().textTheme,
    ).apply(bodyColor: AppColors.lightText, displayColor: AppColors.lightText),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.primary),
    ),
    useMaterial3: true,
  );

  ThemeData get darkTheme => ThemeData(
    scaffoldBackgroundColor: AppColors.darkBackground,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      background: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      onBackground: AppColors.darkText,
    ),
    textTheme: GoogleFonts.notoSansEthiopicTextTheme(
      ThemeData.dark().textTheme,
    ).apply(bodyColor: AppColors.darkText, displayColor: AppColors.darkText),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.white),
    ),
    useMaterial3: true,
  );
}
