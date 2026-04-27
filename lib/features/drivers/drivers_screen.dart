import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../admin/admin_reference_ui.dart';
import 'models/driver_models.dart';
import 'repositories/drivers_repository.dart';
import 'repositories/mock_drivers_repository.dart';
import 'services/drivers_api_service.dart';
import 'widgets/drivers_filters_bar.dart';
import 'widgets/drivers_kpi_row.dart';
import 'widgets/drivers_table.dart';

final driversApiServiceProvider = Provider<DriversApiService>((ref) {
  return DriversApiService(baseUrl: kSouAssistApiBaseUrl);
});

final driversRepositoryProvider = Provider<DriversRepository>((ref) {
  // Mantemos mock nesta etapa; swap para API real fica centralizado aqui.
  ref.watch(driversApiServiceProvider);
  return const MockDriversRepository();
});

final driversKpiProvider = FutureProvider<DriverKpiSummary>((ref) async {
  final repository = ref.watch(driversRepositoryProvider);
  return repository.getKpiSummary();
});

final driversListProvider = FutureProvider<List<DriverRecord>>((ref) async {
  final repository = ref.watch(driversRepositoryProvider);
  return repository.getDrivers();
});

class DriversScreen extends ConsumerStatefulWidget {
  const DriversScreen({super.key});

  @override
  ConsumerState<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends ConsumerState<DriversScreen> {
  final _searchController = TextEditingController();

  String _search = '';
  String _status = 'Todos';
  String _vehicle = 'Todos';
  String _cnh = 'Todas';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kpiAsync = ref.watch(driversKpiProvider);
    final listAsync = ref.watch(driversListProvider);

    return AdminReferenceScaffold(
      title: 'Motoristas',
      breadcrumbs: const ['Operacao', 'Motoristas'],
      selectedMenu: 'drivers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiAsync.when(
            data: (summary) => DriversKpiRow(summary: summary),
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar indicadores: $error',
            ),
          ),
          const SizedBox(height: 12),
          listAsync.when(
            data: (records) {
              final statusOptions = <String>{
                'Todos',
                ...records.map((item) => item.status.label),
              }.toList();
              final vehicleOptions = <String>{
                'Todos',
                ...records.map((item) => item.vehicle),
              }.toList();
              final cnhOptions = <String>{
                'Todas',
                ...records.map((item) => item.cnhState.label),
              }.toList();

              final filtered = _applyFilters(records);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DriversFiltersBar(
                    searchController: _searchController,
                    status: _status,
                    vehicle: _vehicle,
                    cnh: _cnh,
                    statusOptions: statusOptions,
                    vehicleOptions: vehicleOptions,
                    cnhOptions: cnhOptions,
                    onSearchChanged: (value) => setState(() => _search = value),
                    onStatusChanged: (value) => setState(() => _status = value),
                    onVehicleChanged: (value) =>
                        setState(() => _vehicle = value),
                    onCnhChanged: (value) => setState(() => _cnh = value),
                    onMoreFilters: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Mais filtros sera habilitado na proxima etapa.'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  DriversTable(records: filtered),
                ],
              );
            },
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar motoristas: $error',
            ),
          ),
        ],
      ),
    );
  }

  List<DriverRecord> _applyFilters(List<DriverRecord> records) {
    final query = _search.trim().toLowerCase();

    return records.where((record) {
      if (query.isNotEmpty) {
        final matchesQuery = record.name.toLowerCase().contains(query) ||
            record.phone.toLowerCase().contains(query) ||
            record.cnh.toLowerCase().contains(query);
        if (!matchesQuery) return false;
      }

      if (_status != 'Todos' && record.status.label != _status) return false;
      if (_vehicle != 'Todos' && record.vehicle != _vehicle) return false;
      if (_cnh != 'Todas' && record.cnhState.label != _cnh) return false;

      return true;
    }).toList();
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const AdminGlassPanel(
      child: SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: SizedBox(
        height: 120,
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFDDE5F0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
