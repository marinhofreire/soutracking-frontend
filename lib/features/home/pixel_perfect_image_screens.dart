import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PixelPerfectImageScreens extends StatefulWidget {
  const PixelPerfectImageScreens({super.key});

  static const Size referenceSize = Size(1672, 941);

  @override
  State<PixelPerfectImageScreens> createState() =>
      _PixelPerfectImageScreensState();
}

class _PixelPerfectImageScreensState extends State<PixelPerfectImageScreens> {
  static const List<_PixelScreenEntry> _screens = [
    _PixelScreenEntry(
        id: 'dashboard', asset: 'assets/branding/pixel_screens/dashboard.png'),
    _PixelScreenEntry(
        id: 'mapa', asset: 'assets/branding/pixel_screens/mapa.png'),
    _PixelScreenEntry(
        id: 'veiculos', asset: 'assets/branding/pixel_screens/veiculos.png'),
    _PixelScreenEntry(
        id: 'equipamentos',
        asset: 'assets/branding/pixel_screens/equipamentos.png'),
    _PixelScreenEntry(
        id: 'telemetria',
        asset: 'assets/branding/pixel_screens/telemetria.png'),
    _PixelScreenEntry(
        id: 'alertas', asset: 'assets/branding/pixel_screens/alertas.png'),
    _PixelScreenEntry(
        id: 'cercas', asset: 'assets/branding/pixel_screens/cercas.png'),
    _PixelScreenEntry(
        id: 'relatorios',
        asset: 'assets/branding/pixel_screens/relatorios.png'),
    _PixelScreenEntry(
        id: 'comandos', asset: 'assets/branding/pixel_screens/comandos.png'),
    _PixelScreenEntry(
        id: 'manutencao',
        asset: 'assets/branding/pixel_screens/manutencao.png'),
    _PixelScreenEntry(
        id: 'comunicacao',
        asset: 'assets/branding/pixel_screens/comunicacao.png'),
    _PixelScreenEntry(
        id: 'log', asset: 'assets/branding/pixel_screens/log.png'),
    _PixelScreenEntry(
        id: 'configuracoes',
        asset: 'assets/branding/pixel_screens/configuracoes.png'),
  ];

  static final Map<String, int> _indexById = {
    for (var i = 0; i < _screens.length; i++) _screens[i].id: i,
  };

  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = _resolveInitialIndex();
  }

  int _resolveInitialIndex() {
    final raw = Uri.base.queryParameters['screen']?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return 1; // mapa
    return _indexById[raw] ?? 1;
  }

  void _goToIndex(int index) {
    if (index < 0 || index >= _screens.length) return;
    setState(() => _activeIndex = index);
  }

  void _goNext() {
    final next = (_activeIndex + 1) % _screens.length;
    _goToIndex(next);
  }

  void _goPrev() {
    final prev = (_activeIndex - 1 + _screens.length) % _screens.length;
    _goToIndex(prev);
  }

  void _handleTap(Offset position, Rect drawRect) {
    if (!drawRect.contains(position)) return;

    final refX = (position.dx - drawRect.left) *
        PixelPerfectImageScreens.referenceSize.width /
        drawRect.width;
    final refY = (position.dy - drawRect.top) *
        PixelPerfectImageScreens.referenceSize.height /
        drawRect.height;

    final row = _sidebarRowHit(refX, refY);
    if (row == null) return;

    final screenId = _screenIdForSidebarRow(row);
    if (screenId == null) return;

    final target = _indexById[screenId];
    if (target != null) {
      _goToIndex(target);
    }
  }

  int? _sidebarRowHit(double refX, double refY) {
    if (refX < 14 || refX > 236) return null;
    if (refY < 93 || refY > 820) return null;

    const rowHeight = 40.0;
    final row = ((refY - 93) / rowHeight).floor();
    if (row < 0 || row > 16) return null;
    return row;
  }

  String? _screenIdForSidebarRow(int row) {
    switch (row) {
      case 0:
        return 'dashboard';
      case 1:
        return 'mapa';
      case 2:
        return 'veiculos';
      case 3:
        return 'equipamentos';
      case 4:
        return 'alertas';
      case 5:
        return 'cercas';
      case 6:
        return 'relatorios';
      case 7:
        return 'comandos';
      case 8:
        return 'comunicacao';
      case 9:
        return 'manutencao';
      case 13:
        return 'telemetria';
      case 14:
        return 'log';
      case 16:
        return 'configuracoes';
      default:
        return null;
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      _goNext();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      _goPrev();
      return KeyEventResult.handled;
    }

    const keyOrder = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];

    final keyPos = keyOrder.indexOf(event.logicalKey);
    if (keyPos >= 0 && keyPos < _screens.length) {
      _goToIndex(keyPos);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final active = _screens[_activeIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFE8EBEF),
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final canvasSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final fitted = applyBoxFit(
              BoxFit.contain,
              PixelPerfectImageScreens.referenceSize,
              canvasSize,
            );
            final drawSize = fitted.destination;
            final drawRect = Rect.fromLTWH(
              (canvasSize.width - drawSize.width) / 2,
              (canvasSize.height - drawSize.height) / 2,
              drawSize.width,
              drawSize.height,
            );

            return Stack(
              children: [
                Positioned.fromRect(
                  rect: drawRect,
                  child: Image.asset(
                    active.asset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) => _handleTap(
                      details.localPosition,
                      drawRect,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PixelScreenEntry {
  const _PixelScreenEntry({
    required this.id,
    required this.asset,
  });

  final String id;
  final String asset;
}
