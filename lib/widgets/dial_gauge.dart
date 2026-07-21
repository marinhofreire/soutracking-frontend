import 'dart:math' as math;

import 'package:flutter/material.dart';

const double gaugeStartAngle = math.pi * 3 / 4; // 135° — bottom-left
const double gaugeSweep = math.pi * 3 / 2; // 270°

/// Mostrador circular tipo velocímetro/RPM, extraído da tela de Telemetria
/// para reutilização em outras áreas do app (ex: overlay de replay no mapa).
class DialGauge extends StatelessWidget {
  const DialGauge({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.max,
    required this.color,
    required this.ticks,
    required this.loading,
  });

  final String label;
  final String unit;
  final double value;
  final double max;
  final Color color;
  final List<double> ticks;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F0)),
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : CustomPaint(
                painter: DialPainter(
                  label: label,
                  unit: unit,
                  value: value.clamp(0.0, max),
                  max: max,
                  color: color,
                  ticks: ticks,
                ),
              ),
      ),
    );
  }
}

class DialPainter extends CustomPainter {
  const DialPainter({
    required this.label,
    required this.unit,
    required this.value,
    required this.max,
    required this.color,
    required this.ticks,
  });

  final String label;
  final String unit;
  final double value;
  final double max;
  final Color color;
  final List<double> ticks;

  @override
  void paint(Canvas canvas, Size size) {
    final d = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = d / 2 - 10;
    const strokeW = 10.0;

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      gaugeStartAngle,
      gaugeSweep,
      false,
      Paint()
        ..color = const Color(0xFFE8EFF7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );

    // Value arc
    final frac = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    if (frac > 0.005) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        gaugeStartAngle,
        gaugeSweep * frac,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
    }

    // Tick marks
    final innerEdge = radius - strokeW / 2 - 1;
    final majorPaint = Paint()..color = const Color(0xFFB0BEC5)..strokeWidth = 1.2;
    final minorPaint = Paint()..color = const Color(0xFFCDD5E0)..strokeWidth = 0.8;
    const int totalTicks = 48;
    final int majorEvery = totalTicks ~/ (ticks.length - 1);
    for (int i = 0; i <= totalTicks; i++) {
      final angle = gaugeStartAngle + gaugeSweep * i / totalTicks;
      final isMajor = i % majorEvery == 0;
      final outerR = innerEdge - 2;
      final innerR = outerR - (isMajor ? 9.0 : 4.0);
      final c = math.cos(angle);
      final s = math.sin(angle);
      canvas.drawLine(
        Offset(center.dx + c * outerR, center.dy + s * outerR),
        Offset(center.dx + c * innerR, center.dy + s * innerR),
        isMajor ? majorPaint : minorPaint,
      );
    }

    // Scale labels
    final lblR = innerEdge - 22;
    for (int i = 0; i < ticks.length; i++) {
      final angle = gaugeStartAngle + gaugeSweep * i / (ticks.length - 1);
      final lx = center.dx + math.cos(angle) * lblR;
      final ly = center.dy + math.sin(angle) * lblR;
      final tp = TextPainter(
        text: TextSpan(
          text: ticks[i].toStringAsFixed(0),
          style: const TextStyle(color: Color(0xFF243044), fontSize: 10, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }

    // Needle
    final needleAngle = gaugeStartAngle + gaugeSweep * frac;
    final needleLen = innerEdge - 26;
    const halfBase = 5.0;
    final perp = needleAngle + math.pi / 2;
    final tip = Offset(center.dx + math.cos(needleAngle) * needleLen,
        center.dy + math.sin(needleAngle) * needleLen);
    final b1 = Offset(center.dx + math.cos(perp) * halfBase,
        center.dy + math.sin(perp) * halfBase);
    final b2 = Offset(center.dx - math.cos(perp) * halfBase,
        center.dy - math.sin(perp) * halfBase);
    canvas.drawPath(Path()..moveTo(tip.dx, tip.dy)..lineTo(b1.dx, b1.dy)..lineTo(b2.dx, b2.dy)..close(),
        Paint()..color = color);

    // Hub
    canvas.drawCircle(center, 7, Paint()..color = const Color(0xFF1F2A44));
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);

    // Value + unit inside circle (bottom half)
    final valStr = max <= 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(0);
    final valTp = TextPainter(
      text: TextSpan(
        text: valStr,
        style: TextStyle(
          color: value > (max <= 10 ? 0.05 : 0.5) ? color : const Color(0xFF4B5A72),
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final valY = center.dy + radius * 0.24;
    valTp.paint(canvas, Offset(center.dx - valTp.width / 2, valY));

    final unitTp = TextPainter(
      text: TextSpan(
        text: unit,
        style: const TextStyle(color: Color(0xFF4B5A72), fontSize: 10, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    unitTp.paint(canvas, Offset(center.dx - unitTp.width / 2, valY + 25));

    // Label text (Velocidade / RPM) at top-center inside
    final lblTp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Color(0xFF1F2A44), fontSize: 11, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lblTp.paint(canvas, Offset(center.dx - lblTp.width / 2, center.dy - radius * 0.38));
  }

  @override
  bool shouldRepaint(DialPainter old) =>
      old.value != value || old.color != color || old.label != label;
}
