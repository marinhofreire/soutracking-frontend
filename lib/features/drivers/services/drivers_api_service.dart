import '../models/driver_models.dart';

class DriversApiService {
  const DriversApiService({required this.baseUrl});

  final String baseUrl;

  Future<DriverKpiSummary> fetchKpiSummary() async {
    throw UnimplementedError(
      'Integracao API de motoristas ainda nao habilitada.',
    );
  }

  Future<List<DriverRecord>> fetchDrivers() async {
    throw UnimplementedError(
      'Integracao API de motoristas ainda nao habilitada.',
    );
  }
}
