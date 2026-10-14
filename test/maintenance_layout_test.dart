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
import 'package:soutracking_flutter/features/maintenance/maintenance_screen.dart';
import 'package:soutracking_flutter/state/session_state.dart';

void main() {
  for (final size in [const Size(1104, 492), const Size(400, 700)]) {
    testWidgets('Maintenance selection and layout at $size', (tester) async {
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
      final container = ProviderContainer(overrides: [
        maintenanceProvider.overrideWith((ref) async => <Map<String, dynamic>>[
              {
                'id': 1,
                'name': 'Troca de óleo do motor',
                'type': 'distance',
                'start': 2000,
                'period': 10000,
                'deviceId': 1
              },
            ]),
        devicesProvider.overrideWith((ref) async => <TraccarDevice>[]),
      ]);
      addTearDown(container.dispose);
      await container.read(maintenanceProvider.future);
      await container.read(devicesProvider.future);
      final imageKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: imageKey,
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: buildAppTheme(WhiteLabelConfig.fallback),
              home: const Scaffold(body: MaintenanceScreen()),
            ),
          )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Usar').first);
      await tester.pumpAndSettle();
      final fields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[0].controller!.text, 'Troca de óleo do motor');
      expect(fields[2].controller!.text, '10000');
      if (size.width >= 1000) {
        await tester.runAsync(() async {
          final image = await (imageKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('C:/Projetos/docs/manutencao-aplicada.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(find.text('Criar plano').hitTestable(), findsOneWidget);
        expect(find.byType(TextField).first.hitTestable(), findsOneWidget);
        final formPosition = tester.getTopLeft(find.byType(TextField).first);
        final catalog = find.byType(ListView).first;
        await tester.drag(catalog, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byType(TextField).first), formPosition);
        await tester.tap(find.text('Usar').hitTestable().first);
        await tester.pumpAndSettle();
        expect(fields[0].controller!.text, isNot('Troca de óleo do motor'));
        expect(find.text('Criar plano').hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
