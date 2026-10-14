import 'package:flutter/material.dart';

class MdvrVideo extends StatelessWidget {
  const MdvrVideo({super.key, required this.streamUrl, this.preview = true});
  final String streamUrl;
  final bool preview;
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFFF1F4F9),
        child: Center(
            child: Text('Vídeo disponível na versão web.',
                style: TextStyle(color: Color(0xFF60718D), fontSize: 11))),
      );
}
