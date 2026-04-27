import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../admin/admin_reference_ui.dart';
import 'models/client_models.dart';
import 'repositories/clients_repository.dart';
import 'repositories/mock_clients_repository.dart';
import 'services/clients_api_service.dart';
import 'widgets/clients_kpi_row.dart';
import 'widgets/clients_table.dart';

final clientsApiServiceProvider = Provider<ClientsApiService>((ref) {
  return ClientsApiService(baseUrl: kSouAssistApiBaseUrl);
});

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) {
  // Mantemos mock para esta etapa; a troca para API real fica centralizada aqui.
  ref.watch(clientsApiServiceProvider);
  return const MockClientsRepository();
});

final clientsKpiProvider = FutureProvider<ClientKpiSummary>((ref) async {
  final repository = ref.watch(clientsRepositoryProvider);
  return repository.getKpiSummary();
});

final clientsListProvider = FutureProvider<List<ClientRecord>>((ref) async {
  final repository = ref.watch(clientsRepositoryProvider);
  return repository.getClients();
});

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiAsync = ref.watch(clientsKpiProvider);
    final listAsync = ref.watch(clientsListProvider);

    return AdminReferenceScaffold(
      title: 'Clientes',
      breadcrumbs: const ['Operacao', 'Clientes'],
      selectedMenu: 'clients',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiAsync.when(
            data: (summary) => ClientsKpiRow(summary: summary),
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar indicadores: $error',
            ),
          ),
          const SizedBox(height: 12),
          listAsync.when(
            data: (records) => ClientsTable(records: records),
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar clientes: $error',
            ),
          ),
        ],
      ),
    );
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
