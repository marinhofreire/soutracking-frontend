import 'package:flutter/material.dart';

import 'white_label.dart';

ThemeData buildAppTheme(WhiteLabelConfig config) {
  const base = Color(0xFFF2F6FC);
  const surface = Color(0xF2FFFFFF);
  const card = Color(0xD9FFFFFF);
  const border = Color(0xFFD6E2F2);
  const menuSurface = Color(0xF5FFFFFF);
  const menuSelected = Color(0xFF1F6FEB);
  final accent = config.primaryColor;

  final colorScheme = const ColorScheme.light().copyWith(
    primary: accent,
    secondary: config.secondaryColor,
    surface: surface,
    outline: border,
    onSurface: const Color(0xFF1F2A44),
    onPrimary: Colors.white,
  );

  final standardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  );

  return ThemeData(
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: base,
    useMaterial3: true,
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: Color(0xFF1F2A44),
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: Color(0xFF1F2A44),
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        color: Color(0xFF2F3F59),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: TextStyle(
        color: Color(0xFF3D506D),
        fontSize: 13.5,
      ),
      bodySmall: TextStyle(
        color: Color(0xFF60718D),
        fontSize: 12,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white.withValues(alpha: 0.78),
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Color(0xFF324968)),
      titleTextStyle: const TextStyle(
        color: Color(0xFF1F2A44),
        fontWeight: FontWeight.w800,
        fontSize: 17,
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.62),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: accent, width: 1.2),
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF7A8EA9),
        fontWeight: FontWeight.w500,
      ),
      labelStyle: const TextStyle(
        color: Color(0xFF4B5C77),
        fontWeight: FontWeight.w600,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: menuSurface,
      textStyle: const TextStyle(color: Color(0xFF1F2A44), fontSize: 13.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x55CFE0F5)),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(menuSurface),
        side: const WidgetStatePropertyAll(
          BorderSide(color: Color(0x55CFE0F5)),
        ),
      ),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      textStyle: TextStyle(color: Color(0xFF1F2A44), fontSize: 13.5),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF324968),
      textColor: Color(0xFF1F2A44),
      selectedColor: Color(0xFF176EEB),
      selectedTileColor: Color(0x261F6FEB),
    ),
    navigationDrawerTheme: const NavigationDrawerThemeData(
      backgroundColor: menuSurface,
      indicatorColor: Color(0x261F6FEB),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: menuSelected,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 40),
        shape: standardShape,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1F2A44),
        minimumSize: const Size(0, 40),
        side: const BorderSide(color: Color(0xFFBDD0E8)),
        shape: standardShape,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: menuSelected,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 40),
        shape: standardShape,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    dataTableTheme: const DataTableThemeData(
      headingTextStyle: TextStyle(
        color: Color(0xFF324968),
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
      dataTextStyle: TextStyle(
        color: Color(0xFF23324B),
        fontWeight: FontWeight.w500,
        fontSize: 12.5,
      ),
      headingRowColor: WidgetStatePropertyAll(Color(0x99FFFFFF)),
      dividerThickness: 0.8,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.72),
      selectedColor: const Color(0x261F6FEB),
      labelStyle: const TextStyle(
        color: Color(0xFF2F3F59),
        fontWeight: FontWeight.w600,
      ),
      side: const BorderSide(color: Color(0xFFCCDDF2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    dividerColor: border,
  );
}
