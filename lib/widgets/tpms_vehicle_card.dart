import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Presentation only. Sensor positions, units, freshness and alert limits must
/// be resolved upstream. Never infer a healthy pressure from a received value.
enum TireVisualState { unknown, normal, attention, alert }

/// Captions for the existing position IDs. Keep the original ID in tooltips.
String tirePositionCaption(String id, {bool full = false}) {
  final names = <String, (String, String)>{
    '11': ('DE', 'Dianteiro esquerdo'),
    '14': ('DD', 'Dianteiro direito'),
    '21': ('TE', 'Traseiro esquerdo'),
    '22': ('TE', 'Traseiro esquerdo'),
    '23': ('TD', 'Traseiro direito'),
    '24': ('TD', 'Traseiro direito'),
  };
  final known = names[id];
  if (known != null) return full ? known.$2 : known.$1;
  if (RegExp(r'^[3-9][1-4]$').hasMatch(id)) {
    final left = int.parse(id[1]) <= 2;
    return full
        ? 'Eixo ${id[0]} · ${left ? 'esquerdo' : 'direito'}'
        : 'E${id[0]}-${left ? 'E' : 'D'}';
  }
  return 'P$id';
}

class TireVisualReading {
  const TireVisualReading({
    required this.id,
    required this.label,
    required this.pressure,
    required this.temperature,
    this.pressureUnit,
    this.battery,
    this.state = TireVisualState.unknown,
    this.reason,
  });
  final String id, label, pressure, temperature;
  /// Supplied together with an already converted value by the data adapter.
  final String? pressureUnit;
  final String? battery, reason;
  final TireVisualState state;
  String get displayPressure => pressureUnit == null || pressureUnit!.isEmpty
      ? pressure : '$pressure $pressureUnit';
}

/// Fixed width; the entire vehicle diagram scrolls inside the card.
/// The current adapter supplies sensor order, not verified axle positions.
class TpmsVehicleCard extends StatefulWidget {
  const TpmsVehicleCard(
      {super.key, required this.readings, this.positionsConfirmed = false});
  final List<TireVisualReading> readings;
  final bool positionsConfirmed;

  @override
  State<TpmsVehicleCard> createState() => _TpmsVehicleCardState();
}

class _TpmsVehicleCardState extends State<TpmsVehicleCard> {
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateWindow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateWindow());
  }

  void _updateWindow() {
    if (mounted) setState(() {});
  }

  void _move(double direction) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
        (_scroll.offset + direction * 128)
            .clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut);
  }

  List<TireVisualReading?> get _slots {
    if (!widget.readings.every((r) => RegExp(r'^[1-9][1-4]$').hasMatch(r.id))) {
      return widget.readings;
    }
    final byId = {for (final r in widget.readings) r.id: r};
    final axles = widget.readings.map((r) => r.id[0]).toSet().toList()..sort();
    return [
      for (final axle in axles)
        for (final pair in const [
          ['1', '4'],
          ['2', '3']
        ])
          if (byId.containsKey('$axle${pair[0]}') ||
              byId.containsKey('$axle${pair[1]}')) ...[
            byId['$axle${pair[0]}'],
            byId['$axle${pair[1]}']
          ]
    ];
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.readings.isEmpty) return const SizedBox.shrink();
    final rows = math.max(2, (_slots.length / 2).ceil());
    return Container(
      key: const ValueKey('tpms-vehicle-card'),
      width: 170,
      height: 204,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A10233F), blurRadius: 12, offset: Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.tire_repair_rounded,
              size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 5),
          const Expanded(
              child: Text('Pneus (TPMS)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2A44)))),
          const SizedBox(width: 4),
          Text('${widget.readings.length}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        ]),
        const SizedBox(height: 4),
        Expanded(
            child: Scrollbar(
          controller: _scroll,
          thumbVisibility: rows > 2,
          thickness: 3,
          radius: const Radius.circular(3),
          child: SingleChildScrollView(
            key: const ValueKey('tpms-diagram-scroll'),
            controller: _scroll,
            child: SizedBox(
                height: rows * 64.0,
                child: Stack(children: [
                  Positioned(
                      left: 45,
                      right: 45,
                      top: 0,
                      bottom: 0,
                      child: TpmsVehicleArtwork(
                          truck: widget.readings.length > 4)),
                  for (var row = 0; row < rows; row++) ...[
                    _wheel(row * 2, row, false),
                    _wheel(row * 2 + 1, row, true),
                  ],
                ])),
          ),
        )),
        const SizedBox(height: 3),
        const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(children: [
              _TireLegend('Normal', Color(0xFF16A36B)),
              _TireLegend('Atenção', Color(0xFFD89116)),
              _TireLegend('Alerta', Color(0xFFDC4545)),
              _TireLegend('Sem leitura', Color(0xFF8793A4)),
            ])),
        const SizedBox(height: 3),
        SizedBox(
            height: 17,
            child: Row(children: [
              _scrollButton(Icons.chevron_left_rounded, 'Pneus anteriores', -1),
              Expanded(
                  child: Text(_windowLabel(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334A70)))),
              _scrollButton(Icons.chevron_right_rounded, 'Próximos pneus', 1),
            ])),
      ]),
    );
  }

  String _windowLabel() {
    final start = _scroll.hasClients ? (_scroll.offset / 64).floor() * 2 : 0;
    final before = _slots.take(start).whereType<TireVisualReading>().length;
    final shown =
        _slots.skip(start).take(4).whereType<TireVisualReading>().length;
    return '${before + 1}–${before + shown} de ${widget.readings.length}';
  }

  Widget _scrollButton(IconData icon, String label, double direction) {
    final enabled = _scroll.hasClients &&
        (direction < 0
            ? _scroll.offset > 0
            : _scroll.offset < _scroll.position.maxScrollExtent);
    return Tooltip(
        message: label,
        child: Semantics(
            button: true,
            label: label,
            child: InkWell(
                onTap: enabled ? () => _move(direction) : null,
                borderRadius: BorderRadius.circular(5),
                child: Icon(icon,
                    size: 17,
                    color: enabled
                        ? const Color(0xFF215FAD)
                        : const Color(0xFFB8C3D2)))));
  }

  Widget _wheel(int index, int row, bool right) {
    final slots = _slots;
    final reading = index < slots.length ? slots[index] : null;
    final color = switch (reading?.state ?? TireVisualState.unknown) {
      TireVisualState.normal => const Color(0xFF16A36B),
      TireVisualState.attention => const Color(0xFFD89116),
      TireVisualState.alert => const Color(0xFFDC4545),
      TireVisualState.unknown => const Color(0xFF8793A4),
    };
    final description = reading == null
        ? 'Posição sem sensor informado'
        : '${tirePositionCaption(reading.id, full: true)}. Sensor ${reading.id}. Pressão: ${reading.displayPressure}. ${reading.temperature}.'
            '${reading.battery == null ? '' : ' Bateria ${reading.battery}.'}'
            '${reading.reason == null ? '' : ' ${reading.reason}.'}'
            '${widget.positionsConfirmed ? '' : ' Posição a confirmar.'}';
    return Positioned(
      top: row * 64.0 + 6,
      left: right ? null : 0,
      right: right ? 0 : null,
      width: 57,
      height: 54,
      child: Tooltip(
          message: description,
          child: Semantics(
              label: description,
              child: Stack(children: [
                if (reading != null && reading.state != TireVisualState.unknown)
                  Positioned(
                    top: 12,
                    left: right ? 6 : null,
                    right: right ? null : 4,
                    child: Container(
                        width: 4,
                        height: 19,
                        decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: color, width: 1)))),
                Positioned(
                    left: right ? 10 : 0,
                    right: right ? 0 : 10,
                    child: Column(
                        crossAxisAlignment: right
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                              reading == null
                                  ? '—'
                                  : (RegExp(r'^[1-9][1-4]$')
                                          .hasMatch(reading.id)
                                      ? tirePositionCaption(reading.id)
                                      : reading.label),
                              maxLines: 1,
                              style: const TextStyle(
                                  fontSize: 9, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          const Text('Pressão', style: TextStyle(fontSize: 6.5,
                            color: Color(0xFF72839D))),
                          Text(reading?.displayPressure ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      reading?.state == TireVisualState.unknown
                                          ? const Color(0xFF334155)
                                          : color)),
                          Text(reading?.temperature ?? '—',
                              maxLines: 1,
                              style: const TextStyle(
                                  fontSize: 9, color: Color(0xFF596B85))),
                        ])),
              ]))),
    );
  }
}

