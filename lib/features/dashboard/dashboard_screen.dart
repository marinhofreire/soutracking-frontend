import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices =
        ref.watch(devicesProvider).valueOrNull ?? const <TraccarDevice>[];
    final positions =
        ref.watch(positionsProvider).valueOrNull ?? const <TraccarPosition>[];
    final latestEvents = ref.watch(latestEventsProvider).valueOrNull ??
        const <Map<String, dynamic>>[];
    final orders =
        ref.watch(ordersProvider).valueOrNull ?? const <Map<String, dynamic>>[];

    final positionByDeviceId = <int, TraccarPosition>{
      for (final position in positions) position.deviceId: position,
    };

    final total = devices.length;
    final online = devices.where((d) => _isOnline(d.status)).length;
    final offline = devices.where((d) => _isOffline(d.status)).length;
    final moving = positions.where((p) => (p.speed ?? 0) > 1).length;
    final noCommunication =
        devices.where((d) => !positionByDeviceId.containsKey(d.id)).length;
    final alerts = latestEvents.isNotEmpty
        ? latestEvents.length
        : devices.where((d) => !_isOnline(d.status)).length;
    final avgSpeed = _averageSpeed(positions);

    final onlineStopped = math.max(0, online - moving);
    final fleetStatusSeries = <_ChartSlice>[
      _ChartSlice(
        label: 'Em movimento',
        value: moving,
        color: const Color(0xFF22C55E),
      ),
      _ChartSlice(
        label: 'Online',
        value: onlineStopped,
        color: const Color(0xFF06B6D4),
      ),
      _ChartSlice(
        label: 'Offline',
        value: offline,
        color: const Color(0xFF9CA3AF),
      ),
      _ChartSlice(
        label: 'Sem comunicação',
        value: noCommunication,
        color: const Color(0xFFF59E0B),
      ),
    ];

    final speedSeries = positions
        .map((p) => p.speed ?? 0)
        .where((v) => v > 0)
        .take(20)
        .toList(growable: false);

    final rankingRows = devices.map((device) {
      final position = positionByDeviceId[device.id];
      return _RankingRow(
        deviceName: device.name.trim().isEmpty ? 'Sem nome' : device.name,
        distanceKm: _distanceKmFromPosition(position),
        speed: position?.speed ?? 0,
        status: device.status,
      );
    }).toList(growable: false)
      ..sort((a, b) {
        final distanceOrder = b.distanceKm.compareTo(a.distanceKm);
        if (distanceOrder != 0) return distanceOrder;
        return b.speed.compareTo(a.speed);
      });

    final topRanking = rankingRows.take(6).toList(growable: false);
    final recentEvents = latestEvents.take(6).toList(growable: false);
    final maintenance = _maintenanceSummary(orders);

    final totalCards = <_MetricData>[
      _MetricData(
        title: 'Frota total',
        value: '$total',
        subtitle: 'equipamentos monitorados',
        icon: Icons.directions_car_filled_outlined,
        color: const Color(0xFF176EEB),
      ),
      _MetricData(
        title: 'Online',
        value: '$online',
        subtitle: '${_percent(online, total)}% do total',
        icon: Icons.wifi_tethering_rounded,
        color: const Color(0xFF22C55E),
      ),
      _MetricData(
        title: 'Offline',
        value: '$offline',
        subtitle: '${_percent(offline, total)}% do total',
        icon: Icons.power_settings_new_rounded,
        color: const Color(0xFF9CA3AF),
      ),
      _MetricData(
        title: 'Em movimento',
        value: '$moving',
        subtitle: '${_percent(moving, total)}% do total',
        icon: Icons.near_me_rounded,
        color: const Color(0xFFF59E0B),
      ),
      _MetricData(
        title: 'Alertas',
        value: '$alerts',
        subtitle: 'eventos recentes',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFEF4444),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final width =
                ((constraints.maxWidth - (totalCards.length - 1) * spacing) /
                        totalCards.length)
                    .clamp(170.0, 240.0)
                    .toDouble();
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < totalCards.length; i++) ...[
                    SizedBox(
                      width: width,
                      child: _CommercialMetricCard(data: totalCards[i]),
                    ),
                    if (i != totalCards.length - 1) const SizedBox(width: 10),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1080;
            final firstColumn = Column(
              children: [
                _CommercialPanelCard(
                  title: 'Resumo operacional',
                  subtitle: 'Panorama geral da operação',
                  icon: Icons.dashboard_customize_outlined,
                  child: Column(
                    children: [
                      _SummaryLine(
                        label: 'Status predominante',
                        value: moving >= onlineStopped
                            ? 'Frota em movimento'
                            : 'Frota estável',
                      ),
                      const SizedBox(height: 7),
                      _SummaryLine(
                        label: 'Velocidade média',
                        value: '${avgSpeed.toStringAsFixed(1)} km/h',
                      ),
                      const SizedBox(height: 7),
                      _SummaryLine(
                        label: 'Sem comunicação',
                        value: '$noCommunication equipamento(s)',
                      ),
                      const SizedBox(height: 7),
                      _SummaryLine(
                        label: 'Eventos críticos',
                        value: '$alerts registro(s) recente(s)',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _CommercialPanelCard(
                  title: 'Velocidade média',
                  subtitle: 'Oscilação das últimas leituras',
                  icon: Icons.show_chart_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            avgSpeed.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Color(0xFF1F2A44),
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                              height: 0.95,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 3),
                            child: Text(
                              'km/h',
                              style: TextStyle(
                                color: Color(0xFF52627C),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 86,
                        child: _SpeedSparkline(values: speedSeries),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final secondColumn = Column(
              children: [
                _CommercialPanelCard(
                  title: 'Status da frota',
                  subtitle: 'Distribuição operacional',
                  icon: Icons.pie_chart_outline_rounded,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 136,
                        height: 136,
                        child: _FleetStatusDonut(series: fleetStatusSeries),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          children: [
                            for (final slice in fleetStatusSeries)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: _LegendLine(
                                  color: slice.color,
                                  label: slice.label,
                                  value: slice.value,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _CommercialPanelCard(
                  title: 'Manutenção',
                  subtitle: 'Acompanhamento de ordens',
                  icon: Icons.build_circle_outlined,
                  child: maintenance.isEmpty
                      ? const _EmptyStateText(
                          text: 'Sem registros de manutenção no período.',
                        )
                      : Column(
                          children: [
                            for (final row in maintenance)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: _MaintenanceLine(row: row),
                              ),
                          ],
                        ),
                ),
              ],
            );

            if (compact) {
              return Column(
                children: [
                  firstColumn,
                  const SizedBox(height: 10),
                  secondColumn,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: firstColumn),
                const SizedBox(width: 10),
                Expanded(child: secondColumn),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1080;
            final eventsCard = _CommercialPanelCard(
              title: 'Eventos recentes',
              subtitle: 'Últimos alertas e mudanças',
              icon: Icons.notifications_active_outlined,
              child: recentEvents.isEmpty
                  ? const _EmptyStateText(
                      text: 'Nenhum evento recente retornado pelo servidor.',
                    )
                  : Column(
                      children: [
                        for (final event in recentEvents)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: _EventLine(
                              type: '${event['type'] ?? 'evento'}',
                              details:
                                  '${event['attributes']?['message'] ?? event['attributes']?['alarm'] ?? 'Atualização operacional'}',
                              rawDate:
                                  '${event['eventTime'] ?? event['serverTime'] ?? ''}',
                            ),
                          ),
                      ],
                    ),
            );

            final rankingCard = _CommercialPanelCard(
              title: 'Ranking / Top veículos',
              subtitle: 'Distância percorrida',
              icon: Icons.leaderboard_outlined,
              child: topRanking.isEmpty
                  ? const _EmptyStateText(
                      text: 'Nenhum veículo com distância disponível.',
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < topRanking.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: _RankingLine(
                              rank: i + 1,
                              row: topRanking[i],
                            ),
                          ),
                      ],
                    ),
            );

            if (compact) {
              return Column(
                children: [
                  eventsCard,
                  const SizedBox(height: 10),
                  rankingCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: eventsCard),
                const SizedBox(width: 10),
                Expanded(flex: 5, child: rankingCard),
              ],
            );
          },
        ),
      ],
    );
  }
}

bool _isOnline(String status) {
  final value = status.toLowerCase().trim();
  return value == 'online';
}

bool _isOffline(String status) {
  final value = status.toLowerCase().trim();
  return value == 'offline';
}

double _averageSpeed(List<TraccarPosition> positions) {
  final valid = positions.map((p) => p.speed ?? 0).where((v) => v > 0).toList();
  if (valid.isEmpty) return 0;
  final total = valid.fold<double>(0, (sum, speed) => sum + speed);
  return total / valid.length;
}

double _distanceKmFromPosition(TraccarPosition? position) {
  if (position == null) return 0;
  final attrs = position.attributes ?? const <String, dynamic>{};
  final rawValue =
      attrs['distance'] ?? attrs['totalDistance'] ?? attrs['odometer'];
  final numeric = rawValue is num
      ? rawValue.toDouble()
      : double.tryParse('${rawValue ?? ''}') ?? 0;
  if (numeric <= 0) return 0;
  // Traccar usually reports distance/odometer in meters.
  return numeric / 1000;
}

int _percent(int value, int total) {
  if (total <= 0) return 0;
  return ((value * 100) / total).round().clamp(0, 100);
}

List<_MaintenanceData> _maintenanceSummary(List<Map<String, dynamic>> orders) {
  if (orders.isEmpty) return const <_MaintenanceData>[];
  final now = DateTime.now();
  var open = 0;
  var closed = 0;
  var dueSoon = 0;

  for (final order in orders) {
    final status =
        '${order['status'] ?? order['state'] ?? ''}'.toLowerCase().trim();
    final closedStatus = status.contains('concl') ||
        status.contains('final') ||
        status.contains('fech') ||
        status.contains('close') ||
        status.contains('done');
    if (closedStatus) {
      closed++;
    } else {
      open++;
    }

    final dateRaw = order['scheduledDate'] ??
        order['scheduleDate'] ??
        order['dueDate'] ??
        order['nextServiceDate'];
    final dueAt = DateTime.tryParse('${dateRaw ?? ''}');
    if (dueAt == null) continue;
    final localDue = dueAt.isUtc ? dueAt.toLocal() : dueAt;
    final days = localDue.difference(now).inDays;
    if (days >= 0 && days <= 7) {
      dueSoon++;
    }
  }

  return <_MaintenanceData>[
    _MaintenanceData(
      label: 'Ordens em aberto',
      value: '$open',
      color: const Color(0xFF176EEB),
    ),
    _MaintenanceData(
      label: 'Vencendo em 7 dias',
      value: '$dueSoon',
      color: const Color(0xFFF59E0B),
    ),
    _MaintenanceData(
      label: 'Concluídas',
      value: '$closed',
      color: const Color(0xFF22C55E),
    ),
  ];
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _CommercialMetricCard extends StatelessWidget {
  const _CommercialMetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE6F2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF11243E).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, size: 18, color: data.color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF60718D),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    height: 0.95,
                  ),
                ),
                Text(
                  data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF60718D),
                    fontWeight: FontWeight.w600,
                    fontSize: 9.8,
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

class _CommercialPanelCard extends StatelessWidget {
  const _CommercialPanelCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE6F2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF176EEB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 17, color: const Color(0xFF176EEB)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2A44),
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF60718D),
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5ECF6)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF60718D),
              fontWeight: FontWeight.w700,
              fontSize: 11.3,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w800,
              fontSize: 11.8,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF52627C),
              fontWeight: FontWeight.w700,
              fontSize: 11.3,
            ),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            color: Color(0xFF1F2A44),
            fontWeight: FontWeight.w900,
            fontSize: 12.8,
          ),
        ),
      ],
    );
  }
}

