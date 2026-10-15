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
import 'package:soutracking_flutter/data/bridge_client.dart';
import 'package:soutracking_flutter/data/models.dart';
import 'package:soutracking_flutter/features/alerts/alerts_screen.dart';
import 'package:soutracking_flutter/features/automations/automations_screen.dart';
import 'package:soutracking_flutter/features/calls/calls_screen.dart';
import 'package:soutracking_flutter/features/clients/clients_screen.dart';
import 'package:soutracking_flutter/features/clients/models/client_models.dart';
import 'package:soutracking_flutter/features/commands/commands_screen.dart';
import 'package:soutracking_flutter/features/dashboard/dashboard_screen.dart';
import 'package:soutracking_flutter/features/dashboard/executive_dashboard_screen.dart';
import 'package:soutracking_flutter/features/drivers/drivers_screen.dart';
import 'package:soutracking_flutter/features/drivers/models/driver_models.dart';
import 'package:soutracking_flutter/features/finance/finance_screen.dart';
import 'package:soutracking_flutter/features/geofences/geofences_screen.dart';
import 'package:soutracking_flutter/features/history/history_screen.dart';
import 'package:soutracking_flutter/features/inventory/inventory_screen.dart';
import 'package:soutracking_flutter/state/session_state.dart';

void main() {
  final screens = <String, Widget>{
    'eventos': const AlertsScreen(),
    'cercas': const GeofencesScreen(),
    'automacoes': const AutomationsScreen(),
    'comandos': const CommandsScreen(),
    'data-log': const HistoryScreen(),
    'dashboard': const DashboardScreen(),
    'executiva': const ExecutiveDashboardScreen(),
    'motoristas': const DriversScreen(),
    'clientes': const ClientsScreen(),
    'cobrancas': const FinanceScreen(),
    'estoque': const InventoryScreen(),
    'chamados': const CallsScreen(),
  };
  for (final size in [const Size(1104, 492), const Size(400, 700)]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} layout and existing navigation at $size',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          final fonts = FontLoader('DeviceEditorSegoe')
            ..addFont(rootBundle.load('assets/fonts/device-editor/segoeui.ttf'))
            ..addFont(
                rootBundle.load('assets/fonts/device-editor/seguisb.ttf'));
          await fonts.load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
        final d = TraccarDevice(
            id: 11,
            name: 'Veículo de teste com nome comprido',
            status: 'offline',
            lastUpdate: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
            uniqueId: '12345');
        final c = ClientRecord(
            traccarUserId: 21,
            name: 'Cliente de teste',
            email: 'cliente@example.invalid',
            phone: '11999999999',
            document: '123',
            clientType: ClientType.pj,
            address: 'Rua teste',
            city: 'São Paulo',
            state: 'SP',
            zip: '01000000',
            plan: ClientPlan.basic,
            asaasCustomerId: '',
            status: ClientStatus.active,
            deviceCount: 1,
            operatorCount: 0,
            disabled: false);
        final container = ProviderContainer(overrides: [
          devicesProvider.overrideWith((ref) async => [d]),
          positionsProvider.overrideWith((ref) async => <TraccarPosition>[]),
          alertsRealDevicesProvider.overrideWith((ref) async => [d]),
          alertsEventsByPeriodProvider.overrideWith((ref, period) async => [
                {
                  'id': 1,
                  'deviceId': 11,
                  'type': 'alarm',
                  'eventTime': DateTime.now().toIso8601String(),
                  'attributes': {'alarm': 'powerCut'}
                }
              ]),
          notificationsProvider
              .overrideWith((ref) async => <Map<String, dynamic>>[]),
          permissionsProvider
              .overrideWith((ref) async => <Map<String, dynamic>>[]),
          notificationsManagementProvider
              .overrideWith((ref) async => <Map<String, dynamic>>[]),
          geofencesProvider
              .overrideWith((ref) async => <Map<String, dynamic>>[]),
          savedCommandsProvider
              .overrideWith((ref) async => <Map<String, dynamic>>[]),
          bridgeRulesProvider.overrideWith((ref) async => <BridgeRule>[]),
          chamadosProvider.overrideWith((ref) async => ChamadosResult.empty),
          driversListProvider.overrideWith((ref) async => <DriverRecord>[]),
          clientsProvider.overrideWith((ref) async => [c]),
          financeApiServiceProvider.overrideWithValue(null),
          // Reading these fixture adapters in the production UI is a regression.
          financeChargesProvider.overrideWith((ref) async =>
              throw StateError('Fixture finances should not be queried')),
          inventoryItemsProvider.overrideWith((ref) async =>
              throw StateError('Fixture inventory should not be queried')),
        ]);
        addTearDown(container.dispose);
        await container.read(devicesProvider.future);
        await container.read(positionsProvider.future);
        await container.read(alertsRealDevicesProvider.future);
        await container.read(clientsProvider.future);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
            key: key,
            child: UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                    theme: buildAppTheme(WhiteLabelConfig.fallback),
                    home: Scaffold(body: entry.value)))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width > 1000) {
          await tester.runAsync(() async {
            final image = await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
                    'C:/Projetos/docs/revisao-interface/aplicada-${entry.key}.png')
                .writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        if (entry.key == 'eventos') {
          await tester.tap(find.text('Criar alerta'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Salvar Alerta'), findsOneWidget);
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
          expect(find.text('Eventos'), findsWidgets);
        }
        if (entry.key == 'comandos') {
          final send = find.widgetWithText(FilledButton, 'Enviar comando');
          if (send.evaluate().isNotEmpty)
            expect(tester.widget<FilledButton>(send).onPressed, isNull);
          await tester.tap(find.text('Criar Comando'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Salvar comando'), findsOneWidget);
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
        }
        if (entry.key == 'cercas') {
          await tester.tap(find.text('Adicionar cerca'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Salvar cerca'), findsOneWidget);
          final shape = find.byType(DropdownButtonFormField<String>).last;
          await tester.ensureVisible(shape);
          await tester.tap(shape);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Poligonal').last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Pontos'), findsOneWidget);
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
          expect(find.text('Cercas eletrônicas'), findsOneWidget);
        }
        if (entry.key == 'automacoes') {
          await tester.tap(find.text('Nova regra'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Nova regra'), findsOneWidget);
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
        }
        if (entry.key == 'clientes') {
          await tester.tap(find.text('Cliente de teste'));
          await tester.pumpAndSettle();
          expect(find.text('Resumo do cliente'), findsNothing);
          await tester.tap(find.text('Novo cliente'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Criar Cliente'), findsOneWidget);
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byTooltip('Editar'));
          await tester.tap(find.byTooltip('Editar'));
          await tester.pumpAndSettle();
          expect(find.text('Cliente de teste'), findsWidgets);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
        }
        if (entry.key == 'executiva') {
          await tester.tap(find.text('7 dias'));
          await tester.pumpAndSettle();
          expect(find.textContaining('últimos 7 dias'), findsOneWidget);
          expect(find.text('Km rodados'), findsNothing);
          expect(
              tester
                  .widget<OutlinedButton>(
                      find.widgetWithText(OutlinedButton, 'Exportar PDF'))
                  .onPressed,
              isNull);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}
