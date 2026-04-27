import '../models/alert_models.dart';

class AlertsApiService {
  const AlertsApiService({required this.baseUrl});

  final String baseUrl;

  Future<AlertKpiSummary> fetchKpiSummary() async {
    throw UnimplementedError('Integracao API de alertas ainda nao habilitada.');
  }

  Future<List<AlertRecord>> fetchAlerts() async {
    throw UnimplementedError('Integracao API de alertas ainda nao habilitada.');
  }
}
