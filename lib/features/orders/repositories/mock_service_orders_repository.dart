import '../models/service_order_models.dart';
import 'service_orders_repository.dart';

class MockServiceOrdersRepository implements ServiceOrdersRepository {
  const MockServiceOrdersRepository();

  @override
  Future<ServiceOrderKpiSummary> getKpiSummary() async {
    return const ServiceOrderKpiSummary(
      open: 18,
      inProgress: 9,
      completed: 41,
      overdue: 4,
    );
  }

  @override
  Future<List<ServiceOrderRecord>> getOrders() async {
    final now = DateTime.now();
    return [
      ServiceOrderRecord(
        id: 'OS-2026-1041',
        client: 'Transportes Alfa',
        vehicle: 'ABC1D23',
        serviceType: ServiceType.trackerInstall,
        technician: 'Marcio Lima',
        status: ServiceOrderStatus.inProgress,
        priority: ServiceOrderPriority.high,
        createdAt: now.subtract(const Duration(hours: 5, minutes: 10)),
        scheduledAt: now.add(const Duration(hours: 1, minutes: 30)),
      ),
      ServiceOrderRecord(
        id: 'OS-2026-1040',
        client: 'Varejo Sul',
        vehicle: 'QWE4R56',
        serviceType: ServiceType.chipReplacement,
        technician: 'Paulo Costa',
        status: ServiceOrderStatus.waitingPart,
        priority: ServiceOrderPriority.medium,
        createdAt: now.subtract(const Duration(days: 1, hours: 1)),
        scheduledAt: now.add(const Duration(hours: 5)),
      ),
      ServiceOrderRecord(
        id: 'OS-2026-1039',
        client: 'Construtora Gama',
        vehicle: 'ZXC7V89',
        serviceType: ServiceType.electricalDiagnostics,
        technician: 'Renata Melo',
        status: ServiceOrderStatus.overdue,
        priority: ServiceOrderPriority.critical,
        createdAt: now.subtract(const Duration(days: 2, hours: 3)),
        scheduledAt: now.subtract(const Duration(hours: 7)),
      ),
      ServiceOrderRecord(
        id: 'OS-2026-1038',
        client: 'Grupo Omega',
        vehicle: 'KLM2N34',
        serviceType: ServiceType.preventiveMaintenance,
        technician: 'Ana Souza',
        status: ServiceOrderStatus.scheduled,
        priority: ServiceOrderPriority.low,
        createdAt: now.subtract(const Duration(hours: 14)),
        scheduledAt: now.add(const Duration(days: 1, hours: 2)),
      ),
      ServiceOrderRecord(
        id: 'OS-2026-1037',
        client: 'Transportes Alfa',
        vehicle: 'TYU8I90',
        serviceType: ServiceType.fieldSupport,
        technician: 'Marcio Lima',
        status: ServiceOrderStatus.waitingCustomer,
        priority: ServiceOrderPriority.high,
        createdAt: now.subtract(const Duration(hours: 10, minutes: 22)),
        scheduledAt: now.add(const Duration(hours: 3, minutes: 40)),
      ),
      ServiceOrderRecord(
        id: 'OS-2026-1036',
        client: 'Varejo Sul',
        vehicle: 'HJK5L67',
        serviceType: ServiceType.inspection,
        technician: 'Paulo Costa',
        status: ServiceOrderStatus.completed,
        priority: ServiceOrderPriority.medium,
        createdAt: now.subtract(const Duration(days: 3, hours: 2)),
        scheduledAt: now.subtract(const Duration(days: 2, hours: 5)),
      ),
      ServiceOrderRecord(
        id: 'OS-2026-1035',
        client: 'Construtora Gama',
        vehicle: 'MNO3P45',
        serviceType: ServiceType.trackerRemoval,
        technician: 'Renata Melo',
        status: ServiceOrderStatus.canceled,
        priority: ServiceOrderPriority.low,
        createdAt: now.subtract(const Duration(days: 4, hours: 4)),
        scheduledAt: now.subtract(const Duration(days: 3, hours: 2)),
      ),
      ServiceOrderRecord(
        id: 'OS-2026-1034',
        client: 'Grupo Omega',
        vehicle: 'RST6U78',
        serviceType: ServiceType.powerReview,
        technician: 'Ana Souza',
        status: ServiceOrderStatus.open,
        priority: ServiceOrderPriority.high,
        createdAt: now.subtract(const Duration(hours: 2, minutes: 40)),
        scheduledAt: now.add(const Duration(hours: 8, minutes: 20)),
      ),
    ];
  }
}
