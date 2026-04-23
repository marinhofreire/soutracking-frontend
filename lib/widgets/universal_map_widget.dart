import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/map_config.dart';

class UniversalMapWidget extends StatelessWidget {
  final double latitude;
  final double longitude;
  final double zoom;
  final String? markerTitle;

  const UniversalMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    this.zoom = 15.0,
    this.markerTitle,
  });

  @override
  Widget build(BuildContext context) {
    // Se estiver configurado para usar Google Maps e tiver API Key
    if (MapConfig.mapProvider == 'google') {
      // TODO: Implementar Google Maps quando tiver API Key
      return _buildOpenStreetMap();
    }

    // Usar OpenStreetMap (padrão - gratuito)
    return _buildOpenStreetMap();
  }

  Widget _buildOpenStreetMap() {
    final position = LatLng(latitude, longitude);

    return FlutterMap(
      options: MapOptions(
        initialCenter: position,
        initialZoom: zoom,
        minZoom: MapConfig.minZoom,
        maxZoom: MapConfig.maxZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.openStreetMapTileUrl,
          userAgentPackageName: 'com.soutracking.app',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: position,
              width: 50,
              height: 50,
              child: Column(
                children: [
                  if (markerTitle != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        markerTitle!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40,
                  ),
                ],
              ),
            ),
          ],
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              MapConfig.openStreetMapAttribution,
              onTap: () {
                // Pode adicionar link para OSM se quiser
              },
            ),
          ],
        ),
      ],
    );
  }
}
