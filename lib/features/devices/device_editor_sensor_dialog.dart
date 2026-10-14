import 'package:flutter/material.dart';
import 'device_editor_reference_icons.dart';

class DeviceEditorSensorDialog extends StatefulWidget {
  const DeviceEditorSensorDialog(
      {super.key,
      required this.sensorLabel,
      required this.labelController,
      required this.trueController,
      required this.falseController,
      required this.onClose,
      required this.onSave});
  final String sensorLabel;
  final TextEditingController labelController, trueController, falseController;
  final VoidCallback onClose, onSave;
  @override
  State<DeviceEditorSensorDialog> createState() =>
      _DeviceEditorSensorDialogState();
}

class _DeviceEditorSensorDialogState extends State<DeviceEditorSensorDialog> {
  late final labelController =
      TextEditingController(text: widget.labelController.text);
  late final trueController =
      TextEditingController(text: widget.trueController.text);
  late final falseController =
      TextEditingController(text: widget.falseController.text);
  String get sensorLabel => widget.sensorLabel;
  void onClose() => widget.onClose();
  void onSave() {
    widget.labelController.value = labelController.value;
    widget.trueController.value = trueController.value;
    widget.falseController.value = falseController.value;
    widget.onSave();
  }

  @override
  void dispose() {
    labelController.dispose();
    trueController.dispose();
    falseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const line = Color(0xFFDDE5F0), blue = Color(0xFF176EEB);
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD6E2F2)));
    final theme = Theme.of(context).copyWith(
        textTheme: Theme.of(context)
            .textTheme
            .apply(fontFamily: 'DeviceEditorSegoe')
            .copyWith(
                bodyLarge: const TextStyle(
                    fontFamily: 'DeviceEditorSegoe',
                    fontSize: 11,
                    color: Color(0xFF1F2A44))),
        inputDecorationTheme: InputDecorationTheme(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF8FAFF),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelStyle: const TextStyle(
                fontFamily: 'DeviceEditorSegoe',
                fontSize: 12,
                color: Color(0xFF6D82A3)),
            hintStyle: const TextStyle(
                fontFamily: 'DeviceEditorSegoe',
                fontSize: 11,
                color: Color(0xFF97A7BD)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            enabledBorder: border,
            border: border,
            focusedBorder:
                border.copyWith(borderSide: const BorderSide(color: blue))));
    Widget field(
            TextEditingController ctrl, String label, String hint) =>
        SizedBox(
            height: 40,
            child: TextField(
                controller: ctrl,
                decoration: InputDecoration(labelText: label, hintText: hint)));
    final buttonStyle = ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 33)),
        maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 33)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding:
            const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 15)),
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        textStyle: const WidgetStatePropertyAll(TextStyle(
            fontFamily: 'DeviceEditorSegoe',
            fontSize: 11,
            fontWeight: FontWeight.w600)));
    return Theme(
        data: theme,
        child: DefaultTextStyle(
            style: const TextStyle(
                fontFamily: 'DeviceEditorSegoe',
                fontSize: 11,
                color: Color(0xFF1F2A44)),
            child: Container(
                width: 416,
                height: 402,
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD6E2F2)),
                    borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Container(
                      height: 69,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: line))),
                      child: Row(children: [
                        Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: const Color(0xFFEAF2FF),
                                borderRadius: BorderRadius.circular(8)),
                            child: const DeviceEditorReferenceIcon('tune',
                                color: blue)),
                        const SizedBox(width: 9),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text('Configurar sensor',
                                  style: TextStyle(
                                      fontSize: 14,
                                      height: 19 / 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              Text(sensorLabel,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      height: 1.4,
                                      color: Color(0xFF8B9CB2)))
                            ])),
                        SizedBox(
                            width: 28,
                            height: 28,
                            child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: onClose,
                                icon: const DeviceEditorReferenceIcon('close',
                                    color: Color(0xFF8194AF))))
                      ])),
                  Expanded(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 17, 18, 20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                    'Só a tradução dessa informação — não cria alerta.',
                                    style: TextStyle(
                                        fontSize: 10,
                                        height: 1.6,
                                        color: Color(0xFF7C90AE))),
                                const SizedBox(height: 20),
                                field(labelController, 'Nome de exibição',
                                    sensorLabel),
                                const SizedBox(height: 17),
                                const Text('O que cada valor significa',
                                    style: TextStyle(
                                        fontSize: 11,
                                        height: 15 / 11,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 16),
                                field(
                                    trueController,
                                    'Quando o valor é 1 / true',
                                    'Ex.: Porta aberta'),
                                const SizedBox(height: 17),
                                field(
                                    falseController,
                                    'Quando o valor é 0 / false',
                                    'Ex.: Porta fechada')
                              ]))),
                  Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: line))),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(
                                width: 74.7,
                                child: OutlinedButton(
                                    onPressed: onClose,
                                    style: buttonStyle.copyWith(
                                        side: const WidgetStatePropertyAll(
                                            BorderSide(
                                                color: Color(0xFFD6E2F2))),
                                        foregroundColor:
                                            const WidgetStatePropertyAll(
                                                Color(0xFF60718D))),
                                    child: const Text('Cancelar'))),
                            SizedBox(
                                width: 83.2,
                                child: FilledButton.icon(
                                    onPressed: onSave,
                                    style: buttonStyle.copyWith(
                                        backgroundColor:
                                            const WidgetStatePropertyAll(blue),
                                        foregroundColor:
                                            const WidgetStatePropertyAll(
                                                Colors.white)),
                                    icon: const DeviceEditorReferenceIcon(
                                        'check',
                                        size: 14,
                                        color: Colors.white),
                                    label: const Text('Salvar')))
                          ]))
                ]))));
  }
}
