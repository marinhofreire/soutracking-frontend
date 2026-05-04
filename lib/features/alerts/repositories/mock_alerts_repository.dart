import '../models/alert_models.dart';
import 'alerts_repository.dart';

class MockAlertsRepository implements AlertsRepository {
  const MockAlertsRepository();

  @override
  Future<AlertKpiSummary> getKpiSummary() async {
    return const AlertKpiSummary(
      today: 18,
      critical: 5,
      inAnalysis: 7,
      resolved: 6,
    );
  }

  @override
  Future<List<AlertRecord>> getAlerts() async {
    final now = DateTime.now();
    return <AlertRecord>[
      AlertRecord(
        id: 'ALT-001',
        severity: AlertSeverity.critical,
        type: 'Violacao de cerca',
        vehicle: 'ABC1D23',
        description: 'Entrada em area proibida',
        dateTime: now.subtract(const Duration(minutes: 9)),
        status: AlertStatus.newAlert,
      ),
      AlertRecord(
        id: 'ALT-002',
        severity: AlertSeverity.high,
        type: 'Excesso de velocidade',
        vehicle: 'ZXC7V89',
        description: 'Velocidade acima do limite configurado',
        dateTime: now.subtract(const Duration(minutes: 22)),
        status: AlertStatus.inAnalysis,
      ),
      AlertRecord(
        id: 'ALT-003',
        severity: AlertSeverity.medium,
        type: 'Ignicao ligada parada',
        vehicle: 'TYU8I90',
        description: 'Motor ligado sem deslocamento',
        dateTime: now.subtract(const Duration(hours: 1, minutes: 4)),
        status: AlertStatus.inAnalysis,
      ),
      AlertRecord(
        id: 'ALT-004',
        severity: AlertSeverity.low,
        type: 'Perda de sinal',
        vehicle: 'KLM2N34',
        description: 'Dispositivo sem comunicacao recente',
        dateTime: now.subtract(const Duration(hours: 2, minutes: 31)),
        status: AlertStatus.newAlert,
      ),
      AlertRecord(
        id: 'ALT-005',
        severity: AlertSeverity.critical,
        type: 'Botao de panico',
        vehicle: 'QWE4R56',
        description: 'Sinal de emergencia acionado',
        dateTime: now.subtract(const Duration(hours: 3, minutes: 15)),
        status: AlertStatus.resolved,
      ),
      AlertRecord(
        id: 'ALT-006',
        severity: AlertSeverity.high,
        type: 'Desconexao bateria',
        vehicle: 'HJK5L67',
        description: 'Fonte de energia desconectada',
        dateTime: now.subtract(const Duration(hours: 5, minutes: 8)),
        status: AlertStatus.resolved,
      ),
      AlertRecord(
        id: 'ALT-007',
        severity: AlertSeverity.medium,
        type: 'Movimento fora do expediente',
        vehicle: 'ABC1D23',
        description: 'Deslocamento fora da janela operacional',
        dateTime: now.subtract(const Duration(hours: 9, minutes: 42)),
        status: AlertStatus.inAnalysis,
      ),
      AlertRecord(
        id: 'ALT-008',
        severity: AlertSeverity.low,
        type: 'Manutencao preventiva',
        vehicle: 'TYU8I90',
        description: 'Lembrete de manutencao preventiva',
        dateTime: now.subtract(const Duration(days: 2, hours: 1)),
        status: AlertStatus.resolved,
      ),
    ];
  }
}
