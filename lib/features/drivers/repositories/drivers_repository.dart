import '../models/driver_models.dart';

abstract class DriversRepository {
  Future<DriverKpiSummary> getKpiSummary();

  Future<List<DriverRecord>> getDrivers();
}
