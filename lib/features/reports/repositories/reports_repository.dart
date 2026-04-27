import '../models/report_models.dart';

abstract class ReportsRepository {
  Future<ReportKpiSummary> getKpiSummary();

  Future<List<ReportCategory>> getCategories();

  Future<List<ReportRecord>> getReports();
}
