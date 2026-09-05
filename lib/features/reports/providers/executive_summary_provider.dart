import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models.dart';
import '../../../state/session_state.dart';
import '../models/report_models.dart';

/// Parâmetros do "Resumo executivo": período selecionado + veículo (null =
/// frota inteira). O período anterior é calculado automaticamente com a
/// mesma duração, deslocado pra trás -- é o que dá o comparativo "+12% vs
/// período anterior" que aparece nos KPIs.
class ExecutiveSummaryQuery {
  const ExecutiveSummaryQuery({
    required this.from,
    required this.to,
    this.deviceId,
  });

  final DateTime from;
  final DateTime to;
  final int? deviceId;

  @override
  bool operator ==(Object other) {
    return other is ExecutiveSummaryQuery &&
        other.from == from &&
        other.to == to &&
        other.deviceId == deviceId;
  }

  @override
  int get hashCode => Object.hash(from, to, deviceId);
}

/// Lista de critical alert types reaproveitada do mesmo critério já usado
/// no replay de rotas (`_isReplayAlertType` em reports_screen.dart) -- não
/// inventamos uma nova definição de "alerta" pro resumo executivo.
bool _isRelevantAlertType(String type, String alarm) {
  final normalized = '${type.trim()} ${alarm.trim()}'.toLowerCase();
  return normalized.contains('overspeed') ||
      normalized.contains('alarm') ||
      normalized.contains('panic') ||
      normalized.contains('sos') ||
      normalized.contains('geofence') ||
      normalized.contains('offline') ||
      normalized.contains('jammer') ||
      normalized.contains('power');
}

