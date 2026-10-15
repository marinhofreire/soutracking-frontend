import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soutracking_flutter/core/app_theme.dart';
import 'package:soutracking_flutter/core/operational_panel.dart';
import 'package:soutracking_flutter/core/white_label.dart';
import 'package:soutracking_flutter/data/models.dart';
import 'package:soutracking_flutter/features/admin/admin_reference_ui.dart';
import 'package:soutracking_flutter/features/settings/settings_screen.dart';
import 'package:soutracking_flutter/state/session_state.dart';
import 'package:soutracking_flutter/ui/module_scaffold.dart';

Future<void> loadFonts(WidgetTester tester) => tester.runAsync(() async {
      await (FontLoader('DeviceEditorSegoe')
            ..addFont(
                rootBundle.load('assets/fonts/device-editor/segoeui.ttf')))
          .load();
      var root = File(Platform.resolvedExecutable).parent;
      while (!File('${root.path}/artifacts/material_fonts/roboto-regular.ttf')
          .existsSync()) {
        if (root.parent.path == root.path)
          throw StateError('Flutter fonts not found');
        root = root.parent;
      }
      await (FontLoader('Roboto')
            ..addFont(Future.value(ByteData.sublistView(await File(
                    '${root.path}/artifacts/material_fonts/roboto-regular.ttf')
                .readAsBytes()))))
          .load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Existing brand preferences survive new assets and controller reload',
      () async {
    SharedPreferences.setMockInitialValues({
      'whiteLabelConfig': jsonEncode({
        'appName': 'Marca antiga',
        'tagline': 'Descrição',
        'primaryColor': '#7C3AED',
        'secondaryColor': '#0F766E',
        'homeHubId': 'fleet',
        'logoAsset': 'logo.png'
      })
    });
    final first = ProviderContainer();
    final controller = first.read(whiteLabelProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final old = first.read(whiteLabelProvider).requireValue;
    expect(old.symbolAsset, isNull);
    expect(old.homeHubId, 'fleet');
    await controller.save(old.copyWith(
        primaryColor: const Color(0xFF7C5CFF),
        customPalette: true,
        symbolAsset: 'symbol.svg',
        darkLogoAsset: 'dark.png'));
    first.dispose();
    final second = ProviderContainer();
    second.read(whiteLabelProvider);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final restored = second.read(whiteLabelProvider).requireValue;
    expect(restored.appName, 'Marca antiga');
    expect(restored.homeHubId, 'fleet');
    expect(restored.logoAsset, 'logo.png');
    expect(restored.symbolAsset, 'symbol.svg');
    expect(restored.darkLogoAsset, 'dark.png');
    expect(restored.primaryColor, const Color(0xFF7C5CFF));
    second.dispose();
  });

  testWidgets('Panel controls follow a custom brand and preserve status colors',
      (tester) async {
    await loadFonts(tester);
    final config = WhiteLabelConfig.fallback
        .copyWith(primaryColor: const Color(0xFFEAB308));
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(config),
        home: Scaffold(
            body: OperationalPanel(
                child: Column(children: [
          AdminActionButton(label: 'Ação existente', onPressed: () {}),
          ModuleListItem(title: 'Selecionado', selected: true, onTap: () {}),
          const ModuleStatusChip('Crítico', tone: ModuleTone.critical)
        ])))));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style!.backgroundColor!.resolve({}), config.primaryColor);
    expect(button.style!.foregroundColor!.resolve({}), Colors.black);
    final status = tester.widget<Container>(find
        .descendant(
            of: find.byType(ModuleStatusChip), matching: find.byType(Container))
        .first);
    expect(
        (status.decoration! as BoxDecoration).color, const Color(0xFFFDECEC));
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(1104, 540), const Size(400, 760)]) {
    testWidgets('Brand fields, picker, invalid hex and save at $size',
        (tester) async {
      await loadFonts(tester);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final config = WhiteLabelConfig.fallback.copyWith(
          homeHubId: 'fleet',
          symbolAsset:
              'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg"/>',
          darkLogoAsset:
              'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg"/>');
      SharedPreferences.setMockInitialValues(
          {'whiteLabelConfig': jsonEncode(config.toJson())});
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
              theme: buildAppTheme(config),
              home: Scaffold(body: SettingsScreen(onLogout: () {})))));
      await tester.pumpAndSettle();
      final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Cor primária');
      await tester.ensureVisible(field);
      await tester.enterText(field, '#GGGGGG');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(field, '#FDE047');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Escolher Cor primária'));
      await tester.pumpAndSettle();
      expect(find.text('Usar esta cor'), findsOneWidget);
      await tester.tap(find.text('Usar esta cor'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Salvar marca'));
      await tester.tap(find.text('Salvar marca'));
      await tester.pumpAndSettle();
      final saved = container.read(whiteLabelProvider).requireValue;
      expect(saved.primaryColor, const Color(0xFFFDE047));
      expect(saved.symbolAsset, config.symbolAsset);
      expect(saved.darkLogoAsset, config.darkLogoAsset);
      expect(saved.homeHubId, 'fleet');
      expect(tester.takeException(), isNull);
    });
  }
}
