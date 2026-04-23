import 'package:flutter/material.dart';

import 'white_label.dart';

ThemeData buildAppTheme(WhiteLabelConfig config) {
  const base = Color(0xFF0A0A0A);
  const surface = Color(0xFF12161D);
  const card = Color(0xFF1A1A1A);
  const border = Color(0xFF2A2A2A);
  const menuSurface = Color(0xFF12161D);
  const menuSelected = Color(0xFF1F6FEB);
  final accent = config.primaryColor;

  final colorScheme = const ColorScheme.dark().copyWith(
    primary: accent,
    secondary: config.secondaryColor,
    surface: surface,
    outline: border,
  );

  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: base,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: base,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.2),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: menuSurface,
      textStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x33FFFFFF)),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(menuSurface),
        side: const WidgetStatePropertyAll(
          BorderSide(color: Color(0x33FFFFFF)),
        ),
      ),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      textStyle: TextStyle(color: Colors.white),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Colors.white,
      textColor: Colors.white,
      selectedColor: Color(0xFF8EC5FF),
      selectedTileColor: Color(0x3D1F6FEB),
    ),
    navigationDrawerTheme: const NavigationDrawerThemeData(
      backgroundColor: menuSurface,
      indicatorColor: Color(0x3D1F6FEB),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: menuSelected,
        foregroundColor: Colors.white,
      ),
    ),
    dividerColor: border,
  );
}
