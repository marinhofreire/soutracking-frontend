import '../models/driver_models.dart';
import 'drivers_repository.dart';

class MockDriversRepository implements DriversRepository {
  const MockDriversRepository();

  @override
  Future<DriverKpiSummary> getKpiSummary() async {
    return const DriverKpiSummary(
      active: 23,
      onRoute: 11,
      withoutVehicle: 4,
      cnhExpiring: 3,
    );
  }

  @override
  Future<List<DriverRecord>> getDrivers() async {
    final now = DateTime.now();
    return <DriverRecord>[
      DriverRecord(
        id: 'DRV-001',
        name: 'Joao Silva',
        phone: '(11) 98888-1001',
        cnh: 'SP-12345678900',
        cnhCategory: 'B',
        ear: false,
        toxicologicoDate: null,
        vehicle: 'ABC1D23',
        status: DriverStatus.onRoute,
        lastActivity: now.subtract(const Duration(minutes: 3)),
        cnhExpiry: now.add(const Duration(days: 210)),
        cnhState: CnhState.valid,
        score: 94,
        base: 'Sao Paulo - Centro',
      ),
      DriverRecord(
        id: 'DRV-002',
        name: 'Ana Martins',
        phone: '(19) 97777-2233',
        cnh: 'SP-55667788990',
        cnhCategory: 'AB',
        ear: true,
        toxicologicoDate: now.subtract(const Duration(days: 200)),
        vehicle: 'ZXC7V89',
        status: DriverStatus.onRoute,
        lastActivity: now.subtract(const Duration(minutes: 1)),
        cnhExpiry: now.add(const Duration(days: 47)),
        cnhState: CnhState.expiring,
        score: 91,
        base: 'Campinas - Norte',
      ),
      DriverRecord(
        id: 'DRV-003',
        name: 'Paulo Costa',
        phone: '(11) 96666-3344',
        cnh: 'SP-99887766550',
        cnhCategory: 'D',
        ear: true,
        toxicologicoDate: now.subtract(const Duration(days: 700)),
        vehicle: 'QWE4R56',
        status: DriverStatus.available,
        lastActivity: now.subtract(const Duration(minutes: 18)),
        cnhExpiry: now.add(const Duration(days: 13)),
        cnhState: CnhState.expiring,
        score: 88,
        base: 'Guarulhos - Base Leste',
      ),
      DriverRecord(
        id: 'DRV-004',
        name: 'Renata Lima',
        phone: '(11) 95555-8899',
        cnh: 'SP-10293847560',
        cnhCategory: 'B',
        ear: false,
        toxicologicoDate: null,
        vehicle: '-',
        status: DriverStatus.withoutVehicle,
        lastActivity: now.subtract(const Duration(hours: 2, minutes: 11)),
        cnhExpiry: now.add(const Duration(days: 330)),
        cnhState: CnhState.valid,
        score: 84,
        base: 'Santo Andre - Patio',
      ),
      DriverRecord(
        id: 'DRV-005',
        name: 'Carlos Souza',
        phone: '(11) 94444-5566',
        cnh: 'SP-66778899001',
        cnhCategory: 'C',
        ear: true,
        toxicologicoDate: now.subtract(const Duration(days: 950)),
        vehicle: 'KLM2N34',
        status: DriverStatus.inactive,
        lastActivity: now.subtract(const Duration(days: 1, hours: 3)),
        cnhExpiry: now.subtract(const Duration(days: 8)),
        cnhState: CnhState.expired,
        score: 72,
        base: 'Jundiai - Oeste',
      ),
      DriverRecord(
        id: 'DRV-006',
        name: 'Marcos Dias',
        phone: '(11) 93333-7788',
        cnh: 'SP-44556677880',
        cnhCategory: 'B',
        ear: false,
        toxicologicoDate: null,
        vehicle: 'TYU8I90',
        status: DriverStatus.available,
        lastActivity: now.subtract(const Duration(minutes: 25)),
        cnhExpiry: now.add(const Duration(days: 540)),
        cnhState: CnhState.valid,
        score: 89,
        base: 'Osasco - Base Sul',
      ),
    ];
  }
}
