// Mapeamento de AVL IDs do protocolo Teltonika (codec 8 extended, dados
// de OBD II) para os nomes de campo que o resto do app ja conhece
// (rpm/fuelLevel/coolantTemp/etc). O decoder nativo do Traccar nao
// traduz esses IDs especificos pra nome amigavel -- eles chegam como
// "io<N>" cru nos attributes da posicao. Confirmado em campo 2026-10-01
// com equipamento MTB100 real (IMEI 354017114450907): valores batem com
// a leitura OBD mostrada no Teltonika Configurator (Engine RPM, Coolant
// Temperature, Fuel Level, Throttle Position etc). Fonte: tabela oficial
// de AVL ID Teltonika (wiki.teltonika-gps.com, "OBD (Parameter ID)").
const Map<String, String> teltonikaObdIoMap = {
  'io30': 'obdDtcCount',
  'io31': 'obdEngineLoad',
  'io32': 'coolantTemp',
  'io33': 'obdShortFuelTrim',
  'io34': 'obdFuelPressure',
  'io35': 'obdIntakeMap',
  'io36': 'rpm',
  'io37': 'obdSpeed',
  'io38': 'obdTimingAdvance',
  'io39': 'obdThrottlePosition',
  'io40': 'obdRunTime',
  'io41': 'obdIntakeAirTemp',
  'io42': 'obdMaf',
  'io43': 'obdDistanceMil',
  'io48': 'fuelLevelRaw',
  'io50': 'fuelLevel',
  'io51': 'obdFuelRailPressure',
  'io68': 'obdEngineOilTemp',
  'io69': 'obdFuelRate',
  'io80': 'obdBarometricPressure',
  'io113': 'batteryLevel',
  'io200': 'sleepMode',
};

/// Aplica o mapeamento acima a um mapa de attributes, sem alterar os
/// campos originais (mantem io<N> cru tambem, caso algo ainda dependa
/// deles -- so adiciona os nomes conhecidos por cima).
Map<String, dynamic> withTeltonikaObdFields(Map<String, dynamic> attrs) {
  if (attrs.isEmpty) return attrs;
  Map<String, dynamic>? mapped;
  for (final entry in teltonikaObdIoMap.entries) {
    if (attrs.containsKey(entry.key) && !attrs.containsKey(entry.value)) {
      (mapped ??= Map<String, dynamic>.from(attrs))[entry.value] =
          attrs[entry.key];
    }
  }
  return mapped ?? attrs;
}
