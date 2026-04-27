import '../models/alert_models.dart';

abstract class AlertsRepository {
  Future<AlertKpiSummary> getKpiSummary();

  Future<List<AlertRecord>> getAlerts();
}
