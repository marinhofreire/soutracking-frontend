import '../models/inventory_models.dart';

class InventoryApiService {
  const InventoryApiService({required this.baseUrl});

  final String baseUrl;

  Future<List<Map<String, dynamic>>> fetchInventoryEntries() async {
    // Preparado para futura entrada de rastreadores/chips via API/planilha.
    return const [];
  }

  Future<List<Map<String, dynamic>>> fetchInventoryOutputs() async {
    // Preparado para futura saida de itens para instalacao.
    return const [];
  }

  Future<List<Map<String, dynamic>>> fetchInventoryTransfers() async {
    // Preparado para transferencia entre locais de estoque.
    return const [];
  }

  Future<List<Map<String, dynamic>>> fetchOrderLinks() async {
    // Preparado para vinculo com ordem de servico.
    return const [];
  }

  Future<List<Map<String, dynamic>>> fetchVehicleLinks() async {
    // Preparado para vinculo com veiculo.
    return const [];
  }

  Future<List<Map<String, dynamic>>> fetchTechnicianLinks() async {
    // Preparado para vinculo com técnico responsavel.
    return const [];
  }

  Future<List<Map<String, dynamic>>> fetchChipControl() async {
    // Preparado para controle futuro de chips.
    return const [];
  }

  Future<InventoryKpiSummary> fetchKpiSummary() async {
    throw UnimplementedError('Integracao de estoque ainda nao implementada.');
  }
}
