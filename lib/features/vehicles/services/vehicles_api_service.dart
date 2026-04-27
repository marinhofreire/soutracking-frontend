import '../models/vehicle_models.dart';

class VehiclesApiService {
  const VehiclesApiService({required this.baseUrl});

  final String baseUrl;

  Future<VehicleKpiSummary> fetchKpiSummary() async {
    throw UnimplementedError(
        'Integracao API de veiculos ainda nao habilitada.');
  }

  Future<List<VehicleRecord>> fetchVehicles() async {
    throw UnimplementedError(
        'Integracao API de veiculos ainda nao habilitada.');
  }
}
