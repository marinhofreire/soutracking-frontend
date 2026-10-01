import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bridge_client.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';

// Visão consolidada pro dono da plataforma. Layout pixel-perfect a partir do
// protótipo aprovado (docs/painel-master/01-dashboard-master.html) -- mesma
// grade de 6 KPIs, mesmas 3 colunas do meio, mesma tabela embaixo -- mas com
// dado 100% real onde existe hoje, e "—"/zerado honesto onde não existe
// ainda, em vez dos números demonstrativos do protótipo (Aurora/Horizonte/Via
// eram fictícios).
//
// Limitação real e conhecida (mesma do CallsScreen): hoje o login só carrega
// UM tenant por sessão e o backend tem o cliente B2B fixo em variável de
// ambiente -- não existe consulta "todas as empresas de uma vez". Por isso
// o card "Empresas sob sua gestão" mostra só a empresa da sessão atual, e o
// MRR/Churn ficam em "—" (sem fonte de dado ainda), igual ao protótipo já
// fazia mesmo lá.
class MasterPanelScreen extends ConsumerWidget {
  const MasterPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final devices =
        ref.watch(devicesProvider).valueOrNull ?? const <TraccarDevice>[];
    final chamados = ref.watch(chamadosProvider);
    final companyName = session.tenantConfig.companyName.isNotEmpty
        ? session.tenantConfig.companyName
        : 'SouTracking';

    final totalVeiculos = devices.length;
    final online = devices.where((d) => _isOnline(d.status)).length;
    final offline = devices.where((d) => _isOffline(d.status)).length;
    final stats = chamados.valueOrNull?.stats;
    final chamadosAbertos = stats?.total ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoticeBanner(companyName: companyName),
          const SizedBox(height: 14),
          const _Heading(),
          const SizedBox(height: 16),
          _KpiGrid(
            empresasAtivas: 1,
            totalVeiculos: totalVeiculos,
            online: online,
            offline: offline,
            chamadosAbertos: chamadosAbertos,
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final children = <Widget>[
                _AttentionCard(chamados: chamados),
                _FleetHealthCard(
                  total: totalVeiculos,
                  online: online,
                  offline: offline,
                ),
                const _PipelineCard(),
              ];
              if (!isWide) {
                return Column(
                  children: [
                    for (final c in children) ...[
                      c,
                      const SizedBox(height: 13),
                    ],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 138, child: children[0]),
                    const SizedBox(width: 13),
                    Expanded(flex: 100, child: children[1]),
                    const SizedBox(width: 13),
                    Expanded(flex: 93, child: children[2]),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final companiesCard = _CompaniesCard(
                companyName: companyName,
                totalVeiculos: totalVeiculos,
                online: online,
                chamadosAbertos: chamadosAbertos,
              );
              const reference = _ReferenceCard();
              if (!isWide) {
                return Column(
                  children: [
                    companiesCard,
                    const SizedBox(height: 13),
                    reference,
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: companiesCard),
                    const SizedBox(width: 13),
                    const SizedBox(width: 265, child: reference),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _isOnline(String? status) =>
      (status ?? '').trim().toLowerCase() == 'online';

  bool _isOffline(String? status) =>
      (status ?? '').trim().toLowerCase() == 'offline';
}

const _kInk = Color(0xFF1F2A44);
const _kMuted = Color(0xFF718099);
const _kLine = Color(0xFFDCE5F1);
const _kBlue = Color(0xFF176EEB);
const _kGreen = Color(0xFF19A875);
const _kAmber = Color(0xFFDC941C);
const _kRed = Color(0xFFDC5662);

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.companyName});
  final String companyName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration:
              const BoxDecoration(color: Color(0xFFC69D48), shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Painel Master · mostrando dado real de "$companyName" (a conta logada). Consolidar múltiplas empresas ainda não existe no backend.',
            style: const TextStyle(
                color: Color(0xFF7B6639),
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VISÃO CONSOLIDADA',
                  style: TextStyle(
                      color: _kBlue,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
              SizedBox(height: 4),
              Text('Sua operação, em um só lugar.',
                  style: TextStyle(
                      color: _kInk,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6)),
              SizedBox(height: 5),
              Text('Acompanhe o comercial, a frota e os atendimentos.',
                  style: TextStyle(
                      color: _kMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: _kLine),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: _kMuted),
              const SizedBox(width: 8),
              Text(_todayLabel(),
                  style: const TextStyle(
                      color: _kInk,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const Text('  ·  Visão do dia',
                  style: TextStyle(
                      color: Color(0xFFA2AEC0),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  static String _todayLabel() {
    const meses = [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez',
    ];
    final now = DateTime.now();
    return '${now.day} ${meses[now.month - 1]} ${now.year}';
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.empresasAtivas,
    required this.totalVeiculos,
    required this.online,
    required this.offline,
    required this.chamadosAbertos,
  });

  final int empresasAtivas;
  final int totalVeiculos;
  final int online;
  final int offline;
  final int chamadosAbertos;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiData('Empresas ativas', '$empresasAtivas', 'Sua conta',
          Icons.apartment_outlined, _kGreen),
      _KpiData('MRR consolidado', '—', 'Aguardando dados de contratos',
          Icons.account_balance_wallet_outlined, _kMuted),
      _KpiData('Churn mensal', '—', 'Aguardando histórico de clientes',
          Icons.show_chart_rounded, _kMuted),
      _KpiData(
          'Chamados abertos',
          '$chamadosAbertos',
          chamadosAbertos > 0 ? 'Verificar SLA' : 'Nenhum chamado aberto',
          Icons.headset_mic_outlined,
          chamadosAbertos > 0 ? _kRed : _kGreen),
      _KpiData('Veículos na frota', '$totalVeiculos',
          '$online online · $offline offline', Icons.directions_car_outlined, _kMuted),
      _KpiData('Demandas pendentes', '—', 'Instalações e manutenções',
          Icons.calendar_today_outlined, _kAmber),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final perRow = constraints.maxWidth > 1100
          ? 6
          : constraints.maxWidth > 760
              ? 3
              : 2;
      final gap = 10.0;
      final cardWidth =
          (constraints.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final c in cards) SizedBox(width: cardWidth, child: _KpiCard(c)),
        ],
      );
    });
  }
}

class _KpiData {
  const _KpiData(this.label, this.value, this.note, this.icon, this.noteColor);
  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color noteColor;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.data);
  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(data.label,
                    style: const TextStyle(
                        color: Color(0xFF63728A),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
              Icon(data.icon, size: 15, color: _kBlue),
            ],
          ),
          const SizedBox(height: 4),
          Text(data.value,
              style: const TextStyle(
                  color: _kInk,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6)),
          const SizedBox(height: 5),
          Text(data.note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: data.noteColor == _kMuted
                      ? const Color(0xFF8591A5)
                      : data.noteColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _kLine),
      ),
      child: child,
    );
  }
}

