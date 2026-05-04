import 'package:flutter/foundation.dart';

const String kAppName = 'SouTracking';

const String _kDefaultTraccarHttpOrigin = 'https://app.mackflow.com.br';
const String _kTraccarBaseUrlFromEnv = String.fromEnvironment(
  'API_ORIGIN',
  defaultValue: '',
);

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
// Base dedicada do backend SouFind (demanda/tenant), isolada do Traccar.
const String kSouAssistApiBaseUrl = String.fromEnvironment(
  'SOUASSIST_API_ORIGIN',
  defaultValue: 'https://api.souassit.com.br',
);
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

// Log do endpoint Traccar em uso (aparece no console ao iniciar app)
void logTraccarBaseUrl({String? endpoint}) {
  // ignore: avoid_print
  print(
      '[INFO] Traccar baseUrl em uso: "$kTraccarBaseUrl" | endpoint: ${endpoint ?? ''} | presentationMode: $presentationMode');
}

void logSouAssistBaseUrl({String? endpoint}) {
  // ignore: avoid_print
  print(
      '[INFO] SouFind baseUrl em uso: "$kSouAssistApiBaseUrl" | endpoint: ${endpoint ?? ''} | presentationMode: $presentationMode');
}
