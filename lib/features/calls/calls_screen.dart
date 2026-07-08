import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Demo data ──────────────────────────────────────────────────────────────────

enum _DispatchStatus { waiting, offering, enRoute, inService, done }

class _Ticket {
  _Ticket({
    required this.id,
    required this.customer,
    required this.phone,
    required this.service,
    required this.location,
    required this.partner,
    required this.partnerEta,
    required this.value,
    required this.status,
    required this.openedAt,
    required this.slaMins,
    this.slaWarning = false,
  });

  final String id;
  final String customer;
  final String phone;
  final String service;
  final String location;
  String partner;
  int partnerEta;
  final double value;
  _DispatchStatus status;
  final DateTime openedAt;
  final int slaMins;
  bool slaWarning;
}

class _AiSuggestion {
  const _AiSuggestion({
    required this.ticketId,
    required this.message,
    required this.partner,
    required this.value,
    required this.distance,
    required this.reason,
    required this.icon,
    required this.color,
  });

  final String ticketId;
  final String message;
  final String partner;
  final double value;
  final double distance;
  final String reason;
  final IconData icon;
  final Color color;
}

List<_Ticket> _buildDemoTickets() {
  final now = DateTime.now();
  return [
    _Ticket(
      id: '#4821', customer: 'Ricardo Mendes', phone: '(11) 99234-5670',
      service: 'Guincho', location: 'Av. Paulista, 1578 — Bela Vista',
      partner: 'Aguardando', partnerEta: 0,
      value: 280.00, status: _DispatchStatus.waiting,
      openedAt: now.subtract(const Duration(minutes: 4)), slaMins: 15, slaWarning: true,
    ),
    _Ticket(
      id: '#4820', customer: 'Fernanda Lima', phone: '(11) 98567-3421',
      service: 'Pane Elétrica', location: 'R. Augusta, 890 — Consolação',
      partner: 'Carlos Guincho SP', partnerEta: 8,
      value: 120.00, status: _DispatchStatus.offering,
      openedAt: now.subtract(const Duration(minutes: 9)), slaMins: 20,
    ),
    _Ticket(
      id: '#4819', customer: 'Marcos Oliveira', phone: '(11) 97812-6543',
      service: 'Pane Mecânica', location: 'Marginal Tietê, km 14 — sentido Ayrton Senna',
      partner: 'Rápido Assist 24h', partnerEta: 12,
      value: 190.00, status: _DispatchStatus.enRoute,
      openedAt: now.subtract(const Duration(minutes: 22)), slaMins: 30,
    ),
    _Ticket(
      id: '#4818', customer: 'Ana Paula Costa', phone: '(11) 96345-7890',
      service: 'Troca de Pneu', location: 'Rod. Bandeirantes, km 47 — Jundiaí',
      partner: 'AutoSocorro Norte', partnerEta: 0,
      value: 95.00, status: _DispatchStatus.inService,
      openedAt: now.subtract(const Duration(minutes: 38)), slaMins: 30,
    ),
    _Ticket(
      id: '#4817', customer: 'Bruno Souza', phone: '(11) 95678-1234',
      service: 'Guincho', location: 'Av. Brasil, 200 — Jardins',
      partner: 'Aguardando', partnerEta: 0,
      value: 320.00, status: _DispatchStatus.waiting,
      openedAt: now.subtract(const Duration(minutes: 2)), slaMins: 15,
    ),
    _Ticket(
      id: '#4816', customer: 'Juliana Ferreira', phone: '(11) 94321-8765',
      service: 'Chaveiro Automotivo', location: 'Shopping Iguatemi — Itaim Bibi',
      partner: 'TotalAssist SP', partnerEta: 5,
      value: 150.00, status: _DispatchStatus.offering,
      openedAt: now.subtract(const Duration(minutes: 14)), slaMins: 20,
    ),
    _Ticket(
      id: '#4815', customer: 'Paulo Henrique', phone: '(11) 93456-2109',
      service: 'Reboque', location: 'Av. 23 de Maio, 450 — Liberdade',
      partner: 'Guincho Expresso', partnerEta: 3,
      value: 240.00, status: _DispatchStatus.inService,
      openedAt: now.subtract(const Duration(minutes: 55)), slaMins: 40,
    ),
    _Ticket(
      id: '#4814', customer: 'Camila Rocha', phone: '(11) 92567-3456',
      service: 'Pane Elétrica', location: 'R. Vergueiro, 1200 — Vila Mariana',
      partner: 'ElétricaCar 24h', partnerEta: 0,
      value: 110.00, status: _DispatchStatus.done,
      openedAt: now.subtract(const Duration(minutes: 90)), slaMins: 30,
    ),
  ];
}

