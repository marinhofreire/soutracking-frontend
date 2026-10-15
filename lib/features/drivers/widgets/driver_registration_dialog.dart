import 'package:flutter/material.dart';

/// Presentation of the existing registration fields and actions.
class DriverRegistrationDialog extends StatefulWidget {
  const DriverRegistrationDialog(
      {super.key,
      required this.controllers,
      required this.category,
      required this.categories,
      required this.ear,
      required this.requiresExam,
      required this.saving,
      required this.error,
      required this.photoDataUrl,
      required this.photoFileName,
      required this.onCategoryChanged,
      required this.onEarChanged,
      required this.onPickDate,
      required this.onPickPhoto,
      required this.onCancel,
      required this.onSave});
  final Map<String, TextEditingController> controllers;
  final String category;
  final List<String> categories;
  final bool ear, requiresExam, saving;
  final String? error, photoDataUrl, photoFileName;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onEarChanged;
  final Future<void> Function(TextEditingController, BuildContext) onPickDate;
  final VoidCallback onPickPhoto, onCancel;
  final VoidCallback? onSave;
  @override
  State<DriverRegistrationDialog> createState() =>
      _DriverRegistrationDialogState();
}

class _DriverRegistrationDialogState extends State<DriverRegistrationDialog> {
  static const blue = Color(0xFF176EEB),
      ink = Color(0xFF1F2A44),
      line = Color(0xFFDDE5F0),
      muted = Color(0xFF8194B1);
  int step = 0;
  String text(String key) => widget.controllers[key]!.text.trim();
  static const titles = [
    'Dados pessoais',
    'CNH e vínculo',
    'Credencial e acesso'
  ];
  static const descriptions = [
    'Identificação e contato',
    'Habilitação e atividade',
    'Crachá, QR Code e check-in'
  ];
  static const icons = [
    Icons.person_outline_rounded,
    Icons.credit_card_outlined,
    Icons.qr_code_2_rounded
  ];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: Listenable.merge(widget.controllers.values.toList()),
      builder: (context, _) {
        final desktop = MediaQuery.sizeOf(context).width >= 1180;
        final mobile = MediaQuery.sizeOf(context).width < 760;
        final base = Theme.of(context);
        final border = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD6E2F2)));
        final theme = base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'DeviceEditorSegoe'),
          inputDecorationTheme: InputDecorationTheme(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFF),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              labelStyle:
                  const TextStyle(fontSize: 11, color: Color(0xFF7187A8)),
              hintStyle:
                  const TextStyle(fontSize: 11, color: Color(0xFF91A2BD)),
              prefixIconColor: muted,
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 35, minHeight: 32),
              border: border,
              enabledBorder: border,
              focusedBorder:
                  border.copyWith(borderSide: const BorderSide(color: blue))),
        );
        final content =
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (step == 0) ...personalFields(context),
          if (step == 1) ...licenseFields(context),
          if (step == 2) ...accessFields(context),
          if (widget.error != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(widget.error!,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFEF4444)))),
        ]);
        final body = mobile
            ? SingleChildScrollView(
                child: Column(children: [
                navigation(true),
                Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
                    child: content),
                summary(mobile: true)
              ]))
            : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(width: desktop ? 194 : 180, child: navigation(false)),
                Expanded(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 19, 16, 16),
                        child: content)),
                SizedBox(
                    width: desktop ? 232 : 218,
                    child: SingleChildScrollView(child: summary())),
              ]);
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: desktop
              ? const EdgeInsets.fromLTRB(226, 104, 36, 38)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          clipBehavior: Clip.antiAlias,
          child: Theme(
              data: theme,
              child: DefaultTextStyle.merge(
                  style: const TextStyle(
                      fontFamily: 'DeviceEditorSegoe',
                      fontSize: 12,
                      color: ink),
                  child: SizedBox(
                      width: 1104,
                      height: desktop
                          ? 540
                          : MediaQuery.sizeOf(context).height - 60,
                      child: Column(children: [
                        Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            decoration: const BoxDecoration(
                                border:
                                    Border(bottom: BorderSide(color: line))),
                            child: Row(children: [
                              Container(
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(
                                              color: blue, width: 3))),
                                  child: const Text('Novo motorista',
                                      style: TextStyle(
                                          color: blue,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600))),
                              const Spacer(),
                              SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: IconButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: widget.saving
                                          ? null
                                          : widget.onCancel,
                                      tooltip: 'Fechar',
                                      icon: const Icon(Icons.close_rounded,
                                          size: 18, color: muted)))
                            ])),
                        Expanded(child: body),
                        Container(
                            height: 54,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: line))),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  SizedBox(
                                      height: 33,
                                      child: OutlinedButton(
                                          onPressed: widget.saving
                                              ? null
                                              : widget.onCancel,
                                          style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                  color: Color(0xFFD6E2F2)),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              foregroundColor:
                                                  const Color(0xFF536E93),
                                              textStyle: const TextStyle(
                                                  fontFamily:
                                                      'DeviceEditorSegoe',
                                                  fontSize: 10)),
                                          child: const Text('Cancelar'))),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                      height: 33,
                                      child: FilledButton.icon(
                                          onPressed: widget.saving ||
                                                  text('name').isEmpty
                                              ? null
                                              : widget.onSave,
                                          icon: widget.saving
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white))
                                              : const Icon(Icons.check_rounded,
                                                  size: 14),
                                          label:
                                              const Text('Salvar e continuar'),
                                          style: FilledButton.styleFrom(
                                              backgroundColor: blue,
                                              minimumSize: const Size(155, 33),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              textStyle: const TextStyle(
                                                  fontFamily:
                                                      'DeviceEditorSegoe',
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600)))),
                                ])),
                      ])))),
        );
      });

  Widget caption(String value) => Text(value,
      style: const TextStyle(
          fontSize: 9, height: 12 / 9, color: Color(0xFF62799C)));
  Widget navigation(bool horizontal) {
    final buttons = List.generate(
        3,
        (index) => Padding(
            padding: EdgeInsets.only(
                bottom: horizontal ? 0 : 6, right: horizontal ? 5 : 0),
            child: SizedBox(
                height: 54,
                child: OutlinedButton(
                    onPressed: widget.saving
                        ? null
                        : () => setState(() => step = index),
                    style: OutlinedButton.styleFrom(
                        textStyle:
                            const TextStyle(fontFamily: 'DeviceEditorSegoe'),
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        backgroundColor: step == index
                            ? const Color(0xFFEDF4FF)
                            : Colors.white,
                        side: BorderSide(
                            color:
                                step == index ? blue : const Color(0xFFD6E2F2)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9))),
                    child: Row(children: [
                      Icon(icons[index],
                          size: 14, color: step == index ? blue : muted),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(titles[index],
                                maxLines: 2,
                                style: TextStyle(
                                    fontSize: horizontal ? 9 : 10,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                    color: step == index ? blue : ink)),
                            const SizedBox(height: 4),
                            Text(descriptions[index],
                                maxLines: 2,
                                style: TextStyle(
                                    fontSize: horizontal ? 8 : 9,
                                    height: 1.25,
                                    color: muted))
                          ])),
                      if (step == index && !horizontal)
                        const Icon(Icons.chevron_right, size: 15, color: blue)
                    ])))));
    return Container(
        padding: EdgeInsets.all(horizontal ? 10 : 10)
            .copyWith(top: horizontal ? 10 : 17, bottom: horizontal ? 10 : 17),
        decoration: BoxDecoration(
            border: horizontal
                ? const Border(bottom: BorderSide(color: line))
                : const Border(right: BorderSide(color: line))),
        child: horizontal
            ? Row(children: buttons.map((b) => Expanded(child: b)).toList())
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                caption('CADASTRO DO MOTORISTA'),
                const SizedBox(height: 13),
                ...buttons,
                const Spacer(),
                const Divider(height: 1, color: Color(0xFFEDF1F6)),
                const SizedBox(height: 12),
                const Text('Novo motorista',
                    style: TextStyle(
                        fontSize: 10, color: Color(0xFF536E93), height: 1.6)),
                const SizedBox(height: 3),
                const Text('Cadastre os dados e a habilitação do motorista.',
                    style: TextStyle(
                        fontSize: 10, color: Color(0xFF8A9BB2), height: 1.6))
              ]));
  }

  Widget heading(String title, String subtitle) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, height: 24 / 18)),
        const SizedBox(height: 3),
        Text(subtitle,
            style: const TextStyle(fontSize: 10, height: 1.6, color: muted))
      ]));
  Widget group(IconData icon, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 7),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 10, height: 1.5, color: Color(0xFF4F6C94))))
      ]));
  Widget field(BuildContext context, String key, String label, IconData icon,
          {String? hint, bool date = false, bool password = false}) =>
      SizedBox(
          height: 36,
          child: TextField(
              controller: widget.controllers[key],
              style: const TextStyle(fontSize: 11),
              readOnly: date,
              obscureText: password,
              keyboardType:
                  key == 'phone' ? TextInputType.phone : TextInputType.text,
              onTap: date
                  ? () => widget.onPickDate(widget.controllers[key]!, context)
                  : null,
              decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  prefixIcon: Icon(icon, size: 14))));
  Widget pair(Widget left, Widget right) => Row(children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right)
      ]);
  Widget gap([double height = 14]) => SizedBox(height: height);
  Widget divider() => const Padding(
      padding: EdgeInsets.only(top: 21, bottom: 15),
      child: Divider(height: 1, color: Color(0xFFE5ECF7)));
  List<Widget> personalFields(BuildContext context) => [
        heading('Dados pessoais',
            'Identificação e informações de contato do motorista.'),
        group(Icons.person_outline_rounded, 'IDENTIFICAÇÃO DO MOTORISTA'),
        Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 18),
            child: Row(children: [
              Semantics(
                  button: true,
                  label: 'Selecionar foto do motorista',
                  child: GestureDetector(
                      onTap: widget.onPickPhoto,
                      child: SizedBox(
                          width: 54,
                          height: 54,
                          child: Stack(children: [
                            CircleAvatar(
                                radius: 27,
                                backgroundColor: const Color(0xFFF1F6FE),
                                backgroundImage: widget.photoDataUrl == null
                                    ? null
                                    : NetworkImage(widget.photoDataUrl!),
                                child: widget.photoDataUrl == null
                                    ? const Icon(Icons.person_outline_rounded,
                                        size: 27, color: Color(0xFF95A8C3))
                                    : null),
                            Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                    width: 19,
                                    height: 19,
                                    decoration: BoxDecoration(
                                        color: blue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2)),
                                    child: const Icon(Icons.camera_alt_outlined,
                                        color: Colors.white, size: 11)))
                          ])))),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Foto do motorista',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Text(
                        widget.photoFileName ??
                            'Selecione a foto pelo ícone da câmera.',
                        style: const TextStyle(fontSize: 10, color: muted))
                  ]))
            ])),
        field(context, 'name', 'Nome completo', Icons.person_outline_rounded,
            hint: 'Informe o nome completo'),
        gap(),
        pair(
            field(context, 'phone', 'Telefone', Icons.phone_outlined,
                hint: 'Ex: 5511999999999'),
            field(context, 'cpf', 'CPF', Icons.badge_outlined,
                hint: '000.000.000-00')),
        gap(),
        pair(
            field(context, 'birth', 'Data de nascimento', Icons.cake_outlined,
                date: true),
            const SizedBox()),
        gap(),
        field(context, 'address', 'Endereço', Icons.location_on_outlined,
            hint: 'Rua, número, bairro, cidade'),
      ];
  List<Widget> licenseFields(BuildContext context) => [
        heading('CNH e vínculo',
            'Habilitação e atividade exercida pelo motorista.'),
        group(Icons.credit_card_outlined, 'CARTEIRA NACIONAL DE HABILITAÇÃO'),
        field(context, 'cnh', 'Número da CNH', Icons.credit_card_outlined,
            hint: 'Informe o número da CNH'),
        gap(),
        pair(
            SizedBox(
                height: 36,
                child: DropdownButtonFormField<String>(
                    initialValue: widget.category,
                    style: const TextStyle(
                        fontFamily: 'DeviceEditorSegoe',
                        fontSize: 11,
                        color: ink),
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: widget.categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) widget.onCategoryChanged(v);
                    })),
            field(context, 'expiry', 'Validade da CNH', Icons.event_outlined,
                date: true)),
        divider(),
        group(Icons.work_outline_rounded, 'ATIVIDADE DO MOTORISTA'),
        SizedBox(
            height: 35,
            child: Row(children: [
              SizedBox(
                  width: 20,
                  child: Checkbox(
                      value: widget.ear,
                      activeColor: blue,
                      onChanged: (v) => widget.onEarChanged(v ?? false))),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('EAR — Exerce Atividade Remunerada',
                      style: TextStyle(fontSize: 11)))
            ])),
        if (widget.requiresExam) ...[
          Container(
              margin: const EdgeInsets.only(top: 10, bottom: 18),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFFAEE),
                  border: Border.all(color: const Color(0xFFFFE1AA)),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text(
                  'Informe o último exame toxicológico para esta categoria.',
                  style: TextStyle(
                      fontSize: 10, height: 1.6, color: Color(0xFF9B6B20)))),
          field(context, 'exam', 'Data do último exame toxicológico',
              Icons.science_outlined,
              date: true)
        ],
      ];
  List<Widget> accessFields(BuildContext context) => [
        heading('Credencial e acesso',
            'Identificação do motorista e acesso ao check-in.'),
        group(Icons.lock_outline_rounded, 'ACESSO AO CHECK-IN'),
        field(context, 'password', 'Senha de check-in',
            Icons.lock_outline_rounded,
            password: true, hint: 'Informe a senha de check-in'),
        gap(9),
        const Text(
            'Senha utilizada no check-in pelo QR Code do veículo.\nO acesso ao painel possui credenciais próprias.',
            style: TextStyle(fontSize: 10, height: 1.7, color: muted)),
        divider(),
        group(Icons.qr_code_2_rounded, 'IDENTIFICAÇÃO DO MOTORISTA'),
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                border: Border.all(color: const Color(0xFFD6E2F2)),
                borderRadius: BorderRadius.circular(9)),
            child: Row(children: [
              const Icon(Icons.qr_code_2_rounded, size: 32, color: blue),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Crachá / QR Code do motorista',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    gap(5),
                    const Text(
                        'Identificação vinculada ao cadastro do motorista.',
                        style: TextStyle(fontSize: 10, color: muted)),
                    gap(10),
                    chip('Cadastro não salvo')
                  ]))
            ])),
        gap(),
        identityRow(
            'Motorista', text('name').isEmpty ? 'Não informado' : text('name')),
        gap(12),
        identityRow('Identificador', 'Definido ao salvar o cadastro'),
      ];
  Widget chip(String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: const Color(0xFFEDF1F7),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: line)),
      child: Text(value,
          style: const TextStyle(
              fontSize: 9, height: 13 / 9, color: Color(0xFF7C91AF))));
  Widget identityRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 105,
              child: Text(label,
                  style: const TextStyle(fontSize: 10, color: muted))),
          Expanded(
              child: Text(value,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF536E93)))),
        ],
      );
  Widget summaryRow(String label, String value, {Widget? trailing}) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 86,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 10, height: 1.5, color: muted))),
        const SizedBox(width: 5),
        Expanded(
            child: Align(
                alignment: Alignment.centerRight,
                child: trailing ??
                    Text(value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 10,
                            height: 1.5,
                            color: Color(0xFF536E93)))))
      ]);
  Widget card(String title, List<Widget> children) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFD6E2F2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, height: 15 / 11)),
        gap(),
        ...children
      ]));
  Widget check(String label, bool ready) => Row(children: [
        Icon(ready ? Icons.check_rounded : Icons.radio_button_unchecked,
            size: 12,
            color: ready ? const Color(0xFF18A558) : const Color(0xFFB2BED0)),
        const SizedBox(width: 7),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 9,
                    height: 13 / 9,
                    color: ready
                        ? const Color(0xFF617D9E)
                        : const Color(0xFF8798AF))))
      ]);
  Widget summary({bool mobile = false}) {
    final overview = card('Resumo do cadastro', [
      summaryRow('Status', '', trailing: chip('Não salvo')),
      gap(12),
      summaryRow(
          'Motorista', text('name').isEmpty ? 'Não informado' : text('name')),
      gap(12),
      summaryRow(
          'Telefone', text('phone').isEmpty ? 'Não informado' : text('phone')),
      gap(12),
      summaryRow('Categoria CNH', widget.category),
      gap(12),
      summaryRow('Validade CNH',
          text('expiry').isEmpty ? 'Não informada' : text('expiry')),
      gap(12),
      summaryRow('Atividade EAR', widget.ear ? 'Remunerada' : 'Não informada')
    ]);
    final checklist = card('Checklist do cadastro', [
      check('Nome informado', text('name').isNotEmpty),
      gap(13),
      check('Telefone informado', text('phone').isNotEmpty),
      gap(13),
      check('CNH preenchida',
          text('cnh').isNotEmpty && text('expiry').isNotEmpty),
      gap(13),
      check('Senha de check-in definida', text('password').isNotEmpty)
    ]);
    return Container(
        padding:
            EdgeInsets.symmetric(horizontal: mobile ? 14 : 10, vertical: 17),
        decoration: BoxDecoration(
            border: mobile
                ? const Border(top: BorderSide(color: line))
                : const Border(left: BorderSide(color: line))),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              caption('RESUMO DO MOTORISTA'),
              gap(13),
              overview,
              gap(10),
              checklist
            ]));
  }
}
