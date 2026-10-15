import 'package:flutter/material.dart';
import 'browser_brand_stub.dart'
    if (dart.library.js_interop) 'browser_brand_web.dart' as browser;

/// Presentation only: renders the logo source already stored by the application.
/// Original files and persisted brand settings are never rewritten here.
class BrandLogo extends StatelessWidget {
  const BrandLogo(
      {super.key,
      this.source,
      this.symbolSource,
      this.darkSource,
      this.name = 'SouTracking',
      this.height = 40,
      this.width,
      this.compact = false,
      this.dark = false});
  final String? source;
  final String? symbolSource, darkSource;
  final String name;
  final double height;
  final double? width;
  final bool compact;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final original = (compact && (symbolSource?.trim().isNotEmpty ?? false)
                ? symbolSource
                : dark && (darkSource?.trim().isNotEmpty ?? false)
                    ? darkSource
                    : source)
            ?.trim() ??
        '';
    final builtIn =
        original == 'assets/branding/soutracking_logo_horizontal.png' ||
            original == 'assets/branding/soutracking_logo_transparent.png' ||
            (original.isEmpty && name.trim().toLowerCase() == 'soutracking');
    final path = builtIn
        ? (compact
            ? 'assets/branding/soutracking_symbol_transparent.png'
            : dark
                ? 'assets/branding/soutracking_logo_dark.png'
                : 'assets/branding/soutracking_logo_transparent.png')
        : original;
    Widget fallback() => Text(
        compact
            ? (name.trim().isEmpty
                ? 'S'
                : name.trim().characters.first.toUpperCase())
            : name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: compact ? height * .45 : 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface));
    Widget image() {
      try {
        if (path.startsWith('data:image/svg+xml') ||
            (Uri.tryParse(path)?.path.toLowerCase().endsWith('.svg') ??
                false)) {
          return browser.brandSvg(path, name, fallback());
        }
        if (path.startsWith('data:')) {
          final bytes = Uri.parse(path).data!.contentAsBytes();
          return Image.memory(bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => fallback());
        }
        if (path.startsWith('https://') || path.startsWith('http://')) {
          return Image.network(path,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => fallback());
        }
        if (path.isEmpty) return fallback();
        return Image.asset(path,
            fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback());
      } catch (_) {
        return fallback();
      }
    }

    final content = builtIn
        ? FittedBox(
            fit: BoxFit.contain,
            child: ClipRect(
                child: Align(
                    widthFactor: compact ? .85 : .99,
                    heightFactor: compact ? .85 : .48,
                    alignment: Alignment.center,
                    child: SizedBox(
                        width: compact ? 125 : 480,
                        height: compact ? 125 : 160,
                        child: image()))))
        : image();
    return Semantics(
        label: name,
        image: true,
        child: SizedBox(
            width: width ?? (compact ? height : 160),
            height: height,
            child: content));
  }
}