const List<_AiSuggestion> _demoSuggestions = [
  _AiSuggestion(
    ticketId: '#4821',
    message: 'Despachar guincho para Ricardo Mendes',
    partner: 'Carlos Guincho SP',
    value: 280.00,
    distance: 1.8,
    reason: 'Mais próximo disponível • Avaliação 4.9 • 97% de aceite',
    icon: Icons.local_shipping_rounded,
    color: Color(0xFF176EEB),
  ),
  _AiSuggestion(
    ticketId: '#4817',
    message: 'Despachar guincho para Bruno Souza',
    partner: 'AutoSocorro Norte',
    value: 320.00,
    distance: 3.2,
    reason: 'Única opção disponível no raio de 5km neste momento',
    icon: Icons.local_shipping_rounded,
    color: Color(0xFF7C3AED),
  ),
];

// ── Providers ──────────────────────────────────────────────────────────────────

final _ticketsProvider = StateProvider<List<_Ticket>>((ref) => _buildDemoTickets());
final _suggestionsProvider = StateProvider<List<_AiSuggestion>>((ref) => _demoSuggestions);
final _selectedTabProvider = StateProvider<_DispatchStatus?>((ref) => null);

// ── Screen ─────────────────────────────────────────────────────────────────────

class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key, this.onClose});
  final VoidCallback? onClose;

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> {
  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(_ticketsProvider);
    final suggestions = ref.watch(_suggestionsProvider);

    final waiting  = tickets.where((t) => t.status == _DispatchStatus.waiting).toList();
    final offering = tickets.where((t) => t.status == _DispatchStatus.offering).toList();
    final enRoute  = tickets.where((t) => t.status == _DispatchStatus.enRoute).toList();
    final inService= tickets.where((t) => t.status == _DispatchStatus.inService).toList();
    final done     = tickets.where((t) => t.status == _DispatchStatus.done).toList();
    final slaWarn  = tickets.where((t) => t.slaWarning && t.status != _DispatchStatus.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────────────
        Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF176EEB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.headset_mic_rounded, color: Color(0xFF176EEB), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chamados', style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w900, fontSize: 18)),
                  SizedBox(height: 1),
                  Text('Central de despacho e atendimento', style: TextStyle(color: Color(0xFF60718D), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (slaWarn > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_off_outlined, size: 13, color: Color(0xFFEF4444)),
                    const SizedBox(width: 5),
                    Text('$slaWarn SLA crítico', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800, fontSize: 11)),
                  ],
                ),
              ),
            FilledButton.icon(
              onPressed: () => _newTicketDialog(context),
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('Novo chamado', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF176EEB),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: () => ref.invalidate(_ticketsProvider),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Atualizar',
              style: IconButton.styleFrom(foregroundColor: const Color(0xFF60718D)),
            ),
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Fechar',
              style: IconButton.styleFrom(foregroundColor: const Color(0xFF60718D)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── KPI row ───────────────────────────────────────────────────────────
        _KpiBar(waiting: waiting.length, offering: offering.length, enRoute: enRoute.length, inService: inService.length, done: done.length),
        const SizedBox(height: 10),

        // ── Charts row ────────────────────────────────────────────────────────
        SizedBox(
          height: 130,
          child: Row(
            children: [
              Expanded(flex: 5, child: _HourlyChart()),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: _CategoryChart(tickets: tickets)),
              const SizedBox(width: 10),
              Expanded(flex: 4, child: _SlaStatsCard(tickets: tickets)),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── AI suggestions ────────────────────────────────────────────────────
        if (suggestions.isNotEmpty) ...[
          _AiPanel(suggestions: suggestions),
          const SizedBox(height: 10),
        ],

        // ── Kanban ────────────────────────────────────────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KanbanColumn(title: 'Aguardando', color: const Color(0xFF9DB1CC), icon: Icons.hourglass_empty_rounded, tickets: waiting, onAction: _onAction),
              const SizedBox(width: 8),
              _KanbanColumn(title: 'Ofertando', color: const Color(0xFFF59E0B), icon: Icons.send_rounded, tickets: offering, onAction: _onAction),
              const SizedBox(width: 8),
              _KanbanColumn(title: 'A caminho', color: const Color(0xFF176EEB), icon: Icons.directions_car_rounded, tickets: enRoute, onAction: _onAction),
              const SizedBox(width: 8),
              _KanbanColumn(title: 'Em serviço', color: const Color(0xFF10B981), icon: Icons.build_rounded, tickets: inService, onAction: _onAction),
              const SizedBox(width: 8),
              _KanbanColumn(title: 'Concluído', color: const Color(0xFF526684), icon: Icons.check_circle_rounded, tickets: done, onAction: _onAction),
            ],
          ),
        ),
      ],
    );
  }

  void _onAction(_Ticket ticket, _DispatchStatus next) {
    ref.read(_ticketsProvider.notifier).update((list) {
      final idx = list.indexWhere((t) => t.id == ticket.id);
      if (idx == -1) return list;
      final updated = List<_Ticket>.from(list);
      updated[idx].status = next;
      if (next == _DispatchStatus.enRoute && updated[idx].partner == 'Aguardando') {
        updated[idx].partner = 'Parceiro Designado';
        updated[idx].partnerEta = 10;
      }
      return updated;
    });
    // Remove AI suggestion for this ticket
    ref.read(_suggestionsProvider.notifier).update(
      (list) => list.where((s) => s.ticketId != ticket.id).toList(),
    );
  }

  void _approveSuggestion(_AiSuggestion s) {
    ref.read(_ticketsProvider.notifier).update((list) {
      final idx = list.indexWhere((t) => t.id == s.ticketId);
      if (idx == -1) return list;
      final updated = List<_Ticket>.from(list);
      updated[idx].status = _DispatchStatus.offering;
      updated[idx].partner = s.partner;
      updated[idx].partnerEta = 8;
      updated[idx].slaWarning = false;
      return updated;
    });
    ref.read(_suggestionsProvider.notifier).update(
      (list) => list.where((sg) => sg.ticketId != s.ticketId).toList(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Oferta enviada para ${s.partner}'), backgroundColor: const Color(0xFF10B981)),
    );
  }

  void _dismissSuggestion(_AiSuggestion s) {
    ref.read(_suggestionsProvider.notifier).update(
      (list) => list.where((sg) => sg.ticketId != s.ticketId).toList(),
    );
  }

  void _newTicketDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Novo chamado — integração com ZPro pendente.')),
    );
  }

  Widget _AiPanel({required List<_AiSuggestion> suggestions}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF176EEB).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF176EEB).withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF176EEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 13),
              ),
              const SizedBox(width: 8),
              const Text('Sugestões da IA', style: TextStyle(color: Color(0xFF176EEB), fontWeight: FontWeight.w900, fontSize: 12.5)),
              const SizedBox(width: 6),
              Text('${suggestions.length} pendente${suggestions.length != 1 ? 's' : ''}',
                  style: const TextStyle(color: Color(0xFF60718D), fontSize: 11, fontWeight: FontWeight.w600)),
              const Spacer(),
              const Text('Aprovação do gestor obrigatória', style: TextStyle(color: Color(0xFF9DB1CC), fontSize: 10.5, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              const Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF9DB1CC)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in suggestions)
                _SuggestionCard(
                  suggestion: s,
                  onApprove: () => _approveSuggestion(s),
                  onDismiss: () => _dismissSuggestion(s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── KPI bar ────────────────────────────────────────────────────────────────────

class _KpiBar extends StatelessWidget {
  const _KpiBar({required this.waiting, required this.offering, required this.enRoute, required this.inService, required this.done});
  final int waiting, offering, enRoute, inService, done;

  @override
  Widget build(BuildContext context) {
    final total = waiting + offering + enRoute + inService + done;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDDE5F0))),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _kpi('Total hoje', '$total', const Color(0xFF526684), Icons.receipt_long_rounded),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _kpi('Aguardando', '$waiting', const Color(0xFF9DB1CC), Icons.hourglass_empty_rounded),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _kpi('Ofertando', '$offering', const Color(0xFFF59E0B), Icons.send_rounded),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _kpi('A caminho', '$enRoute', const Color(0xFF176EEB), Icons.directions_car_rounded),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _kpi('Em serviço', '$inService', const Color(0xFF10B981), Icons.build_rounded),
            const VerticalDivider(width: 1, color: Color(0xFFE8EFF7)),
            _kpi('Concluídos', '$done', const Color(0xFF526684), Icons.check_circle_outline_rounded),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
                Text(label, style: const TextStyle(color: Color(0xFF60718D), fontSize: 10.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Charts ─────────────────────────────────────────────────────────────────────

class _HourlyChart extends StatelessWidget {
  static const _hours = ['06h', '08h', '10h', '12h', '14h', '16h', '18h', '20h', '22h'];
  static const _data  = [2.0, 4.0, 7.0, 11.0, 9.0, 13.0, 8.0, 5.0, 3.0];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDDE5F0))),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chamados por hora', style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w800, fontSize: 11.5)),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              painter: _BarChartPainter(data: _data, labels: _hours, color: const Color(0xFF176EEB)),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({required this.data, required this.labels, required this.color});
  final List<double> data;
  final List<String> labels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final max = data.reduce(math.max);
    final barW = (size.width - (data.length - 1) * 4) / data.length;
    final barPaint = Paint()..color = color.withValues(alpha: 0.80)..style = PaintingStyle.fill;
    final nowPaint = Paint()..color = color..style = PaintingStyle.fill;
    final labelStyle = const TextStyle(color: Color(0xFF9DB1CC), fontSize: 8, fontWeight: FontWeight.w600);

    for (int i = 0; i < data.length; i++) {
      final x = i * (barW + 4);
      final h = (data[i] / max) * (size.height - 16);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - 16 - h, barW, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, i == 5 ? nowPaint : barPaint);

      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, size.height - 13));
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => false;
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.tickets});
  final List<_Ticket> tickets;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final t in tickets) counts[t.service] = (counts[t.service] ?? 0) + 1;
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDDE5F0))),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Por categoria', style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w800, fontSize: 11.5)),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final e in entries.take(4)) ...[
                  _CategoryBar(label: e.key, count: e.value, total: tickets.length),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.label, required this.count, required this.total});
  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF526684), fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: const Color(0xFFE8EFF7),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF176EEB)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('$count', style: const TextStyle(color: Color(0xFF1F2A44), fontSize: 10, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _SlaStatsCard extends StatelessWidget {
  const _SlaStatsCard({required this.tickets});
  final List<_Ticket> tickets;

  @override
  Widget build(BuildContext context) {
    final active = tickets.where((t) => t.status != _DispatchStatus.done).toList();
    final warn = active.where((t) => t.slaWarning).length;
    final avgEta = active.where((t) => t.partnerEta > 0).isEmpty ? 0 :
        active.where((t) => t.partnerEta > 0).map((t) => t.partnerEta).reduce((a, b) => a + b) ~/
        active.where((t) => t.partnerEta > 0).length;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDDE5F0))),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Operação', style: TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w800, fontSize: 11.5)),
          const SizedBox(height: 8),
          _statRow(Icons.timer_off_outlined, 'SLA em risco', '$warn chamado${warn != 1 ? 's' : ''}', const Color(0xFFEF4444)),
          const SizedBox(height: 6),
          _statRow(Icons.directions_car_outlined, 'ETA médio', '~$avgEta min', const Color(0xFF176EEB)),
          const SizedBox(height: 6),
          _statRow(Icons.people_outline_rounded, 'Parceiros ativos', '${active.where((t) => t.partner != 'Aguardando').length}', const Color(0xFF10B981)),
          const SizedBox(height: 6),
          _statRow(Icons.attach_money_rounded, 'Volume hoje',
              'R\$ ${tickets.fold(0.0, (s, t) => s + t.value).toStringAsFixed(0)}', const Color(0xFF526684)),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF60718D), fontSize: 10.5, fontWeight: FontWeight.w600))),
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ── AI suggestion card ─────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onApprove, required this.onDismiss});
  final _AiSuggestion suggestion;
  final VoidCallback onApprove;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: s.color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
                child: Icon(s.icon, size: 13, color: s.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.ticketId, style: TextStyle(color: s.color, fontWeight: FontWeight.w800, fontSize: 10.5)),
                    Text(s.message, style: const TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w700, fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: BoxDecoration(color: const Color(0xFFF7F9FD), borderRadius: BorderRadius.circular(6)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 11, color: Color(0xFF60718D)),
                    const SizedBox(width: 4),
                    Text(s.partner, style: const TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w700, fontSize: 11)),
                    const Spacer(),
                    Text('${s.distance} km', style: const TextStyle(color: Color(0xFF60718D), fontSize: 10.5, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('R\$ ${s.value.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF176EEB), fontWeight: FontWeight.w800, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(s.reason, style: const TextStyle(color: Color(0xFF9DB1CC), fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    foregroundColor: const Color(0xFF526684),
                    side: const BorderSide(color: Color(0xFFDDE5F0)),
                  ),
                  child: const Text('Recusar', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: const Text('Aprovar despacho', style: TextStyle(fontSize: 11)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    backgroundColor: const Color(0xFF176EEB),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Kanban column ──────────────────────────────────────────────────────────────

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.title,
    required this.color,
    required this.icon,
    required this.tickets,
    required this.onAction,
  });

  final String title;
  final Color color;
  final IconData icon;
  final List<_Ticket> tickets;
  final void Function(_Ticket, _DispatchStatus) onAction;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            // Column header
            Container(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 6),
                  Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                    child: Text('${tickets.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            // Cards
            Expanded(
              child: tickets.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('Nenhum', style: TextStyle(color: color.withValues(alpha: 0.40), fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: tickets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _TicketCard(ticket: tickets[i], color: color, onAction: onAction),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ticket card ────────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.color, required this.onAction});
  final _Ticket ticket;
  final Color color;
  final void Function(_Ticket, _DispatchStatus) onAction;

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final elapsed = DateTime.now().difference(t.openedAt).inMinutes;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.slaWarning ? const Color(0xFFEF4444).withValues(alpha: 0.40) : const Color(0xFFDDE5F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: ID + SLA warning
          Row(
            children: [
              Text(t.id, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(t.service, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF526684), fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
              if (t.slaWarning)
                const Icon(Icons.timer_off_rounded, size: 12, color: Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 5),
          // Customer
          Row(children: [
            const Icon(Icons.person_outline_rounded, size: 11, color: Color(0xFF9DB1CC)),
            const SizedBox(width: 4),
            Expanded(child: Text(t.customer, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF1F2A44), fontSize: 11, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 3),
          // Location
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF9DB1CC)),
            const SizedBox(width: 4),
            Expanded(child: Text(t.location, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF60718D), fontSize: 10, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 5),
          // Partner + ETA
          if (t.partner != 'Aguardando') ...[
            Row(children: [
              const Icon(Icons.support_agent_rounded, size: 11, color: Color(0xFF9DB1CC)),
              const SizedBox(width: 4),
              Expanded(child: Text(t.partner, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF526684), fontSize: 10.5, fontWeight: FontWeight.w600))),
              if (t.partnerEta > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFF176EEB).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(4)),
                  child: Text('~${t.partnerEta} min', style: const TextStyle(color: Color(0xFF176EEB), fontSize: 9.5, fontWeight: FontWeight.w800)),
                ),
            ]),
            const SizedBox(height: 5),
          ],
          // Footer: value + elapsed + action
          Row(
            children: [
              Text('R\$ ${t.value.toStringAsFixed(0)}',
                  style: const TextStyle(color: Color(0xFF1F2A44), fontWeight: FontWeight.w800, fontSize: 11)),
              const SizedBox(width: 6),
              Text('${elapsed}min', style: const TextStyle(color: Color(0xFF9DB1CC), fontSize: 10, fontWeight: FontWeight.w600)),
              const Spacer(),
              _actionButton(t),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(_Ticket t) {
    final (label, next, btnColor) = switch (t.status) {
      _DispatchStatus.waiting   => ('Ofertar', _DispatchStatus.offering, const Color(0xFFF59E0B)),
      _DispatchStatus.offering  => ('A caminho', _DispatchStatus.enRoute, const Color(0xFF176EEB)),
      _DispatchStatus.enRoute   => ('Em serviço', _DispatchStatus.inService, const Color(0xFF10B981)),
      _DispatchStatus.inService => ('Concluir', _DispatchStatus.done, const Color(0xFF526684)),
      _DispatchStatus.done      => ('', _DispatchStatus.done, Colors.transparent),
    };

    if (t.status == _DispatchStatus.done) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => onAction(t, next),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: btnColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: btnColor.withValues(alpha: 0.30)),
        ),
        child: Text(label, style: TextStyle(color: btnColor, fontWeight: FontWeight.w800, fontSize: 10)),
      ),
    );
  }
}
