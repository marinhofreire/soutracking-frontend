import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soutracking_flutter/core/app_theme.dart';
import 'package:soutracking_flutter/core/white_label.dart';
import 'package:soutracking_flutter/features/assist/assist_requests_screen.dart';

void main() {
  for (final size in [const Size(1104, 492), const Size(400, 700)]) {
    testWidgets(
        'Colored demands preserve amounts, status and navigation at $size',
        (tester) async {
      tester.view.physicalSize = size;
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
      String? opened;
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
        theme: buildAppTheme(WhiteLabelConfig.fallback),
        onGenerateRoute: (settings) {
          opened = settings.name;
          return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Destino')));
        },
        home: const Scaffold(body: AssistRequestsScreen()),
      )));
      await tester.pumpAndSettle();
      expect(find.text('2 ativos agora'), findsOneWidget);
      expect(find.text('R\$ 480,00'), findsOneWidget);
      expect(find.text('R\$ 220,00'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Despachado')).style!.color,
          const Color(0xFF176EEB));
      expect(tester.widget<Text>(find.text('Em deslocamento')).style!.color,
          const Color(0xFF7C3AED));
      expect(find.text('ETA 5 min'), findsOneWidget);
      expect(find.text('ETA 8 min'), findsOneWidget);
      expect(find.text('Guincho Leste 24h'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Guincho'));
      await tester.pumpAndSettle();
      expect(opened, '/assist/request/1001');
      Navigator.of(tester.element(find.text('Destino'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar chamado'));
      await tester.pumpAndSettle();
      expect(opened, '/assist/create');
      expect(tester.takeException(), isNull);
    });
  }
}