class _ChartSlice {
  const _ChartSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class _FleetStatusDonut extends StatelessWidget {
  const _FleetStatusDonut({required this.series});

  final List<_ChartSlice> series;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FleetStatusDonutPainter(series: series),
      child: const SizedBox.expand(),
    );
  }
}

class _FleetStatusDonutPainter extends CustomPainter {
  _FleetStatusDonutPainter({required this.series});

  final List<_ChartSlice> series;

  @override
  void paint(Canvas canvas, Size size) {
    final total = series.fold<int>(0, (sum, item) => sum + item.value);
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius - 6);
    final stroke = 18.0;
    final background = Paint()
      ..color = const Color(0xFFE5ECF6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, background);

    if (total <= 0) return;
    var start = -math.pi / 2;
    for (final item in series) {
      if (item.value <= 0) continue;
      final sweep = (item.value / total) * math.pi * 2;
      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _FleetStatusDonutPainter oldDelegate) {
    return oldDelegate.series != series;
  }
}

class _SpeedSparkline extends StatelessWidget {
  const _SpeedSparkline({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpeedSparklinePainter(values: values),
      child: const SizedBox.expand(),
    );
  }
}

class _SpeedSparklinePainter extends CustomPainter {
  _SpeedSparklinePainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final valuesToDraw = values.isEmpty ? <double>[0, 0, 0, 0] : values;
    final maxValue = valuesToDraw.reduce(math.max);
    final minValue = valuesToDraw.reduce(math.min);
    final range =
        (maxValue - minValue).abs() < 0.0001 ? 1.0 : maxValue - minValue;

