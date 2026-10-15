import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soutracking_flutter/core/app_theme.dart';
import 'package:soutracking_flutter/core/white_label.dart';
import 'package:soutracking_flutter/data/models.dart';
import 'package:soutracking_flutter/features/devices/devices_screen.dart';
import 'package:soutracking_flutter/state/session_state.dart';

void main() {
  for (final size in [const Size(1366, 682), const Size(740, 900)]) {
    testWidgets(
        'Cadastro mantém campos entre seções e cancelar não salva em $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final fonts = FontLoader('DeviceEditorSegoe')
          ..addFont(rootBundle.load('assets/fonts/device-editor/segoeui.ttf'))
          ..addFont(rootBundle.load('assets/fonts/device-editor/seguisb.ttf'));
        await fonts.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      final container = ProviderContainer(overrides: [
        devicesManagementProvider.overrideWith((ref) async => [
              TraccarDevice(
                  id: 1,
                  name: 'Veículo de teste',
                  status: 'offline',
                  lastUpdate: null,
                  uniqueId: '123456789012345',
                  phone: '11999999999',
                  attributes: const {
                    'plate': 'ABC1D23',
                    'souPort': '6200',
                    'souOperator': 'vivo',
                    'souApn': 'custom.m2m',
                    'souSensors': ['ignition', 'input2']
                  })
            ]),
        positionsProvider.overrideWith((ref) async => [
              TraccarPosition(
                  id: 20,
                  deviceId: 1,
                  latitude: 0,
                  longitude: 0,
                  fixTime: '2026-10-14T10:00:00Z',
                  protocol: 'h02'),
            ]),
      ]);
      addTearDown(container.dispose);
      await container.read(devicesManagementProvider.future);
      await container.read(positionsProvider.future);
      final captureKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: captureKey,
          child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                  theme: buildAppTheme(WhiteLabelConfig.fallback),
                  home: const Scaffold(body: DevicesScreen())))));
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        if (size.width != 1366) return;
        await tester.runAsync(() async {
          final boundary = captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('C:/Projetos/docs/dispositivos-previa/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.tap(find.text('Novo Equipamento'));
      await tester.pumpAndSettle();
      await capture('aplicado-veiculo');
      final name = find.byWidgetPredicate((w) =>
          w is TextField && w.decoration?.labelText == 'Nome do Veículo *');
      await tester.enterText(name, 'Cadastro sem enviar');
      await tester.tap(find.text('Chip e equipamento'));
      await tester.pumpAndSettle();
      if (size.width == 1366) {
        final panel = find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_DeviceEditorLayout');
        expect(tester.getTopLeft(panel), const Offset(226, 104));
        expect(tester.getSize(panel), const Size(1104, 540));
        final phone = find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.labelText == 'Chip / Telefone');
        expect(tester.getTopLeft(phone), const Offset(436, 248));
        expect(tester.getSize(phone), const Size(317, 36));
        await tester.runAsync(() async {
          final boundary = captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  'C:/Projetos/docs/dispositivos-previa/aplicado-chip-e-equipamento.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(
          find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.labelText == 'APN'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Configurar Sensores'));
      await tester.pumpAndSettle();
      expect(find.text('SENSORES'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('aplicado-sensores');
      await tester.ensureVisible(find.byTooltip('Configurar').at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Configurar').at(2));
      await tester.pumpAndSettle();
      await capture('aplicado-configurar-sensor');
      final sensorName = find.byWidgetPredicate((w) =>
          w is TextField && w.decoration?.labelText == 'Nome de exibição');
      await tester.enterText(sensorName, 'Porta do motorista');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Porta do motorista'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Veículo'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(name).controller!.text,
          'Cadastro sem enviar');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Veículo de teste'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Editar').first);
      await tester.pumpAndSettle();
      expect(find.text('Checklist de edição'), findsOneWidget);
      expect(find.text('Status inicial'), findsNothing);
      expect(
          find.text(
              'Cadastre um novo rastreador e defina seus parâmetros iniciais.'),
          findsNothing);
      final checklist = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_ChecklistItem');
      expect((tester.widget(checklist.at(2)) as dynamic).checked, isFalse);
      await tester.tap(find.text('Chip e equipamento'));
      await tester.pumpAndSettle();
      Finder field(String label) => find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label);
      expect(
          tester.widget<TextField>(field('Chip / Telefone')).controller!.text,
          '11999999999');
      expect(tester.widget<TextField>(field('Porta')).controller!.text, '6200');
      expect(tester.widget<TextField>(field('APN')).controller!.text,
          'custom.m2m');
      expect(find.text('h02'), findsWidgets);
      expect(find.text('Só Traccar'), findsNothing);
      final operator = find.byWidgetPredicate((w) =>
          w.runtimeType.toString() == '_DeviceDropdown' &&
          (w as dynamic).label == 'Operadora');
      await tester.tap(operator);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Claro').last);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field('APN')).controller!.text,
          'claro.com.br');
      await tester.tap(find.text('Veículo'));
      await tester.pumpAndSettle();
      final picker = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_VehicleVisualPicker');
      final carIcon = find.descendant(
          of: picker,
          matching: find.byWidgetPredicate((w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/icons/map_sprites/car/car_0.png'));
      expect(carIcon, findsOneWidget);
      await tester.ensureVisible(carIcon);
      await tester.pumpAndSettle();
      await capture('aplicado-icones-originais');
      await tester.tap(find.text('Configurar Sensores'));
      await tester.pumpAndSettle();
      final customRow = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_SelectedSensorRow');
      await tester.ensureVisible(customRow);
      await tester.pumpAndSettle();
      expect(tester.getSize(customRow).height, 47); // 42 px row + 5 px spacing.
      expect(find.text('input2'), findsOneWidget);
      await capture('aplicado-sensores-personalizados');
      await tester.tap(find.byTooltip('Remover sensor'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remover sensor'), findsNothing);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
