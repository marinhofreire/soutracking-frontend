import '../../data/models.dart';

/// Only recorded configuration and telemetry; a protocol's default port is
/// not evidence of the listening port configured on this server.
class DeviceConnectivity {
  DeviceConnectivity.fromDevice(
    TraccarDevice device,
    List<TraccarPosition> positions,
    Map<String, String> operatorApns,
  ) {
    final attributes = device.attributes ?? const <String, dynamic>{};
    phone = _text(device.phone) ?? _text(attributes['phone']) ?? '';
    port = _text(attributes['souPort']) ?? '';
    apn = _text(attributes['souApn']) ?? '';
    protocol = _text(attributes['souProtocol']);
    final matching = positions.where((p) => p.deviceId == device.id).toList()
      ..sort((a, b) => b.fixTime.compareTo(a.fixTime));
    final current =
        matching.where((p) => p.id == device.positionId).firstOrNull ??
            matching.firstOrNull;
    protocol ??= _text(current?.protocol);
    operator = _text(attributes['souOperator']);
    if (operator != null && operatorApns.containsKey(operator!.toLowerCase())) {
      operator = operator!.toLowerCase();
    }
    // Infer the carrier only for an exact known APN; custom M2M APNs stay intact.
    operator ??= operatorApns.entries
        .where((entry) => entry.value.toLowerCase() == apn.toLowerCase())
        .firstOrNull
        ?.key;
    if (apn.isEmpty && operator != null) {
      apn = operatorApns[operator] ?? '';
    }
  }

  late final String phone;
  late final String port;
  late String apn;
  String? protocol;
  String? operator;

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
