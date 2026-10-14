import 'package:flutter/material.dart';
import 'assist_dispatch_state.dart';

class AssistRequestListCard extends StatelessWidget {
  const AssistRequestListCard(
      {super.key,
      required this.request,
      required this.partnerName,
      required this.status,
      required this.channel,
      required this.profile,
      required this.split,
      required this.distance,
      required this.eta,
      required this.offerText,
      required this.onTap});
  final AssistRequest request;
  final String partnerName;
  final String status;
  final String channel;
  final String profile;
  final String split;
  final String distance;
  final String eta;
  final String offerText;
  final VoidCallback onTap;

  static const _ink = Color(0xFF1F2A44);
  static const _muted = Color(0xFF7D8DA5);
  static const _line = Color(0xFFDBE5F3);

  Color get _accent => switch (request.status) {
        AssistRequestStatus.aberto => const Color(0xFF9DB1CC),
        AssistRequestStatus.aguardandoAceite => const Color(0xFFF59E0B),
        AssistRequestStatus.despachado => const Color(0xFF176EEB),
        AssistRequestStatus.emDeslocamento => const Color(0xFF7C3AED),
        AssistRequestStatus.emAtendimento => const Color(0xFF0EA5E9),
        AssistRequestStatus.finalizado => const Color(0xFF16A34A),
      };
  Color get _tint => switch (request.status) {
        AssistRequestStatus.despachado => const Color(0xFFEDF4FF),
        AssistRequestStatus.emDeslocamento => const Color(0xFFF3EEFF),
        _ => _accent.withValues(alpha: .07),
      };
  Color get _badgeBorder => switch (request.status) {
        AssistRequestStatus.despachado => const Color(0xFFCDDDFF),
        AssistRequestStatus.emDeslocamento => const Color(0xFFE4D6FF),
        _ => _accent.withValues(alpha: .22),
      };

  String _money(double value) {
    if (!value.isFinite) return '—';
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts.first
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return 'R\$ $whole,${parts.last}';
  }

  Widget _serviceIcon() => Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: _tint,
          border: Border.all(color: _badgeBorder),
          borderRadius: BorderRadius.circular(9)),
      child: Icon(Icons.support_agent_outlined, size: 20, color: _accent));

  Widget _details() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
                spacing: 9,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('#${request.id}',
                      style: const TextStyle(color: _muted, fontSize: 11)),
                  Text(request.service,
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: _tint,
                          border: Border.all(color: _badgeBorder),
                          borderRadius: BorderRadius.circular(5)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                                color: _accent, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(status,
                            style: TextStyle(
                                color: _accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ])),
                ]),
            Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 9),
                child: Text(request.customer,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF526884)))),
            Wrap(
                spacing: 6,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.directions_car_outlined,
                      size: 15, color: Color(0xFF8A9FBD)),
                  Text(partnerName,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF4E6684))),
                  Text('· ${distance.replaceAll('.', ',')}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF7C8CA3))),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF2FAF6),
                          border: Border.all(color: const Color(0xFFD9E9E3)),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(eta,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF27845E)))),
                ]),
            const SizedBox(height: 10),
            Wrap(
                spacing: 7,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                          color: channel == 'WhatsApp'
                              ? const Color(0xFFEFF9F4)
                              : const Color(0xFFF2F6FC),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(channel,
                          style: TextStyle(
                              fontSize: 10,
                              color: channel == 'WhatsApp'
                                  ? const Color(0xFF258965)
                                  : const Color(0xFF5D789F)))),
                  Text('Perfil: $profile',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF8A9BB2))),
                  const Text('·',
                      style: TextStyle(fontSize: 10, color: Color(0xFF8A9BB2))),
                  Text(
                      'Rota: ${request.routeDistanceKm.toStringAsFixed(1).replaceAll('.', ',')} km',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF8A9BB2))),
                ]),
            if (offerText.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(offerText.trim(),
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF7D8DA5)))),
          ]);

  Widget _platform() => RichText(
          text: TextSpan(
              style: const TextStyle(
                  fontFamily: 'DeviceEditorSegoe',
                  fontSize: 10,
                  color: Color(0xFF8494AC)),
              children: [
            const TextSpan(text: 'Plataforma  '),
            TextSpan(
                text: _money(request.platformFeeAmount),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF526985))),
          ]));

  Widget _amount() => Text(_money(request.serviceAmount),
      style: const TextStyle(
          fontSize: 19, fontWeight: FontWeight.w600, color: Color(0xFF238160)));

  Widget _moneyBlock(bool narrow) {
    final content = narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
                Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [_amount(), _platform()]),
                const SizedBox(height: 5),
                Text(split,
                    style:
                        const TextStyle(fontSize: 9, color: Color(0xFF8A9BB2))),
              ])
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                const Text('VALOR DO SERVIÇO',
                    style: TextStyle(fontSize: 9, color: Color(0xFF8696AD))),
                const SizedBox(height: 4),
                _amount(),
                const SizedBox(height: 6),
                _platform(),
                const SizedBox(height: 5),
                Text(split,
                    style:
                        const TextStyle(fontSize: 9, color: Color(0xFF8A9BB2))),
              ]);
    return Container(
        padding: narrow
            ? const EdgeInsets.only(top: 10)
            : const EdgeInsets.only(left: 19),
        decoration: BoxDecoration(
            border: narrow
                ? const Border(top: BorderSide(color: Color(0xFFE8EEF7)))
                : const Border(left: BorderSide(color: Color(0xFFE8EEF7)))),
        child: content);
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 600;
        const arrow =
            Icon(Icons.chevron_right, size: 20, color: Color(0xFF8C9EB9));
        final content = narrow
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _serviceIcon(),
                  const SizedBox(width: 9),
                  Expanded(child: _details()),
                  const SizedBox(width: 8),
                  arrow
                ]),
                const SizedBox(height: 10),
                Padding(
                    padding: const EdgeInsets.only(left: 43, right: 28),
                    child: _moneyBlock(true)),
              ])
            : IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    Align(
                        alignment: Alignment.topCenter, child: _serviceIcon()),
                    const SizedBox(width: 13),
                    Expanded(
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: _details())),
                    const SizedBox(width: 13),
                    SizedBox(width: 200, child: _moneyBlock(false)),
                    const SizedBox(width: 13),
                    const SizedBox(width: 18, child: arrow),
                  ]));
        return Semantics(
            button: true,
            label: 'Abrir chamado ${request.id}',
            child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: _line)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: onTap,
                    hoverColor: const Color(0xFFFAFCFF),
                    child: Container(
                      constraints:
                          BoxConstraints(minHeight: narrow ? 190 : 144),
                      decoration: BoxDecoration(
                          border: Border(
                              left: BorderSide(color: _accent, width: 3))),
                      padding: narrow
                          ? const EdgeInsets.fromLTRB(11, 13, 10, 13)
                          : const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: content,
                    ))));
      });
}
