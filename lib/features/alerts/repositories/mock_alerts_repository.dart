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
        driver: 'Joao Silva',
        location: 'Av. Paulista, SP',
        dateTime: now.subtract(const Duration(minutes: 9)),
        status: AlertStatus.newAlert,
      ),
      AlertRecord(
        id: 'ALT-002',
        severity: AlertSeverity.high,
        type: 'Excesso de velocidade',
        vehicle: 'ZXC7V89',
        driver: 'Ana Martins',
        location: 'BR-116, Km 228',
        dateTime: now.subtract(const Duration(minutes: 22)),
        status: AlertStatus.inAnalysis,
      ),
      AlertRecord(
        id: 'ALT-003',
        severity: AlertSeverity.medium,
        type: 'Ignicao ligada parada',
        vehicle: 'TYU8I90',
        driver: 'Marcos Dias',
        location: 'Campinas, SP',
        dateTime: now.subtract(const Duration(hours: 1, minutes: 4)),
        status: AlertStatus.inAnalysis,
      ),
      AlertRecord(
        id: 'ALT-004',
        severity: AlertSeverity.low,
        type: 'Perda de sinal',
        vehicle: 'KLM2N34',
        driver: 'Carlos Souza',
        location: 'Jundiai, SP',
        dateTime: now.subtract(const Duration(hours: 2, minutes: 31)),
        status: AlertStatus.newAlert,
      ),
      AlertRecord(
        id: 'ALT-005',
        severity: AlertSeverity.critical,
        type: 'Botao de panico',
        vehicle: 'QWE4R56',
        driver: 'Paulo Costa',
        location: 'Marginal Tiete, SP',
        dateTime: now.subtract(const Duration(hours: 3, minutes: 15)),
        status: AlertStatus.resolved,
      ),
      AlertRecord(
        id: 'ALT-006',
        severity: AlertSeverity.high,
        type: 'Desconexao bateria',
        vehicle: 'HJK5L67',
        driver: 'Renata Lima',
        location: 'Santo Andre, SP',
        dateTime: now.subtract(const Duration(hours: 5, minutes: 8)),
        status: AlertStatus.resolved,
      ),
      AlertRecord(
        id: 'ALT-007',
        severity: AlertSeverity.medium,
        type: 'Movimento fora do expediente',
        vehicle: 'ABC1D23',
        driver: 'Joao Silva',
        location: 'Guarulhos, SP',
        dateTime: now.subtract(const Duration(hours: 9, minutes: 42)),
        status: AlertStatus.inAnalysis,
      ),
      AlertRecord(
        id: 'ALT-008',
        severity: AlertSeverity.low,
        type: 'Manutencao preventiva',
        vehicle: 'TYU8I90',
        driver: 'Marcos Dias',
        location: 'Osasco, SP',
        dateTime: now.subtract(const Duration(days: 2, hours: 1)),
        status: AlertStatus.resolved,
      ),
    ];
  }
}
