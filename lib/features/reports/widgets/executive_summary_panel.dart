import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/report_models.dart';

class ExecutiveSummaryPanel extends StatelessWidget {
  const ExecutiveSummaryPanel({super.key, required this.summary});

  final ExecutiveKpiSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _KpiCard(
        label: 'Km percorridos',
        value: _distanceLabel(summary.distanceKm.current),
        change: summary.distanceKm.changePercent,
        icon: Icons.route_outlined,
        color: const Color(0xFF176EEB),
        points: summary.distanceKm.sparkline,
      ),
      _KpiCard(
        label: 'Utilizacao da frota',
        value: '${summary.utilizationPercent.current.toStringAsFixed(0)}%',
        change: summary.utilizationPercent.changePercent,
        icon: Icons.donut_large_outlined,
        color: const Color(0xFF10B981),
        points: summary.utilizationPercent.sparkline,
      ),
      _KpiCard(
        label: 'Em operacao',
        value: _hoursLabel(summary.operatingHours.current),
        change: summary.operatingHours.changePercent,
        icon: Icons.timer_outlined,
        color: const Color(0xFFF59E0B),
        points: summary.operatingHours.sparkline,
      ),
      _KpiCard(
        label: 'Alertas criticos',
        value: summary.criticalAlerts.current.toStringAsFixed(0),
        change: summary.criticalAlerts.changePercent,
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFE74B4B),
        points: summary.criticalAlerts.sparkline,
        inverseChangeMeaning: true,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 920;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact)
              Wrap(spacing: 10, runSpacing: 10, children: cards)
            else
              Row(
                children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    Expanded(child: cards[index]),
                    if (index < cards.length - 1) const SizedBox(width: 10),
                  ],
                ],
              ),
            const SizedBox(height: 12),
            if (compact)
              Column(
                children: [
                  _TrendCard(summary: summary),
                  const SizedBox(height: 12),
                  SizedBox(height: 230, child: _TopVehiclesCard(vehicles: summary.topVehicles)),
                ],
              )
            else
              SizedBox(
                height: 250,
                child: Row(
                  children: [
                    Expanded(flex: 7, child: _TrendCard(summary: summary)),
                    const SizedBox(width: 12),
                    Expanded(flex: 4, child: _TopVehiclesCard(vehicles: summary.topVehicles)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  static String _distanceLabel(double value) => value >= 1000
      ? '${(value / 1000).toStringAsFixed(1)} mil km'
      : '${value.toStringAsFixed(0)} km';

  static String _hoursLabel(double value) {
    final minutes = (value * 60).round();
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.change,
    required this.icon,
    required this.color,
    required this.points,
    this.inverseChangeMeaning = false,
  });

  final String label;
  final String value;
  final double? change;
  final IconData icon;
  final Color color;
  final List<double> points;
  final bool inverseChangeMeaning;

  @override
  Widget build(BuildContext context) {
    final positive = change == null || (inverseChangeMeaning ? change! <= 0 : change! >= 0);
    final changeColor = positive ? const Color(0xFF049669) : const Color(0xFFE5484D);
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: _surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 19),
              ),
              const Spacer(),
              if (points.length > 1)
                SizedBox(width: 56, height: 28, child: CustomPaint(painter: _SparklinePainter(points: points, color: color))),
            ],
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Color(0xFF60718D), fontWeight: FontWeight.w700, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: Color(0xFF23324A), fontWeight: FontWeight.w900, fontSize: 23, height: 1.05)),
          const SizedBox(height: 4),
          Text(
            change == null ? 'Sem comparativo anterior' : '${change! >= 0 ? '+' : ''}${change!.toStringAsFixed(0)}% vs. periodo anterior',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: change == null ? const Color(0xFF7B8DA8) : changeColor, fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.summary});
  final ExecutiveKpiSummary summary;

  @override
  Widget build(BuildContext context) {
    final hasCurrent = summary.trendCurrent.any((value) => value > 0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: _surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tendencia operacional', style: TextStyle(color: Color(0xFF263650), fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 2),
          const Text('Quilometragem diaria no periodo selecionado', style: TextStyle(color: Color(0xFF71829C), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Expanded(
            child: hasCurrent
                ? CustomPaint(
                    painter: _TrendPainter(current: summary.trendCurrent, previous: summary.trendPrevious, labels: summary.trendLabels),
                    child: const SizedBox.expand(),
                  )
                : const Center(child: Text('Sem quilometragem registrada no periodo.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF71829C), fontWeight: FontWeight.w600))),
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              _LegendItem(color: Color(0xFF176EEB), label: 'Periodo atual'),
              SizedBox(width: 14),
              _LegendItem(color: Color(0xFF7EAEFF), label: 'Periodo anterior', dashed: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopVehiclesCard extends StatelessWidget {
  const _TopVehiclesCard({required this.vehicles});
  final List<TopVehicleActivity> vehicles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: _surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Veiculos com maior atividade', style: TextStyle(color: Color(0xFF263650), fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 8),
          if (vehicles.isEmpty)
            const Expanded(child: Center(child: Text('Sem atividade no periodo.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF71829C), fontWeight: FontWeight.w600))))
          else
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: math.min(vehicles.length, 4),
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE3EAF3)),
                itemBuilder: (context, index) => _VehicleRow(index: index + 1, vehicle: vehicles[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({required this.index, required this.vehicle});
  final int index;
  final TopVehicleActivity vehicle;

  @override
  Widget build(BuildContext context) {
    final change = vehicle.changePercent;
    final color = change == null || change >= 0 ? const Color(0xFF049669) : const Color(0xFFE5484D);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 20, child: Text('$index', style: const TextStyle(color: Color(0xFF7B8DA8), fontWeight: FontWeight.w800))),
          const Icon(Icons.directions_car_filled_outlined, size: 16, color: Color(0xFF176EEB)),
          const SizedBox(width: 7),
          Expanded(child: Text(vehicle.vehicleName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF263650), fontWeight: FontWeight.w700, fontSize: 12))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${vehicle.distanceKm.toStringAsFixed(0)} km', style: const TextStyle(color: Color(0xFF263650), fontWeight: FontWeight.w800, fontSize: 12)),
              if (change != null) Text('${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.dashed = false});
  final Color color;
  final String label;
  final bool dashed;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 18, child: CustomPaint(painter: _LegendPainter(color: color, dashed: dashed))),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Color(0xFF71829C), fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      );
}

BoxDecoration _surfaceDecoration() => BoxDecoration(
      color: Colors.white.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD7E2F0)),
    );

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.points, required this.color});
  final List<double> points;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final low = points.reduce(math.min);
    final high = points.reduce(math.max);
    final range = (high - low).abs() < 0.001 ? 1.0 : high - low;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i / (points.length - 1) * size.width;
      final y = size.height - ((points[i] - low) / range * (size.height - 4)) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => oldDelegate.points != points || oldDelegate.color != color;
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.current, required this.previous, required this.labels});
  final List<double> current;
  final List<double> previous;
  final List<DateTime> labels;
  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const top = 8.0;
    const bottom = 24.0;
    final chart = Rect.fromLTWH(left, top, math.max(1, size.width - left - 4), math.max(1, size.height - top - bottom));
    final values = [...current, ...previous];
    final maxValue = values.isEmpty ? 1.0 : math.max(1.0, values.reduce(math.max));
    final gridPaint = Paint()..color = const Color(0xFFDDE6F1)..strokeWidth = 1;
    const labelStyle = TextStyle(color: Color(0xFF8090A8), fontSize: 9, fontWeight: FontWeight.w600);
    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height / 3 * i;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final value = maxValue * (3 - i) / 3;
      final painter = TextPainter(text: TextSpan(text: value.toStringAsFixed(0), style: labelStyle), textDirection: TextDirection.ltr)..layout();
      painter.paint(canvas, Offset(0, y - painter.height / 2));
    }
    _paintSeries(canvas, chart, previous, maxValue, const Color(0xFF7EAEFF), dashed: true);
    _paintSeries(canvas, chart, current, maxValue, const Color(0xFF176EEB));
    if (labels.isNotEmpty) {
      for (final i in <int>{0, labels.length ~/ 2, labels.length - 1}) {
        if (i < 0 || i >= labels.length) continue;
        final x = labels.length == 1 ? chart.left : chart.left + chart.width * i / (labels.length - 1);
        final text = '${labels[i].day.toString().padLeft(2, '0')}/${labels[i].month.toString().padLeft(2, '0')}';
        final painter = TextPainter(text: TextSpan(text: text, style: labelStyle), textDirection: TextDirection.ltr)..layout();
        painter.paint(canvas, Offset(x - painter.width / 2, chart.bottom + 5));
      }
    }
  }
  void _paintSeries(Canvas canvas, Rect chart, List<double> values, double maximum, Color color, {bool dashed = false}) {
    if (values.length < 2) return;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = chart.left + chart.width * i / (values.length - 1);
      final y = chart.bottom - (values[i] / maximum).clamp(0.0, 1.0) * chart.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = dashed ? 1.6 : 2.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 9) {
        canvas.drawPath(metric.extractPath(distance, math.min(distance + 5, metric.length)), paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => oldDelegate.current != current || oldDelegate.previous != previous || oldDelegate.labels != labels;
}

class _LegendPainter extends CustomPainter {
  const _LegendPainter({required this.color, required this.dashed});
  final Color color;
  final bool dashed;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2..strokeCap = StrokeCap.round;
    if (dashed) {
      canvas.drawLine(Offset.zero, const Offset(5, 0), paint);
      canvas.drawLine(const Offset(9, 0), Offset(size.width, 0), paint);
    } else {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    }
  }
  @override
  bool shouldRepaint(covariant _LegendPainter oldDelegate) => oldDelegate.color != color || oldDelegate.dashed != dashed;
}
