import '../models/vehicle_models.dart';
import 'vehicles_repository.dart';

class MockVehiclesRepository implements VehiclesRepository {
  const MockVehiclesRepository();

  @override
  Future<VehicleKpiSummary> getKpiSummary() async {
    return const VehicleKpiSummary(
      total: 32,
      online: 21,
      maintenance: 6,
      noSignal: 5,
    );
  }

  @override
  Future<List<VehicleRecord>> getVehicles() async {
    final now = DateTime.now();
    return <VehicleRecord>[
      VehicleRecord(
        id: 'VEH-001',
        plate: 'ABC1D23',
        model: 'Volvo FH 540',
        driver: 'Joao Silva',
        status: VehicleStatus.online,
        ignition: IgnitionStatus.on,
        speedKmh: 68,
        lastUpdate: now.subtract(const Duration(minutes: 2)),
      ),
      VehicleRecord(
        id: 'VEH-002',
        plate: 'QWE4R56',
        model: 'Mercedes Atego 2430',
        driver: 'Paulo Costa',
        status: VehicleStatus.maintenance,
        ignition: IgnitionStatus.off,
        speedKmh: 0,
        lastUpdate: now.subtract(const Duration(minutes: 18)),
      ),
      VehicleRecord(
        id: 'VEH-003',
        plate: 'ZXC7V89',
        model: 'Scania R450',
        driver: 'Ana Martins',
        status: VehicleStatus.online,
        ignition: IgnitionStatus.on,
        speedKmh: 74,
        lastUpdate: now.subtract(const Duration(minutes: 1)),
      ),
      VehicleRecord(
        id: 'VEH-004',
        plate: 'KLM2N34',
        model: 'Iveco Tector 240E',
        driver: 'Carlos Souza',
        status: VehicleStatus.noSignal,
        ignition: IgnitionStatus.off,
        speedKmh: 0,
        lastUpdate: now.subtract(const Duration(hours: 2, minutes: 12)),
      ),
      VehicleRecord(
        id: 'VEH-005',
        plate: 'HJK5L67',
        model: 'VW Delivery 11.180',
        driver: 'Renata Lima',
        status: VehicleStatus.offline,
        ignition: IgnitionStatus.off,
        speedKmh: 0,
        lastUpdate: now.subtract(const Duration(hours: 1, minutes: 5)),
      ),
      VehicleRecord(
        id: 'VEH-006',
        plate: 'TYU8I90',
        model: 'Ford Cargo 2429',
        driver: 'Marcos Dias',
        status: VehicleStatus.online,
        ignition: IgnitionStatus.on,
        speedKmh: 52,
        lastUpdate: now.subtract(const Duration(minutes: 4)),
      ),
    ];
  }
}
