import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soutracking_flutter/core/app_constants.dart';
import 'package:soutracking_flutter/core/app_theme.dart';
import 'package:soutracking_flutter/core/white_label.dart';
import 'package:soutracking_flutter/data/bridge_client.dart';
import 'package:soutracking_flutter/data/bridge_config.dart';
import 'package:soutracking_flutter/features/ia/ia_screen.dart';

void main() {
  test('Public version is short and has no timestamp', () {
    expect(kAppVersionLabel, 'v4.5');
    expect(kAppVersionLabel, isNot(contains('dev')));
    expect(kAppVersionLabel, isNot(contains('(')));
  });
  for (final size in [const Size(1104, 492), const Size(400, 700)]) {
    testWidgets('IA labels, approvals and autonomy work at $size',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'bridge_url': '', 'bridge_api_key': ''});
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
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: buildAppTheme(WhiteLabelConfig.fallback),
                home: const Scaffold(body: IaScreen()),
              ))));
      await tester.pumpAndSettle();
      expect(find.text('Bridge'), findsNothing);
      expect(find.text('IA'), findsOneWidget);
      expect(container.read(iaProvider).pending.length, 3);
      await tester.tap(find.text('Aprovar e executar').first);
      await tester.pumpAndSettle();
      expect(container.read(iaProvider).pending.length, 2);
      expect(container.read(iaProvider).events.first.aprovado, isTrue);
      expect(tester.takeException(), isNull);
      final autonomy = find.text('Criar cercas');
      if (size.width < 760) {
        final scrollable = tester.state<ScrollableState>(find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pumpAndSettle();
      } else {
        await tester.ensureVisible(autonomy);
      }
      await tester.pumpAndSettle();
      final row = find.ancestor(of: autonomy, matching: find.byType(Row)).first;
      final toggle = find.descendant(
          of: row,
          matching: find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_IaToggle'));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(container.read(bridgeConfigProvider).autonomy['cercas'], isTrue);
      if (size.width >= 1000) {
        await tester.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('C:/Projetos/docs/ia-ajustada.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    });
  }
}
