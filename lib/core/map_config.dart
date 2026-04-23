import 'app_constants.dart';

/// Configuração de mapas para o aplicativo
class MapConfig {
  // Escolha o provedor de mapa: 'google' ou 'openstreet'
  static const String mapProvider =
      'google'; // Google habilitado para satélite/trânsito/street view

  // Google Maps API Key
  // Para obter uma chave:
  // 1. Acesse: https://console.cloud.google.com/
  // 2. Crie um projeto
  // 3. Ative "Maps JavaScript API", "Maps SDK for Android" e "Maps SDK for iOS"
  // 4. Configure billing (Google oferece $200/mês grátis)
  // 5. Vá em "Credentials" e crie uma API Key
  // 6. Cole a chave abaixo
  static const String googleMapsApiKey = kGoogleMapsApiKey;

  // URLs dos tiles do OpenStreetMap (gratuito, sem necessidade de chave)
  static const String openStreetMapTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Configuração de atribuição (obrigatória para OSM)
  static const String openStreetMapAttribution = '© OpenStreetMap contributors';

  // Configurações gerais
  static const double defaultZoom = 15.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 18.0;
}
