import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin/admin_reference_ui.dart';
import '../../state/session_state.dart';

class GeneralPanelScreen extends ConsumerWidget {
  const GeneralPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider).valueOrNull ?? const [];
    final positions = ref.watch(positionsProvider).valueOrNull ?? const [];
    final events = ref.watch(latestEventsProvider).valueOrNull ?? const [];
    final orders = ref.watch(ordersProvider).valueOrNull ?? const [];
    final online =
        devices.where((it) => it.status.toLowerCase() == 'online').length;
    final stopped = positions.where((it) => (it.speed ?? 0) <= 1).length;
    final alertCount = events.isNotEmpty
        ? events.length
        : devices.where((it) => it.status.toLowerCase() != 'online').length;

    return AdminReferenceScaffold(
      title: 'Painel Geral',
      breadcrumbs: const ['Comercial', 'Resumo'],
      selectedMenu: 'general-panel',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1080;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _KpiStatCard(
                    label: 'Veículos Online',
                    value: '$online',
                    delta: '${devices.length} total',
                    color: Color(0xFF3F8CFF),
                    icon: Icons.wifi_tethering_rounded,
                  ),
                  _KpiStatCard(
                    label: 'Veículos Parados',
                    value: '$stopped',
                    delta: 'SouTracking',
                    color: Color(0xFFFF5A7A),
                    icon: Icons.pause_circle_outline,
                  ),
                  _KpiStatCard(
                    label: 'Alertas Ativos',
                    value: '$alertCount',
                    delta: '7 dias',
                    color: Color(0xFF00A7B5),
                    icon: Icons.warning_amber_rounded,
                  ),
                  _KpiStatCard(
                    label: 'Ordens Abertas',
                    value: '${orders.length}',
                    delta: 'SouTracking',
                    color: Color(0xFFFFB11B),
                    icon: Icons.assignment_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (compact)
                Column(
                  children: const [
                    _RecentClientsPanel(),
                    SizedBox(height: 12),
                    _GeneralInsightsPanel(),
                  ],
                )
              else
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 8, child: _RecentClientsPanel()),
                    SizedBox(width: 12),
                    Expanded(flex: 4, child: _GeneralInsightsPanel()),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class ServiceOrdersReferenceScreen extends StatelessWidget {
  const ServiceOrdersReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminReferenceScaffold(
      title: 'Ordens de Serviço',
      breadcrumbs: const ['Comercial', 'Ordens'],
      selectedMenu: 'service-orders',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _OrdersFilterBar(),
          SizedBox(height: 12),
          _OrdersTablePanel(),
          SizedBox(height: 12),
          _MiniMapPanel(),
        ],
      ),
    );
  }
}

class FinancialManagementScreen extends StatelessWidget {
  const FinancialManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminReferenceScaffold(
      title: 'Gestão Financeira',
      breadcrumbs: const ['Comercial', 'Financeiro'],
      selectedMenu: 'financial-management',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RevenueChartPanel(),
          SizedBox(height: 12),
          _FinancialOverviewPanel(),
        ],
      ),
    );
  }
}

class InventoryAssetsScreen extends StatelessWidget {
  const InventoryAssetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminReferenceScaffold(
      title: 'Estoque e Ativos',
      breadcrumbs: const ['Comercial', 'Estoque'],
      selectedMenu: 'inventory-assets',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InventorySummaryRow(),
          SizedBox(height: 12),
          _InventoryMainTable(),
          SizedBox(height: 12),
          _InventoryAuxTable(),
        ],
      ),
    );
  }
}