final executiveSummaryProvider = FutureProvider.family<ExecutiveKpiSummary,
    ExecutiveSummaryQuery>((ref, query) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return ExecutiveKpiSummary.empty;
  }

  final client = ref.watch(traccarClientProvider);
  final duration = query.to.difference(query.from);
  final previousFrom = query.from.subtract(duration);
  final previousTo = query.from;

  final devices = await client.getDevices(
    cookie: session.cookie,
    authHeader: session.authHeader,
  );
  final deviceIds = query.deviceId != null
      ? [query.deviceId!]
      : devices.map((d) => d.id).toList();

  if (deviceIds.isEmpty) return ExecutiveKpiSummary.empty;

  final devicesById = <int, TraccarDevice>{
    for (final d in devices) d.id: d,
  };

  // Duas visões da mesma janela: totalizada (pro card/ranking) e diária
  // (pro gráfico de tendência + sparkline). Chamadas em paralelo.
  List<Map<String, dynamic>> currentSummary = const [];
  List<Map<String, dynamic>> previousSummary = const [];
  List<Map<String, dynamic>> currentDaily = const [];
  List<Map<String, dynamic>> previousDaily = const [];
  try {
    final results = await Future.wait([
      client.getFleetSummary(
        deviceIds: deviceIds, from: query.from, to: query.to,
        cookie: session.cookie, authHeader: session.authHeader,
      ),
      client.getFleetSummary(
        deviceIds: deviceIds, from: previousFrom, to: previousTo,
        cookie: session.cookie, authHeader: session.authHeader,
      ),
      client.getFleetSummary(
        deviceIds: deviceIds, from: query.from, to: query.to,
        cookie: session.cookie, authHeader: session.authHeader, daily: true,
      ),
      client.getFleetSummary(
        deviceIds: deviceIds, from: previousFrom, to: previousTo,
        cookie: session.cookie, authHeader: session.authHeader, daily: true,
      ),
    ]);
    currentSummary = results[0];
    previousSummary = results[1];
    currentDaily = results[2];
    previousDaily = results[3];
  } catch (_) {
    // Se qualquer chamada falhar, segue com o que já tem (listas vazias
    // viram KPI zerado/sem comparativo -- nunca dado inventado).
  }

  double sumDistanceMeters(List<Map<String, dynamic>> rows) {
    var total = 0.0;
    for (final row in rows) {
      total += (row['distance'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  double sumEngineHoursMs(List<Map<String, dynamic>> rows) {
    var total = 0.0;
    for (final row in rows) {
      total += (row['engineHours'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  final currentDistanceKm = sumDistanceMeters(currentSummary) / 1000.0;
  final previousDistanceKm = sumDistanceMeters(previousSummary) / 1000.0;
  final currentHours = sumEngineHoursMs(currentSummary) / 3600000.0;
  final previousHours = sumEngineHoursMs(previousSummary) / 3600000.0;

  // % de utilização = fração das horas do período em que havia motor ligado
  // em pelo menos 1 veículo, sobre o total de horas do período * nº de
  // veículos -- aproximação simples e honesta, sem inventar métrica mais
  // sofisticada que exigiria dado que não temos (turno de trabalho, etc).
  final periodHours = duration.inMinutes / 60.0;
  final maxPossibleHours = periodHours * deviceIds.length;
  final currentUtilization = maxPossibleHours > 0
      ? (currentHours / maxPossibleHours * 100).clamp(0, 100).toDouble()
      : 0.0;
  final previousUtilization = maxPossibleHours > 0
      ? (previousHours / maxPossibleHours * 100).clamp(0, 100).toDouble()
      : 0.0;

  // Alertas críticos: eventos reais do período, filtrados pelo mesmo
  // critério já usado no replay de rotas.
  int currentAlerts = 0;
  int previousAlerts = 0;
  try {
    for (final deviceId in deviceIds) {
      final events = await client.getReport(
        path: '/reports/events',
        deviceId: deviceId,
        from: query.from,
        to: query.to,
        cookie: session.cookie,
        authHeader: session.authHeader,
        extraQuery: const {'type': 'allEvents'},
      );
      for (final event in events) {
        final type = '${event['type'] ?? ''}';
        final attrs = event['attributes'];
        final alarm = attrs is Map ? '${attrs['alarm'] ?? ''}' : '';
        if (_isRelevantAlertType(type, alarm)) currentAlerts++;
      }
    }
  } catch (_) {
    // Se a checagem de eventos falhar, o KPI fica 0 -- não trava o resto
    // do resumo executivo por causa de 1 chamada extra.
  }

  // Top veículos por km percorrido no período atual.
  // Top veículos por km percorrido, com variação vs o mesmo device no
  // período anterior (agora que temos previousSummary por device).
  final previousByDevice = <int, double>{
    for (final row in previousSummary)
      if ((row['deviceId'] as num?)?.toInt() != null)
        (row['deviceId'] as num).toInt(): ((row['distance'] as num?)?.toDouble() ?? 0.0) / 1000.0,
  };
  final topVehicles = currentSummary
      .map((row) {
        final deviceId = (row['deviceId'] as num?)?.toInt();
        final device = deviceId != null ? devicesById[deviceId] : null;
        final name = device?.name ?? (row['deviceName'] as String? ?? 'Dispositivo');
        final km = ((row['distance'] as num?)?.toDouble() ?? 0.0) / 1000.0;
        final prevKm = deviceId != null ? previousByDevice[deviceId] : null;
        final change = (prevKm != null && prevKm > 0) ? ((km - prevKm) / prevKm * 100) : null;
        return TopVehicleActivity(
          vehicleName: name,
          distanceKm: km,
          changePercent: change,
        );
      })
      .where((v) => v.distanceKm > 0)
      .toList()
    ..sort((a, b) => b.distanceKm.compareTo(a.distanceKm));

  // Agrega o retorno "daily" (1 linha por device por dia) somando todos os
  // devices no mesmo dia -- vira a série diária da frota inteira.
  Map<DateTime, double> aggregateByDay(List<Map<String, dynamic>> rows) {
    final byDay = <DateTime, double>{};
    for (final row in rows) {
      final startTime = row['startTime'] as String?;
      if (startTime == null) continue;
      final parsed = DateTime.tryParse(startTime)?.toLocal();
      if (parsed == null) continue;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      final km = ((row['distance'] as num?)?.toDouble() ?? 0.0) / 1000.0;
      byDay[day] = (byDay[day] ?? 0) + km;
    }
    return byDay;
  }

  final currentByDay = aggregateByDay(currentDaily);
  final previousByDay = aggregateByDay(previousDaily);
  final trendLabels = (currentByDay.keys.toList()..sort());
  final trendCurrentSeries = [for (final day in trendLabels) currentByDay[day] ?? 0.0];
  // Alinha o período anterior pelo índice do dia (dia 1 do período atual
  // casa com dia 1 do período anterior), não pela data em si.
  final previousDaysSorted = previousByDay.keys.toList()..sort();
  final trendPreviousSeries = [
    for (var i = 0; i < trendLabels.length; i++)
      i < previousDaysSorted.length ? (previousByDay[previousDaysSorted[i]] ?? 0.0) : 0.0,
  ];

  return ExecutiveKpiSummary(
    distanceKm: ExecutiveKpi(
      current: currentDistanceKm,
      previous: previousSummary.isEmpty ? null : previousDistanceKm,
      sparkline: trendCurrentSeries,
    ),
    utilizationPercent: ExecutiveKpi(
      current: currentUtilization,
      previous: previousSummary.isEmpty ? null : previousUtilization,
      sparkline: const [],
    ),
    operatingHours: ExecutiveKpi(
      current: currentHours,
      previous: previousSummary.isEmpty ? null : previousHours,
      sparkline: const [],
    ),
    criticalAlerts: ExecutiveKpi(
      current: currentAlerts.toDouble(),
      previous: previousAlerts.toDouble(),
      sparkline: const [],
    ),
    trendCurrent: trendCurrentSeries,
    trendPrevious: trendPreviousSeries,
    trendLabels: trendLabels,
    topVehicles: topVehicles.take(10).toList(),
  );
});
