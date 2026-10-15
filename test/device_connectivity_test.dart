import 'package:flutter_test/flutter_test.dart';
import 'package:soutracking_flutter/data/models.dart';
import 'package:soutracking_flutter/features/devices/device_connectivity.dart';

const apns = {
  'vivo': 'zap.vivo.com.br',
  'claro': 'claro.com.br',
  'tim': 'tim.br'
};
TraccarDevice device(Map<String, dynamic> values) => TraccarDevice.fromJson({
      'id': 1,
      'name': 'Carro',
      'status': 'online',
      ...values,
    });
TraccarPosition position(int id, int deviceId, String protocol) =>
    TraccarPosition.fromJson({
      'id': id,
      'deviceId': deviceId,
      'protocol': protocol,
      'latitude': 0,
      'longitude': 0,
      'fixTime': '2026-10-14T10:00:00Z',
    });

void main() {
  test('Native phone and the selected device protocol are retained', () {
    final result = DeviceConnectivity.fromDevice(
        device({'phone': '11999999999', 'positionId': 20}),
        [position(10, 2, 'gt06'), position(20, 1, 'h02')],
        apns);
    expect(result.phone, '11999999999');
    expect(result.protocol, 'h02');
    expect(result.port, isEmpty); // Never guess a configured server port.
  });
  test('Saved port, protocol and custom APN are preserved', () {
    final result = DeviceConnectivity.fromDevice(
        device({
          'phone': '11999999999',
          'attributes': {
            'phone': 'legacy',
            'souProtocol': 'gt06',
            'souPort': '6200',
            'souOperator': 'Vivo',
            'souApn': 'custom.m2m'
          },
        }),
        [position(20, 1, 'h02')],
        apns);
    expect(result.phone, '11999999999');
    expect(result.protocol, 'gt06');
    expect(result.port, '6200');
    expect(result.operator, 'vivo');
    expect(result.apn, 'custom.m2m');
  });
  test('Legacy phone and known carrier APN are loaded', () {
    final result = DeviceConnectivity.fromDevice(
        device({
          'attributes': {'phone': '11988888888', 'souOperator': 'tim'},
        }),
        [],
        apns);
    expect(result.phone, '11988888888');
    expect(result.apn, 'tim.br');
  });
  test('Carrier inference requires an exact known APN', () {
    expect(
        DeviceConnectivity.fromDevice(
                device({
                  'attributes': {'souApn': 'claro.com.br'},
                }),
                [],
                apns)
            .operator,
        'claro');
    expect(
        DeviceConnectivity.fromDevice(
                device({
                  'attributes': {'souApn': 'custom.m2m'},
                }),
                [],
                apns)
            .operator,
        isNull);
  });
}
