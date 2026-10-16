import 'package:flutter_test/flutter_test.dart';
import 'package:soutracking_flutter/features/home/home_shell.dart';
import 'package:soutracking_flutter/widgets/tpms_vehicle_card.dart';

void main() {
  test('unit must be explicit and match raw decoder before comparing limits',
      () {
    expect(tpmsLimitsFromAttributes(null), isNull);
    expect(
        tpmsLimitsFromAttributes({
          'souTpmsLimits': {
            'unit': 'psi',
            'byPosition': {
              '11': {'pressureMin': 30}
            }
          }
        }),
        isNull);
  });
  test('per-vehicle raw limits classify received zero as a low pressure alert',
      () {
    final limits = tpmsLimitsFromAttributes({
      'souTpmsLimits': {
        'unit': 'raw',
        'byPosition': {
          '11': {'pressureMin': 200}
        }
      }
    });
    final reading = TireReading(
        positionId: '11',
        rawId: '11',
        batteryVolts: 3.2,
        temperatureC: 24,
        pressureRaw: 0,
        lastUpdate: DateTime.now());
    expect(limits, isNotNull);
    expect(tireVisualState(reading, limits), TireVisualState.alert);
    expect(tireStateReason(reading, limits), 'Pressão baixa');
  });
  test('missing measurement is not classified normal by unrelated limits', () {
    final limits = tpmsLimitsFromAttributes({
      'souTpmsLimits': {
        'unit': 'raw',
        'byPosition': {
          '11': {'temperatureMax': 80}
        }
      }
    });
    final reading = TireReading(
        positionId: '11',
        rawId: '11',
        batteryVolts: 3.2,
        temperatureC: null,
        pressureRaw: 0,
        lastUpdate: DateTime.now());
    expect(tireVisualState(reading, limits), TireVisualState.unknown);
  });
  test('empty or invalid ranges do not produce healthy classifications', () {
    expect(
        tpmsLimitsFromAttributes({
          'souTpmsLimits': {
            'unit': 'raw',
            'byPosition': {
              '11': {'pressureMin': 'invalid'}
            }
          }
        }),
        isNull);
  });
}
