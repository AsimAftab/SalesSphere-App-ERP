import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const String _fontFamily = 'Poppins';

  // Brand palette ported from SalesSphere v1
  static const Color _primary = Color(0xFF163355);
  static const Color _primaryContainer = Color(0xFF2A4F7C);
  static const Color _secondary = Color(0xFF197ADC);
  static const Color _secondaryContainer = Color(0xFF52A6E8);
  static const Color _tertiary = Color(0xFFE2A93D);
  static const Color _appBarBackground = Color(0xFF163355);

  static FlexSchemeColor get _lightScheme => const FlexSchemeColor(
        primary: _primary,
        primaryContainer: _primaryContainer,
        secondary: _secondary,
        secondaryContainer: _secondaryContainer,
        tertiary: _tertiary,
        appBarColor: _appBarBackground,
      );

  static FlexSchemeColor get _darkScheme => const FlexSchemeColor(
        primary: _secondaryContainer,
        primaryContainer: _primary,
        secondary: _secondary,
        secondaryContainer: _primaryContainer,
        tertiary: _tertiary,
        appBarColor: _primary,
      );

  static ThemeData light() {
    return FlexThemeData.light(
      colors: _lightScheme,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      appBarStyle: FlexAppBarStyle.primary,
      appBarOpacity: 1,
      appBarElevation: 0,
      tabBarStyle: FlexTabBarStyle.forAppBar,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: true,
      fontFamily: _fontFamily,
      subThemesData: const FlexSubThemesData(
        defaultRadius: 8,
        inputDecoratorRadius: 8,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        elevatedButtonRadius: 8,
        outlinedButtonRadius: 8,
        filledButtonRadius: 8,
        bottomNavigationBarSelectedLabelSize: 12,
        bottomNavigationBarUnselectedLabelSize: 11,
      ),
    );
  }

  static ThemeData dark() {
    return FlexThemeData.dark(
      colors: _darkScheme,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 13,
      appBarStyle: FlexAppBarStyle.background,
      appBarElevation: 0,
      tabBarStyle: FlexTabBarStyle.forAppBar,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: true,
      fontFamily: _fontFamily,
      subThemesData: const FlexSubThemesData(
        defaultRadius: 8,
        inputDecoratorRadius: 8,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        elevatedButtonRadius: 8,
        outlinedButtonRadius: 8,
        filledButtonRadius: 8,
        bottomNavigationBarSelectedLabelSize: 12,
        bottomNavigationBarUnselectedLabelSize: 11,
      ),
    );
  }
}
