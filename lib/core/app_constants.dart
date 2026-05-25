import 'package:flutter/foundation.dart';

const String kAppName = 'SouTracking';

const String _kDefaultTraccarHttpOrigin = 'http://api.soutracking.com.br';
const String _kTraccarBaseUrlFromEnv = String.fromEnvironment(
  'API_ORIGIN',
  defaultValue: '',
);
const String _kSouAssistBaseUrlFromEnv = String.fromEnvironment(
  'SOUASSIST_API_ORIGIN',
  defaultValue: '',
);
const String _kDefaultSouAssistHttpOrigin = 'http://api.soutracking.com.br';

String _resolveTraccarBaseUrl() {
  final envValue = _kTraccarBaseUrlFromEnv.trim();
  if (envValue.isNotEmpty) {
    return envValue;
  }

  // Em produção web via Cloudflare Pages, usa o mesmo origin e deixa o proxy
  // /api cuidar da ponte HTTPS -> HTTP legado do Traccar.
  if (kIsWeb) {
    final uri = Uri.base;
    final isHttps = uri.scheme == 'https';
    final isCloudflarePages = uri.host.toLowerCase().endsWith('.pages.dev');
    if (isHttps || isCloudflarePages) {
      return uri.origin;
    }
  }

  return _kDefaultTraccarHttpOrigin;
}

// Default para Traccar SEM /api para evitar /api/api.
final String kTraccarBaseUrl = _resolveTraccarBaseUrl();

String _resolveSouAssistBaseUrl() {
  final souAssistEnv = _kSouAssistBaseUrlFromEnv.trim();
  if (souAssistEnv.isNotEmpty) {
    return souAssistEnv;
  }

  // Mantem o backend de tenant alinhado com API_ORIGIN quando nao houver
  // override dedicado para SOUASSIST_API_ORIGIN.
  final traccarEnv = _kTraccarBaseUrlFromEnv.trim();
  if (traccarEnv.isNotEmpty) {
    return traccarEnv;
  }

  return _kDefaultSouAssistHttpOrigin;
}

// Base dedicada do backend SouFind (demanda/tenant), isolada do Traccar.
final String kSouAssistApiBaseUrl = _resolveSouAssistBaseUrl();
const String kGoogleMapsApiKey = 'AIzaSyDX-KnRJNMbZKp_EPiSdYPxo-XE5LvdHiY';
const bool kEnableRoadSpeedLimits = bool.fromEnvironment(
  'ENABLE_ROAD_SPEED_LIMITS',
  defaultValue: true,
);
const String kZproPanelUrl = String.fromEnvironment(
  'ZPRO_PANEL_URL',
  defaultValue: '',
);
const String kPlatformWhatsAppNumber = String.fromEnvironment(
  'PLATFORM_WHATSAPP_NUMBER',
  defaultValue: '',
);
const bool kUseMockApi = bool.fromEnvironment(
  'USE_MOCK_API',
  defaultValue: false,
);
// Para alternar entre DEMO e PROD, altere presentationMode abaixo:
const bool presentationMode = bool.fromEnvironment(
  'PRESENTATION_MODE',
  defaultValue: false,
); // true = DEMO (estável para prints), false = PROD (usa API real)

const bool kPixeltiPilotMode = bool.fromEnvironment(
  'PIXELTI_PILOT',
  defaultValue: false,
);

const bool kEnableDataLogMenu = bool.fromEnvironment(
  'ENABLE_DATA_LOG',
  defaultValue: false,
);

final bool kEnableFormulaTelemetryDemo = const bool.fromEnvironment(
  'ENABLE_FORMULA_TELEMETRY_DEMO',
  defaultValue: false,
);

const bool kShowPlaceholderPanels = bool.fromEnvironment(
  'SHOW_PLACEHOLDER_PANELS',
  defaultValue: false,
);

// Log de depuracao de endpoint da API (somente em debug).
void logTraccarBaseUrl({String? endpoint}) {
  if (!kDebugMode) return;
  final target = endpoint?.trim() ?? '';
  // ignore: avoid_print
  print(target.isEmpty
      ? '[DEBUG] API baseUrl em uso: "$kTraccarBaseUrl" | presentationMode: $presentationMode'
      : '[DEBUG] API baseUrl em uso: "$kTraccarBaseUrl" | endpoint: $target | presentationMode: $presentationMode');
}

void logSouAssistBaseUrl({String? endpoint}) {
  if (!kDebugMode) return;
  final target = endpoint?.trim() ?? '';
  // ignore: avoid_print
  print(target.isEmpty
      ? '[DEBUG] API de apoio baseUrl em uso: "$kSouAssistApiBaseUrl" | presentationMode: $presentationMode'
      : '[DEBUG] API de apoio baseUrl em uso: "$kSouAssistApiBaseUrl" | endpoint: $target | presentationMode: $presentationMode');
}
