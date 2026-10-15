import 'dart:js_interop';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

String? _lastIdentity;

String _url(String source) =>
    source.startsWith('assets/') ? 'assets/$source' : source;

void syncBrowserBrand(String name, String icon, {String color = '#1F6FEB'}) {
  final identity = '$name\n$icon\n$color';
  if (_lastIdentity == identity) return;
  _lastIdentity = identity;
  web.document.title = name;
  final link = (web.document.querySelector('link[rel="icon"]') ??
      web.document.createElement('link')) as web.HTMLLinkElement;
  link.rel = 'icon';
  link.removeAttribute('type');
  final initial = const HtmlEscape().convert(name.trim().isEmpty
      ? 'S'
      : String.fromCharCode(name.trim().runes.first).toUpperCase());
  link.href = icon.isNotEmpty
      ? _url(icon)
      : Uri.dataFromString(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><rect width="40" height="40" rx="8" fill="$color"/><text x="20" y="28" text-anchor="middle" font-family="sans-serif" font-size="26" fill="white">$initial</text></svg>',
              mimeType: 'image/svg+xml')
          .toString();
  if (link.parentNode == null) web.document.head?.appendChild(link);
  final meta = (web.document.querySelector('meta[name="theme-color"]') ??
      web.document.createElement('meta')) as web.HTMLMetaElement;
  meta.name = 'theme-color';
  meta.content = color;
  if (meta.parentNode == null) web.document.head?.appendChild(meta);
}

Widget brandSvg(String source, String name, Widget fallback) =>
    _BrandSvg(source: source, name: name, fallback: fallback);

class _BrandSvg extends StatefulWidget {
  const _BrandSvg(
      {required this.source, required this.name, required this.fallback});
  final String source, name;
  final Widget fallback;
  @override
  State<_BrandSvg> createState() => _BrandSvgState();
}

class _BrandSvgState extends State<_BrandSvg> {
  bool failed = false;
  @override
  void didUpdateWidget(covariant _BrandSvg oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) failed = false;
  }

  @override
  Widget build(BuildContext context) => failed
      ? widget.fallback
      : HtmlElementView.fromTagName(
          key: ValueKey(widget.source),
          tagName: 'img',
          onElementCreated: (element) {
            final img = element as web.HTMLImageElement;
            img.alt = widget.name;
            img.style.width = '100%';
            img.style.height = '100%';
            img.style.objectFit = 'contain';
            img.style.pointerEvents = 'none';
            img.addEventListener(
                'error',
                ((web.Event _) {
                  if (mounted) setState(() => failed = true);
                }).toJS);
            img.src = _url(widget.source);
          },
        );
}
