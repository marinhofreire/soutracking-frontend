import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soutracking_flutter/data/models.dart';
import 'package:soutracking_flutter/state/session_state.dart';
import 'package:soutracking_flutter/features/telemetry/telemetry_sensors_screen.dart';
import 'package:soutracking_flutter/features/telemetry/tpms_screen.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    for (final tpms in [false, true]) {
      testWidgets('Mobile ${tpms ? 'TPMS' : 'telemetry'} at $width',
          (tester) async {
        final previousHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          previousHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = previousHandler);
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final device = TraccarDevice(
            id: 1,
            name: 'Equipamento com nome longo para validar mobile',
            status: 'online',
            lastUpdate: DateTime.now().toIso8601String(),
            uniqueId: 'mobile-test');
        final position = TraccarPosition(
            id: 2,
            deviceId: 1,
            latitude: -23.55,
            longitude: -46.63,
            speed: 0,
            course: 0,
            fixTime: DateTime.now().toIso8601String(),
            attributes: const {
              'ignition': false,
              'rpm': 0,
              'tire11Pressure': 32,
              'tire11Temp': 24,
              'tire11Battery': 3.28
            });
        await tester.pumpWidget(ProviderScope(
            overrides: [
              devicesProvider.overrideWith((ref) async => [device]),
              positionsProvider.overrideWith((ref) async => [position]),
            ],
            child: MaterialApp(
                home: Scaffold(
                    body: Padding(
                        padding: const EdgeInsets.all(8),
                        child: tpms
                            ? const TpmsScreen()
                            : const TelemetrySensorsScreen())))));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(find.text('Atualizar'), findsOneWidget);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}
