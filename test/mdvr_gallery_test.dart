import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soutracking_flutter/data/bridge_config.dart';
import 'package:soutracking_flutter/data/models.dart';
import 'package:soutracking_flutter/features/mdvr/mdvr_devices_screen.dart';
import 'package:soutracking_flutter/state/session_state.dart';

TraccarDevice vehicle(int id, String name, {bool camera = true}) =>
    TraccarDevice(
      id: id,
      name: name,
      status: 'online',
      lastUpdate: null,
      uniqueId: 'IMEI$id',
      attributes: camera ? const {'souIsMdvr': true} : const {},
    );

void main() {
  test('Bridge URL uses exact vehicle name, path prefix and channel', () {
    final uri = mdvrStreamUri(
        vehicle(1, 'Carro São Paulo / 01'),
        const BridgeConfig(
            bridgeUrl: 'https://example.com/bridge/',
            bridgeApiKey: 'never-in-url'))!;
    expect(uri.pathSegments,
        ['bridge', 'mdvr', 'Carro São Paulo / 01', 'live.m3u8']);
    expect(uri.queryParameters, {'channel': '1'});
    expect(uri.toString(), isNot(contains('never-in-url')));
    expect(mdvrStreamUri(vehicle(1, 'Carro'), const BridgeConfig()), isNull);
    expect(
        mdvrStreamUri(vehicle(1, 'Carro'),
            const BridgeConfig(bridgeUrl: 'javascript:alert(1)')),
        isNull);
  });

  for (final size in [const Size(1104, 540), const Size(400, 700)]) {
    testWidgets('Gallery/list preserve real names, search, actions at $size',
        (tester) async {
      SharedPreferences.setMockInitialValues({'bridge_url': ''});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(overrides: [
        devicesProvider.overrideWith((ref) async => [
              vehicle(1, 'Veículo um'),
              vehicle(2, 'Veículo dois'),
              vehicle(3, 'Rastreador sem câmera', camera: false)
            ]),
        positionsProvider.overrideWith((ref) async => <TraccarPosition>[]),
      ]);
      addTearDown(container.dispose);
      await container.read(devicesProvider.future);
      String? route;
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            onGenerateRoute: (settings) {
              route = settings.name;
              return MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Text('Detalhes abertos')));
            },
            home: const Scaffold(body: MdvrDevicesScreen()),
          )));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Veículo um'), findsOneWidget);
      expect(find.text('Rastreador sem câmera'), findsNothing);
      expect(find.text('2 de 2 veículos'), findsOneWidget);
      expect(find.text('Prévia indisponível'), findsNWidgets(2));
      final gridRect = tester.getRect(find.byType(GridView));
      expect(gridRect.left, 20);
      await tester.tap(find.text('Lista'));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsNothing);
      expect(find.text('ID IMEI1'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'IMEI2');
      await tester.pumpAndSettle();
      expect(find.text('Veículo um'), findsNothing);
      expect(find.text('Veículo dois'), findsOneWidget);
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
      final copy = size.width < 600
          ? find.byTooltip('Copiar ID')
          : find.text('Copiar ID');
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(copied, 'Veículo dois (#2)');
      final details =
          size.width < 600 ? find.byTooltip('Detalhes') : find.text('Detalhes');
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(route, '/mdvr/device/2');
      expect(tester.takeException(), isNull);
    });
  }
}
