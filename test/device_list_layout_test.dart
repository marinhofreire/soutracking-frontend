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
import 'package:soutracking_flutter/features/devices/devices_screen.dart';
import 'package:soutracking_flutter/state/session_state.dart';

void main() {
  testWidgets('Lista mantém busca, filtros, exportação e ações fixas',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 682);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final font = FontLoader('DeviceEditorSegoe')
        ..addFont(rootBundle.load('assets/fonts/device-editor/segoeui.ttf'))
        ..addFont(rootBundle.load('assets/fonts/device-editor/seguisb.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    final devices = [
      for (var i = 0; i < 3; i++)
        TraccarDevice(
            id: i + 1,
            name: i == 0 ? 'Andre Galante' : 'Estoque NT40 - 0$i',
            status: 'offline',
            lastUpdate: null,
            uniqueId: '12345678901234$i',
            attributes: const {'plate': 'ABC1D23'})
    ];
    final container = ProviderContainer(overrides: [
      devicesManagementProvider.overrideWith((ref) async => devices),
      positionsProvider.overrideWith((ref) async => <TraccarPosition>[])
    ]);
    addTearDown(container.dispose);
    await container.read(devicesManagementProvider.future);
    await container.read(positionsProvider.future);
    final key = GlobalKey();
    final app = MaterialApp(
        theme: buildAppTheme(WhiteLabelConfig.fallback),
        home: const Scaffold(
            body: Center(
                child: SizedBox(
                    width: 1104, height: 492, child: DevicesScreen()))));
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: UncontrolledProviderScope(container: container, child: app)));
    await tester.pumpAndSettle();
    final metrics = find
        .byWidgetPredicate((w) => w.runtimeType.toString() == '_MetricCard');
    expect(metrics, findsNWidgets(6));
    for (var i = 1; i < 6; i++) {
      expect(tester.getTopLeft(metrics.at(i)).dy,
          tester.getTopLeft(metrics.first).dy);
    }
    expect(find.text('3 de 3 equipamentos'), findsOneWidget);
    expect(find.byTooltip('Editar'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
              'C:/Projetos/docs/dispositivos-lista-previa/aplicado-lista.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    final search = find.byWidgetPredicate((w) =>
        w is TextField &&
        w.decoration?.hintText == 'Buscar equipamento, IMEI ou placa...');
    await tester.enterText(search, 'Estoque');
    await tester.pumpAndSettle();
    expect(find.text('2 de 3 equipamentos'), findsOneWidget);
    expect(find.byTooltip('Editar'), findsNWidgets(2));
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.text('Exportar'));
    await tester.pumpAndSettle();
    expect(copied, contains('Estoque NT40 - 01'));
    expect(copied, contains('Estoque NT40 - 02'));
    expect(copied, isNot(contains('Andre Galante')));
    await tester.enterText(search, '');
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Online (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum equipamento encontrado com os filtros atuais.'),
        findsOneWidget);
    expect(find.text('0 de 3 equipamentos'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Todos os status (3)'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Editar'), findsNWidgets(3));
    final horizontal = find.byWidgetPredicate((w) =>
        w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
    await tester.drag(horizontal, const Offset(-700, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar').first);
    await tester.pumpAndSettle();
    expect(find.text('Editar equipamento'), findsWidgets);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
