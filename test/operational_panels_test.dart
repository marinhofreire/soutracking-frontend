import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soutracking_flutter/core/app_theme.dart';
import 'package:soutracking_flutter/core/white_label.dart';
import 'package:soutracking_flutter/data/bridge_client.dart';
import 'package:soutracking_flutter/data/models.dart';
import 'package:soutracking_flutter/features/assist/assist_create_request_screen.dart';
import 'package:soutracking_flutter/features/assist/assist_dispatch_state.dart';
import 'package:soutracking_flutter/features/assist/assist_request_detail_screen.dart';
import 'package:soutracking_flutter/features/assist/assist_requests_screen.dart';
import 'package:soutracking_flutter/features/communication/communication_screen.dart';
import 'package:soutracking_flutter/features/master_panel/master_panel_screen.dart';
import 'package:soutracking_flutter/features/mdvr/mdvr_device_detail_screen.dart';
import 'package:soutracking_flutter/features/mdvr/mdvr_devices_screen.dart';
import 'package:soutracking_flutter/state/session_state.dart';

void main() {
  final screens = <String, Widget>{
    'master': const MasterPanelScreen(),
    'demandas': const AssistRequestsScreen(),
    'criar-chamado': const AssistCreateRequestScreen(),
    'detalhes-chamado': const AssistRequestDetailScreen(requestId: '1001'),
    'comunicacao': const CommunicationScreen(),
    'mdvr': const MdvrDevicesScreen(),
    'detalhes-mdvr': const MdvrDeviceDetailScreen(deviceId: '1'),
  };
  for (final size in [const Size(1104, 492), const Size(400, 700)]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} preserves controls at $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          final font = FontLoader('DeviceEditorSegoe')
            ..addFont(
                rootBundle.load('assets/fonts/device-editor/segoeui.ttf'));
          await font.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
        final device = TraccarDevice(
            id: 1,
            name: 'Câmera teste',
            status: 'online',
            lastUpdate: null,
            uniqueId: '12345',
            attributes: const {'souIsMdvr': true});
        final ticket = SoucallTicket(
            id: 1,
            contactName: 'Contato teste',
            lastMessage: 'Mensagem recebida',
            status: 'open',
            unreadMessages: 1,
            updatedAt: DateTime.now(),
            channel: 'WhatsApp',
            isGroup: true);
        final container = ProviderContainer(overrides: [
          devicesProvider.overrideWith((ref) async => [device]),
          positionsProvider.overrideWith((ref) async => <TraccarPosition>[]),
          notificationsProvider
              .overrideWith((ref) async => <Map<String, dynamic>>[]),
          soucallTicketsProvider.overrideWith((ref) async => [ticket]),
          chamadosProvider.overrideWith((ref) async => ChamadosResult.empty),
        ]);
        addTearDown(container.dispose);
        await container.read(devicesProvider.future);
        await container.read(positionsProvider.future);
        await container.read(notificationsProvider.future);
        final imageKey = GlobalKey();
        String? openedRoute;
        await tester.pumpWidget(RepaintBoundary(
          key: imageKey,
          child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: buildAppTheme(WhiteLabelConfig.fallback),
                onGenerateRoute: (settings) {
                  openedRoute = settings.name;
                  return MaterialPageRoute<void>(
                      settings: settings,
                      builder: (_) => const Scaffold(body: Text('Destino')));
                },
                home: Scaffold(body: entry.value),
              )),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width >= 1000) {
          await tester.runAsync(() async {
            final image = await (imageKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File('C:/Projetos/docs/padroes-${entry.key}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        if (entry.key == 'demandas') {
          await tester.tap(find.text('Criar chamado'));
          await tester.pumpAndSettle();
          expect(openedRoute, '/assist/create');
        } else if (entry.key == 'criar-chamado') {
          expect(find.text('Criar e despachar agora').hitTestable(),
              findsOneWidget);
          final latitude = find.widgetWithText(TextField, 'Latitude');
          await tester.ensureVisible(latitude);
          await tester.enterText(latitude, 'inválido');
          await tester.tap(find.text('Criar e despachar agora'));
          await tester.pumpAndSettle();
          expect(container.read(assistDispatchProvider).requests.length, 2);
        } else if (entry.key == 'detalhes-chamado') {
          expect(find.text('Avançar status').hitTestable(), findsOneWidget);
          expect(find.text('Redespachar mais próximo').hitTestable(),
              findsOneWidget);
        } else if (entry.key == 'comunicacao') {
          await tester.tap(find.text('Notificações'));
          await tester.pumpAndSettle();
          expect(find.text('Nova mensagem'), findsOneWidget);
          await tester.tap(find.text('Histórico'));
          await tester.pumpAndSettle();
          expect(find.text('Histórico de envios'), findsOneWidget);
        } else if (entry.key == 'mdvr') {
          await tester.enterText(find.byType(TextField), 'inexistente');
          await tester.pumpAndSettle();
          expect(find.text('Nenhum dispositivo encontrado.'), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'Câmera');
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Detalhes').first);
          await tester.pumpAndSettle();
          expect(openedRoute, '/mdvr/device/1');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
