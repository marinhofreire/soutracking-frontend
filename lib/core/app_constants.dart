const String kAppName = 'Sou Fleet';
// Default para Traccar SEM /api para evitar /api/api
const String kTraccarBaseUrl = String.fromEnvironment(
  'API_ORIGIN',
  defaultValue: 'http://204.168.191.10:8082',
);
// Base dedicada do backend SouAssist (demanda/tenant), isolada do Traccar.
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
      '[INFO] SouAssist baseUrl em uso: "$kSouAssistApiBaseUrl" | endpoint: ${endpoint ?? ''} | presentationMode: $presentationMode');
}
