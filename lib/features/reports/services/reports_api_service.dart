import '../models/report_models.dart';

class ReportsApiService {
  const ReportsApiService({required this.baseUrl});

  final String baseUrl;

  Future<List<Map<String, dynamic>>> fetchTraccarReport({
    required ReportType type,
    required DateTime from,
    required DateTime to,
    int? deviceId,
    int? driverId,
  }) async {
    // Estrutura pronta para integrar chamadas HTTP do Traccar futuramente.
    return <Map<String, dynamic>>[];
  }
}
