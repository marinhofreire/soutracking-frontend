import 'package:flutter/material.dart';

/// Edits the existing color controller; no separate persistence or palette state.
class BrandColorField extends StatelessWidget {
  const BrandColorField(
      {super.key,
      required this.label,
      required this.controller,
      required this.color,
      required this.onChanged});
  final String label;
  final TextEditingController controller;
  final Color color;
  final VoidCallback onChanged;

  static String hex(Color value) =>
      '#${(value.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Future<void> _choose(BuildContext context) async {
    var draft = color;
    final selected = await showDialog<Color>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title: Text(label),
                  content: SizedBox(
                      width: 320,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            height: 64,
                            decoration: BoxDecoration(
                                color: draft,
                                borderRadius: BorderRadius.circular(8)),
                            alignment: Alignment.center,
                            child: Text(hex(draft),
                                style: TextStyle(
                                    color: draft.computeLuminance() > .179
                                        ? Colors.black
                                        : Colors.white))),
                        const SizedBox(height: 16),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final value in const [
                            Color(0xFF1F6FEB),
                            Color(0xFF7C3AED),
                            Color(0xFF0F766E),
                            Color(0xFF15803D),
                            Color(0xFFBE123C),
                            Color(0xFFB45309),
                            Color(0xFFEAB308),
                            Color(0xFF334155)
                          ])
                            Semantics(
                                label: 'Cor ${hex(value)}',
                                button: true,
                                child: InkWell(
                                    onTap: () => update(() => draft = value),
                                    child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                            color: value,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: value == draft
                                                    ? Colors.black
                                                    : Colors.transparent,
                                                width: 2)))))
                        ]),
                        const SizedBox(height: 12),
                        for (var channel = 0; channel < 3; channel++)
                          Row(children: [
                            Text(['R', 'G', 'B'][channel]),
                            Expanded(
                                child: Slider(
                                    label: [
                                      'Vermelho',
                                      'Verde',
                                      'Azul'
                                    ][channel],
                                    min: 0,
                                    max: 255,
                                    value: ((draft.toARGB32() >>
                                                (16 - channel * 8)) &
                                            255)
                                        .toDouble(),
                                    onChanged: (value) => update(() {
                                          final channels = [
                                            (draft.toARGB32() >> 16) & 255,
                                            (draft.toARGB32() >> 8) & 255,
                                            draft.toARGB32() & 255
                                          ];
                                          channels[channel] = value.round();
                                          draft = Color.fromARGB(
                                              255,
                                              channels[0],
                                              channels[1],
                                              channels[2]);
                                        })))
                          ])
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, draft),
                        child: const Text('Usar esta cor'))
                  ],
                )));
    if (selected == null) return;
    controller.text = hex(selected);
    onChanged();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
                labelText: label,
                helperText: '#RRGGBB',
                suffixIcon: IconButton(
                    tooltip: 'Escolher $label',
                    onPressed: () => _choose(context),
                    icon: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.black26)))))),
        if ((1.05 / (color.computeLuminance() + .05)) < 4.5)
          const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                  'Contraste baixo com branco. Os botões usarão texto escuro.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8A530B))))
      ]);
}
