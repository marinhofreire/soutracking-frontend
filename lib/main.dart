import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_router.dart';
import 'core/app_theme.dart';
import 'core/white_label.dart';
import 'features/home/home_shell.dart';
import 'features/home/pixel_perfect_image_screens.dart';
import 'features/login/login_screen.dart';
import 'state/session_state.dart';

void main() {
  runApp(const ProviderScope(child: SouFleetApp()));
}

class SouFleetApp extends ConsumerWidget {
  const SouFleetApp({super.key});

  bool _isPixelMode() {
    final raw = Uri.base.queryParameters['pixel']?.trim().toLowerCase();
    return raw == '1' || raw == 'true' || raw == 'yes';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final whiteLabelAsync = ref.watch(whiteLabelProvider);
    final pixelMode = _isPixelMode();

    return whiteLabelAsync.when(
      data: (config) {
        final home = pixelMode
            ? const PixelPerfectImageScreens()
            : session.status == SessionStatus.loading
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()))
                : session.isAuthenticated
                    ? _SessionActivityCapture(child: HomeShell())
                    : const LoginScreen();
        return MaterialApp(
          title: config.appName,
          theme: buildAppTheme(config),
          debugShowCheckedModeBanner: false,
          onGenerateRoute: appOnGenerateRoute,
          home: home,
        );
      },
      loading: () => MaterialApp(
        title: WhiteLabelConfig.fallback.appName,
        theme: buildAppTheme(WhiteLabelConfig.fallback),
        debugShowCheckedModeBanner: false,
        onGenerateRoute: appOnGenerateRoute,
        home: pixelMode
            ? const PixelPerfectImageScreens()
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (_, __) => MaterialApp(
        title: WhiteLabelConfig.fallback.appName,
        theme: buildAppTheme(WhiteLabelConfig.fallback),
        debugShowCheckedModeBanner: false,
        onGenerateRoute: appOnGenerateRoute,
        home: pixelMode
            ? const PixelPerfectImageScreens()
            : session.isAuthenticated
                ? HomeShell()
                : const LoginScreen(),
      ),
    );
  }
}

class _SessionActivityCapture extends ConsumerWidget {
  const _SessionActivityCapture({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void touch() => ref.read(sessionProvider.notifier).markActivity();

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => touch(),
      onPointerMove: (_) => touch(),
      onPointerSignal: (_) => touch(),
      child: child,
    );
  }
}
