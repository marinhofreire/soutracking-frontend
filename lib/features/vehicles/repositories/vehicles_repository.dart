import '../models/vehicle_models.dart';

abstract class VehiclesRepository {
  Future<VehicleKpiSummary> getKpiSummary();

  Future<List<VehicleRecord>> getVehicles();
}
