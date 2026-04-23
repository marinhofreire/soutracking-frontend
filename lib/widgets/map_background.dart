import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as latlng;

import '../core/map_config.dart';

class MapBackground extends StatefulWidget {
  const MapBackground({
    super.key,
    required this.child,
    required this.markers,
    required this.circles,
    required this.initialTarget,
    required this.initialZoom,
    required this.googleMapType,
    required this.trafficEnabled,
    required this.interactiveEnabled,
  });

  final Widget child;
  final Set<gmaps.Marker> markers;
  final Set<gmaps.Circle> circles;
  final gmaps.LatLng initialTarget;
  final double initialZoom;
  final gmaps.MapType googleMapType;
  final bool trafficEnabled;
  final bool interactiveEnabled;

  @override
  State<MapBackground> createState() => _MapBackgroundState();
}

class _MapBackgroundState extends State<MapBackground> {
  static const String _googleNoPoiStyle = '''
[
  {
    "featureType": "poi",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.business",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit.station",
    "stylers": [{"visibility": "off"}]
  }
]
''';

  @override
  Widget build(BuildContext context) {
    final useGoogleMap = MapConfig.mapProvider == 'google';

    return Stack(
      children: [
        Positioned.fill(
          child: useGoogleMap
              ? IgnorePointer(
                  ignoring: !widget.interactiveEnabled,
                  child: gmaps.GoogleMap(
                    style: _googleNoPoiStyle,
                    initialCameraPosition: gmaps.CameraPosition(
                      target: widget.initialTarget,
                      zoom: widget.initialZoom,
                    ),
                    markers: widget.markers,
                    circles: widget.circles,
                    mapType: widget.googleMapType,
                    trafficEnabled: widget.trafficEnabled,
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    tiltGesturesEnabled: false,
                    rotateGesturesEnabled: widget.interactiveEnabled,
                    zoomGesturesEnabled: widget.interactiveEnabled,
                    scrollGesturesEnabled: widget.interactiveEnabled,
                  ),
                )
              : fm.FlutterMap(
                  options: fm.MapOptions(
                    initialCenter: latlng.LatLng(widget.initialTarget.latitude,
                        widget.initialTarget.longitude),
                    initialZoom: widget.initialZoom,
                    minZoom: MapConfig.minZoom,
                    maxZoom: MapConfig.maxZoom,
                    interactionOptions: fm.InteractionOptions(
                      flags: widget.interactiveEnabled
                          ? fm.InteractiveFlag.all
                          : fm.InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    fm.TileLayer(
                      urlTemplate: MapConfig.openStreetMapTileUrl,
                      userAgentPackageName: 'com.soutracking.app',
                    ),
                    fm.MarkerLayer(
                      markers: widget.markers
                          .map(
                            (m) => fm.Marker(
                              point: latlng.LatLng(
                                m.position.latitude,
                                m.position.longitude,
                              ),
                              width: 26,
                              height: 26,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 22,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}
