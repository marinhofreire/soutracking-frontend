import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soutracking_flutter/core/app_theme.dart';
import 'package:soutracking_flutter/core/white_label.dart';
import 'package:soutracking_flutter/core/checkin_password.dart';
import 'package:soutracking_flutter/data/models.dart';
import 'package:soutracking_flutter/data/traccar_client.dart';
import 'package:soutracking_flutter/features/drivers/drivers_screen.dart';
import 'package:soutracking_flutter/features/drivers/models/driver_models.dart';
import 'package:soutracking_flutter/features/drivers/widgets/driver_registration_dialog.dart';
import 'package:soutracking_flutter/state/session_state.dart';

class RecordingClient extends TraccarClient {
  RecordingClient() : super(baseUrl: 'http://localhost/test');
  String? savedName, savedId;
  Map<String, dynamic>? savedAttributes;
  @override
  Future<TraccarDriver> createDriver(
      {required String name,
      required String uniqueId,
      Map<String, dynamic>? attributes,
      String? cookie,
      String? authHeader}) async {
    savedName = name;
    savedId = uniqueId;
    savedAttributes = attributes;
    return TraccarDriver(
        id: 100, name: name, uniqueId: uniqueId, attributes: attributes);
  }
}

Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label);
Future<void> fonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    await (FontLoader('DeviceEditorSegoe')
          ..addFont(rootBundle.load('assets/fonts/device-editor/segoeui.ttf'))
          ..addFont(rootBundle.load('assets/fonts/device-editor/seguisb.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
}

void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final size in [const Size(1366, 682), const Size(400, 740)]) {
    testWidgets(
        'Driver sections retain values, dates, access and footer in $size',
        (tester) async {
      viewport(tester, size);
      await fonts(tester);
      final controllers = {
        for (final key in [
          'name',
          'phone',
          'cpf',
          'birth',
          'address',
          'cnh',
          'expiry',
          'exam',
          'password'
        ])
          key: TextEditingController()
      };
      addTearDown(() {
        for (final controller in controllers.values) {
          controller.dispose();
        }
      });
      var category = 'B', ear = false, saves = 0;
      final capture = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: capture,
          child: MaterialApp(
              theme: buildAppTheme(WhiteLabelConfig.fallback),
              home: Scaffold(
                  body: StatefulBuilder(
                      builder: (context, setState) => DriverRegistrationDialog(
                            controllers: controllers,
                            category: category,
                            categories: const ['A', 'B', 'AB', 'C', 'D', 'E'],
                            ear: ear,
                            requiresExam: ['C', 'D', 'E'].contains(category),
                            saving: false,
                            error: null,
                            photoDataUrl: null,
                            photoFileName: null,
                            onCategoryChanged: (v) =>
                                setState(() => category = v),
                            onEarChanged: (v) => setState(() => ear = v),
                            onPickDate: (controller, context) async {
                              controller.text = '14/10/2028';
                            },
                            onPickPhoto: () {},
                            onCancel: () {},
                            onSave: () => saves++,
                          ))))));
      await tester.pumpAndSettle();
      if (size.width == 1366) {
        expect(tester.getSize(find.byType(DriverRegistrationDialog)),
            const Size(1366, 682));
        expect(tester.getSize(find.byType(Dialog)), const Size(1366, 682));
      }
      final save = find.widgetWithText(FilledButton, 'Salvar e continuar');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.enterText(field('Nome completo'), 'Motorista teste');
      await tester.enterText(field('Telefone'), '5511999999999');
      await tester.tap(field('Data de nascimento'));
      await tester.pumpAndSettle();
      expect(controllers['birth']!.text, '14/10/2028');
      await tester.tap(find.text('CNH e vínculo').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('D').last);
      await tester.pumpAndSettle();
      expect(field('Data do último exame toxicológico'), findsOneWidget);
      await tester.enterText(field('Número da CNH'), '12345678900');
      await tester.tap(field('Validade da CNH'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(ear, isTrue);
      await tester.tap(find.text('Credencial e acesso').first);
      await tester.pumpAndSettle();
      expect(find.text('Crachá / QR Code do motorista'), findsOneWidget);
      expect(tester.widget<TextField>(field('Senha de check-in')).obscureText,
          isTrue);
      await tester.enterText(field('Senha de check-in'), 'segredo-teste');
      await tester.pumpAndSettle();
      if (size.width == 1366) {
        await tester.runAsync(() async {
          final boundary = capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  'C:/Projetos/docs/motoristas-previa/aplicado-credencial.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Dados pessoais').first);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field('Nome completo')).controller!.text,
          'Motorista teste');
      expect(controllers['password']!.text, 'segredo-teste');
      expect(save.hitTestable(), findsOneWidget);
      await tester.tap(save);
      expect(saves, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets(
      'Existing driver save keeps identity, attributes and password hash',
      (tester) async {
    viewport(tester, const Size(1366, 682));
    await fonts(tester);
    final client = RecordingClient();
    final container = ProviderContainer(overrides: [
      traccarClientProvider.overrideWithValue(client),
      driversListProvider.overrideWith((ref) async => []),
      driversKpiProvider.overrideWith((ref) async => const DriverKpiSummary(
          active: 0, onRoute: 0, withoutVehicle: 0, cnhExpiring: 0)),
    ]);
    addTearDown(container.dispose);
    await container.read(driversListProvider.future);
    await container.read(driversKpiProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: buildAppTheme(WhiteLabelConfig.fallback),
            home: const Scaffold(body: DriversScreen()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo motorista'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Nome completo'), ' Motorista teste ');
    await tester.enterText(field('Telefone'), '5511999999999');
    await tester.enterText(field('CPF'), '12345678900');
    await tester.tap(find.text('Credencial e acesso').first);
    await tester.pumpAndSettle();
    await tester.enterText(field('Senha de check-in'), 'segredo-teste');
    await tester.tap(find.text('Salvar e continuar'));
    await tester.pumpAndSettle();
    expect(client.savedName, 'Motorista teste');
    expect(client.savedId, '5511999999999');
    expect(client.savedAttributes, {
      'phone': '5511999999999',
      'cpf': '12345678900',
      'cnh_category': 'B',
      'ear': false,
      'souPasswordHash': hashCheckinPassword('segredo-teste')
    });
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
