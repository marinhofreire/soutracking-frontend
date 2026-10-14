import 'package:flutter/material.dart';
import 'device_editor_reference_paths.dart';

// The same SVG paths used by the approved HTML preview, rendered by Flutter.
class DeviceEditorReferenceIcon extends StatelessWidget {
  const DeviceEditorReferenceIcon(this.name,
      {super.key, this.size = 16, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
          painter: _ReferenceIconPainter(
              deviceEditorReferencePaths[name] ??
                  deviceEditorReferencePaths['chip']!,
              color ?? const Color(0xFF8098BC))));
}

class _ReferenceIconPainter extends CustomPainter {
  const _ReferenceIconPainter(this.data, this.color);
  final String data;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final tokens = RegExp(r'[a-zA-Z]|[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?')
        .allMatches(data)
        .map((m) => m.group(0)!)
        .toList();
    final path = Path();
    var i = 0;
    String command = 'M';
    Offset current = Offset.zero, start = Offset.zero;
    double number() => double.parse(tokens[i++]);
    bool isCommand(String value) => RegExp(r'^[a-zA-Z]$').hasMatch(value);
    while (i < tokens.length) {
      if (isCommand(tokens[i])) command = tokens[i++];
      final relative = command == command.toLowerCase();
      Offset point() {
        final p = Offset(number(), number());
        return relative ? p + current : p;
      }

      switch (command.toUpperCase()) {
        case 'M':
          current = point();
          start = current;
          path.moveTo(current.dx, current.dy);
          command = relative ? 'l' : 'L';
          break;
        case 'L':
          current = point();
          path.lineTo(current.dx, current.dy);
          break;
        case 'H':
          current = Offset(number() + (relative ? current.dx : 0), current.dy);
          path.lineTo(current.dx, current.dy);
          break;
        case 'V':
          current = Offset(current.dx, number() + (relative ? current.dy : 0));
          path.lineTo(current.dx, current.dy);
          break;
        case 'A':
          final rx = number(),
              ry = number(),
              rotation = number(),
              large = number() != 0,
              clockwise = number() != 0;
          final end = point();
          path.arcToPoint(end,
              radius: Radius.elliptical(rx, ry),
              rotation: rotation,
              largeArc: large,
              clockwise: clockwise);
          current = end;
          break;
        case 'Z':
          path.close();
          current = start;
          break;
        default:
          throw StateError('Unsupported SVG command $command');
      }
    }
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.65
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReferenceIconPainter old) =>
      data != old.data || color != old.color;
}
