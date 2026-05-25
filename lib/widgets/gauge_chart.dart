import 'dart:math';
import 'package:flutter/material.dart';

class GaugeChart extends StatelessWidget {
  final double value;
  final double minValue;
  final double maxValue;
  final String title;
  final String unit;
  final Color color;
  final List<Color>? gradientColors;

  const GaugeChart({
    super.key,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.title,
    required this.unit,
    this.color = Colors.blue,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: GaugePainter(
                  value: value,
                  minValue: minValue,
                  maxValue: maxValue,
                  color: color,
                  gradientColors: gradientColors,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        value.toStringAsFixed(0),
                        style:
                            Theme.of(context).textTheme.displayMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                      ),
                      Text(
                        unit,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double value;
  final double minValue;
  final double maxValue;
  final Color color;
  final List<Color>? gradientColors;

  GaugePainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.color,
    this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;

    // ?ngulo inicial e final (semic?rculo de baixo)
    const startAngle = pi * 0.75; // 135 graus
    const sweepAngle = pi * 1.5; // 270 graus

    // Desenhar o arco de fundo
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    // Desenhar marcações
    _drawTicks(canvas, center, radius, size);

    // Calcular o ângulo do valor atual
    final normalizedValue = (value - minValue) / (maxValue - minValue);
    final valueAngle =
        startAngle + (sweepAngle * normalizedValue.clamp(0.0, 1.0));

    // Desenhar o arco de valor com gradiente se fornecido
    if (gradientColors != null && gradientColors!.length > 1) {
      final shader = SweepGradient(
        colors: gradientColors!,
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        transform: const GradientRotation(pi * 0.75),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      final gradientPaint = Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        valueAngle - startAngle,
        false,
        gradientPaint,
      );
    } else {
      final valuePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        valueAngle - startAngle,
        false,
        valuePaint,
      );
    }

    // Desenhar ponteiro (agulha)
    _drawNeedle(canvas, center, radius - 30, valueAngle, color);

    // Desenhar círculo central
    final centerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 12, centerPaint);

    final centerBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, 12, centerBorderPaint);
  }

  void _drawTicks(Canvas canvas, Offset center, double radius, Size size) {
    const startAngle = pi * 0.75;
    const sweepAngle = pi * 1.5;
    const numTicks = 9;

    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i <= numTicks; i++) {
      final angle = startAngle + (sweepAngle * i / numTicks);
      final startRadius = radius - 15;
      final endRadius = radius - 5;

      final startPoint = Offset(
        center.dx + cos(angle) * startRadius,
        center.dy + sin(angle) * startRadius,
      );

      final endPoint = Offset(
        center.dx + cos(angle) * endRadius,
        center.dy + sin(angle) * endRadius,
      );

      canvas.drawLine(startPoint, endPoint, tickPaint);
    }
  }

  void _drawNeedle(
      Canvas canvas, Offset center, double length, double angle, Color color) {
    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final needleEnd = Offset(
      center.dx + cos(angle) * length,
      center.dy + sin(angle) * length,
    );

    // Desenhar sombra da agulha
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawLine(
      Offset(center.dx + 2, center.dy + 2),
      Offset(needleEnd.dx + 2, needleEnd.dy + 2),
      shadowPaint,
    );

    // Desenhar agulha principal
    canvas.drawLine(center, needleEnd, needlePaint);
  }

  @override
  bool shouldRepaint(GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue;
  }
}
