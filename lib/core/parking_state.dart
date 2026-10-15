/// Trava de estacionamento -- decide se o marcador/posicao do veiculo deve
/// "congelar" (ignorar ruido de GPS) ou continuar acompanhando o movimento.
///
/// Regra definida pelo usuario (2026-10-15), mais especifica que threshold
/// generico de distancia:
/// - Ignicao FISICA desligada (attributes['ignition'] == false vindo do fio
///   real do equipamento): trava na hora. So "data/hora da ultima
///   comunicacao" continua atualizando via keep-alive/heartbeat
///   (tipicamente a cada ~1h), a posicao nao se move.
/// - Sem ignicao fisica (equipamento so manda posicao/velocidade, sem fio de
///   ACC): ignicao "virtual" -- considera estacionado so apos 5 minutos
///   continuos com velocidade ~0. Esse limiar evita falso-positivo de
///   congestionamento parado (gira em ~5min na maioria dos casos reais),
///   sem deixar o carro "rabiscando" por muito tempo apos estacionar de
///   verdade.
library;

import '../data/models.dart' show TraccarPosition;

const Duration kVirtualIgnitionStopThreshold = Duration(minutes: 5);
const double kStoppedSpeedThresholdKnots = 1.0; // ~1.85 km/h, folga de ruido

/// true = ignicao fisica real está presente nos atributos da posicao
/// (equipamento tem o fio de ACC conectado e manda o dado).
bool hasPhysicalIgnitionData(TraccarPosition? position) {
  final attrs = position?.attributes;
  return attrs != null && attrs.containsKey('ignition');
}

/// true = ignicao fisica ligada (só valido quando hasPhysicalIgnitionData).
bool isPhysicalIgnitionOn(TraccarPosition? position) {
  final attrs = position?.attributes;
  final raw = attrs?['ignition'];
  return raw == true || raw == 'true' || raw == 1 || raw == '1';
}

/// Decide se a posicao deve ficar travada (nao anima/nao soma km), dado o
/// histórico recente de posicoes do mesmo device (mais recente primeiro).
bool isParked(List<TraccarPosition> recentPositionsNewestFirst) {
  if (recentPositionsNewestFirst.isEmpty) return false;
  final latest = recentPositionsNewestFirst.first;

  if (hasPhysicalIgnitionData(latest)) {
    return !isPhysicalIgnitionOn(latest);
  }

  // Ignicao virtual: precisa de N minutos continuos com velocidade ~0.
  final now = DateTime.tryParse(latest.fixTime);
  if (now == null) return false;
  final cutoff = now.subtract(kVirtualIgnitionStopThreshold);

  for (final p in recentPositionsNewestFirst) {
    final speed = p.speed ?? 0;
    if (speed > kStoppedSpeedThresholdKnots) return false;
    final fixTime = DateTime.tryParse(p.fixTime);
    if (fixTime == null) continue;
    if (fixTime.isBefore(cutoff)) {
      // Teve pelo menos kVirtualIgnitionStopThreshold de posicoes paradas.
      return true;
    }
  }
  // Ainda nao acumulou o tempo minimo parado -- nao trava ainda.
  return false;
}
