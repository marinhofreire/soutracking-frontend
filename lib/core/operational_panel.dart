import 'package:flutter/material.dart';

/// Visual scope for the panels being aligned with the approved settings UI.
class OperationalPanel extends StatelessWidget {
  const OperationalPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1F2A44);
    const muted = Color(0xFF60718D);
    const line = Color(0xFFDDE5F0);
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 760;
    final blue = theme.colorScheme.primary;
    final selectedSurface = blue.withValues(alpha: .08);
    final textTheme = theme.textTheme.apply(
        fontFamily: 'DeviceEditorSegoe', bodyColor: ink, displayColor: ink);
    const buttonText = TextStyle(
        fontFamily: 'DeviceEditorSegoe',
        fontSize: 11,
        fontWeight: FontWeight.w600);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
            surface: Colors.white,
            onSurface: ink,
            outline: line,
            primary: blue,
            secondaryContainer: selectedSurface,
            onSecondaryContainer: blue),
        textTheme: textTheme.copyWith(
          headlineSmall: textTheme.headlineSmall
              ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
          titleMedium: textTheme.titleMedium
              ?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
          bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 12),
          bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 11),
          bodySmall: textTheme.bodySmall?.copyWith(fontSize: 10, color: muted),
        ),
        visualDensity: VisualDensity.compact,
        chipTheme: theme.chipTheme.copyWith(
          backgroundColor: const Color(0xFFF7F9FC),
          selectedColor: selectedSurface,
          labelStyle: buttonText.copyWith(color: muted),
          side: const BorderSide(color: line),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
            style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(buttonText),
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? selectedSurface
                  : Colors.white),
          foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? blue : muted),
          side: const WidgetStatePropertyAll(BorderSide(color: line)),
          shape: WidgetStatePropertyAll(shape),
        )),
        cardTheme: CardThemeData(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
                side: const BorderSide(color: line))),
        dividerTheme: const DividerThemeData(color: line, thickness: 1),
        dialogTheme: DialogThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: buttonText.copyWith(fontSize: 13, color: blue),
            contentTextStyle:
                buttonText.copyWith(fontWeight: FontWeight.w400, color: ink),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF7F9FC),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          labelStyle: TextStyle(
              fontFamily: 'DeviceEditorSegoe', fontSize: 11, color: muted),
          hintStyle: TextStyle(
              fontFamily: 'DeviceEditorSegoe', fontSize: 11, color: muted),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: blue)),
        ),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                minimumSize: const Size(0, 33),
                textStyle: buttonText,
                shape: shape)),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 33),
                textStyle: buttonText,
                shape: shape,
                side: const BorderSide(color: line),
                foregroundColor: muted)),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(textStyle: buttonText, shape: shape)),
        listTileTheme: const ListTileThemeData(
            iconColor: muted,
            textColor: ink,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
      ),
      child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle(
              style: const TextStyle(
                  fontFamily: 'DeviceEditorSegoe', fontSize: 11, color: ink),
              child: Padding(
                  padding: EdgeInsets.all(compact ? 8 : 16), child: child))),
    );
  }
}

class OperationalPage extends StatelessWidget {
  const OperationalPage(
      {super.key,
      required this.header,
      required this.body,
      required this.footer});
  final Widget header;
  final Widget body;
  final Widget footer;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        const SizedBox(height: 12),
        Expanded(child: body),
        Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFDDE5F0)))),
            child: footer),
      ]);
}

class OperationalColumns extends StatelessWidget {
  const OperationalColumns(
      {super.key, required this.left, required this.right});
  final Widget left;
  final Widget right;

  Widget _card(Widget child) =>
      Card(child: Padding(padding: const EdgeInsets.all(16), child: child));

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                _card(left),
                const SizedBox(height: 12),
                _card(right),
                const SizedBox(height: 12)
              ]));
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: SingleChildScrollView(child: _card(left))),
          const SizedBox(width: 12),
          Expanded(child: SingleChildScrollView(child: _card(right))),
        ]);
      });
}
