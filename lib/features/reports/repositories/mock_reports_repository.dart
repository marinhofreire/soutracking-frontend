import '../models/report_models.dart';
import 'reports_repository.dart';

class MockReportsRepository implements ReportsRepository {
  const MockReportsRepository();

  @override
  Future<ReportKpiSummary> getKpiSummary() async {
    return const ReportKpiSummary(
      generated: 48,
      scheduled: 9,
      exports: 31,
      criticalAlerts: 5,
    );
  }

  @override
  Future<List<ReportCategory>> getCategories() async {
    return const [
      ReportCategory(
        type: ReportType.trips,
        description: 'Deslocamentos e tempos por veiculo',
        generatedCount: 12,
      ),
      ReportCategory(
        type: ReportType.routes,
        description: 'Percursos com pontos e desvios',
        generatedCount: 8,
      ),
      ReportCategory(
        type: ReportType.events,
        description: 'Eventos operacionais e telemetria',
        generatedCount: 14,
      ),
      ReportCategory(
        type: ReportType.stops,
        description: 'Paradas e duracao por local',
        generatedCount: 6,
      ),
      ReportCategory(
        type: ReportType.distance,
        description: 'KM rodados por periodo',
        generatedCount: 11,
      ),
      ReportCategory(
        type: ReportType.speed,
        description: 'Faixas de velocidade e excessos',
        generatedCount: 10,
      ),
      ReportCategory(
        type: ReportType.alerts,
        description: 'Alertas por severidade e status',
        generatedCount: 7,
      ),
      ReportCategory(
        type: ReportType.drivers,
        description: 'Desempenho e score de motoristas',
        generatedCount: 5,
      ),
      ReportCategory(
        type: ReportType.vehicles,
        description: 'Consolidado de frota e disponibilidade',
        generatedCount: 9,
      ),
    ];
  }

  @override
  Future<List<ReportRecord>> getReports() async {
    final now = DateTime.now();
    return [
      ReportRecord(
        name: 'Resumo executivo da frota',
        type: ReportType.vehicles,
        vehicle: 'Todos',
        driver: 'Todos',
        period: '01/04 - 27/04',
        status: ReportStatus.ready,
        createdAt: now.subtract(const Duration(hours: 2, minutes: 15)),
        format: ReportFormat.pdf,
        totalRecords: 128,
      ),
      ReportRecord(
        name: 'Viagens por motorista',
        type: ReportType.trips,
        vehicle: 'ABC1D23',
        driver: 'Joao Silva',
        period: '20/04 - 27/04',
        status: ReportStatus.processing,
        createdAt: now.subtract(const Duration(minutes: 42)),
        format: ReportFormat.screen,
        totalRecords: 42,
      ),
      ReportRecord(
        name: 'Eventos de ignicao e cerca',
        type: ReportType.events,
        vehicle: 'ZXC7V89',
        driver: 'Ana Martins',
        period: '24/04 - 27/04',
        status: ReportStatus.ready,
        createdAt: now.subtract(const Duration(hours: 7, minutes: 8)),
        format: ReportFormat.excel,
        totalRecords: 76,
      ),
      ReportRecord(
        name: 'Paradas acima de 20 min',
        type: ReportType.stops,
        vehicle: 'QWE4R56',
        driver: 'Paulo Costa',
        period: '27/04',
        status: ReportStatus.failed,
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        format: ReportFormat.pdf,
        totalRecords: 19,
      ),
      ReportRecord(
        name: 'Rotas e desvios de corredor',
        type: ReportType.routes,
        vehicle: 'TYU8I90',
        driver: 'Marcos Dias',
        period: '15/04 - 27/04',
        status: ReportStatus.scheduled,
        createdAt: now.subtract(const Duration(hours: 12)),
        format: ReportFormat.screen,
        totalRecords: 64,
      ),
      ReportRecord(
        name: 'Velocidade media e picos',
        type: ReportType.speed,
        vehicle: 'KLM2N34',
        driver: 'Carlos Souza',
        period: '01/04 - 27/04',
        status: ReportStatus.ready,
        createdAt: now.subtract(const Duration(days: 2, hours: 5)),
        format: ReportFormat.excel,
        totalRecords: 88,
      ),
      ReportRecord(
        name: 'Alertas criticos semanais',
        type: ReportType.alerts,
        vehicle: 'Todos',
        driver: 'Todos',
        period: '21/04 - 27/04',
        status: ReportStatus.scheduled,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 5)),
        format: ReportFormat.pdf,
        totalRecords: 23,
      ),
    ];
  }
}
