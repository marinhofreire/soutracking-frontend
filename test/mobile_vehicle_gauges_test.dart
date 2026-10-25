import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soutracking_flutter/widgets/dial_gauge.dart';
import 'package:soutracking_flutter/widgets/mobile_vehicle_gauges.dart';

void main() {
  for (final width in [320.0, 360.0, 430.0]) {
    testWidgets('Circular mobile gauges fit $width and preserve readings',
        (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: Padding(
                  padding: EdgeInsets.all(10),
                  child: MobileVehicleGauges(speedKmh: 42, rpm: 2.1)))));
      final dials =
          tester.widgetList<DialGauge>(find.byType(DialGauge)).toList();
      expect(dials.length, 2);
      expect(dials[0].value, 42);
      expect(dials[1].value, 2.1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: MobileVehicleGauges(speedKmh: 0))));
      expect(find.byType(DialGauge), findsOneWidget);
      expect(tester.widget<DialGauge>(find.byType(DialGauge)).value, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
