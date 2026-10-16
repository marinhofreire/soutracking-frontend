import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soutracking_flutter/widgets/tpms_vehicle_card.dart';

List<TireVisualReading> readings(int count) => List.generate(
    count,
    (i) => TireVisualReading(
        id: '${i + 1}',
        label: 'P${i + 1}',
        pressure: '0 psi',
        temperature: '24 °C',
        battery: '3.00 V'));

Future<void> mount(WidgetTester tester, int count) => tester.pumpWidget(
    MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.topLeft,
                child: TpmsVehicleCard(readings: readings(count))))));

void main() {
  testWidgets('empty readings do not create an empty instrument',
      (tester) async {
    await mount(tester, 0);
    expect(find.text('Pneus (TPMS)'), findsNothing);
  });

  testWidgets('four received zero readings stay visible without assumed alerts',
      (tester) async {
    await mount(tester, 4);
    expect(find.text('0 psi'), findsNWidgets(4));
    expect(find.text('24 °C'), findsNWidgets(4));
    expect(find.text('1–4 de 4'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget); // legend, not a sensor verdict
    expect(tester.widget<Text>(find.text('0 psi').first).style!.color,
        const Color(0xFF334155));
    expect(tester.getSize(find.byKey(const ValueKey('tpms-vehicle-card'))),
        const Size(170, 204));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long vehicle scrolls internally without growing the card',
      (tester) async {
    await mount(tester, 12);
    final scroll = find.byKey(const ValueKey('tpms-diagram-scroll'));
    expect(find.text('P12').hitTestable(), findsNothing);
    await tester.drag(scroll, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('P12').hitTestable(), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('tpms-vehicle-card'))),
        const Size(170, 204));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two sensors do not fabricate four readings', (tester) async {
    await mount(tester, 2);
    expect(find.text('0 psi'), findsNWidgets(2));
    expect(find.text('P3'), findsNothing);
    expect(find.text('P4'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrow advances the visible four tires without widening the card',
      (tester) async {
    await mount(tester, 12);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Próximos pneus'));
    await tester.pumpAndSettle();
    expect(find.text('5–8 de 12'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('tpms-vehicle-card'))),
        const Size(170, 204));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'real position IDs determine sides independently of arrival order',
      (tester) async {
    final values = ['23', '14', '11', '22']
        .map((id) => TireVisualReading(
            id: id, label: 'P$id', pressure: '0', temperature: '24 °C'))
        .toList();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: TpmsVehicleCard(readings: values))));
    expect(tester.getTopLeft(find.text('DE')).dx,
        lessThan(tester.getTopLeft(find.text('DD')).dx));
    expect(tester.getTopLeft(find.text('DE')).dy,
        lessThan(tester.getTopLeft(find.text('TE')).dy));
    expect(tester.getTopLeft(find.text('TE')).dx,
        lessThan(tester.getTopLeft(find.text('TD')).dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('received states color the readouts and keep reasons accessible',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: TpmsVehicleCard(readings: [
      TireVisualReading(
          id: '11',
          label: 'P11',
          pressure: '22 psi',
          temperature: '60 °C',
          state: TireVisualState.alert,
          reason: 'Pressão baixa e Temperatura alta')
    ]))));
    expect(tester.widget<Text>(find.text('22 psi')).style!.color,
        const Color(0xFFDC4545));
    expect(
        find.byWidgetPredicate((w) =>
            w is Tooltip &&
            (w.message ?? '').contains('Pressão baixa e Temperatura alta')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
