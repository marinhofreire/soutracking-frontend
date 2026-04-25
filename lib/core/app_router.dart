import 'package:flutter/material.dart';

import '../features/assist/assist_create_request_screen.dart';
import '../features/assist/assist_request_detail_screen.dart';
import '../features/assist/assist_requests_screen.dart';
import '../features/assist/assist_visual_dashboard_screen.dart';
import '../features/mdvr/mdvr_device_detail_screen.dart';
import '../features/mdvr/mdvr_devices_screen.dart';

class AppRoutes {
  static const String assistRequests = '/assist/requests';
  static const String assistCreate = '/assist/create';
  static const String assistRequestPrefix = '/assist/request';
  static const String assistPrivateVisualDashboard =
      '/assist/private-visual-dashboard';

  static const String mdvrDevices = '/mdvr/devices';
  static const String mdvrDevicePrefix = '/mdvr/device';

  static String assistRequest(String id) => '$assistRequestPrefix/$id';
  static String mdvrDevice(String id) => '$mdvrDevicePrefix/$id';
}

Route<dynamic>? appOnGenerateRoute(RouteSettings settings) {
  final name = settings.name;
  if (name == null) {
    return null;
  }

  final assistMatch = RegExp(r'^/assist/request/([^/]+)$').firstMatch(name);
  if (assistMatch != null) {
    final requestId = assistMatch.group(1) ?? '';
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => AssistRequestDetailScreen(requestId: requestId),
    );
  }

  if (name == AppRoutes.assistRequests) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const _RoutedSurface(child: AssistRequestsScreen()),
    );
  }

  if (name == AppRoutes.assistCreate) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const _RoutedSurface(child: AssistCreateRequestScreen()),
    );
  }

  if (name == AppRoutes.assistPrivateVisualDashboard) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const _AssistPrivateDashboardGate(),
    );
  }

  final mdvrMatch = RegExp(r'^/mdvr/device/([^/]+)$').firstMatch(name);
  if (mdvrMatch != null) {
    final deviceId = mdvrMatch.group(1) ?? '';
    return MaterialPageRoute(
      settings: settings,
      builder: (_) =>
          _RoutedSurface(child: MdvrDeviceDetailScreen(deviceId: deviceId)),
    );
  }

  if (name == AppRoutes.mdvrDevices) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const _RoutedSurface(child: MdvrDevicesScreen()),
    );
  }

  return null;
}

class _RoutedSurface extends StatelessWidget {
  const _RoutedSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SouFind')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _AssistPrivateDashboardGate extends StatefulWidget {
  const _AssistPrivateDashboardGate();

  @override
  State<_AssistPrivateDashboardGate> createState() =>
      _AssistPrivateDashboardGateState();
}

class _AssistPrivateDashboardGateState
    extends State<_AssistPrivateDashboardGate> {
  static const String _privatePin = String.fromEnvironment(
    'ASSIST_PRIVATE_DASHBOARD_PIN',
    defaultValue: 'soufind123',
  );

  final TextEditingController _pinController = TextEditingController();
  bool _authenticated = false;
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_authenticated) {
      return const AssistVisualDashboardScreen();
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Acesso privado',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Informe a senha para abrir o dashboard visual.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      errorText: _errorText,
                    ),
                    onSubmitted: (_) => _validatePin(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _validatePin,
                    child: const Text('Entrar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _validatePin() {
    if (_pinController.text.trim() == _privatePin) {
      setState(() {
        _authenticated = true;
        _errorText = null;
      });
      return;
    }

    setState(() {
      _errorText = 'Senha inválida';
    });
  }
}
