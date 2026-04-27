import '../models/call_models.dart';

abstract class CallsRepository {
  Future<CallKpiSummary> getKpiSummary();

  Future<List<CallTicket>> getTickets();
}
