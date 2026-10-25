import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soutracking_flutter/core/app_theme.dart';
import 'package:soutracking_flutter/core/white_label.dart';
import 'package:soutracking_flutter/data/models.dart';
import 'package:soutracking_flutter/state/session_state.dart';
import 'package:soutracking_flutter/features/settings/settings_screen.dart';
import 'white_label_identity_test.dart' show loadFonts;

void main() {
  for (final width in [320.0, 390.0, 1104.0]) {
    testWidgets('All settings tabs fit $width without writing preferences',
        (tester) async {
      final previousHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        debugPrint(details.toString());
        previousHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousHandler);
      await loadFonts(tester);
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues(
          {'whiteLabelConfig': jsonEncode(WhiteLabelConfig.fallback.toJson())});
      final container = ProviderContainer(overrides: [
        usersProvider.overrideWith((ref) async => <TraccarUser>[])
      ]);
      addTearDown(container.dispose);
      container.read(whiteLabelProvider);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              theme: buildAppTheme(WhiteLabelConfig.fallback),
              home: Scaffold(body: SizedBox(width: width >= 1000 ? 700 : width, child: SettingsScreen(onLogout: () {}))))));
      await tester.pumpAndSettle();
      for (final label in [
        'Geral',
        'Perfil',
        'Usuários',
        'Permissões',
        'Integrações',
        'Notificações',
        'Segurança'
      ]) {
        final tab = find.widgetWithText(Tab, label);
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Tab $label at $width');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
