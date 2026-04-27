import '../models/finance_models.dart';

abstract class FinanceRepository {
  Future<FinanceKpiSummary> getKpiSummary();

  Future<List<FinanceSummaryCard>> getSummaryCards();

  Future<List<FinanceChargeRecord>> getCharges();
}
