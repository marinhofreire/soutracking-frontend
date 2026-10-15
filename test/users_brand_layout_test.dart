import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soutracking_flutter/core/app_theme.dart';
import 'package:soutracking_flutter/core/white_label.dart';
import 'package:soutracking_flutter/data/models.dart';
import 'package:soutracking_flutter/data/traccar_client.dart';
import 'package:soutracking_flutter/features/users/users_screen.dart';
import 'package:soutracking_flutter/features/settings/settings_screen.dart';
import 'package:soutracking_flutter/state/session_state.dart';
import 'package:soutracking_flutter/ui/brand_logo.dart';

class _RecordingClient extends TraccarClient {
  _RecordingClient() : super(baseUrl: 'http://localhost/test');
  Map<String, dynamic>? updated;
  int writes = 0;
  @override
  Future<Map<String, dynamic>> updateEntityById(
      {required String path,
      required int id,
      String? cookie,
      String? authHeader,
      required Map<String, dynamic> body}) async {
    writes++;
    updated = body;
    return body;
  }
}

Future<void> _fonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    await (FontLoader('DeviceEditorSegoe')
          ..addFont(rootBundle.load('assets/fonts/device-editor/segoeui.ttf'))
          ..addFont(rootBundle.load('assets/fonts/device-editor/seguisb.ttf')))
        .load();
    var fontRoot = File(Platform.resolvedExecutable).parent;
    while (!File('${fontRoot.path}/artifacts/material_fonts/roboto-regular.ttf')
        .existsSync()) {
      if (fontRoot.parent.path == fontRoot.path)
        throw StateError('Flutter material fonts not found');
      fontRoot = fontRoot.parent;
    }
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.sublistView(await File(
                  '${fontRoot.path}/artifacts/material_fonts/roboto-regular.ttf')
              .readAsBytes()))))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
}

Finder _field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label);
Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final destination = Platform.environment['SOUTRACKING_CAPTURE_DIR'];
  if (destination == null) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$destination/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final size in [
    const Size(1104, 540),
    const Size(740, 650),
    const Size(400, 760)
  ]) {
    testWidgets('Users layout, forms and existing edit payload at $size',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _fonts(tester);
      final user = TraccarUser(
          id: 8,
          name: 'Pessoa de teste',
          email: 'contato.com.nome.comprido@example.invalid',
          administrator: false,
          readonly: false,
          disabled: false,
          attributes: {
            'soutracking_role': 'operator',
            'existing_key': 'preservar',
            'souExecutiveView': false
          });
      final client = _RecordingClient();
      final container = ProviderContainer(overrides: [
        usersProvider.overrideWith((ref) async => [user]),
        traccarClientProvider.overrideWithValue(client)
      ]);
      addTearDown(container.dispose);
      await container.read(usersProvider.future);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                  theme: buildAppTheme(WhiteLabelConfig.fallback),
                  home: const Scaffold(body: UsersScreen())))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('/2024'), findsNothing);
      await tester.tap(find.text('Pessoa de teste'));
      await tester.pumpAndSettle();
      expect(find.text('Bloqueada'), findsOneWidget);
      if (size.width < 932)
        expect(find.text('Bloqueada').hitTestable(), findsOneWidget);
      if (size.width > 1000) await _capture(tester, key, 'usuarios-aplicado');
      await tester.tap(find.text('Novo usuário'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_field('Nome'), findsOneWidget);
      await tester.enterText(_field('Nome'), 'Cadastro de teste');
      await tester.pumpAndSettle();
      expect(find.text('Cadastro de teste'), findsWidgets);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(client.writes, 0);
      await tester.ensureVisible(find.byTooltip('Editar'));
      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_field('Nome')).controller!.text,
          'Pessoa de teste');
      final toggle = find.byType(SwitchListTile);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      if (size.width > 1000)
        await _capture(tester, key, 'usuario-editar-aplicado');
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(client.writes, 1);
      expect(client.updated!['attributes'],
          containsPair('existing_key', 'preservar'));
      expect(client.updated!['attributes'],
          containsPair('souExecutiveView', true));
      expect(client.updated!['administrator'], false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
    testWidgets(
        'Brand preview renders asset and follows existing fields at $size',
        (tester) async {
      final config = WhiteLabelConfig.fallback.copyWith(
          logoAsset: 'assets/branding/soutracking_logo_horizontal.png');
      SharedPreferences.setMockInitialValues(
          {'whiteLabelConfig': jsonEncode(config.toJson())});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _fonts(tester);
      final container = ProviderContainer(overrides: [
        usersProvider.overrideWith((ref) async => <TraccarUser>[])
      ]);
      addTearDown(container.dispose);
      container.read(whiteLabelProvider);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                  theme: buildAppTheme(config),
                  home: Scaffold(body: SettingsScreen(onLogout: () {}))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Não foi possível abrir esta imagem.'), findsNothing);
      expect(find.byType(BrandLogo), findsWidgets);
      await tester.runAsync(() async {
        for (final path in [
          'assets/branding/soutracking_logo_transparent.png',
          'assets/branding/soutracking_logo_dark.png'
        ]) {
          await precacheImage(
              AssetImage(path), tester.element(find.byType(SettingsScreen)));
        }
      });
      await tester.pumpAndSettle();
      await tester.ensureVisible(_field('Nome da empresa'));
      await tester.enterText(_field('Nome da empresa'), 'Minha marca');
      await tester.pumpAndSettle();
      expect(find.text('Minha marca'), findsWidgets);
      if (size.width > 1000) await _capture(tester, key, 'marca-aplicada');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets('Uploaded image stays a memory image without an HTTP request',
      (tester) async {
    final bytes = File('assets/branding/soutracking_logo_transparent.png')
        .readAsBytesSync();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BrandLogo(
                source: 'data:image/png;base64,${base64Encode(bytes)}',
                name: 'Minha marca'))));
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
    expect(tester.takeException(), isNull);
  });
}
