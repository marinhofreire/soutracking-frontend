import 'package:flutter_test/flutter_test.dart';
import 'package:soutracking_flutter/features/home/home_shell.dart';
import 'package:soutracking_flutter/widgets/tpms_vehicle_card.dart';

TireReading reading({
  String positionId = '11',
  double? battery = 3.29,
  int? temperature = 23,
  int? pressure = 0,
  DateTime? lastUpdate,
}) => TireReading(
  positionId: positionId,
  rawId: positionId,
  batteryVolts: battery,
  temperatureC: temperature,
  pressureRaw: pressure,
  lastUpdate: lastUpdate ?? DateTime.now(),
);

void main() {
  group('sem limites configurados', () {
    test('nunca classifica como normal mesmo com leitura boa', () {
      final r = reading(pressure: 0, temperature: 23);
      expect(tireVisualState(r, null), TireVisualState.unknown);
      expect(tireStateReason(r, null), isNull);
    });

    test('limites presentes mas sem faixa pra essa posição também fica unknown', () {
      final r = reading(positionId: '14');
      final limits = TpmsPressureLimits(byPosition: {
        '11': const TireLimitRange(pressureMin: 200, pressureMax: 300),
      });
      expect(tireVisualState(r, limits), TireVisualState.unknown);
    });
  });

  group('com limites configurados', () {
    test('pressão dentro da faixa classifica normal', () {
      final r = reading(pressure: 250, temperature: 23);
      final limits = TpmsPressureLimits(byPosition: {
        '11': const TireLimitRange(
          pressureMin: 200,
          pressureMax: 300,
          temperatureMax: 70,
        ),
      });
      expect(tireVisualState(r, limits), TireVisualState.normal);
      expect(tireStateReason(r, limits), isNull);
    });

    test('pressão abaixo do mínimo crítico gera alerta com motivo', () {
      final r = reading(pressure: 100, temperature: 23);
      final limits = TpmsPressureLimits(byPosition: {
        '11': const TireLimitRange(pressureMin: 200, pressureMax: 300),
      });
      expect(tireVisualState(r, limits), TireVisualState.alert);
      expect(tireStateReason(r, limits), 'Pressão baixa');
    });

    test('pressão na faixa de atenção (warn) não vira alerta', () {
      final r = reading(pressure: 190, temperature: 23);
      final limits = TpmsPressureLimits(byPosition: {
        '11': const TireLimitRange(
          pressureMin: 150,
          pressureMax: 350,
          pressureWarnMin: 200,
          pressureWarnMax: 300,
        ),
      });
      expect(tireVisualState(r, limits), TireVisualState.attention);
      expect(tireStateReason(r, limits), 'Pressão baixa');
    });

    test('temperatura alta soma ao motivo de pressão', () {
      final r = reading(pressure: 100, temperature: 90);
      final limits = TpmsPressureLimits(byPosition: {
        '11': const TireLimitRange(
          pressureMin: 200,
          pressureMax: 300,
          temperatureMax: 80,
        ),
      });
      expect(tireVisualState(r, limits), TireVisualState.alert);
      expect(tireStateReason(r, limits), 'Pressão baixa e Temperatura alta');
    });

    test('leitura desatualizada nunca é classificada, mesmo com limites', () {
      final stale = reading(
        pressure: 100,
        lastUpdate: DateTime.now().subtract(const Duration(hours: 2)),
      );
      final limits = TpmsPressureLimits(byPosition: {
        '11': const TireLimitRange(pressureMin: 200, pressureMax: 300),
      });
      expect(tireVisualState(stale, limits), TireVisualState.unknown);
      expect(tireStateReason(stale, limits), contains('Desatualizado'));
    });
  });

  group('pressão zero é leitura válida', () {
    test('pressão 0 não é tratada como ausência de dado', () {
      final r = reading(pressure: 0);
      expect(r.pressureRaw, 0);
      // Com limites, 0 pode ser classificado como alerta de verdade (pressão
      // baixa), nunca omitido ou tratado como "sem leitura".
      final limits = TpmsPressureLimits(byPosition: {
        '11': const TireLimitRange(pressureMin: 200, pressureMax: 300),
      });
      expect(tireVisualState(r, limits), TireVisualState.alert);
    });
  });

  group('troca de veículo não mistura leituras', () {
    test('positionId repetido entre dois readings de devices diferentes '
        'ainda carrega o lastUpdate individual de cada um', () {
      final now = DateTime.now();
      final earlier = now.subtract(const Duration(minutes: 5));
      final fromVehicleA = reading(positionId: '11', lastUpdate: earlier);
      final fromVehicleB = reading(positionId: '11', lastUpdate: now);
      expect(fromVehicleA.lastUpdate, earlier);
      expect(fromVehicleB.lastUpdate, now);
      expect(fromVehicleA.lastUpdate, isNot(fromVehicleB.lastUpdate));
    });
  });
}
