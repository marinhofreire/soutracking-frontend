import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soutracking_flutter/core/app_theme.dart';
import 'package:soutracking_flutter/core/white_label.dart';
import 'package:soutracking_flutter/data/models.dart';
import 'package:soutracking_flutter/features/master_panel/superadmin_empresas_screen.dart';
import 'package:soutracking_flutter/state/session_state.dart';

void main() {
  for (final size in [const Size(1366, 682), const Size(400, 700)]) {
    testWidgets('Company creation, modules and keys at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final font = FontLoader('DeviceEditorSegoe')
          ..addFont(rootBundle.load('assets/fonts/device-editor/segoeui.ttf'));
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      final user = TraccarUser(
          id: 4,
          name: 'Empresa teste',
          email: 'teste@example.com',
          administrator: false,
          readonly: false,
          disabled: false,
          userLimit: 5,
          deviceLimit: 20,
          attributes: {
            'sou_modules': 'soutracking',
            'sou_key_ia': 'test-only-key'
          });
      final container = ProviderContainer(overrides: [
        usersProvider.overrideWith((ref) async => [user]),
      ]);
      addTearDown(container.dispose);
      await container.read(usersProvider.future);
      final imageKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: imageKey,
        child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: buildAppTheme(WhiteLabelConfig.fallback),
              home: const Scaffold(body: SuperadminEmpresasScreen()),
            )),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Empresa teste'), findsOneWidget);
      await tester.tap(find.text('Criar empresa'));
      await tester.pumpAndSettle();
      expect(find.text('Criar').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();
      expect(
          find.text('Nome, e-mail e senha são obrigatórios.'), findsOneWidget);
      final fields = find.descendant(
          of: find.byType(Dialog), matching: find.byType(TextField));
      await tester.enterText(fields.first, 'Empresa nova');
      if (size.width >= 1000) {
        final souCall = find.descendant(
            of: find.byType(Dialog),
            matching: find.text('Comunicação (SouCall)'));
        await tester.tap(souCall);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextField, 'Token SouCall'), findsOneWidget);
        expect(tester.widget<TextField>(fields.first).controller!.text,
            'Empresa nova');
        await tester.tap(find.descendant(
            of: find.byType(Dialog), matching: find.text('Demandas')));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextField, 'Chave de integração SouFind'),
            findsOneWidget);
        expect(find.text('Criar').hitTestable(), findsOneWidget);
        await tester.runAsync(() async {
          final image = await (imageKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('C:/Projetos/docs/empresas-cadastro-aplicado.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      await tester.tap(find.text('Chaves'));
      await tester.pumpAndSettle();
      final keys =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(keys.length, 3);
      expect(keys.every((f) => f.obscureText), isTrue);
      expect(keys.first.controller!.text, 'test-only-key');
      expect(find.text('Salvar').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