    final guidePaint = Paint()
      ..color = const Color(0xFFE5ECF6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }

    final path = Path();
    for (var i = 0; i < valuesToDraw.length; i++) {
      final x = valuesToDraw.length == 1
          ? size.width / 2
          : (size.width / (valuesToDraw.length - 1)) * i;
      final normalized = (valuesToDraw[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 4)) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x6622C55E),
          Color(0x1022C55E),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SpeedSparklinePainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _MaintenanceData {
  const _MaintenanceData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

class _MaintenanceLine extends StatelessWidget {
  const _MaintenanceLine({required this.row});

  final _MaintenanceData row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE6F2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: row.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row.label,
              style: const TextStyle(
                color: Color(0xFF52627C),
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ),
          Text(
            row.value,
            style: const TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventLine extends StatelessWidget {
  const _EventLine({
    required this.type,
    required this.details,
    required this.rawDate,
  });

  final String type;
  final String details;
  final String rawDate;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(rawDate);
    final local = date == null ? null : (date.isUtc ? date.toLocal() : date);
    final label = local == null
        ? '--:--'
        : '${local.hour.toString().padLeft(2, '0')}:'
            '${local.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE6F2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            size: 16,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF52627C),
                    fontWeight: FontWeight.w700,
                    fontSize: 10.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF60718D),
              fontWeight: FontWeight.w700,
              fontSize: 10.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingRow {
  const _RankingRow({
    required this.deviceName,
    required this.distanceKm,
    required this.speed,
    required this.status,
  });

  final String deviceName;
  final double distanceKm;
  final double speed;
  final String status;
}

class _RankingLine extends StatelessWidget {
  const _RankingLine({
    required this.rank,
    required this.row,
  });

  final int rank;
  final _RankingRow row;

  @override
  Widget build(BuildContext context) {
    final normalized = row.status.toLowerCase().trim();
    final color = normalized == 'online'
        ? const Color(0xFF22C55E)
        : normalized == 'offline'
            ? const Color(0xFF9CA3AF)
            : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE6F2)),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF176EEB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Color(0xFF176EEB),
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.directions_car_filled_rounded,
            size: 16,
            color: Color(0xFF4B5D79),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              row.deviceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1F2A44),
                fontWeight: FontWeight.w800,
                fontSize: 11.6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            row.distanceKm > 0
                ? '${row.distanceKm.toStringAsFixed(1)} km'
                : '${row.speed.toStringAsFixed(0)} km/h',
            style: const TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w900,
              fontSize: 11.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateText extends StatelessWidget {
  const _EmptyStateText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF60718D),
        fontWeight: FontWeight.w600,
        fontSize: 11.4,
      ),
    );
  }
}
