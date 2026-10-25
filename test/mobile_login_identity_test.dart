import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soutracking_flutter/core/app_theme.dart';
import 'package:soutracking_flutter/core/white_label.dart';
import 'package:soutracking_flutter/features/login/login_screen.dart';
import 'white_label_identity_test.dart' show loadFonts;

void main() {
  Future<void> openLogin(
      WidgetTester tester, Size size, WhiteLabelConfig config) async {
    await loadFonts(tester);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(
        {'whiteLabelConfig': jsonEncode(config.toJson())});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(whiteLabelProvider);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: buildAppTheme(config), home: const LoginScreen())));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0]) {
    testWidgets(
        'Mobile login keeps desktop reference colors and usable fields at $width',
        (tester) async {
      await openLogin(tester, Size(width, 844), WhiteLabelConfig.fallback);
      expect(tester.takeException(), isNull);
      final fields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields, hasLength(2));
      for (final field in fields) {
        expect(field.cursorColor, const Color(0xFFF9C61B));
        expect(field.decoration!.focusedBorder!.borderSide.color,
            const Color(0xFFF9C61B));
      }
      expect(
          find.image(
              const AssetImage('assets/branding/login_pixel_reference.png')),
          findsOneWidget);
      expect(fields.last.obscureText, isTrue);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(
          tester.widgetList<TextField>(find.byType(TextField)).last.obscureText,
          isFalse);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.tap(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, 'teste@exemplo.com');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Entrar'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Desktop preserves the existing reference image and form',
      (tester) async {
    await openLogin(tester, const Size(1366, 768), WhiteLabelConfig.fallback);
    expect(
        find.image(
            const AssetImage('assets/branding/login_pixel_reference.png')),
        findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Custom brand keeps its configured submit color', (tester) async {
    final config = WhiteLabelConfig.fallback.copyWith(
        appName: 'Minha marca',
        primaryColor: const Color(0xFF008577),
        customPalette: true);
    await openLogin(tester, const Size(390, 844), config);
    expect(find.text('Minha marca'), findsOneWidget);
    expect(
        find.image(
            const AssetImage('assets/branding/login_pixel_reference.png')),
        findsNothing);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.style!.backgroundColor!.resolve({}), config.primaryColor);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
