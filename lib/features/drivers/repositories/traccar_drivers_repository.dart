import '../../../data/traccar_client.dart';
import '../models/driver_models.dart';
import 'drivers_repository.dart';

/// Repositório real: le/cria motoristas via /api/drivers do Traccar
/// (TraccarClient.getDrivers/createDriver). Diferente do
/// MockDriversRepository que existia antes, aqui nenhum campo é inventado --
/// o Traccar so tem name/uniqueId/attributes por motorista, entao os campos
/// ricos que a UI espera (CNH, score, base, veiculo, status de rota) ficam
/// honestamente vazios/neutros ate existir uma fonte real pra eles (provavel
/// candidato: guardar em attributes customizados, do mesmo jeito que ja
/// fazemos com souMapIcon/whatsapp em device.attributes).
class TraccarDriversRepository implements DriversRepository {
  const TraccarDriversRepository({
    required this.client,
    this.cookie,
    this.authHeader,
  });

  final TraccarClient client;
  final String? cookie;
  final String? authHeader;

  // Parseia "dd/MM/yyyy" (formato salvo pelo date picker do dialog de
  // cadastro). Retorna null se vazio/invalido -- nunca inventa uma data.
  static DateTime? _parseBrDate(dynamic raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return null;
    final parts = text.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  static CnhState _cnhStateFor(DateTime? expiry) {
    if (expiry == null) return CnhState.unknown;
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return CnhState.expired;
    if (daysLeft <= 60) return CnhState.expiring;
    return CnhState.valid;
  }

  @override
  Future<DriverKpiSummary> getKpiSummary() async {
    final drivers = await client.getDrivers(cookie: cookie, authHeader: authHeader);
    final cnhExpiringCount = drivers.where((d) {
      final expiry = _parseBrDate(d.attributes?['cnh_expiry']);
      return _cnhStateFor(expiry) == CnhState.expiring || _cnhStateFor(expiry) == CnhState.expired;
    }).length;
    // "active" tem base real (todo motorista cadastrado conta como ativo --
    // Traccar nao tem conceito de motorista inativo). onRoute/withoutVehicle
    // dependem de vinculo motorista<->veiculo em tempo real, que ainda nao
    // existe como dado no sistema -- ficam 0, nao inventados. cnhExpiring
    // agora usa o campo real cnh_expiry, quando cadastrado.
    return DriverKpiSummary(
      active: drivers.length,
      onRoute: 0,
      withoutVehicle: 0,
      cnhExpiring: cnhExpiringCount,
    );
  }

  @override
  Future<List<DriverRecord>> getDrivers() async {
    final drivers = await client.getDrivers(cookie: cookie, authHeader: authHeader);
    final now = DateTime.now();
    return drivers.map((d) {
      final cnhExpiry = _parseBrDate(d.attributes?['cnh_expiry']);
      final earRaw = d.attributes?['ear'];
      final ear = earRaw == true || earRaw == 'true';
      return DriverRecord(
        id: d.id.toString(),
        name: d.name,
        phone: (d.attributes?['phone'] ?? '').toString(),
        cnh: (d.attributes?['cnh'] ?? '').toString(),
        cnhCategory: (d.attributes?['cnh_category'] ?? '').toString(),
        ear: ear,
        toxicologicoDate: _parseBrDate(d.attributes?['toxicologico_date']),
        vehicle: (d.attributes?['vehicle'] ?? '').toString(),
        status: DriverStatus.available,
        lastActivity: now,
        cnhExpiry: cnhExpiry,
        cnhState: _cnhStateFor(cnhExpiry),
        score: 0,
        base: (d.attributes?['base'] ?? '').toString(),
      );
    }).toList();
  }
}