class _CardHead extends StatelessWidget {
  const _CardHead({required this.title, this.pillText, this.pillRed = false});
  final String title;
  final String? pillText;
  final bool pillRed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  color: _kInk, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        if (pillText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: pillRed ? const Color(0xFFFFF0F1) : const Color(0xFFEDF4FF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(pillText!,
                style: TextStyle(
                    color: pillRed ? const Color(0xFFC74855) : _kBlue,
                    fontSize: 9,
                    fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.chamados});
  final AsyncValue<ChamadosResult> chamados;

  @override
  Widget build(BuildContext context) {
    final stats = chamados.valueOrNull?.stats;
    final aguardando = stats?.aguardando ?? 0;
    final hasPendencia = aguardando > 0;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHead(
            title: 'Precisam da sua atenção',
            pillText: hasPendencia ? '$aguardando aguardando' : 'Tudo em dia',
            pillRed: hasPendencia,
          ),
          const SizedBox(height: 2),
          const Text('Prioridades de atendimento e operação',
              style: TextStyle(
                  color: Color(0xFF8491A5),
                  fontSize: 9,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Expanded(
            child: chamados.when(
              loading: () => const Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
              error: (_, __) => const _EmptyMini(
                  text: 'Não foi possível carregar chamados agora.'),
              data: (result) {
                if (result.os.isEmpty) {
                  return const _EmptyMini(
                      text: 'Nenhum chamado real pendente agora.');
                }
                final items = result.os.take(3).toList();
                return ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, color: Color(0xFFEFF3F8)),
                  itemBuilder: (context, i) {
                    final c = items[i];
                    final urgent = c.status == 'aguardando';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Container(
                            width: 27,
                            height: 27,
                            decoration: BoxDecoration(
                              color: urgent
                                  ? const Color(0xFFFFF0F1)
                                  : const Color(0xFFFFF7E8),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(
                              urgent
                                  ? Icons.headset_mic_rounded
                                  : Icons.warning_amber_rounded,
                              size: 14,
                              color: urgent
                                  ? const Color(0xFFD65863)
                                  : const Color(0xFFC49439),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.tipo.isNotEmpty ? c.tipo : 'Chamado #${c.id}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(c.status,
                                    style: const TextStyle(
                                        color: Color(0xFF7E8BA1),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMini extends StatelessWidget {
  const _EmptyMini({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFF9DAAC0), fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _FleetHealthCard extends StatelessWidget {
  const _FleetHealthCard({
    required this.total,
    required this.online,
    required this.offline,
  });

  final int total;
  final int online;
  final int offline;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : online / total;
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHead(title: 'Saúde da frota'),
          const SizedBox(height: 2),
          const Text('Comunicação dos veículos agora',
              style: TextStyle(
                  color: Color(0xFF8491A5),
                  fontSize: 9,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(96, 96),
                      painter: _RingPainter(pct: pct),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$total',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: _kInk)),
                        const Text('veículos',
                            style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF8390A4))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendRow('Online', online, const Color(0xFF299E83)),
                    const SizedBox(height: 10),
                    _legendRow('Offline', offline, const Color(0xFFD9E2EE)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAEE),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 12, color: Color(0xFFAC7F2D)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    offline > 0
                        ? '$offline veículo(s) sem comunicação'
                        : 'Toda a frota comunicando',
                    style: const TextStyle(
                        color: Color(0xFFAC7F2D),
                        fontSize: 9,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: _kInk, fontSize: 10, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text('$value',
            style: const TextStyle(
                color: _kInk, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.pct});
  final double pct;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokePaintBg = Paint()
      ..color = const Color(0xFFE5EBF4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    final strokePaintFg = Paint()
      ..color = const Color(0xFF299E83)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius - 6, strokePaintBg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      -math.pi / 2,
      2 * math.pi * pct,
      false,
      strokePaintFg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.pct != pct;
}

class _PipelineCard extends StatelessWidget {
  const _PipelineCard();

  @override
  Widget build(BuildContext context) {
    const stages = ['Leads', 'Proposta', 'Negociação', 'Fechado'];
    const colors = [
      Color(0xFFA9C6F7),
      Color(0xFF7EA8EF),
      Color(0xFF4E89E7),
      Color(0xFF299E83),
    ];

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHead(title: 'Funil comercial', pillText: 'Sem CRM ligado', pillRed: true),
          const SizedBox(height: 2),
          const Text('Oportunidades por etapa',
              style: TextStyle(
                  color: Color(0xFF8491A5),
                  fontSize: 9,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          for (var i = 0; i < stages.length; i++) ...[
            _StageRow(label: stages[i], value: 0, color: colors[i]),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFEDF1F6)),
          const SizedBox(height: 7),
          const Text('Barras zeradas: nenhum CRM comercial conectado ainda',
              style: TextStyle(
                  color: Color(0xFF718199),
                  fontSize: 9,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFF75849B), fontSize: 10, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FA),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value <= 0 ? 0.001 : (value / 4).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 14,
          child: Text('$value',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _CompaniesCard extends StatelessWidget {
  const _CompaniesCard({
    required this.companyName,
    required this.totalVeiculos,
    required this.online,
    required this.chamadosAbertos,
  });

  final String companyName;
  final int totalVeiculos;
  final int online;
  final int chamadosAbertos;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Empresas sob sua gestão',
                    style: TextStyle(
                        color: _kInk, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const Text('1 empresa · dado real da sessão',
                  style: TextStyle(
                      color: Color(0xFF8895A9),
                      fontSize: 9,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
            },
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Color(0xFFF9FBFE)),
                children: [
                  _TableHeadCell('Empresa'),
                  _TableHeadCell('Frota'),
                  _TableHeadCell('Chamados'),
                  _TableHeadCell('Demandas'),
                  _TableHeadCell('Situação'),
                ],
              ),
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFEEF2F8))),
                ),
                children: [
                  _TableCompanyCell(companyName),
                  _TableCell('$totalVeiculos / $online online'),
                  _TableCell('$chamadosAbertos abertos'),
                  const _TableCell('—'),
                  const _TableStatusCell(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableHeadCell extends StatelessWidget {
  const _TableHeadCell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Text(text,
          style: const TextStyle(
              color: Color(0xFF8895A9), fontSize: 9, fontWeight: FontWeight.w500)),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Text(text, style: const TextStyle(fontSize: 10)),
    );
  }
}

class _TableCompanyCell extends StatelessWidget {
  const _TableCompanyCell(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final abbr = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 19,
            height: 19,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEDF3FD),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(abbr,
                style: const TextStyle(
                    color: Color(0xFF7393C5), fontSize: 8, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _TableStatusCell extends StatelessWidget {
  const _TableStatusCell();

  @override
  Widget build(BuildContext context) {
    // Não existe campo de status de contrato/billing por tenant hoje
    // (TenantConfig não tem isso) -- "Sessão ativa" é honesto porque só
    // reflete que a sessão logada está autenticada agora, não um status
    // administrativo real de assinatura.
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: _kGreen),
          SizedBox(width: 4),
          Text('Sessão ativa', style: TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        border: Border.all(color: const Color(0xFFD7E5FA)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('REFERÊNCIA HISTÓRICA · NÃO É AO VIVO',
                    style: TextStyle(
                        color: Color(0xFF5E7EAC),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6)),
              ),
              const Icon(Icons.history_rounded, size: 13, color: Color(0xFF5E7EAC)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Operação SouFind',
              style: TextStyle(color: _kInk, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          const Text('Retrato de 23/09/2026 · números fixos, não consultam produção',
              style: TextStyle(
                  color: Color(0xFF8B98AE),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 13),
          const Row(
            children: [
              _RefValue(value: '59', label: 'OS registradas'),
              _RefDivider(),
              _RefValue(value: 'R\$ 880', label: 'receita total'),
              _RefDivider(),
              _RefValue(value: '1', label: 'parceiro online'),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Retrato pontual, não é MRR e não acompanha filtro de empresa.',
            style: TextStyle(color: Color(0xFF7D8BA1), fontSize: 9, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _RefValue extends StatelessWidget {
  const _RefValue({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Color(0xFF7E8CA3), fontSize: 9)),
        ],
      ),
    );
  }
}

class _RefDivider extends StatelessWidget {
  const _RefDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFFDCE6F4),
    );
  }
}
