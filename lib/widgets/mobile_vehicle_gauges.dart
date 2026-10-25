import 'package:flutter/material.dart';
import 'dial_gauge.dart';

/// Existing circular gauges, sized for the mobile map.
class MobileVehicleGauges extends StatelessWidget {
  const MobileVehicleGauges({super.key, required this.speedKmh, this.rpm});
  final double? speedKmh;
  final double? rpm;

  static double sizeForWidth(double width) =>
      ((width - 10) / 2).clamp(104.0, 142.0);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final size = sizeForWidth(constraints.maxWidth);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: size,
                height: size,
                child: FittedBox(
                    child: SizedBox(
                        width: 170,
                        height: 170,
                        child: DialGauge(
                            label: 'km/h',
                            unit: '',
                            value: speedKmh ?? 0,
                            max: 240,
                            color: const Color(0xFF2D8CFF),
                            ticks: const [0, 40, 80, 120, 160, 200, 240],
                            loading: false)))),
            if (rpm != null) ...[
              const SizedBox(width: 10),
              SizedBox(
                  width: size,
                  height: size,
                  child: FittedBox(
                      child: SizedBox(
                          width: 170,
                          height: 170,
                          child: DialGauge(
                              label: 'RPM',
                              unit: 'x1000',
                              value: rpm!,
                              max: 8,
                              color: const Color(0xFFEF4444),
                              ticks: const [0, 2, 4, 6, 8],
                              loading: false)))),
            ],
          ]);
        },
      );
}