class _KpiStatCard extends StatelessWidget {
  const _KpiStatCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String delta;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 238,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            delta,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentClientsPanel extends StatelessWidget {
  const _RecentClientsPanel();

  @override
  Widget build(BuildContext context) {
    const clients = [
      ('Isabela Silva', 'Ford Ranger', '24/04/2024', 'R\$ 84.912'),
      ('Marcelo Borges', 'Fiat Strada', '24/04/2024', 'R\$ 391.412'),
      ('João Medeiros', 'VW Amarok', '24/04/2024', 'R\$ 441.022'),
    ];

    return _GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(title: 'Clientes Recentes'),
          const SizedBox(height: 8),
          for (final client in clients)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6DDE9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.directions_car_filled_outlined,
                      size: 16,
                      color: Color(0xFF4D607D),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.$1,
                          style: const TextStyle(
                            color: Color(0xFF1F2A44),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          client.$2,
                          style: const TextStyle(
                            color: Color(0xFF6B7C95),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _TinyTag(
                    label: 'Prioritário',
                    color: const Color(0xFF68D2A4),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        client.$3,
                        style: const TextStyle(
                          color: Color(0xFF5E718F),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        client.$4,
                        style: const TextStyle(
                          color: Color(0xFF1F2A44),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GeneralInsightsPanel extends StatelessWidget {
  const _GeneralInsightsPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _PanelHeader(title: 'KPIs'),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total de Clientes',
                    style: TextStyle(
                      color: Color(0xFF5E718F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '282',
                    style: TextStyle(
                      color: Color(0xFF1F2A44),
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              _SparklineChart(height: 56),
              SizedBox(height: 10),
              _DualMetricLegend(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _PanelHeader(title: 'Pagamentos em Atraso'),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LegendItem(
                          color: Color(0xFF3F8CFF),
                          label: 'Boletos Pendentes',
                          value: '18',
                        ),
                        SizedBox(height: 8),
                        _LegendItem(
                          color: Color(0xFFFF5A7A),
                          label: 'Reincidentes',
                          value: '5',
                        ),
                        SizedBox(height: 8),
                        _LegendItem(
                          color: Color(0xFFFFB11B),
                          label: 'Sem notificação',
                          value: '3',
                        ),
                      ],
                    ),
                  ),
                  _DonutChart(size: 120),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrdersFilterBar extends StatelessWidget {
  const _OrdersFilterBar();

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: const [
          _FilterChip(label: 'Filtrar', icon: Icons.search),
          _FilterChip(label: 'Em Aberto', icon: Icons.schedule_outlined),
          _FilterChip(label: 'Em Andamento', icon: Icons.engineering_outlined),
          _FilterChip(label: 'Concluído', icon: Icons.task_alt_outlined),
          _FilterChip(label: 'Pendentes', icon: Icons.flag_outlined),
        ],
      ),
    );
  }
}

class _OrdersTablePanel extends StatelessWidget {
  const _OrdersTablePanel();

  @override
  Widget build(BuildContext context) {
    const rows = [
      (
        'ESJ939',
        'Luís Medeiros',
        'Ford Ranger',
        'Feita na Área',
        'Cancelada',
        'Falta boleto',
        '23/04/2024',
      ),
      (
        'BRP223',
        'Catadoce Range',
        'Renault Master',
        'Sem dor. Crux.',
        'Concluída',
        'V. pendente 01',
        '23/04/2024',
      ),
      (
        'PRF223',
        'Roció Mata',
        'Felipe Mota',
        'Felipe Mota',
        'Cancelada',
        'Retorno 07',
        '23/04/2024',
      ),
      (
        'GRT223',
        'Roció Cifletes',
        'Rape Wistons',
        'Caixa Linha',
        'Andamento',
        'Aguardando',
        '23/04/2024',
      ),
      (
        'BCT30',
        'Rocío Anáxis',
        'Barranco Veta',
        'Caixa Linha',
        'Revisada',
        'Finalizada',
        '23/04/2024',
      ),
    ];

    return _GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(title: 'Tabela de Ordens'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingTextStyle: const TextStyle(
                color: Color(0xFF6E809A),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              dataTextStyle: const TextStyle(
                color: Color(0xFF2E405B),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Cliente')),
                DataColumn(label: Text('Veículo')),
                DataColumn(label: Text('Descrição')),
                DataColumn(label: Text('Serviço')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Abertura')),
              ],
              rows: [
                for (final row in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(row.$1)),
                      DataCell(Text(row.$2)),
                      DataCell(Text(row.$3)),
                      DataCell(Text(row.$4)),
                      DataCell(
                        _TinyTag(
                          label: row.$5,
                          color: row.$5 == 'Concluída'
                              ? const Color(0xFF62D2A2)
                              : row.$5 == 'Andamento'
                                  ? const Color(0xFF4CA9FF)
                                  : const Color(0xFFFFB45C),
                        ),
                      ),
                      DataCell(
                        _TinyTag(label: row.$6, color: const Color(0xFF61D0C2)),
                      ),
                      DataCell(Text(row.$7)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMapPanel extends StatelessWidget {
  const _MiniMapPanel();

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 160,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFEAF2FF),
                        const Color(0xFFDDEBFF).withValues(alpha: 0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(child: CustomPaint(painter: _GridMapPainter())),
            const Positioned(
              right: 20,
              bottom: 14,
              child: Row(
                children: [
                  Icon(Icons.place, color: Color(0xFF2C7BE5), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Mapa Operacional',
                    style: TextStyle(
                      color: Color(0xFF2C4A72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueChartPanel extends StatelessWidget {
  const _RevenueChartPanel();

  @override
  Widget build(BuildContext context) {
    const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago'];
    const values = [42.0, 28.0, 61.0, 50.0, 68.0, 59.0, 81.0, 72.0];

    return _GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(title: 'Receita Mensal'),
          const SizedBox(height: 6),
          const Row(
            children: [
              Text(
                'Acumulado no ano',
                style: TextStyle(
                  color: Color(0xFF6E809A),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Spacer(),
              Text(
                'R\$3.450',
                style: TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < months.length; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 20,
                          height: values[i] * 1.7,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: i.isEven
                                ? const Color(0xFF3E8BFF)
                                : const Color(0xFF63D2C4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          months[i],
                          style: const TextStyle(
                            color: Color(0xFF6E809A),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialOverviewPanel extends StatelessWidget {
  const _FinancialOverviewPanel();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;

        return compact
            ? Column(
                children: const [
                  _FinancialListCard(),
                  SizedBox(height: 12),
                  _QuickActionsCard(),
                ],
              )
            : const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _FinancialListCard()),
                  SizedBox(width: 12),
                  Expanded(flex: 5, child: _QuickActionsCard()),
                ],
              );
      },
    );
  }
}

class _FinancialListCard extends StatelessWidget {
  const _FinancialListCard();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Recebimentos', 'R\$ 293.450', '+6.8%'),
      ('Inadimplências', 'R\$ 28.200', '-1.1%'),
      ('Últimos 30 dias', 'R\$ 146.390', '+4.2%'),
      ('Ticket Médio', 'R\$ 190,00', '+2.4%'),
    ];

    return _GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(title: 'Visão Geral Financeira'),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        color: Color(0xFF526684),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    row.$2,
                    style: const TextStyle(
                      color: Color(0xFF1F2A44),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _TinyTag(
                    label: row.$3,
                    color: row.$3.startsWith('+')
                        ? const Color(0xFF62D2A2)
                        : const Color(0xFFFFB45C),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _PanelHeader(title: 'Ações Rápidas'),
          SizedBox(height: 8),
          _QuickActionRow(
            icon: Icons.receipt_long_outlined,
            title: 'Cobrar Carteira',
            subtitle: '8 pendências hoje',
          ),
          SizedBox(height: 8),
          _QuickActionRow(
            icon: Icons.file_download_done_outlined,
            title: 'Fechar Conciliação',
            subtitle: '2 lotes liberados',
          ),
          SizedBox(height: 8),
          _QuickActionRow(
            icon: Icons.notifications_active_outlined,
            title: 'Enviar Notificação',
            subtitle: 'Clientes em atraso',
          ),
        ],
      ),
    );
  }
}

class _InventorySummaryRow extends StatelessWidget {
  const _InventorySummaryRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _InventorySummaryCard(
          title: 'Estoque de Rastreadores',
          value: '102',
          subline: '12 críticos',
          progress: 0.78,
          color: Color(0xFF3E8BFF),
        ),
        _InventorySummaryCard(
          title: 'Estoque',
          value: '23',
          subline: '4 vencendo',
          progress: 0.54,
          color: Color(0xFF18B7C9),
        ),
        _InventorySummaryCard(
          title: 'Estoque',
          value: '12',
          subline: '2 indisponível',
          progress: 0.36,
          color: Color(0xFFFFB45C),
        ),
      ],
    );
  }
}

class _InventoryMainTable extends StatelessWidget {
  const _InventoryMainTable();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('CH-1100', 'VT1000', 'Rastreador', 'Pendente', '23/03/2024 19:00'),
      ('CH-1199', 'VT1300', 'Rastreador', 'Cancelado', '23/03/2024 15:00'),
      ('CH-1204', 'VT2001', 'Rastreador', 'Ativo', '22/03/2024 10:20'),
    ];

    return _GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(title: 'Estoque de Chips'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              headingTextStyle: const TextStyle(
                color: Color(0xFF6E809A),
                fontWeight: FontWeight.w700,
              ),
              columns: const [
                DataColumn(label: Text('Código')),
                DataColumn(label: Text('Veículo')),
                DataColumn(label: Text('Plano')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Último Mov.')),
              ],
              rows: [
                for (final row in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(row.$1)),
                      DataCell(Text(row.$2)),
                      DataCell(Text(row.$3)),
                      DataCell(
                        _TinyTag(
                          label: row.$4,
                          color: row.$4 == 'Ativo'
                              ? const Color(0xFF62D2A2)
                              : const Color(0xFFFFB45C),
                        ),
                      ),
                      DataCell(Text(row.$5)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryAuxTable extends StatelessWidget {
  const _InventoryAuxTable();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Volvo', '113.000', 'Controlador', '24', 'Cor 05'),
      ('Primo', 'VT200', 'Tacômetro', '12', 'Cor 65'),
      ('111', 'VT100', 'Tacômetro', '18', 'Cor 12'),
    ];

    return _GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(title: 'Estoque do Chips 2'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingTextStyle: const TextStyle(
                color: Color(0xFF6E809A),
                fontWeight: FontWeight.w700,
              ),
              columns: const [
                DataColumn(label: Text('Seção')),
                DataColumn(label: Text('Estoque')),
                DataColumn(label: Text('Tipo')),
                DataColumn(label: Text('Qtde')),
                DataColumn(label: Text('Lote')),
              ],
              rows: [
                for (final row in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(row.$1)),
                      DataCell(Text(row.$2)),
                      DataCell(Text(row.$3)),
                      DataCell(Text(row.$4)),
                      DataCell(Text(row.$5)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventorySummaryCard extends StatelessWidget {
  const _InventorySummaryCard({
    required this.title,
    required this.value,
    required this.subline,
    required this.progress,
    required this.color,
  });

  final String title;
  final String value;
  final String subline;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: _GlassSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF4D607D),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  subline,
                  style: const TextStyle(
                    color: Color(0xFF6E809A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: progress,
                backgroundColor: const Color(0xFFE5ECF7),
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DualMetricLegend extends StatelessWidget {
  const _DualMetricLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Text(
            'Possibilidade\nAguardando',
            style: TextStyle(
              color: Color(0xFF6E809A),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Text(
            'Setor\n53/1000',
            style: TextStyle(
              color: Color(0xFF6E809A),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Text(
            'Sinteiro\n86.143/3000',
            style: TextStyle(
              color: Color(0xFF6E809A),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6E809A),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF2E405B),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _SparklineChart extends StatelessWidget {
  const _SparklineChart({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: const [
            0.1,
            0.2,
            0.25,
            0.18,
            0.32,
            0.38,
            0.28,
            0.46,
            0.55,
            0.51,
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final areaPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x664CA9FF), Color(0x00FFFFFF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePaint = Paint()
      ..color = const Color(0xFF4CA9FF)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final areaPath = Path();

    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final range =
        (maxValue - minValue).abs() < 0.0001 ? 1.0 : maxValue - minValue;

    for (var i = 0; i < values.length; i++) {
      final x = i * size.width / (values.length - 1);
      final t = (values[i] - minValue) / range;
      final y = size.height - (t * size.height * 0.88 + size.height * 0.06);
      if (i == 0) {
        path.moveTo(x, y);
        areaPath.moveTo(x, size.height);
        areaPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        areaPath.lineTo(x, y);
      }
    }
    areaPath.lineTo(size.width, size.height);
    areaPath.close();

    canvas.drawPath(areaPath, areaPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          slices: const [
            _DonutSlice(0.56, Color(0xFFFFB11B)),
            _DonutSlice(0.26, Color(0xFF4CA9FF)),
            _DonutSlice(0.18, Color(0xFFFF5A7A)),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '57%',
                style: TextStyle(
                  color: Color(0xFF1F2A44),
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              Text(
                'Cobrança',
                style: TextStyle(
                  color: Color(0xFF6E809A),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices});

  final List<_DonutSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const startBase = -math.pi / 2;
    var start = startBase;

    for (final slice in slices) {
      final sweep = 2 * math.pi * slice.ratio;
      final paint = Paint()
        ..color = slice.color
        ..strokeWidth = 15
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect.deflate(10), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices;
  }
}

class _DonutSlice {
  const _DonutSlice(this.ratio, this.color);

  final double ratio;
  final Color color;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF526684),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4C84FF), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF243551),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF70839F),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.95),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
      ),
      child: child,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF233653),
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
        const Icon(Icons.unfold_more, color: Color(0xFF9AA9BE), size: 16),
      ],
    );
  }
}

class _GridMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBCD0EA)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final routePaint = Paint()
      ..color = const Color(0xFF4CA9FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(26, size.height - 28)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.58,
        size.width * 0.52,
        size.height * 0.62,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.66,
        size.width - 30,
        24,
      );

    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
