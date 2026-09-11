import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_ahaw/theme/app_colors.dart';
import 'package:mobile_ahaw/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemeProvider light/dark themes use the migrated ColorScheme fields',
      () {
    final themeProvider = ThemeProvider();

    expect(themeProvider.themeMode, ThemeMode.light);

    final light = themeProvider.lightTheme;
    final dark = themeProvider.darkTheme;

    // surface/onSurface replaced the deprecated background/onBackground.
    expect(light.colorScheme.surface, AppColors.lightBackground);
    expect(light.colorScheme.onSurface, AppColors.lightText);
    expect(dark.colorScheme.surface, AppColors.darkBackground);
    expect(dark.colorScheme.onSurface, AppColors.darkText);

    // Scaffolds pick up the surface color in Material 3.
    expect(light.scaffoldBackgroundColor, AppColors.lightBackground);
    expect(dark.scaffoldBackgroundColor, AppColors.darkBackground);
  });
}