/// Reuse the existing map artwork. Crop transparent margins at paint time;
/// no bitmap files, marker assets or sensor rules are changed.
class _TireLegend extends StatelessWidget {
  const _TireLegend(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Row(children: [
        Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 2),
        Text(label,
            style: const TextStyle(fontSize: 6.5, color: Color(0xFF526681))),
      ]));
}

/// Shared approved artwork for the live-map card and Dashboard > TPMS.
class TpmsVehicleArtwork extends StatefulWidget {
  const TpmsVehicleArtwork({super.key, required this.truck});
  final bool truck;
  @override
  State<TpmsVehicleArtwork> createState() => _VehicleArtworkState();
}

class _VehicleArtworkState extends State<TpmsVehicleArtwork> {
  ui.Image? _image;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TpmsVehicleArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.truck != widget.truck) _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final data = await rootBundle.load(widget.truck
        ? 'assets/icons/map_sprites/truck/truck_8.png'
        : 'assets/icons/map/tpms_car_premium.png');
    final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted || generation != _generation) {
      frame.image.dispose();
      return;
    }
    final previous = _image;
    setState(() => _image = frame.image);
    previous?.dispose();
  }

  @override
  void dispose() {
    ++_generation;
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _image == null
      ? const SizedBox.expand()
      : CustomPaint(painter: _VehicleSpritePainter(_image!, widget.truck));
}

class _VehicleSpritePainter extends CustomPainter {
  const _VehicleSpritePainter(this.image, this.truck);
  final ui.Image image;
  final bool truck;
  @override
  void paint(Canvas canvas, Size size) {
    final source = truck
        ? const Rect.fromLTWH(43, 26, 42, 83)
        : const Rect.fromLTWH(164, 56, 696, 1404);
    final paint = Paint()..filterQuality = FilterQuality.high;
    if (!truck) {
      // Approved top view: keep the original proportions and center the
      // silver vehicle between the existing four wheel readouts.
      final height =
          math.min(size.height - 4, size.width * source.height / source.width);
      final width = height * source.width / source.height;
      canvas.drawImageRect(
          image,
          source,
          Rect.fromLTWH((size.width - width) / 2, (size.height - height) / 2,
              width, height),
          paint);
      return;
    }
    // Preserve cabin/tail proportions. Only the existing cargo section
    // extends with the scrollable illustrative vehicle diagram.
    final scale = size.width / source.width;
    final head = 30 * scale, tail = 7 * scale;
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(source.left, source.top, source.width, 30),
        Rect.fromLTWH(0, 0, size.width, head),
        paint);
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(source.left, source.top + 30, source.width, 46),
        Rect.fromLTWH(0, head, size.width, size.height - head - tail),
        paint);
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(source.left, source.bottom - 7, source.width, 7),
        Rect.fromLTWH(0, size.height - tail, size.width, tail),
        paint);
  }

  @override
  bool shouldRepaint(_VehicleSpritePainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.truck != truck;
}
