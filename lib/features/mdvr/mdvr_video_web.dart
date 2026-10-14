import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class MdvrVideo extends StatefulWidget {
  const MdvrVideo({super.key, required this.streamUrl, this.preview = true});
  final String streamUrl;
  final bool preview;
  @override
  State<MdvrVideo> createState() => _MdvrVideoState();
}

class _MdvrVideoState extends State<MdvrVideo> {
  static int _nextId = 0;
  late final String _viewType;
  late final web.HTMLIFrameElement _frame;

  @override
  void initState() {
    super.initState();
    _viewType = 'soutracking-camera-${_nextId++}';
    _frame = web.HTMLIFrameElement()
      ..title = 'Câmera do veículo'
      ..allow = 'autoplay; fullscreen'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.pointerEvents = widget.preview ? 'none' : 'auto';
    _setSource();
    ui.platformViewRegistry.registerViewFactory(_viewType, (_) => _frame);
  }

  void _setSource() {
    _frame.src = Uri.base.resolve('mdvr-player.html').replace(queryParameters: {
      'stream': widget.streamUrl,
      'preview': widget.preview ? '1' : '0',
    }).toString();
  }

  @override
  void didUpdateWidget(MdvrVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl ||
        oldWidget.preview != widget.preview) {
      _frame.style.pointerEvents = widget.preview ? 'none' : 'auto';
      _setSource();
    }
  }

  @override
  void dispose() {
    // Navigating away stops playlist/segment requests and releases the decoder.
    _frame.src = 'about:blank';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
