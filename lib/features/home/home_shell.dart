// ignore_for_file: unused_element_parameter

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/tenant_config.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';
import '../../widgets/map_background.dart';
import '../../core/app_constants.dart'
    show kEnableRoadSpeedLimits, kGoogleMapsApiKey, presentationMode;
import '../admin/admin_tenants_screen.dart';
import '../assist/assist_create_request_screen.dart';
import '../assist/assist_requests_screen.dart';
import '../attributes/attributes_screen.dart';
import '../calendars/calendars_screen.dart';
import '../commands/commands_screen.dart';
import '../communication/zpro_communication_screen.dart';
import '../business/business_reference_screens.dart';
import '../dashboard/dashboard_screen.dart';
import '../drivers/drivers_screen.dart';
import '../events/events_screen.dart';
import '../geofences/geofences_screen.dart';
import '../groups/groups_screen.dart';
import '../history/history_screen.dart';
import '../journey/journey_checkin_screen.dart';
import '../maintenance/maintenance_screen.dart';
import '../map/map_screen.dart';
import '../notifications/notifications_screen.dart';
import '../orders/orders_screen.dart';
import '../permissions/permissions_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../sharing/sharing_screen.dart';
import '../statistics/statistics_screen.dart';
import '../users/user_profiles_screen.dart';
import '../users/users_screen.dart';
import '../vehicles/vehicles_screen.dart';
import '../../core/white_label.dart';
import '../mdvr/mdvr_devices_screen.dart';
import '../assist/demand_control_panel_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  bool _sidebarExpanded = true;
  bool _showLiveDevicesPanel = false;
  int? _selectedDeviceId;
  bool _showDeviceHoverCard = false;
  bool _showDeviceBottomBar = false;
  _DeviceDetailTab _activeDeviceDetailTab = _DeviceDetailTab.overview;
  MapType _mapType = MapType.normal;
  bool _trafficEnabled = false;
  bool _showManagementAlerts = true;
  bool _mapInteractionEnabled = false;
  final bool _showNativeMapMarkers = true;
  Timer? _refreshTimer;
  bool _roadSpeedLookupInFlight = false;
  final Map<int, _RoadSpeedSnapshot> _roadSpeedByDeviceId = {};
  final Set<String> _collapsedSections = {};
  final Map<int, String> _deviceMarkerTypeOverride = {};
  final Map<int, String> _deviceMarkerColorOverride = {};
  final Map<int, String> _deviceCategoryOverride = {};
  final Map<int, String> _deviceImageOverride = {};
  final Map<String, BitmapDescriptor> _markerIconCache = {};
  final Set<String> _markerIconPending = {};
  final Map<int, _AddressSummary> _resolvedAddressByDeviceId = {};
  final Set<int> _addressLookupInFlight = {};

  // Padrao visual dos detalhes de veiculo (popup + barra inferior).
  static const Color _vehiclePanelSurface = Color(0xE612161D);
  static const Color _vehiclePanelBorder = Color(0x40FFFFFF);
  static const Color _vehiclePanelShadow = Color(0x99000000);
  static const Color _vehicleTextPrimary = Color(0xFFF4F8FF);
  static const Color _vehicleTextSecondary = Color(0xFFC2D0E6);
  static const Color _vehicleTextMuted = Color(0xFF8FA0BB);
  static const Color _vehicleActionSurface = Color(0x2AFFFFFF);
  static const Color _vehicleActionBorder = Color(0x38FFFFFF);
  static const Color _vehicleActionIcon = Color(0xFFBFD4F5);
  static const Color _vehicleTabIdle = Color(0x1FFFFFFF);
  static const Color _vehicleTabIdleBorder = Color(0x33FFFFFF);
  static const Color _vehicleTabIdleText = Color(0xFFD7E6FF);
  static const Color _vehicleContentSurface = Color(0x1FFFFFFF);
  static const Color _vehiclePlaceholderSurface = Color(0x22FFFFFF);
  static const Color _vehiclePlaceholderIcon = Color(0xFF9FB3D1);
  static const Color _vehicleAccent = Color(0xFF2C7BE5);

  String? _resolvedDeviceCategory(TraccarDevice device) {
    final override = _deviceCategoryOverride[device.id];
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    final category = device.category;
    if (category != null && category.trim().isNotEmpty) {
      return category.trim();
    }
    final attrs = device.attributes ?? const <String, dynamic>{};
    final attrCategory = attrs['category'];
    if (attrCategory is String && attrCategory.trim().isNotEmpty) {
      return attrCategory.trim();
    }
    return null;
  }

  String _deviceType(TraccarDevice device) {
    final attrs = device.attributes ?? const <String, dynamic>{};
    final candidates = [
      _resolvedDeviceCategory(device),
      attrs['category'],
      attrs['deviceType'],
      attrs['type'],
      attrs['model'],
      device.name,
    ].whereType<String>().map((e) => e.toLowerCase()).toList();

    final joined = candidates.join(' ');
    if (joined.contains('bike') ||
        joined.contains('bicycle') ||
        joined.contains('bicic')) {
      return 'bike';
    }
    if (joined.contains('phone') ||
        joined.contains('mobile') ||
        joined.contains('cel') ||
        joined.contains('smart')) {
      return 'phone';
    }
    if (joined.contains('retro') ||
        joined.contains('escav') ||
        joined.contains('excav') ||
        joined.contains('backhoe') ||
        joined.contains('maquina')) {
      return 'excavator';
    }
    if (joined.contains('ship') ||
        joined.contains('boat') ||
        joined.contains('navio') ||
        joined.contains('barco') ||
        joined.contains('embarc')) {
      return 'boat';
    }
    if (joined.contains('truck') ||
        joined.contains('car') ||
        joined.contains('veic') ||
        joined.contains('bus') ||
        joined.contains('moto')) {
      return 'car';
    }
    return 'tracker';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'bike':
        return Icons.pedal_bike_rounded;
      case 'phone':
        return Icons.smartphone_rounded;
      case 'excavator':
        return Icons.construction_rounded;
      case 'boat':
        return Icons.directions_boat_filled_rounded;
      case 'car':
        return Icons.directions_car_filled_rounded;
      default:
        return Icons.gps_fixed_rounded;
    }
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case 'online':
        return Colors.greenAccent;
      case 'offline':
        return Colors.redAccent;
      default:
        return Colors.amberAccent;
    }
  }

  String _resolvedDeviceType(TraccarDevice device) {
    return _deviceMarkerTypeOverride[device.id] ?? _deviceType(device);
  }

  _MarkerColorOption _defaultMarkerColorForType(String type) {
    switch (type) {
      case 'bike':
        return _markerColorByKey['cyan'] ?? _markerColorOptions.first;
      case 'phone':
        return _markerColorByKey['violet'] ?? _markerColorOptions.first;
      case 'excavator':
        return _markerColorByKey['orange'] ?? _markerColorOptions.first;
      case 'boat':
        return _markerColorByKey['teal'] ?? _markerColorOptions.first;
      case 'car':
        return _markerColorByKey['green'] ?? _markerColorOptions.first;
      default:
        return _markerColorByKey['azure'] ?? _markerColorOptions.first;
    }
  }

  _MarkerColorOption _markerColorForDevice(TraccarDevice? device) {
    if (device == null) {
      return _markerColorByKey['azure'] ?? _markerColorOptions.first;
    }
    final selectedKey = _deviceMarkerColorOverride[device.id];
    if (selectedKey != null && _markerColorByKey.containsKey(selectedKey)) {
      return _markerColorByKey[selectedKey]!;
    }
    return _defaultMarkerColorForType(_resolvedDeviceType(device));
  }

  String _movementStatus(TraccarDevice device, TraccarPosition? position) {
    if (device.status == 'offline') {
      return 'offline';
    }
    if (position == null) {
      return 'idle';
    }
    return _speedKmh(position) >= 5 ? 'moving' : 'idle';
  }

  Color _haloColorFor(String movementStatus) {
    switch (movementStatus) {
      case 'moving':
        return Colors.greenAccent;
      case 'offline':
        return Colors.redAccent;
      default:
        return Colors.amberAccent;
    }
  }

  bool _isNewerPosition(TraccarPosition candidate, TraccarPosition current) {
    final candidateTime = DateTime.tryParse(candidate.fixTime);
    final currentTime = DateTime.tryParse(current.fixTime);

    if (candidateTime != null && currentTime != null) {
      return candidateTime.isAfter(currentTime);
    }
    if (candidateTime != null) {
      return true;
    }
    if (currentTime != null) {
      return false;
    }
    return candidate.id > current.id;
  }

  double _speedKmh(TraccarPosition position) {
    final base = position.speed ?? 0;
    if (base.isNaN || base.isNegative) {
      return 0;
    }
    return base * 1.852;
  }

  double _speedLimitKmh(TraccarDevice device) {
    const keys = [
      'speedLimit',
      'speed_limit',
      'roadSpeedLimit',
      'maxSpeed',
      'overspeedLimit',
      'speedlimit',
    ];
    final attrs = device.attributes;
    if (attrs == null || attrs.isEmpty) {
      return 60;
    }

    for (final key in keys) {
      final value = attrs[key];
      if (value is num && value > 0) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
    }
    return 60;
  }

  bool _hasConfiguredSpeedLimit(TraccarDevice device) {
    const keys = [
      'speedLimit',
      'speed_limit',
      'roadSpeedLimit',
      'maxSpeed',
      'overspeedLimit',
      'speedlimit',
    ];
    final attrs = device.attributes;
    if (attrs == null || attrs.isEmpty) {
      return false;
    }

    for (final key in keys) {
      final value = attrs[key];
      if (value is num && value > 0) {
        return true;
      }
      if (value is String) {
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed != null && parsed > 0) {
          return true;
        }
      }
    }
    return false;
  }

  double _effectiveSpeedLimitKmh(
    TraccarDevice device,
    TraccarPosition position,
  ) {
    final cached = _roadSpeedByDeviceId[device.id];
    if (cached != null && cached.matches(position)) {
      return cached.limitKmh;
    }
    return _speedLimitKmh(device);
  }

  String _speedLimitSourceLabel(
    TraccarDevice device,
    TraccarPosition position,
  ) {
    final cached = _roadSpeedByDeviceId[device.id];
    if (cached != null && cached.matches(position)) {
      return 'Google Roads';
    }
    return _hasConfiguredSpeedLimit(device) ? 'Veículo' : 'Padrão';
  }

  Future<double?> _fetchRoadSpeedLimitKmh(TraccarPosition position) async {
    if (!kEnableRoadSpeedLimits || kGoogleMapsApiKey.trim().isEmpty) {
      return null;
    }

    final lat = position.latitude.toStringAsFixed(6);
    final lon = position.longitude.toStringAsFixed(6);
    final uri = Uri.https('roads.googleapis.com', '/v1/speedLimits', {
      'path': '$lat,$lon',
      'units': 'KPH',
      'key': kGoogleMapsApiKey,
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        return null;
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        return null;
      }
      final speedLimits = body['speedLimits'];
      if (speedLimits is! List || speedLimits.isEmpty) {
        return null;
      }
      final first = speedLimits.first;
      if (first is! Map<String, dynamic>) {
        return null;
      }
      final value = first['speedLimit'];
      if (value is num && value > 0) {
        return value.toDouble();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureRoadSpeedLimitForSelected(
    TraccarDevice device,
    TraccarPosition position,
  ) async {
    if (!kEnableRoadSpeedLimits || _roadSpeedLookupInFlight) {
      return;
    }
    final existing = _roadSpeedByDeviceId[device.id];
    if (existing != null && existing.matches(position)) {
      return;
    }

    _roadSpeedLookupInFlight = true;
    final limit = await _fetchRoadSpeedLimitKmh(position);
    _roadSpeedLookupInFlight = false;

    if (!mounted || limit == null) {
      return;
    }

    setState(() {
      _roadSpeedByDeviceId[device.id] = _RoadSpeedSnapshot(
        limitKmh: limit,
        lat: position.latitude,
        lon: position.longitude,
        fetchedAt: DateTime.now(),
      );
    });
  }

  bool _isOverspeed(TraccarDevice device, TraccarPosition position) {
    final speed = _speedKmh(position);
    final limit = _effectiveSpeedLimitKmh(device, position);
    return speed > (limit + 5);
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
    }
    return null;
  }

  double? _batteryPercentFor(TraccarDevice device, TraccarPosition? position) {
    final attrs = <String, dynamic>{
      ...(device.attributes ?? const <String, dynamic>{}),
      ...(position?.attributes ?? const <String, dynamic>{}),
    };

    for (final key in ['batteryLevel', 'battery', 'batteryPercent']) {
      final candidate = _asDouble(attrs[key]);
      if (candidate == null || candidate <= 0) {
        continue;
      }
      final normalized = candidate <= 1 ? candidate * 100 : candidate;
      return normalized.clamp(0, 100).toDouble();
    }
    return null;
  }

  IconData _batteryIconFor(double percent) {
    if (percent <= 10) return Icons.battery_0_bar_rounded;
    if (percent <= 25) return Icons.battery_2_bar_rounded;
    if (percent <= 50) return Icons.battery_4_bar_rounded;
    if (percent <= 75) return Icons.battery_6_bar_rounded;
    return Icons.battery_full_rounded;
  }

  Color _batteryColorFor(double percent) {
    if (percent <= 10) return Colors.redAccent;
    if (percent <= 25) return Colors.orangeAccent;
    if (percent <= 50) return Colors.amberAccent;
    return Colors.greenAccent;
  }

  double _courseDegrees(TraccarPosition position) {
    final attrs = position.attributes ?? const <String, dynamic>{};
    for (final key in ['course', 'heading', 'bearing']) {
      final value = _asDouble(attrs[key]);
      if (value != null && value >= 0) {
        return value % 360;
      }
    }
    return 0;
  }

  _MarkerColorOption _dynamicMarkerColorOption(
    TraccarDevice? device,
    TraccarPosition position,
  ) {
    if (device == null) {
      return _markerColorByKey['azure'] ?? _markerColorOptions.first;
    }

    final override = _deviceMarkerColorOverride[device.id];
    if (override != null && _markerColorByKey.containsKey(override)) {
      return _markerColorByKey[override]!;
    }

    if (device.status == 'offline') {
      return _markerColorByKey['violet'] ?? _markerColorOptions.first;
    }

    if (_isOverspeed(device, position)) {
      return _markerColorByKey['orange'] ?? _markerColorOptions.first;
    }

    final battery = _batteryPercentFor(device, position);
    if (battery != null && battery <= 15) {
      return _markerColorByKey['yellow'] ?? _markerColorOptions.first;
    }

    final speed = _speedKmh(position);
    if (speed >= 5) {
      return _markerColorByKey['green'] ?? _markerColorOptions.first;
    }

    return _defaultMarkerColorForType(_resolvedDeviceType(device));
  }

  BitmapDescriptor _descriptorForDeviceMarker(
    TraccarDevice? device,
    _MarkerColorOption markerColor,
  ) {
    final type = device == null ? 'tracker' : _resolvedDeviceType(device);

    if (kIsWeb) {
      final assetPath = _markerAssetForType(type);
      if (assetPath != null) {
        final assetCacheKey = 'asset:$assetPath';
        final assetCached = _markerIconCache[assetCacheKey];
        if (assetCached != null) {
          return assetCached;
        }
        _scheduleMarkerAssetBuild(
          cacheKey: assetCacheKey,
          assetPath: assetPath,
        );
        return BitmapDescriptor.defaultMarkerWithHue(markerColor.hue);
      }
    }

    final cacheKey = '$type:${markerColor.key}';
    final cached = _markerIconCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    _scheduleMarkerIconBuild(
      cacheKey: cacheKey,
      type: type,
      color: markerColor.uiColor,
    );

    return BitmapDescriptor.defaultMarkerWithHue(markerColor.hue);
  }

  String? _markerAssetForType(String type) {
    return null;
  }

  void _scheduleMarkerAssetBuild({
    required String cacheKey,
    required String assetPath,
  }) {
    if (_markerIconCache.containsKey(cacheKey) ||
        _markerIconPending.contains(cacheKey)) {
      return;
    }

    _markerIconPending.add(cacheKey);
    unawaited(() async {
      try {
        final descriptor = await BitmapDescriptor.asset(
          const ImageConfiguration(size: Size(70, 70)),
          assetPath,
        );
        if (!mounted) return;
        setState(() {
          _markerIconCache[cacheKey] = descriptor;
        });
      } catch (_) {
        // Keep default marker fallback when an asset is unavailable.
      } finally {
        _markerIconPending.remove(cacheKey);
      }
    }());
  }

  void _scheduleMarkerIconBuild({
    required String cacheKey,
    required String type,
    required Color color,
  }) {
    if (_markerIconCache.containsKey(cacheKey) ||
        _markerIconPending.contains(cacheKey)) {
      return;
    }

    _markerIconPending.add(cacheKey);
    unawaited(() async {
      try {
        final iconData = _iconForType(type);
        final bytes = await _buildMarkerIconBytes(iconData, color);
        final descriptor = BitmapDescriptor.bytes(bytes);
        if (!mounted) return;
        setState(() {
          _markerIconCache[cacheKey] = descriptor;
        });
      } finally {
        _markerIconPending.remove(cacheKey);
      }
    }());
  }

  Future<Uint8List> _buildMarkerIconBytes(
    IconData iconData,
    Color color,
  ) async {
    const markerSize = 112.0;
    const circleRadius = 34.0;
    const circleCenter = Offset(markerSize / 2, markerSize / 2 - 6);

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(
      circleCenter.translate(0, 4),
      circleRadius + 4,
      glowPaint,
    );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(circleCenter.translate(0, 2), circleRadius, shadowPaint);

    final fillPaint = Paint()..color = Colors.white;
    canvas.drawCircle(circleCenter, circleRadius, fillPaint);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(circleCenter, circleRadius, borderPaint);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: 37,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          color: color.withValues(alpha: 0.95),
        ),
      ),
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        circleCenter.dx - textPainter.width / 2,
        circleCenter.dy - textPainter.height / 2,
      ),
    );

    final pointerPath = Path()
      ..moveTo(circleCenter.dx - 11, circleCenter.dy + 26)
      ..lineTo(circleCenter.dx + 11, circleCenter.dy + 26)
      ..lineTo(circleCenter.dx, markerSize - 8)
      ..close();
    final pointerPaint = Paint()..color = color.withValues(alpha: 0.95);
    canvas.drawPath(pointerPath, pointerPaint);

    final onlineDotFill = Paint()..color = const Color(0xFF24D17E);
    final onlineDotStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final dotCenter = Offset(
      circleCenter.dx,
      circleCenter.dy - circleRadius - 2,
    );
    canvas.drawCircle(dotCenter, 6, onlineDotFill);
    canvas.drawCircle(dotCenter, 6, onlineDotStroke);

    final image = await recorder.endRecording().toImage(
          markerSize.toInt(),
          markerSize.toInt(),
        );
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value > 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'on';
    }
    return false;
  }

  double _normalizePressurePsi(double value) {
    if (value > 120 && value < 500) {
      return value * 0.1450377;
    }
    return value;
  }

  List<_ManagementAlert> _buildManagementAlerts({
    required List<TraccarDevice> devices,
    required Map<int, TraccarPosition> latestPositionByDeviceId,
  }) {
    final alerts = <_ManagementAlert>[];
    final now = DateTime.now().toUtc();

    for (final device in devices) {
      final position = latestPositionByDeviceId[device.id];
      final deviceAttrs = device.attributes ?? const <String, dynamic>{};
      final positionAttrs = position?.attributes ?? const <String, dynamic>{};
      final attrs = <String, dynamic>{...deviceAttrs, ...positionAttrs};

      if (device.status == 'offline') {
        alerts.add(
          _ManagementAlert(
            severity: _AlertSeverity.high,
            deviceId: device.id,
            title: 'Dispositivo offline',
            message: '${device.name} está offline.',
          ),
        );
      }

      if (position == null) {
        alerts.add(
          _ManagementAlert(
            severity: _AlertSeverity.high,
            deviceId: device.id,
            title: 'Sem posição',
            message: '${device.name} sem posição recente.',
          ),
        );
        continue;
      }

      final fixTime = DateTime.tryParse(position.fixTime);
      if (fixTime != null) {
        final age = now.difference(fixTime.toUtc());
        if (age.inMinutes >= 20) {
          alerts.add(
            _ManagementAlert(
              severity: _AlertSeverity.medium,
              deviceId: device.id,
              title: 'Telemetria atrasada',
              message:
                  '${device.name} sem atualização há ${age.inMinutes} min.',
            ),
          );
        }
      }

      if (_isOverspeed(device, position)) {
        final speed = _speedKmh(position);
        final limit = _effectiveSpeedLimitKmh(device, position);
        alerts.add(
          _ManagementAlert(
            severity: _AlertSeverity.critical,
            deviceId: device.id,
            title: 'Excesso de velocidade',
            message:
                '${device.name}: ${speed.toStringAsFixed(0)} km/h (limite ${limit.toStringAsFixed(0)}).',
          ),
        );
      }

      double? battery;
      for (final key in ['batteryLevel', 'battery', 'batteryPercent']) {
        final candidate = _asDouble(attrs[key]);
        if (candidate != null) {
          battery = candidate;
          break;
        }
      }
      if (battery != null) {
        if (battery <= 10) {
          alerts.add(
            _ManagementAlert(
              severity: _AlertSeverity.high,
              deviceId: device.id,
              title: 'Bateria crítica',
              message:
                  '${device.name}: bateria ${battery.toStringAsFixed(0)}%.',
            ),
          );
        } else if (battery <= 20) {
          alerts.add(
            _ManagementAlert(
              severity: _AlertSeverity.medium,
              deviceId: device.id,
              title: 'Bateria baixa',
              message:
                  '${device.name}: bateria ${battery.toStringAsFixed(0)}%.',
            ),
          );
        }
      }

      final ignition = _asBool(attrs['ignition']) || _asBool(attrs['acc']);
      if (ignition && _speedKmh(position) < 3) {
        alerts.add(
          _ManagementAlert(
            severity: _AlertSeverity.low,
            deviceId: device.id,
            title: 'Ignição ligada parado',
            message: '${device.name} com ignição ligada e baixa movimentação.',
          ),
        );
      }

      for (final entry in attrs.entries) {
        final key = entry.key.toLowerCase();
        final value = _asDouble(entry.value);
        if (value == null) {
          continue;
        }

        final isTpmsPressure =
            key.contains('tpms') && key.contains('pressure') ||
                key.contains('tire') && key.contains('pressure');
        if (isTpmsPressure) {
          final pressurePsi = _normalizePressurePsi(value);
          if (pressurePsi < 28 || pressurePsi > 46) {
            alerts.add(
              _ManagementAlert(
                severity: _AlertSeverity.critical,
                deviceId: device.id,
                title: 'TPMS fora da faixa',
                message:
                    '${device.name}: ${entry.key} ${pressurePsi.toStringAsFixed(1)} psi.',
              ),
            );
          }
        }

        final isTpmsTemp = key.contains('tpms') && key.contains('temp') ||
            key.contains('tire') && key.contains('temp');
        if (isTpmsTemp && value > 85) {
          alerts.add(
            _ManagementAlert(
              severity: _AlertSeverity.high,
              deviceId: device.id,
              title: 'TPMS temperatura alta',
              message:
                  '${device.name}: ${entry.key} ${value.toStringAsFixed(1)}°C.',
            ),
          );
        }
      }

      final alarm = attrs['alarm'];
      if (alarm is String && alarm.trim().isNotEmpty) {
        alerts.add(
          _ManagementAlert(
            severity: _AlertSeverity.high,
            deviceId: device.id,
            title: 'Alarme do dispositivo',
            message: '${device.name}: ${alarm.trim()}.',
          ),
        );
      }
    }

    alerts.sort((a, b) {
      final bySeverity = b.severity.priority.compareTo(a.severity.priority);
      if (bySeverity != 0) {
        return bySeverity;
      }
      return a.title.compareTo(b.title);
    });
    return alerts;
  }

  Future<void> _openStreetView(BuildContext context, LatLng target) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=${target.latitude},${target.longitude}',
    );
    final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o Street View.')),
      );
    }
  }

  Future<bool> _sendDeviceCommand({
    required BuildContext context,
    required TraccarDevice device,
    required String commandType,
    required String successMessage,
    Map<String, dynamic>? attributes,
    bool showError = true,
  }) async {
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      await client.createEntity(
        path: '/commands/send',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'deviceId': device.id,
          'type': commandType,
          if (attributes != null && attributes.isNotEmpty)
            'attributes': attributes,
        },
      );
      ref.invalidate(commandsProvider);
      if (!context.mounted) return true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      return true;
    } catch (error) {
      if (context.mounted && showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao enviar comando: $error')),
        );
      }
      return false;
    }
  }

  Future<void> _createQuickNotificationAlert({
    required BuildContext context,
    required TraccarDevice device,
  }) async {
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      await client.createEntity(
        path: '/notifications',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': 'Alerta rapido ${device.name} #$timestamp',
          'type': 'alarm',
          'always': true,
          'notificators': ['web'],
        },
      );
      ref.invalidate(notificationsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alerta rapido criado para ${device.name}.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao criar alerta: $error')),
      );
    }
  }

  Future<void> _copyTrackingLink({
    required BuildContext context,
    required TraccarDevice device,
    required TraccarPosition position,
  }) async {
    final lat = position.latitude.toStringAsFixed(6);
    final lon = position.longitude.toStringAsFixed(6);
    final trackingUrl =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lon';

    await Clipboard.setData(ClipboardData(text: trackingUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link de rastreio copiado para ${device.name}.')),
    );
  }

  bool _openJourneyForDevice(TraccarDevice device) {
    final tenant = ref.read(tenantConfigProvider);
    final sections = _visibleSections(_sections(tenant), tenant);
    int cursor = 0;
    int targetIndex = -1;
    for (final section in sections) {
      for (final node in section.children) {
        if (node.id == 'journey-checkin') {
          targetIndex = cursor;
        }
        cursor += 1;
        for (final child in node.children) {
          if (child.id == 'journey-checkin') {
            targetIndex = cursor;
          }
          cursor += 1;
        }
      }
    }

    setState(() {
      _selectedDeviceId = device.id;
      _showDeviceBottomBar = false;
      _showDeviceHoverCard = true;
      _activeDeviceDetailTab = _DeviceDetailTab.overview;
      if (targetIndex >= 0) {
        _index = targetIndex;
      }
    });

    return targetIndex >= 0;
  }

  String _buildAiResponse({
    required String prompt,
    required List<_ManagementAlert> managementAlerts,
    required List<TraccarDevice> devices,
    required Map<int, TraccarPosition> latestPositionByDeviceId,
  }) {
    final text = prompt.trim().toLowerCase();
    final critical = managementAlerts
        .where((a) => a.severity == _AlertSeverity.critical)
        .length;
    final high =
        managementAlerts.where((a) => a.severity == _AlertSeverity.high).length;
    final medium = managementAlerts
        .where((a) => a.severity == _AlertSeverity.medium)
        .length;
    final offlineDevices = devices.where((d) => d.status == 'offline').toList();

    if (text.isEmpty) {
      return 'Resumo operacional: $critical crítico(s), $high alto(s), $medium médio(s). Pergunte, por exemplo: “quais veículos offline?”, “riscos de velocidade”, “status TPMS” ou “o que priorizar agora?”.';
    }

    if (text.contains('offline') || text.contains('sem sinal')) {
      if (offlineDevices.isEmpty) {
        return 'Nenhum dispositivo offline no momento.';
      }
      final names = offlineDevices.take(5).map((d) => d.name).join(', ');
      return 'Offline agora: ${offlineDevices.length}. Destaques: $names. Sugestão: validar energia/chip/sinal e última posição antes de abrir chamado técnico.';
    }

    if (text.contains('veloc') ||
        text.contains('overspeed') ||
        text.contains('risco')) {
      final overspeed = devices.where((device) {
        final pos = latestPositionByDeviceId[device.id];
        return pos != null && _isOverspeed(device, pos);
      }).toList();
      if (overspeed.isEmpty) {
        return 'Sem excesso de velocidade relevante agora.';
      }
      final details = overspeed.take(4).map((device) {
        final pos = latestPositionByDeviceId[device.id]!;
        return '${device.name} (${_speedKmh(pos).toStringAsFixed(0)} km/h)';
      }).join(', ');
      return 'Risco de velocidade em ${overspeed.length} veículo(s): $details. Priorize contato com motorista e verificação de rota.';
    }

    if (text.contains('tpms') ||
        text.contains('pneu') ||
        text.contains('press')) {
      final tpmsAlerts = managementAlerts
          .where((a) => a.title.toLowerCase().contains('tpms'))
          .toList();
      if (tpmsAlerts.isEmpty) {
        return 'Sem alertas TPMS ativos neste momento.';
      }
      final sample = tpmsAlerts.take(3).map((a) => a.message).join(' | ');
      return 'TPMS ativo em ${tpmsAlerts.length} alerta(s). Exemplos: $sample. Ação: inspeção de pressão/temperatura antes do próximo ciclo de rota.';
    }

    if (text.contains('prior') ||
        text.contains('o que fazer') ||
        text.contains('ação')) {
      return 'Prioridade agora: 1) tratar $critical crítico(s), 2) abrir SLA curto para $high alto(s), 3) revisar offline (${offlineDevices.length}) e telemetria atrasada. Depois disso, otimizar despacho com mapa e eventos.';
    }

    final topAlerts = managementAlerts.take(3).map((a) => a.title).join(', ');
    return 'Entendido. Situação atual: $critical crítico(s), $high alto(s), $medium médio(s). Alertas foco: ${topAlerts.isEmpty ? 'sem alertas relevantes' : topAlerts}. Se quiser, eu respondo por tema: offline, velocidade, TPMS, despacho ou prioridade.';
  }

  void _openAiAssistant(
    BuildContext context, {
    required List<_ManagementAlert> managementAlerts,
    required List<TraccarDevice> devices,
    required Map<int, TraccarPosition> latestPositionByDeviceId,
  }) {
    final promptController = TextEditingController();
    var aiResponse = _buildAiResponse(
      prompt: '',
      managementAlerts: managementAlerts,
      devices: devices,
      latestPositionByDeviceId: latestPositionByDeviceId,
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void ask() {
              setDialogState(() {
                aiResponse = _buildAiResponse(
                  prompt: promptController.text,
                  managementAlerts: managementAlerts,
                  devices: devices,
                  latestPositionByDeviceId: latestPositionByDeviceId,
                );
              });
            }

            return AlertDialog(
              backgroundColor: Colors.black.withValues(alpha: 0.84),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.lightBlueAccent),
                  SizedBox(width: 8),
                  Text('IA Operacional', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: promptController,
                      onSubmitted: (_) => ask(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText:
                            'Peça algo: offline, velocidade, TPMS, prioridade...',
                        hintStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        aiResponse,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: ask, child: const Text('Perguntar')),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(promptController.dispose);
  }

  void _openDeviceVisualConfigDialog(
    BuildContext context,
    TraccarDevice device,
  ) {
    final currentCategory =
        _deviceCategoryOverride[device.id] ?? _resolvedDeviceCategory(device);
    final currentImageUrl =
        _deviceImageOverride[device.id] ?? _extractDeviceImageUrl(device) ?? '';

    String selectedCategory =
        (_vehicleCategoryOptions.contains(currentCategory))
            ? currentCategory!
            : _vehicleCategoryOptions.first;
    String selectedMarkerType = _resolvedDeviceType(device);
    if (!_markerTypeOptions.any((option) => option.key == selectedMarkerType)) {
      selectedMarkerType = 'tracker';
    }
    String selectedMarkerColor = _markerColorForDevice(device).key;
    if (!_markerColorByKey.containsKey(selectedMarkerColor)) {
      selectedMarkerColor = 'azure';
    }
    final imageController = TextEditingController(text: currentImageUrl);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Configuração visual do dispositivo'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          border: OutlineInputBorder(),
                        ),
                        items: _vehicleCategoryOptions
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedCategory = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Foto do veiculo',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.image,
                                withData: true,
                                allowMultiple: false,
                              );
                              if (!context.mounted) {
                                return;
                              }

                              if (picked == null) {
                                final tip = kIsWeb
                                    ? 'Selecao cancelada ou bloqueada no navegador embutido. Tente abrir no Chrome/Edge.'
                                    : 'Selecao de imagem cancelada.';
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(tip)));
                                return;
                              }

                              final file = picked.files.single;
                              final bytes = file.bytes;
                              if (bytes == null || bytes.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Nao foi possivel ler a imagem selecionada.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              final mime = _guessImageMimeType(
                                file.extension,
                                file.name,
                              );
                              final dataUrl =
                                  'data:$mime;base64,${base64Encode(bytes)}';
                              setDialogState(() {
                                imageController.text = dataUrl;
                              });
                            },
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text('Escolher do computador'),
                          ),
                          if (imageController.text.trim().isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  imageController.clear();
                                });
                              },
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Remover foto'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Tipo do marcador',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _markerTypeOptions.map((option) {
                          final isSelected = selectedMarkerType == option.key;
                          return ChoiceChip(
                            label: Text(option.label),
                            selected: isSelected,
                            avatar: Icon(option.icon, size: 16),
                            onSelected: (_) {
                              setDialogState(() {
                                selectedMarkerType = option.key;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Cor do marcador',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _markerColorOptions.map((option) {
                          final isSelected = selectedMarkerColor == option.key;
                          return Tooltip(
                            message: option.label,
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedMarkerColor = option.key;
                                });
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: option.uiColor,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.black87
                                        : Colors.black26,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ajustes visuais são opcionais e usados para apresentação.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _deviceCategoryOverride.remove(device.id);
                      _deviceImageOverride.remove(device.id);
                      _deviceMarkerTypeOverride.remove(device.id);
                      _deviceMarkerColorOverride.remove(device.id);
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Limpar'),
                ),
                FilledButton(
                  onPressed: () {
                    final imageValue = imageController.text.trim();
                    final nativeCategory = (device.category ?? '').trim();
                    final categoryValue = selectedCategory.trim();
                    final defaultType = _deviceType(device);
                    final defaultColor = _defaultMarkerColorForType(
                      selectedMarkerType,
                    ).key;
                    setState(() {
                      if (categoryValue.isEmpty ||
                          categoryValue == nativeCategory) {
                        _deviceCategoryOverride.remove(device.id);
                      } else {
                        _deviceCategoryOverride[device.id] = categoryValue;
                      }

                      if (imageValue.isEmpty) {
                        _deviceImageOverride.remove(device.id);
                      } else {
                        _deviceImageOverride[device.id] = imageValue;
                      }

                      if (selectedMarkerType == defaultType) {
                        _deviceMarkerTypeOverride.remove(device.id);
                      } else {
                        _deviceMarkerTypeOverride[device.id] =
                            selectedMarkerType;
                      }

                      if (selectedMarkerColor == defaultColor) {
                        _deviceMarkerColorOverride.remove(device.id);
                      } else {
                        _deviceMarkerColorOverride[device.id] =
                            selectedMarkerColor;
                      }
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(imageController.dispose);
  }

  String? _extractDeviceImageUrl(TraccarDevice device) {
    final overrideImage = _deviceImageOverride[device.id];
    if (overrideImage != null && overrideImage.trim().isNotEmpty) {
      return overrideImage.trim();
    }

    final nativeImage = device.image;
    if (nativeImage != null && nativeImage.trim().isNotEmpty) {
      return nativeImage.trim();
    }

    final attrs = device.attributes;
    if (attrs == null || attrs.isEmpty) {
      return null;
    }

    const keys = ['image', 'imageUrl', 'photo', 'photoUrl', 'avatar', 'icon'];
    for (final key in keys) {
      final value = attrs[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _guessImageMimeType(String? extension, String fileName) {
    final ext = (extension ?? fileName.split('.').last).toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
      case 'svgz':
        return 'image/svg+xml';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  String _connectionLabel(TraccarDevice device) {
    switch (device.status) {
      case 'online':
        return 'Online';
      case 'offline':
        return 'Offline';
      default:
        return 'Sem sinal';
    }
  }

  Color _connectionColor(TraccarDevice device) {
    switch (device.status) {
      case 'online':
        return Colors.greenAccent;
      case 'offline':
        return Colors.redAccent;
      default:
        return Colors.amberAccent;
    }
  }

  String _formatDateTimeLabel(String? isoValue) {
    if (isoValue == null || isoValue.trim().isEmpty) {
      return '-';
    }
    final parsed = DateTime.tryParse(isoValue);
    if (parsed == null) {
      return isoValue;
    }
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  _AddressSummary? _addressSummaryFromPosition(TraccarPosition? position) {
    if (position == null) {
      return null;
    }
    final attrs = position.attributes;
    if (attrs == null || attrs.isEmpty) {
      return null;
    }

    final road = (attrs['road'] ?? attrs['street'])?.toString().trim();
    final number = attrs['house_number']?.toString().trim();
    final suburb =
        (attrs['suburb'] ?? attrs['neighbourhood'])?.toString().trim();
    final city =
        (attrs['city'] ?? attrs['town'] ?? attrs['village'])?.toString().trim();
    if (road != null && road.isNotEmpty) {
      final street =
          number != null && number.isNotEmpty ? '$road, $number' : road;
      final regionParts = <String>[];
      if (suburb != null && suburb.isNotEmpty) {
        regionParts.add(suburb);
      }
      if (city != null && city.isNotEmpty) {
        regionParts.add(city);
      }
      final region = regionParts.join(' - ');
      return _AddressSummary(streetLine: street, regionLine: region);
    }

    const keys = [
      'address',
      'streetAddress',
      'formattedAddress',
      'displayName',
      'road',
      'street',
      'place',
      'city',
    ];

    for (final key in keys) {
      final value = attrs[key];
      if (value is String && value.trim().isNotEmpty) {
        return _addressSummaryFromText(value.trim());
      }
    }
    return null;
  }

  _AddressSummary _addressSummaryFor({
    required TraccarDevice device,
    required TraccarPosition position,
  }) {
    final inlineAddress = _addressSummaryFromPosition(position);
    if (inlineAddress != null) {
      return inlineAddress;
    }
    final cachedAddress = _resolvedAddressByDeviceId[device.id];
    if (cachedAddress != null) {
      return cachedAddress;
    }
    return const _AddressSummary(streetLine: 'Buscando rua...');
  }

  _AddressSummary _addressSummaryFromText(String text) {
    final chunks = text
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (chunks.isEmpty) {
      return const _AddressSummary(streetLine: 'Buscando rua...');
    }
    final street = chunks.first;
    final region = chunks.length > 1 ? chunks.sublist(1).join(' - ') : '';
    return _AddressSummary(streetLine: street, regionLine: region);
  }

  void _ensureAddressForSelected({
    required TraccarDevice device,
    required TraccarPosition position,
  }) {
    if (_addressSummaryFromPosition(position) != null) {
      return;
    }
    if (_resolvedAddressByDeviceId.containsKey(device.id) ||
        _addressLookupInFlight.contains(device.id)) {
      return;
    }

    _addressLookupInFlight.add(device.id);
    unawaited(() async {
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'format': 'jsonv2',
          'lat': position.latitude.toStringAsFixed(6),
          'lon': position.longitude.toStringAsFixed(6),
          'zoom': '18',
          'addressdetails': '1',
        });
        final response = await http.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'sou-fleet/1.0',
          },
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return;
        }

        final payload = jsonDecode(response.body);
        if (payload is! Map<String, dynamic>) {
          return;
        }
        final address = payload['address'];
        String? road;
        String? number;
        String? suburb;
        String? city;
        if (address is Map<String, dynamic>) {
          road = (address['road'] ??
                  address['pedestrian'] ??
                  address['residential'] ??
                  address['street'])
              ?.toString();
          number = address['house_number']?.toString();
          suburb = (address['suburb'] ?? address['neighbourhood'])?.toString();
          city = (address['city'] ??
                  address['town'] ??
                  address['village'] ??
                  address['municipality'])
              ?.toString();
        }

        final parts = <String>[];
        if (road != null && road.trim().isNotEmpty) {
          final roadPart = number != null && number.trim().isNotEmpty
              ? '${road.trim()}, ${number.trim()}'
              : road.trim();
          parts.add(roadPart);
        }
        if (suburb != null && suburb.trim().isNotEmpty) {
          parts.add(suburb.trim());
        }
        if (city != null && city.trim().isNotEmpty) {
          parts.add(city.trim());
        }

        final displayName = payload['display_name']?.toString().trim() ?? '';
        final summary = parts.isNotEmpty
            ? _AddressSummary(
                streetLine: parts.first,
                regionLine:
                    parts.length > 1 ? parts.sublist(1).join(' - ') : '',
              )
            : (displayName.isNotEmpty
                ? _addressSummaryFromText(displayName)
                : const _AddressSummary(streetLine: 'Buscando rua...'));
        if (!mounted) {
          return;
        }

        setState(() {
          _resolvedAddressByDeviceId[device.id] = summary;
        });
      } catch (_) {
        // Ignore lookup failures and keep a lightweight fallback label.
      } finally {
        _addressLookupInFlight.remove(device.id);
      }
    }());
  }

  Widget _buildDeviceImagePreview(String url) {
    Widget fallback() {
      return Container(
        height: 120,
        color: Colors.white10,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white70,
        ),
      );
    }

    if (url.startsWith('data:image/')) {
      try {
        final bytes = UriData.parse(url).contentAsBytes();
        return Image.memory(
          bytes,
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
        );
      } catch (_) {
        return fallback();
      }
    }

    return Image.network(
      url,
      height: 120,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback(),
    );
  }

  String _movementLabel(TraccarDevice device, TraccarPosition position) {
    if (device.status == 'offline') {
      return 'Offline';
    }
    return _speedKmh(position) >= 5 ? 'Em Movimento' : 'Parado';
  }

  String _lastPointRelativeLabel(TraccarPosition position) {
    final parsed = DateTime.tryParse(position.fixTime);
    if (parsed == null) {
      return 'agora';
    }
    final diff = DateTime.now().difference(parsed.toLocal());
    if (diff.inSeconds < 60) {
      return 'agora';
    }
    if (diff.inMinutes < 60) {
      return 'há ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'há ${diff.inHours} h';
    }
    return 'há ${diff.inDays} d';
  }

  String _ignitionLabel(TraccarPosition position) {
    final attrs = position.attributes ?? const <String, dynamic>{};
    final on = _asBool(attrs['ignition']) ||
        _asBool(attrs['acc']) ||
        _asBool(attrs['engine']) ||
        _asBool(attrs['engineOn']);
    return on ? 'Ligada' : 'Desligada';
  }

  String _batteryVoltageLabel(TraccarPosition position) {
    final attrs = position.attributes ?? const <String, dynamic>{};
    for (final key in ['batteryVoltage', 'voltage', 'power', 'battery']) {
      final value = _asDouble(attrs[key]);
      if (value != null && value > 0) {
        return '${value.toStringAsFixed(1)} V';
      }
    }
    return '-';
  }

  String _firstAttrString(
    Map<String, dynamic> attrs,
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final key in keys) {
      final value = attrs[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  String _deviceModelLabel(TraccarDevice device) {
    final attrs = device.attributes ?? const <String, dynamic>{};
    return _firstAttrString(attrs, ['model', 'vehicleModel', 'vehicle']);
  }

  String _deviceYearLabel(TraccarDevice device) {
    final attrs = device.attributes ?? const <String, dynamic>{};
    return _firstAttrString(attrs, ['year', 'modelYear', 'ano']);
  }

  String _deviceDriverLabel(TraccarDevice device) {
    final attrs = device.attributes ?? const <String, dynamic>{};
    return _firstAttrString(attrs, ['driverName', 'driver', 'motorista']);
  }

  String _deviceGroupLabel(TraccarDevice device) {
    final attrs = device.attributes ?? const <String, dynamic>{};
    return _firstAttrString(attrs, ['groupName', 'group', 'fleet']);
  }

  List<double> _speedSeries(TraccarPosition position) {
    final base = _speedKmh(position);
    final normalized = base < 8 ? 12 : base;
    return List<double>.generate(12, (index) {
      final wave = ((index % 4) - 1.5) * 6;
      final drift = index.isEven ? 4 : -3;
      final value = normalized + wave + drift;
      return value < 0 ? 0 : value;
    });
  }

  Widget _buildDeviceHoverPopup({
    required BuildContext context,
    required TraccarDevice device,
    required TraccarPosition position,
    required double? selectedSpeedLimit,
    required String? lastUpdateSource,
    required bool canManageVisualConfig,
  }) {
    final imageUrl = _extractDeviceImageUrl(device);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 410,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _vehiclePanelSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _vehiclePanelBorder),
            boxShadow: [
              BoxShadow(
                color: _vehiclePanelShadow,
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 124,
                  height: 88,
                  child: imageUrl != null
                      ? _buildDeviceImagePreview(imageUrl)
                      : Container(
                          color: _vehiclePlaceholderSurface,
                          alignment: Alignment.center,
                          child: Icon(
                            _iconForType(_resolvedDeviceType(device)),
                            color: _vehiclePlaceholderIcon,
                            size: 34,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _vehicleTextPrimary,
                              fontSize: 31 / 2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar popup',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.close,
                            color: _vehicleTextSecondary,
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() {
                              _showDeviceHoverCard = false;
                            });
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _connectionColor(device),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _movementLabel(device, position),
                          style: const TextStyle(
                            color: Color(0xFF0FA879),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Vel.: ${_speedKmh(position).toStringAsFixed(0)} km/h',
                          style: const TextStyle(
                            color: _vehicleTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Limite da via: ${(selectedSpeedLimit ?? 60).toStringAsFixed(0)} km/h',
                      style: const TextStyle(
                        color: _vehicleTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Ultimo ponto: ${_lastPointRelativeLabel(position)}',
                      style: const TextStyle(
                        color: _vehicleTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (lastUpdateSource != null && lastUpdateSource.isNotEmpty)
                      Text(
                        _formatDateTimeLabel(lastUpdateSource),
                        style: const TextStyle(
                          color: _vehicleTextMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _hoverActionButton(
                          icon: Icons.visibility_outlined,
                          tooltip: 'Abrir barra inferior',
                          onTap: () {
                            setState(() {
                              _showDeviceBottomBar = true;
                              _activeDeviceDetailTab =
                                  _DeviceDetailTab.overview;
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        _hoverActionButton(
                          icon: Icons.notifications_none_outlined,
                          tooltip: 'Configurar alerta',
                          onTap: () {
                            _createQuickNotificationAlert(
                              context: context,
                              device: device,
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        _hoverActionButton(
                          icon: Icons.share_outlined,
                          tooltip: 'Compartilhar',
                          onTap: () {
                            _copyTrackingLink(
                              context: context,
                              device: device,
                              position: position,
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        _hoverActionButton(
                          icon: Icons.more_horiz,
                          tooltip: 'Mais opcoes',
                          onTap: canManageVisualConfig
                              ? () => _openDeviceVisualConfigDialog(
                                    context,
                                    device,
                                  )
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hoverActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _vehicleActionSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _vehicleActionBorder),
          ),
          child: Icon(icon, color: _vehicleActionIcon, size: 18),
        ),
      ),
    );
  }

  Widget _buildDeviceBottomBar({
    required BuildContext context,
    required TraccarDevice device,
    required TraccarPosition position,
    required _AddressSummary? selectedAddress,
    required double? selectedSpeedLimit,
    required String? selectedSpeedLimitSource,
    required double? selectedBatteryPercent,
    required bool hasOverspeedAlert,
    required bool canManageVisualConfig,
  }) {
    final attrs = position.attributes ?? const <String, dynamic>{};
    final imageUrl = _extractDeviceImageUrl(device);
    final street = selectedAddress?.streetLine ?? 'Buscando rua...';
    final region = (selectedAddress?.regionLine.isNotEmpty ?? false)
        ? selectedAddress!.regionLine
        : '-';
    final speedSeries = _speedSeries(position);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: _vehiclePanelSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _vehiclePanelBorder),
            boxShadow: [
              BoxShadow(
                color: _vehiclePanelShadow,
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      setState(() {
                        _showDeviceBottomBar = false;
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: _vehicleAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 52,
                      height: 36,
                      child: imageUrl != null
                          ? _buildDeviceImagePreview(imageUrl)
                          : Container(
                              color: _vehiclePlaceholderSurface,
                              alignment: Alignment.center,
                              child: Icon(
                                _iconForType(_resolvedDeviceType(device)),
                                color: _vehiclePlaceholderIcon,
                                size: 18,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      device.name,
                      style: const TextStyle(
                        color: _vehicleTextPrimary,
                        fontSize: 34 / 2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: _vehicleTextSecondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedDeviceId = null;
                        _showDeviceBottomBar = false;
                        _showDeviceHoverCard = false;
                      });
                    },
                    icon: const Icon(Icons.close, size: 17),
                    label: const Text('Fechar'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _metricCell(
                    'Velocidade',
                    '${_speedKmh(position).toStringAsFixed(0)} km/h',
                  ),
                  _metricCell('Ignicao', _ignitionLabel(position)),
                  _metricCell('Bateria', _batteryVoltageLabel(position)),
                  _metricCell(
                    'Limite da via',
                    '${(selectedSpeedLimit ?? 60).toStringAsFixed(0)} km/h',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDeviceTabButton(
                    _DeviceDetailTab.overview,
                    Icons.hub_outlined,
                    'Visao Geral',
                  ),
                  _buildDeviceTabButton(
                    _DeviceDetailTab.photos,
                    Icons.photo_library_outlined,
                    'Fotos',
                  ),
                  _buildDeviceTabButton(
                    _DeviceDetailTab.commands,
                    Icons.terminal_outlined,
                    'Comandos',
                  ),
                  _buildDeviceTabButton(
                    _DeviceDetailTab.chart,
                    Icons.show_chart_outlined,
                    'Grafico',
                  ),
                  _buildDeviceTabButton(
                    _DeviceDetailTab.info,
                    Icons.info_outline,
                    'Informacoes',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _buildDeviceTabBody(
                  key: ValueKey(_activeDeviceDetailTab),
                  context: context,
                  device: device,
                  attrs: attrs,
                  position: position,
                  street: street,
                  region: region,
                  speedSeries: speedSeries,
                  selectedSpeedLimitSource: selectedSpeedLimitSource,
                  hasOverspeedAlert: hasOverspeedAlert,
                  canManageVisualConfig: canManageVisualConfig,
                  selectedBatteryPercent: selectedBatteryPercent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCell(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _vehicleTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: _vehicleTextPrimary,
                fontSize: 28 / 2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTabButton(
    _DeviceDetailTab tab,
    IconData icon,
    String label,
  ) {
    final selected = _activeDeviceDetailTab == tab;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () {
        setState(() {
          _activeDeviceDetailTab = tab;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _vehicleAccent : _vehicleTabIdle,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? _vehicleAccent : _vehicleTabIdleBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : _vehicleTabIdleText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _vehicleTabIdleText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTabBody({
    required Key key,
    required BuildContext context,
    required TraccarDevice device,
    required Map<String, dynamic> attrs,
    required TraccarPosition position,
    required String street,
    required String region,
    required List<double> speedSeries,
    required String? selectedSpeedLimitSource,
    required bool hasOverspeedAlert,
    required bool canManageVisualConfig,
    required double? selectedBatteryPercent,
  }) {
    final imageUrl = _extractDeviceImageUrl(device);
    final eventTimestamp = _formatDateTimeLabel(position.fixTime);
    const bodyTextStyle = TextStyle(
      color: _vehicleTextSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    if (_activeDeviceDetailTab == _DeviceDetailTab.photos) {
      return Container(
        key: key,
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 136),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imageUrl != null
              ? _buildDeviceImagePreview(imageUrl)
              : Container(
                  color: _vehiclePlaceholderSurface,
                  alignment: Alignment.center,
                  child: Icon(
                    _iconForType(_resolvedDeviceType(device)),
                    color: _vehiclePlaceholderIcon,
                    size: 44,
                  ),
                ),
        ),
      );
    }

    if (_activeDeviceDetailTab == _DeviceDetailTab.commands) {
      return Container(
        key: key,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _vehicleContentSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _vehiclePanelBorder),
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                _sendDeviceCommand(
                  context: context,
                  device: device,
                  commandType: 'engineStop',
                  successMessage:
                      'Comando de bloqueio enviado para ${device.name}.',
                );
              },
              icon: const Icon(Icons.lock_clock_outlined),
              label: const Text('Bloquear'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                final openedJourney = _openJourneyForDevice(device);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      openedJourney
                          ? 'Jornada / Check-in aberto para ${device.name}.'
                          : 'Dispositivo ${device.name} destacado no mapa.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.near_me_outlined),
              label: const Text('Navegar'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final sent = await _sendDeviceCommand(
                  context: context,
                  device: device,
                  commandType: 'alarm',
                  successMessage: 'Alerta sonoro enviado para ${device.name}.',
                  showError: false,
                );
                if (!sent) {
                  await _createQuickNotificationAlert(
                    context: context,
                    device: device,
                  );
                }
              },
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Alerta Sonoro'),
            ),
            if (canManageVisualConfig)
              FilledButton.icon(
                onPressed: () => _openDeviceVisualConfigDialog(context, device),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Trocar foto e marcador'),
              ),
          ],
        ),
      );
    }

    if (_activeDeviceDetailTab == _DeviceDetailTab.chart) {
      return Container(
        key: key,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: _vehicleContentSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _vehiclePanelBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Velocidade (ultimas 2 horas)',
              style: TextStyle(
                color: _vehicleTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 124,
              child: CustomPaint(
                painter: _DeviceSpeedLinePainter(values: speedSeries),
              ),
            ),
          ],
        ),
      );
    }

    if (_activeDeviceDetailTab == _DeviceDetailTab.info) {
      return Container(
        key: key,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _vehicleContentSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _vehiclePanelBorder),
        ),
        child: DefaultTextStyle(
          style: bodyTextStyle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Modelo: ${_deviceModelLabel(device)}'),
              Text('Ano: ${_deviceYearLabel(device)}'),
              Text('Motorista: ${_deviceDriverLabel(device)}'),
              Text('Grupo: ${_deviceGroupLabel(device)}'),
              Text('Conexao: ${_connectionLabel(device)}'),
              Text(
                'Ultima atualizacao: ${_formatDateTimeLabel(position.fixTime)}',
              ),
              if ((selectedSpeedLimitSource ?? '').isNotEmpty)
                Text('Fonte limite: $selectedSpeedLimitSource'),
              if ((device.uniqueId ?? '').isNotEmpty)
                Text('Identificador: ${device.uniqueId}'),
              if (selectedBatteryPercent != null)
                Text('Bateria: ${selectedBatteryPercent.toStringAsFixed(0)}%'),
              if (hasOverspeedAlert)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'ALERTA: Excesso de velocidade detectado.',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _vehicleContentSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _vehiclePanelBorder),
      ),
      child: DefaultTextStyle(
        style: bodyTextStyle,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Localizacao Atual',
                    style: TextStyle(
                      color: _vehicleTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(street),
                  Text(region),
                  const SizedBox(height: 6),
                  const Text(
                    'Ver no mapa',
                    style: TextStyle(
                      color: _vehicleAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ultimos Eventos',
                    style: TextStyle(
                      color: _vehicleTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$eventTimestamp Telemetria atualizada'),
                  Text('${_ignitionLabel(position)}'),
                  Text(
                    hasOverspeedAlert
                        ? 'Excesso de velocidade detectado'
                        : 'Velocidade dentro do limite',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 106,
                child: CustomPaint(
                  painter: _DeviceSpeedLinePainter(values: speedSeries),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Modelo  ${_deviceModelLabel(device)}'),
                  Text('Ano  ${_deviceYearLabel(device)}'),
                  Text('Motorista  ${_deviceDriverLabel(device)}'),
                  Text('Grupo  ${_deviceGroupLabel(device)}'),
                  if (attrs.isNotEmpty &&
                      _resolvedDeviceCategory(device) != null)
                    Text('Categoria  ${_resolvedDeviceCategory(device)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_MenuSection> _sections(TenantConfig tenant) {
    // Menu original do tracking SEM feature flag
    final trackingSections = [
      _MenuSection(
        key: 'comercial',
        label: 'Comercial',
        featureKey: 'tracking',
        children: [
          _MenuNode(
            id: 'general-panel',
            label: 'Painel Geral',
            icon: Icons.space_dashboard_outlined,
            page: const GeneralPanelScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'service-orders',
            label: 'Ordens de Serviço',
            icon: Icons.receipt_long_outlined,
            page: const ServiceOrdersReferenceScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'financial-management',
            label: 'Gestão Financeira',
            icon: Icons.account_balance_wallet_outlined,
            page: const FinancialManagementScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'inventory-assets',
            label: 'Estoque e Ativos',
            icon: Icons.inventory_2_outlined,
            page: const InventoryAssetsScreen(),
            featureKey: 'tracking',
          ),
        ],
      ),
      _MenuSection(
        key: 'mapa',
        label: 'Mapa',
        featureKey: 'tracking',
        children: [
          _MenuNode(
            id: 'map',
            label: 'Mapa',
            icon: Icons.map_outlined,
            page: const MapScreen(),
            featureKey: 'tracking',
          ),
        ],
      ),
      _MenuSection(
        key: 'gestao',
        label: 'Gestão',
        featureKey: 'tracking',
        children: [
          _MenuNode(
            id: 'dashboard',
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            page: const DashboardScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'devices',
            label: 'Dispositivos',
            icon: Icons.directions_car_outlined,
            page: const VehiclesScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'groups',
            label: 'Grupos',
            icon: Icons.folder_open_outlined,
            page: const GroupsScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'drivers',
            label: 'Motoristas',
            icon: Icons.badge_outlined,
            page: const DriversScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'maintenance',
            label: 'Manutenção',
            icon: Icons.build_outlined,
            page: const MaintenanceScreen(),
            featureKey: 'tracking',
          ),
        ],
      ),
      _MenuSection(
        key: 'operacao',
        label: 'Operação',
        featureKey: 'tracking',
        children: [
          _MenuNode(
            id: 'events',
            label: 'Eventos',
            icon: Icons.notifications_outlined,
            page: const EventsScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'history',
            label: 'Historico',
            icon: Icons.history_outlined,
            page: const HistoryScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'notifications',
            label: 'Notificações',
            icon: Icons.campaign_outlined,
            page: const NotificationsScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'commands',
            label: 'Comandos',
            icon: Icons.send_outlined,
            page: const CommandsScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'geofences',
            label: 'Cercas',
            icon: Icons.fence_outlined,
            page: const GeofencesScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'journey-checkin',
            label: 'Jornada / Check-in',
            icon: Icons.fact_check_outlined,
            page: const JourneyCheckinScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'sharing',
            label: 'Compartilhamento',
            icon: Icons.share_outlined,
            page: const SharingScreen(),
            featureKey: 'tracking',
          ),
        ],
      ),
      _MenuSection(
        key: 'relatorios',
        label: 'Relatórios',
        featureKey: 'tracking',
        children: [
          _MenuNode(
            id: 'reports-route',
            label: 'Rotas',
            icon: Icons.alt_route_outlined,
            page: const ReportsScreen(
              title: 'Relatório de rotas',
              endpointPath: '/reports/route',
            ),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'reports-events',
            label: 'Eventos',
            icon: Icons.event_note_outlined,
            page: const ReportsScreen(
              title: 'Relatório de eventos',
              endpointPath: '/reports/events',
            ),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'reports-summary',
            label: 'Resumo',
            icon: Icons.summarize_outlined,
            page: const ReportsScreen(
              title: 'Relatório de resumo',
              endpointPath: '/reports/summary',
            ),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'reports-trips',
            label: 'Viagens',
            icon: Icons.trip_origin_outlined,
            page: const ReportsScreen(
              title: 'Relatório de viagens',
              endpointPath: '/reports/trips',
            ),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'reports-stops',
            label: 'Paradas',
            icon: Icons.stop_circle_outlined,
            page: const ReportsScreen(
              title: 'Relatório de paradas',
              endpointPath: '/reports/stops',
            ),
            featureKey: 'tracking',
          ),
        ],
      ),
      _MenuSection(
        key: 'administracao',
        label: 'Administração',
        featureKey: 'tracking',
        children: [
          _MenuNode(
            id: 'user-profiles',
            label: 'Perfis de Usuários',
            icon: Icons.badge_outlined,
            page: const UserProfilesScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'users',
            label: 'Usuários Internos',
            icon: Icons.people_outline,
            page: const UsersScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'users-permissions',
            label: 'Permissões dos Usuários',
            icon: Icons.vpn_key_outlined,
            page: const PermissionsScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'attributes',
            label: 'Atributos',
            icon: Icons.tune_outlined,
            page: const AttributesScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'calendars',
            label: 'Calendários',
            icon: Icons.calendar_month_outlined,
            page: const CalendarsScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'statistics',
            label: 'Estatísticas',
            icon: Icons.insights_outlined,
            page: const StatisticsScreen(),
            featureKey: 'tracking',
          ),
          _MenuNode(
            id: 'orders',
            label: 'Ordens',
            icon: Icons.assignment_turned_in_outlined,
            page: const OrdersScreen(),
            featureKey: 'tracking',
          ),
        ],
      ),
      _MenuSection(
        key: 'config',
        label: 'Configuração',
        featureKey: 'tracking',
        children: [
          _MenuNode(
            id: 'settings',
            label: 'Config',
            icon: Icons.settings_outlined,
            page: SettingsScreen(
              onLogout: () => ref.read(sessionProvider.notifier).logout(),
            ),
            featureKey: 'tracking',
          ),
        ],
      ),
    ];

    // Novos módulos, condicionados por feature flag
    final List<_MenuSection> extraSections = [];
    if (tenant.isFeatureEnabled('assist')) {
      extraSections.add(
        _MenuSection(
          key: 'assist',
          label: 'Assistência',
          featureKey: 'assist',
          children: [
            _MenuNode(
              id: 'assist-requests',
              label: 'SouAssist Demandas',
              icon: Icons.support_agent_outlined,
              page: const AssistRequestsScreen(),
              featureKey: 'assist',
              children: [
                _MenuNode(
                  id: 'assist-create',
                  label: 'Criar Chamado',
                  icon: Icons.add_task_outlined,
                  page: const AssistCreateRequestScreen(),
                  featureKey: 'assist',
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (tenant.isFeatureEnabled('demand')) {
      extraSections.add(
        _MenuSection(
          key: 'demand',
          label: 'Central de Demandas',
          featureKey: 'demand',
          children: [
            _MenuNode(
              id: 'demand-control',
              label: 'Painel de Controle',
              icon: Icons.hub_outlined,
              page: const DemandControlPanelScreen(),
              featureKey: 'demand',
            ),
            _MenuNode(
              id: 'demand-requests',
              label: 'Chamados Operacionais',
              icon: Icons.support_agent_outlined,
              page: const AssistRequestsScreen(),
              featureKey: 'demand',
              children: [
                _MenuNode(
                  id: 'demand-create',
                  label: 'Criar Chamado',
                  icon: Icons.add_task_outlined,
                  page: const AssistCreateRequestScreen(),
                  featureKey: 'demand',
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (tenant.isFeatureEnabled('mdvr')) {
      extraSections.add(
        _MenuSection(
          key: 'mdvr',
          label: 'Câmeras',
          featureKey: 'mdvr',
          children: [
            _MenuNode(
              id: 'mdvr-devices',
              label: 'Mural de Câmeras',
              icon: Icons.videocam_outlined,
              page: const MdvrDevicesScreen(),
              featureKey: 'mdvr',
            ),
          ],
        ),
      );
    }
    if (tenant.isFeatureEnabled('zpro')) {
      extraSections.add(
        _MenuSection(
          key: 'zpro',
          label: 'Comunicação',
          featureKey: 'zpro',
          children: [
            _MenuNode(
              id: 'zpro-whatsapp',
              label: 'WhatsApp (Z-Pro)',
              icon: Icons.chat_outlined,
              page: const ZproCommunicationScreen(),
              featureKey: 'zpro',
            ),
          ],
        ),
      );
    }
    if (tenant.isFeatureEnabled('admin')) {
      extraSections.add(
        _MenuSection(
          key: 'admin',
          label: 'Administração SaaS',
          featureKey: 'admin',
          children: [
            _MenuNode(
              id: 'admin-tenants',
              label: 'SaaS Empresas',
              icon: Icons.domain_outlined,
              page: const AdminTenantsScreen(),
              featureKey: 'admin',
            ),
          ],
        ),
      );
    }
    return [...trackingSections, ...extraSections];
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(tenantConfigProvider);
    final canManageVisualConfig = tenant.isMasterAdmin || tenant.isCompanyAdmin;
    final sections = _visibleSections(_sections(tenant), tenant);
    final menuBuild = _buildMenu(sections);
    final flatMenu = menuBuild.items;
    final entries = menuBuild.entries;
    _index = _index.clamp(0, flatMenu.length - 1);
    final current = flatMenu[_index];
    final isWide = MediaQuery.of(context).size.width >= 1000;
    final devicesAsync = ref.watch(devicesProvider);
    final positionsAsync = ref.watch(positionsProvider);
    final whiteLabelAsync = ref.watch(whiteLabelProvider);
    final appName = whiteLabelAsync.value?.appName ?? 'Sou Fleet';

    final headerStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Colors.white70,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontSize: 13,
        );
    const menuSurface = Color(0xFF12161D);
    const menuSelectedTile = Color(0x3D1F6FEB);
    const menuSelectedText = Color(0xFF8EC5FF);
    final itemStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        );
    final childItemStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white70,
          fontWeight: FontWeight.w500,
          fontSize: 12.5,
        );

    final devices = devicesAsync.value ?? [];
    final positions = positionsAsync.value ?? [];

    final latestPositionByDeviceId = <int, TraccarPosition>{};
    for (final position in positions) {
      final current = latestPositionByDeviceId[position.deviceId];
      if (current == null || _isNewerPosition(position, current)) {
        latestPositionByDeviceId[position.deviceId] = position;
      }
    }
    final latestPositions = latestPositionByDeviceId.values.toList();
    final hasPositions = latestPositions.isNotEmpty;

    final deviceMap = {for (final d in devices) d.id: d};
    final selectedPosition = _selectedDeviceId == null
        ? null
        : latestPositionByDeviceId[_selectedDeviceId];
    final selectedDevice =
        _selectedDeviceId == null ? null : deviceMap[_selectedDeviceId];
    final hasOverspeedAlert = selectedDevice != null && selectedPosition != null
        ? _isOverspeed(selectedDevice, selectedPosition)
        : false;
    final selectedSpeedLimit =
        selectedDevice != null && selectedPosition != null
            ? _effectiveSpeedLimitKmh(selectedDevice, selectedPosition)
            : null;
    final selectedSpeedLimitSource =
        selectedDevice != null && selectedPosition != null
            ? _speedLimitSourceLabel(selectedDevice, selectedPosition)
            : null;
    final selectedBatteryPercent = selectedDevice == null
        ? null
        : _batteryPercentFor(selectedDevice, selectedPosition);
    final selectedAddress = selectedDevice != null && selectedPosition != null
        ? _addressSummaryFor(device: selectedDevice, position: selectedPosition)
        : null;
    final lastUpdateSource =
        (selectedDevice?.lastUpdate?.trim().isNotEmpty ?? false)
            ? selectedDevice!.lastUpdate
            : selectedPosition?.fixTime;

    final managementAlerts = _buildManagementAlerts(
      devices: devices,
      latestPositionByDeviceId: latestPositionByDeviceId,
    );
    final markers = <Marker>{
      for (final p in latestPositions)
        () {
          final device = deviceMap[p.deviceId];
          final markerColor = _dynamicMarkerColorOption(device, p);
          final markerIcon = _descriptorForDeviceMarker(device, markerColor);
          final isSelected = _selectedDeviceId == p.deviceId;
          final speedKmh = _speedKmh(p);
          final isOffline = device?.status == 'offline';
          final isOverspeed = device != null ? _isOverspeed(device, p) : false;

          return Marker(
            markerId: MarkerId('device-${p.deviceId}'),
            position: LatLng(p.latitude, p.longitude),
            icon: markerIcon,
            alpha: isOffline ? 0.78 : 1,
            zIndexInt: isSelected ? 3 : (isOverspeed ? 2 : 1),
            flat: speedKmh >= 5,
            rotation: _courseDegrees(p),
            // Keep marker taps routed to the custom panel only.
            consumeTapEvents: true,
            infoWindow: InfoWindow.noText,
            onTap: () {
              setState(() {
                final tappedSameMarker = _selectedDeviceId == p.deviceId;
                _selectedDeviceId = p.deviceId;
                _showDeviceHoverCard = true;
                _showDeviceBottomBar =
                    tappedSameMarker ? !_showDeviceBottomBar : false;
                _activeDeviceDetailTab = _DeviceDetailTab.overview;
              });
            },
          );
        }(),
    };
    // Disable native Google marker DOM hitboxes (gmimap/area log="miw").
    // This avoids marker-click popups and pointer layers on web.
    final showNativeMapMarkers = _showNativeMapMarkers;
    final halos = <Circle>{};
    for (final p in latestPositions) {
      final device = deviceMap[p.deviceId];
      if (device == null) {
        continue;
      }

      final movementStatus = _movementStatus(device, p);
      final haloColor = _haloColorFor(movementStatus);
      final isSelected = _selectedDeviceId == p.deviceId;
      final overspeed = _isOverspeed(device, p);
      final showHalo = isSelected || overspeed || movementStatus == 'moving';
      if (!showHalo) {
        continue;
      }

      final outerRadius = isSelected
          ? 120.0
          : overspeed
              ? 95.0
              : 78.0;

      halos.add(
        Circle(
          circleId: CircleId('halo-outer-${p.deviceId}'),
          center: LatLng(p.latitude, p.longitude),
          radius: outerRadius,
          strokeWidth: isSelected ? 2 : 1,
          strokeColor: haloColor.withValues(alpha: isSelected ? 0.9 : 0.72),
          fillColor: haloColor.withValues(alpha: isSelected ? 0.22 : 0.14),
          zIndex: isSelected ? 2 : 1,
        ),
      );

      halos.add(
        Circle(
          circleId: CircleId('halo-core-${p.deviceId}'),
          center: LatLng(p.latitude, p.longitude),
          radius: isSelected ? 46 : 32,
          strokeWidth: 0,
          fillColor: haloColor.withValues(alpha: 0.28),
          zIndex: isSelected ? 3 : 2,
        ),
      );
    }

    final initialTarget = selectedPosition != null
        ? LatLng(selectedPosition.latitude, selectedPosition.longitude)
        : latestPositions.isNotEmpty
            ? LatLng(
                latestPositions.first.latitude,
                latestPositions.first.longitude,
              )
            : const LatLng(-15.78, -47.93);

    final isMapTab = current.page is MapScreen;
    if (isMapTab && selectedDevice != null && selectedPosition != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureRoadSpeedLimitForSelected(selectedDevice, selectedPosition);
        _ensureAddressForSelected(
          device: selectedDevice,
          position: selectedPosition,
        );
      });
    }
    final sidebarWidth = _sidebarExpanded ? (isWide ? 320.0 : 280.0) : 76.0;
    final mapTabIndex = flatMenu.indexWhere((item) => item.page is MapScreen);
    final positionByDeviceId = latestPositionByDeviceId;
    final liveDevices = [...devices]..sort((a, b) {
        int rank(String status) {
          if (status == 'online') return 0;
          if (status == 'unknown') return 1;
          return 2;
        }

        final byStatus = rank(a.status).compareTo(rank(b.status));
        if (byStatus != 0) return byStatus;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    // Para alternar entre DEMO e PROD, edite presentationMode em lib/core/app_constants.dart
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapBackground(
              key: ValueKey(
                'map-${initialTarget.latitude.toStringAsFixed(5)}-${initialTarget.longitude.toStringAsFixed(5)}-${_selectedDeviceId ?? 0}',
              ),
              child: const SizedBox.shrink(),
              markers: showNativeMapMarkers ? markers : const <Marker>{},
              circles: halos,
              initialTarget: initialTarget,
              initialZoom: 12.0,
              googleMapType: _mapType,
              trafficEnabled: _trafficEnabled,
              interactiveEnabled: _mapInteractionEnabled,
            ),
          ),
          // Badge DEMO no topo direito se presentationMode estiver ativo
          if (presentationMode)
            Positioned(
              top: 16,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'DEMO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          if (!hasPositions)
            Positioned(
              top: 16,
              left: sidebarWidth + 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Sem posições ativas no momento',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          if (isMapTab && _showManagementAlerts && managementAlerts.isNotEmpty)
            Positioned(
              top: hasPositions ? 16 : 64,
              left: sidebarWidth + 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: isWide ? 420 : 320,
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.66),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amberAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Central de Alertas (${managementAlerts.length})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Fechar central de alertas',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showManagementAlerts = false;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white24),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: managementAlerts.length > 8
                                ? 8
                                : managementAlerts.length,
                            itemBuilder: (context, index) {
                              final alert = managementAlerts[index];
                              return ListTile(
                                dense: true,
                                visualDensity: const VisualDensity(
                                  vertical: -2,
                                  horizontal: -2,
                                ),
                                leading: Icon(
                                  alert.severity.icon,
                                  color: alert.severity.color,
                                  size: 18,
                                ),
                                title: Text(
                                  alert.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  alert.message,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.5,
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: 'Focar no mapa',
                                  icon: const Icon(
                                    Icons.my_location_outlined,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedDeviceId = alert.deviceId;
                                      if (mapTabIndex >= 0) {
                                        _index = mapTabIndex;
                                      }
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (isMapTab &&
              selectedDevice != null &&
              selectedPosition != null &&
              _showDeviceHoverCard)
            Positioned(
              top: hasPositions ? 118 : 150,
              left: sidebarWidth + 18,
              child: _buildDeviceHoverPopup(
                context: context,
                device: selectedDevice,
                position: selectedPosition,
                selectedSpeedLimit: selectedSpeedLimit,
                lastUpdateSource: lastUpdateSource,
                canManageVisualConfig: canManageVisualConfig,
              ),
            ),
          if (isMapTab &&
              selectedDevice != null &&
              selectedPosition != null &&
              _showDeviceBottomBar)
            Positioned(
              left: sidebarWidth + 18,
              right: 18,
              bottom: 14,
              child: _buildDeviceBottomBar(
                context: context,
                device: selectedDevice,
                position: selectedPosition,
                selectedAddress: selectedAddress,
                selectedSpeedLimit: selectedSpeedLimit,
                selectedSpeedLimitSource: selectedSpeedLimitSource,
                selectedBatteryPercent: selectedBatteryPercent,
                hasOverspeedAlert: hasOverspeedAlert,
                canManageVisualConfig: canManageVisualConfig,
              ),
            ),
          Positioned(
            left: 12,
            top: 12,
            bottom: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: sidebarWidth,
                  decoration: BoxDecoration(
                    color: menuSurface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            _sidebarExpanded ? 8 : 0,
                            8,
                            _sidebarExpanded ? 8 : 0,
                            4,
                          ),
                          child: Row(
                            mainAxisAlignment: _sidebarExpanded
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              IconButton(
                                color: Colors.white,
                                icon: Icon(
                                  _showLiveDevicesPanel
                                      ? Icons.arrow_back
                                      : _sidebarExpanded
                                          ? Icons.menu_open
                                          : Icons.menu,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_showLiveDevicesPanel) {
                                      _showLiveDevicesPanel = false;
                                    } else {
                                      _sidebarExpanded = !_sidebarExpanded;
                                      if (!_sidebarExpanded) {
                                        _showLiveDevicesPanel = false;
                                      }
                                    }
                                  });
                                },
                              ),
                              if (_sidebarExpanded)
                                Expanded(
                                  child: Text(
                                    appName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white24),
                        Expanded(
                          child: ListView(
                            children: _showLiveDevicesPanel && _sidebarExpanded
                                ? [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        10,
                                        16,
                                        6,
                                      ),
                                      child: Text(
                                        'DISPOSITIVOS AO VIVO',
                                        style: headerStyle,
                                      ),
                                    ),
                                    if (liveDevices.isEmpty)
                                      const ListTile(
                                        title: Text(
                                          'Nenhum dispositivo disponível',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      )
                                    else
                                      for (final device in liveDevices)
                                        ListTile(
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 0,
                                          ),
                                          leading: Icon(
                                            _iconForType(
                                              _resolvedDeviceType(device),
                                            ),
                                            size: 18,
                                            color: _colorForStatus(
                                              device.status,
                                            ),
                                          ),
                                          title: Text(
                                            device.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: childItemStyle?.copyWith(
                                              color: Colors.white,
                                            ),
                                          ),
                                          subtitle: Text(
                                            positionByDeviceId[device.id] ==
                                                    null
                                                ? 'Sem posição'
                                                : 'ID ${device.id} • ${device.status}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: childItemStyle,
                                          ),
                                          selected:
                                              _selectedDeviceId == device.id,
                                          selectedColor: menuSelectedText,
                                          selectedTileColor: menuSelectedTile,
                                          onTap: () {
                                            setState(() {
                                              _selectedDeviceId = device.id;
                                              if (mapTabIndex >= 0) {
                                                _index = mapTabIndex;
                                              }
                                            });
                                          },
                                        ),
                                  ]
                                : [
                                    for (final entry in entries) ...[
                                      if (entry.isHeader)
                                        ListTile(
                                          dense: true,
                                          title: _sidebarExpanded
                                              ? Text(
                                                  entry.label.toUpperCase(),
                                                  style: headerStyle,
                                                )
                                              : null,
                                          trailing: _sidebarExpanded
                                              ? Icon(
                                                  _collapsedSections.contains(
                                                    entry.sectionKey,
                                                  )
                                                      ? Icons.expand_more
                                                      : Icons.expand_less,
                                                  size: 18,
                                                  color: Colors.white70,
                                                )
                                              : null,
                                          onTap: () {
                                            final key = entry.sectionKey;
                                            if (key == null) return;
                                            setState(() {
                                              if (_collapsedSections.contains(
                                                key,
                                              )) {
                                                _collapsedSections.remove(key);
                                              } else {
                                                _collapsedSections.add(key);
                                              }
                                            });
                                          },
                                        )
                                      else ...[
                                        if (_sidebarExpanded)
                                          ListTile(
                                            leading: Icon(
                                              entry.icon,
                                              color: Colors.white,
                                            ),
                                            title: Text(
                                              entry.label,
                                              style: entry.label.startsWith('↳')
                                                  ? childItemStyle
                                                  : itemStyle,
                                            ),
                                            selected: entry.index == _index,
                                            selectedColor: menuSelectedText,
                                            selectedTileColor: menuSelectedTile,
                                            onTap: () {
                                              final targetIndex =
                                                  entry.index ?? 0;
                                              final isDevicesEntry =
                                                  targetIndex >= 0 &&
                                                      targetIndex <
                                                          flatMenu.length &&
                                                      flatMenu[targetIndex]
                                                              .label ==
                                                          'Dispositivos';

                                              setState(() {
                                                if (isDevicesEntry) {
                                                  _showLiveDevicesPanel = true;
                                                  if (mapTabIndex >= 0) {
                                                    _index = mapTabIndex;
                                                  } else {
                                                    _index = targetIndex;
                                                  }
                                                } else {
                                                  _showLiveDevicesPanel = false;
                                                  _index = targetIndex;
                                                }
                                              });
                                            },
                                          )
                                        else
                                          Tooltip(
                                            message: entry.label,
                                            child: ListTile(
                                              leading: Icon(
                                                entry.icon,
                                                color: Colors.white,
                                              ),
                                              selected: entry.index == _index,
                                              selectedColor: menuSelectedText,
                                              selectedTileColor:
                                                  menuSelectedTile,
                                              onTap: () => setState(() {
                                                _showLiveDevicesPanel = false;
                                                _index = entry.index ?? 0;
                                              }),
                                            ),
                                          ),
                                      ],
                                    ],
                                    if (_sidebarExpanded &&
                                        liveDevices.isNotEmpty) ...[
                                      const Divider(
                                        height: 1,
                                        color: Colors.white24,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          10,
                                          16,
                                          6,
                                        ),
                                        child: Text(
                                          'DISPOSITIVOS AO VIVO',
                                          style: headerStyle,
                                        ),
                                      ),
                                      for (final device in liveDevices.take(20))
                                        ListTile(
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 0,
                                          ),
                                          leading: Icon(
                                            _iconForType(
                                              _resolvedDeviceType(device),
                                            ),
                                            size: 18,
                                            color: _colorForStatus(
                                              device.status,
                                            ),
                                          ),
                                          title: Text(
                                            device.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: childItemStyle?.copyWith(
                                              color: Colors.white,
                                            ),
                                          ),
                                          subtitle: Text(
                                            positionByDeviceId[device.id] ==
                                                    null
                                                ? 'Sem posição'
                                                : 'ID ${device.id} • ${device.status}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: childItemStyle,
                                          ),
                                          selected:
                                              _selectedDeviceId == device.id,
                                          selectedColor: menuSelectedText,
                                          selectedTileColor: menuSelectedTile,
                                          onTap: () {
                                            setState(() {
                                              _selectedDeviceId = device.id;
                                              if (mapTabIndex >= 0) {
                                                _index = mapTabIndex;
                                              }
                                            });
                                          },
                                        ),
                                    ],
                                  ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!isMapTab)
            Positioned(
              left: sidebarWidth + 24,
              top: 20,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: current.page,
                ),
              ),
            ),
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: PopupMenuButton<String>(
                        tooltip: 'Menu rápido',
                        color: menuSurface,
                        surfaceTintColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        onSelected: (value) {
                          if (value == 'refresh') {
                            ref.invalidate(devicesProvider);
                            ref.invalidate(positionsProvider);
                            return;
                          }
                          if (value == 'toggle-map') {
                            setState(() {
                              _mapInteractionEnabled = !_mapInteractionEnabled;
                            });
                            return;
                          }
                          if (value == 'map-normal') {
                            setState(() {
                              _mapType = MapType.normal;
                            });
                            return;
                          }
                          if (value == 'map-satellite') {
                            setState(() {
                              _mapType = MapType.satellite;
                            });
                            return;
                          }
                          if (value == 'traffic') {
                            setState(() {
                              _trafficEnabled = !_trafficEnabled;
                            });
                            return;
                          }
                          if (value == 'street-view') {
                            _openStreetView(context, initialTarget);
                            return;
                          }
                          if (value == 'logout') {
                            ref.read(sessionProvider.notifier).logout();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            enabled: false,
                            child: Row(
                              children: const [
                                CircleAvatar(
                                  radius: 12,
                                  child: Icon(Icons.person, size: 14),
                                ),
                                SizedBox(width: 8),
                                Text('Perfil'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem<String>(
                            value: 'refresh',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.refresh),
                              title: Text('Atualizar dados'),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'toggle-map',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                _mapInteractionEnabled
                                    ? Icons.pan_tool_alt_outlined
                                    : Icons.pan_tool_outlined,
                              ),
                              title: Text(
                                _mapInteractionEnabled
                                    ? 'Travar mapa (menu livre)'
                                    : 'Destravar mapa (mão/zoom)',
                              ),
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'map-normal',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.map_outlined),
                              title: Text('Mapa normal'),
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'map-satellite',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.satellite_alt_outlined),
                              title: Text('Mapa satélite'),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'traffic',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.traffic_outlined,
                                color:
                                    _trafficEnabled ? Colors.redAccent : null,
                              ),
                              title: Text(
                                _trafficEnabled
                                    ? 'Trânsito (desligar)'
                                    : 'Trânsito (ligar)',
                              ),
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'street-view',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.streetview_outlined),
                              title: Text('Street View'),
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem<String>(
                            value: 'logout',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.logout),
                              title: Text('Sair'),
                            ),
                          ),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (isMapTab &&
                    !_showManagementAlerts &&
                    managementAlerts.isNotEmpty)
                  const SizedBox(height: 8),
                if (isMapTab &&
                    !_showManagementAlerts &&
                    managementAlerts.isNotEmpty)
                  Tooltip(
                    message:
                        'Abrir Central de Alertas (${managementAlerts.length})',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setState(() {
                              _showManagementAlerts = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.85),
                              ),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.redAccent,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Tooltip(
                  message: 'IA operacional',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openAiAssistant(
                          context,
                          managementAlerts: managementAlerts,
                          devices: devices,
                          latestPositionByDeviceId: latestPositionByDeviceId,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.lightBlueAccent.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.lightBlueAccent,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final session = ref.read(sessionProvider);
      if (session.isAuthenticated) {
        ref.invalidate(devicesProvider);
        ref.invalidate(positionsProvider);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

class _AddressSummary {
  const _AddressSummary({required this.streetLine, this.regionLine = ''});

  final String streetLine;
  final String regionLine;
}

class _RoadSpeedSnapshot {
  const _RoadSpeedSnapshot({
    required this.limitKmh,
    required this.lat,
    required this.lon,
    required this.fetchedAt,
  });

  final double limitKmh;
  final double lat;
  final double lon;
  final DateTime fetchedAt;

  bool matches(TraccarPosition position) {
    final age = DateTime.now().difference(fetchedAt);
    if (age > const Duration(minutes: 3)) {
      return false;
    }
    final latDiff = (position.latitude - lat).abs();
    final lonDiff = (position.longitude - lon).abs();
    return latDiff < 0.001 && lonDiff < 0.001;
  }
}

enum _DeviceDetailTab { overview, photos, commands, chart, info }

class _DeviceSpeedLinePainter extends CustomPainter {
  _DeviceSpeedLinePainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }

    final gridPaint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += size.width / 6) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += size.height / 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range =
        (maxValue - minValue).abs() < 0.001 ? 1.0 : (maxValue - minValue);

    final line = Path();
    final fill = Path();
    Offset maxPoint = Offset.zero;
    var maxPointValue = -1.0;

    for (var i = 0; i < values.length; i++) {
      final x = i * size.width / (values.length - 1);
      final normalized = (values[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 16) + 8);

      if (values[i] > maxPointValue) {
        maxPointValue = values[i];
        maxPoint = Offset(x, y);
      }

      if (i == 0) {
        line.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        line.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x552C7BE5), Color(0x002C7BE5)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePaint = Paint()
      ..color = const Color(0xFF2C7BE5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawPath(fill, fillPaint);
    canvas.drawPath(line, linePaint);

    final dotPaint = Paint()..color = const Color(0xFF2C7BE5);
    canvas.drawCircle(maxPoint, 4, dotPaint);
    canvas.drawCircle(maxPoint, 7, dotPaint..color = const Color(0x442C7BE5));

    final label = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: 'Max: ${maxPointValue.toStringAsFixed(0)} km/h',
        style: const TextStyle(
          color: Color(0xFF2C7BE5),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    )..layout(maxWidth: size.width - 8);

    final labelX = (maxPoint.dx - label.width / 2).clamp(
      0.0,
      size.width - label.width,
    );
    final labelY = (maxPoint.dy - 24).clamp(0.0, size.height - label.height);
    label.paint(canvas, Offset(labelX, labelY));
  }

  @override
  bool shouldRepaint(covariant _DeviceSpeedLinePainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _MenuItem {
  _MenuItem({required this.label, required this.icon, required this.page});

  final String label;
  final IconData icon;
  final Widget page;
}

class _MenuNode {
  _MenuNode({
    required this.id,
    required this.label,
    required this.icon,
    required this.page,
    required this.featureKey,
    this.children = const [],
  });

  final String id;
  final String label;
  final IconData icon;
  final Widget page;
  final String featureKey;
  final List<_MenuNode> children;
}

class _MenuSection {
  _MenuSection({
    required this.key,
    required this.label,
    required this.children,
    required this.featureKey,
  });

  final String key;
  final String label;
  final List<_MenuNode> children;
  final String featureKey;
}

class _MenuEntry {
  _MenuEntry.header(this.label, this.sectionKey)
      : isHeader = true,
        icon = null,
        index = null;

  _MenuEntry.item({
    required this.label,
    required this.icon,
    required this.index,
    required this.sectionKey,
  }) : isHeader = false;

  final String label;
  final bool isHeader;
  final IconData? icon;
  final int? index;
  final String? sectionKey;
}

class _MenuBuild {
  _MenuBuild({required this.items, required this.entries});

  final List<_MenuItem> items;
  final List<_MenuEntry> entries;
}

_MenuBuild _buildMenu(List<_MenuSection> sections) {
  final items = <_MenuItem>[];
  final entries = <_MenuEntry>[];
  int index = 0;

  for (final section in sections) {
    entries.add(_MenuEntry.header(section.label, section.key));
    for (final node in section.children) {
      items.add(_MenuItem(label: node.label, icon: node.icon, page: node.page));
      entries.add(
        _MenuEntry.item(
          label: node.label,
          icon: node.icon,
          index: index,
          sectionKey: section.key,
        ),
      );
      index += 1;

      for (final child in node.children) {
        items.add(
          _MenuItem(label: child.label, icon: child.icon, page: child.page),
        );
        entries.add(
          _MenuEntry.item(
            label: '↳ ${child.label}',
            icon: child.icon,
            index: index,
            sectionKey: section.key,
          ),
        );
        index += 1;
      }
    }
  }

  return _MenuBuild(items: items, entries: entries);
}

List<_MenuSection> _visibleSections(
  List<_MenuSection> sections,
  TenantConfig tenant,
) {
  bool enabled(String key) {
    if (key.isEmpty) return true;
    return tenant.isFeatureEnabled(key);
  }

  final filtered = <_MenuSection>[];

  for (final section in sections) {
    if (!enabled(section.featureKey)) {
      continue;
    }

    final children = <_MenuNode>[];
    for (final node in section.children) {
      if (!enabled(node.featureKey)) {
        continue;
      }

      final visibleChildren =
          node.children.where((child) => enabled(child.featureKey)).toList();
      children.add(
        _MenuNode(
          id: node.id,
          label: node.label,
          icon: node.icon,
          page: node.page,
          featureKey: node.featureKey,
          children: visibleChildren,
        ),
      );
    }

    if (children.isNotEmpty) {
      filtered.add(
        _MenuSection(
          key: section.key,
          label: section.label,
          children: children,
          featureKey: section.featureKey,
        ),
      );
    }
  }

  return filtered;
}

enum _AlertSeverity {
  low,
  medium,
  high,
  critical;

  int get priority {
    switch (this) {
      case _AlertSeverity.low:
        return 1;
      case _AlertSeverity.medium:
        return 2;
      case _AlertSeverity.high:
        return 3;
      case _AlertSeverity.critical:
        return 4;
    }
  }

  Color get color {
    switch (this) {
      case _AlertSeverity.low:
        return Colors.lightBlueAccent;
      case _AlertSeverity.medium:
        return Colors.amberAccent;
      case _AlertSeverity.high:
        return Colors.orangeAccent;
      case _AlertSeverity.critical:
        return Colors.redAccent;
    }
  }

  IconData get icon {
    switch (this) {
      case _AlertSeverity.low:
        return Icons.info_outline;
      case _AlertSeverity.medium:
        return Icons.warning_amber_outlined;
      case _AlertSeverity.high:
        return Icons.report_problem_outlined;
      case _AlertSeverity.critical:
        return Icons.error_outline;
    }
  }
}

class _ManagementAlert {
  _ManagementAlert({
    required this.severity,
    required this.deviceId,
    required this.title,
    required this.message,
  });

  final _AlertSeverity severity;
  final int deviceId;
  final String title;
  final String message;
}

class _MarkerTypeOption {
  const _MarkerTypeOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

class _MarkerColorOption {
  const _MarkerColorOption({
    required this.key,
    required this.label,
    required this.uiColor,
    required this.hue,
  });

  final String key;
  final String label;
  final Color uiColor;
  final double hue;
}

const List<_MarkerTypeOption> _markerTypeOptions = [
  _MarkerTypeOption(
    key: 'car',
    label: 'Carro',
    icon: Icons.directions_car_filled_rounded,
  ),
  _MarkerTypeOption(key: 'bike', label: 'Bike', icon: Icons.pedal_bike_rounded),
  _MarkerTypeOption(
    key: 'phone',
    label: 'Celular',
    icon: Icons.smartphone_rounded,
  ),
  _MarkerTypeOption(
    key: 'excavator',
    label: 'Retroescavadeira',
    icon: Icons.construction_rounded,
  ),
  _MarkerTypeOption(
    key: 'boat',
    label: 'Barco',
    icon: Icons.directions_boat_filled_rounded,
  ),
  _MarkerTypeOption(
    key: 'tracker',
    label: 'Tracker',
    icon: Icons.gps_fixed_rounded,
  ),
];

const List<String> _vehicleCategoryOptions = [
  'car',
  'truck',
  'motorcycle',
  'bike',
  'boat',
  'bus',
  'van',
  'tractor',
  'excavator',
  'phone',
  'person',
  'asset',
  'other',
];

const List<_MarkerColorOption> _markerColorOptions = [
  _MarkerColorOption(
    key: 'azure',
    label: 'Azul',
    uiColor: Colors.lightBlueAccent,
    hue: BitmapDescriptor.hueAzure,
  ),
  _MarkerColorOption(
    key: 'green',
    label: 'Verde',
    uiColor: Colors.greenAccent,
    hue: BitmapDescriptor.hueGreen,
  ),
  _MarkerColorOption(
    key: 'yellow',
    label: 'Amarelo',
    uiColor: Colors.amberAccent,
    hue: BitmapDescriptor.hueYellow,
  ),
  _MarkerColorOption(
    key: 'orange',
    label: 'Laranja',
    uiColor: Colors.orangeAccent,
    hue: BitmapDescriptor.hueOrange,
  ),
  _MarkerColorOption(
    key: 'violet',
    label: 'Roxo',
    uiColor: Colors.purpleAccent,
    hue: BitmapDescriptor.hueViolet,
  ),
  _MarkerColorOption(
    key: 'cyan',
    label: 'Ciano',
    uiColor: Colors.cyanAccent,
    hue: BitmapDescriptor.hueCyan,
  ),
];

final Map<String, _MarkerColorOption> _markerColorByKey = {
  for (final option in _markerColorOptions) option.key: option,
};
