import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';
import '../telemetry/sensor_presentation.dart';

final devicesManagementProvider =
    FutureProvider.autoDispose<List<TraccarDevice>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) {
    return [];
  }

  final client = ref.watch(traccarClientProvider);
  return client.getDevices(
    cookie: session.cookie,
    authHeader: session.authHeader,
  );
});

enum _DevicesQuickFilter {
  all,
  online,
  moving,
  alerts,
  offline,
  noCommunication,
}

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  static final List<MapEntry<String, String>> _sensorOptions =
      sensorSelectionOptions();
  static const List<_MapIconChoice> _mapIconChoices = [
    _MapIconChoice('animal', 'Animal'),
    _MapIconChoice('car', 'Carro'),
    _MapIconChoice('motorcycle', 'Moto'),
    _MapIconChoice('truck', 'Caminhão'),
    _MapIconChoice('bus', 'Ônibus'),
    _MapIconChoice('camper', 'Camper'),
    _MapIconChoice('pickup', 'Pickup'),
    _MapIconChoice('van', 'Van'),
    _MapIconChoice('tractor', 'Trator'),
    _MapIconChoice('crane', 'Guindaste'),
    _MapIconChoice('helicopter', 'Helicóptero'),
    _MapIconChoice('offroad', 'Off-road'),
    _MapIconChoice('bicycle', 'Bicicleta'),
    _MapIconChoice('boat', 'Barco'),
    _MapIconChoice('plane', 'Avião'),
    _MapIconChoice('ship', 'Navio'),
    _MapIconChoice('scooter', 'Scooter'),
    _MapIconChoice('train', 'Trem'),
    _MapIconChoice('tram', 'Tram'),
    _MapIconChoice('trolleybus', 'Trolleybus'),
    _MapIconChoice('person', 'Pessoa'),
    _MapIconChoice('default', 'Genérico'),
  ];

  static const Set<String> _defaultSensorKeys = {
    'ignition',
    'motion',
    'door',
    'blocked',
    'gpsTracking',
    'power',
    'batteryLevel',
    'battery',
    'charge',
    'gsm',
    'rssi',
    'satellites',
    'mcc',
    'mnc',
    'lac',
    'cid',
    'odometer',
    'totalHours',
  };

  static const List<MapEntry<String, String>> _protocolOptions = [
    MapEntry('teltonika', 'Teltonika'),
    MapEntry('queclink', 'Queclink / GV'),
    MapEntry('gt06', 'GT06 / Concox'),
    MapEntry('suntech', 'Suntech'),
    MapEntry('coban', 'Coban / TK103'),
    MapEntry('meitrack', 'Meitrack'),
    MapEntry('ruptela', 'Ruptela'),
    MapEntry('galileosky', 'Galileosky'),
    MapEntry('wialon', 'Wialon IPS'),
    MapEntry('osmand', 'OsmAnd'),
    MapEntry('other', 'Outro'),
  ];

  static const Map<String, String> _protocolPorts = {
    'teltonika': '5027',
    'queclink': '5093',
    'gt06': '5023',
    'suntech': '5011',
    'coban': '5004',
    'meitrack': '5020',
    'ruptela': '5046',
    'galileosky': '5004',
    'wialon': '5013',
    'osmand': '5055',
  };

  static const List<MapEntry<String, String>> _operatorOptions = [
    MapEntry('claro', 'Claro'),
    MapEntry('vivo', 'Vivo'),
    MapEntry('tim', 'Tim'),
    MapEntry('oi', 'Oi'),
    MapEntry('other', 'Outra'),
  ];

  static const Map<String, String> _operatorApns = {
    'claro': 'claro.com.br',
    'vivo': 'zap.vivo.com.br',
    'tim': 'tim.br',
    'oi': 'gprs.oi.com.br',
  };

  static const List<MapEntry<String, String>> _timezoneOptions = [
    MapEntry('America/Sao_Paulo', '(UTC-03:00) Brasília'),
    MapEntry('America/Manaus', '(UTC-04:00) Manaus'),
    MapEntry('America/Belem', '(UTC-03:00) Belém'),
    MapEntry('America/Fortaleza', '(UTC-03:00) Fortaleza'),
    MapEntry('America/Recife', '(UTC-03:00) Recife'),
    MapEntry('America/Noronha', '(UTC-02:00) Fernando de Noronha'),
    MapEntry('America/Porto_Velho', '(UTC-04:00) Porto Velho'),
    MapEntry('America/Boa_Vista', '(UTC-04:00) Boa Vista'),
    MapEntry('America/Rio_Branco', '(UTC-05:00) Rio Branco'),
    MapEntry('UTC', '(UTC+00:00) UTC'),
  ];
  static const List<MapEntry<String, String>> _manufacturerOptions = [
    MapEntry('teltonika', 'Teltonika'),
    MapEntry('queclink', 'Queclink'),
    MapEntry('concox', 'Concox / Jointech'),
    MapEntry('suntech', 'Suntech'),
    MapEntry('coban', 'Coban / TK'),
    MapEntry('meitrack', 'Meitrack'),
    MapEntry('ruptela', 'Ruptela'),
    MapEntry('galileosky', 'Galileosky'),
    MapEntry('jt', 'JT / Jointech'),
    MapEntry('other', 'Outro'),
  ];
  static const Map<String, List<String>> _modelsByManufacturer = {
    'teltonika': ['FMB920', 'FMB140', 'FMC130', 'FMB003', 'FMB010', 'FMB110', 'FMC880'],
    'queclink': ['GV20', 'GV310', 'GV500', 'GV55', 'GL300', 'GL500'],
    'concox': ['GT06', 'GT02', 'ET25', 'ET300', 'HVT001', 'HVT002'],
    'suntech': ['ST300', 'ST310', 'ST600', 'ST340'],
    'coban': ['TK103', 'TK303', 'TK305', 'GPS303'],
    'meitrack': ['T333', 'T399', 'MVT380', 'MVT600'],
    'ruptela': ['FM-Eco3', 'FM-Eco4', 'HCV5', 'Pro5'],
    'galileosky': ['Base Block', 'Galileosky 7.0', 'Galileosky 5.0'],
    'jt': ['JT600', 'JT701', 'JT706'],
  };

  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  final _identifierController = TextEditingController();
  final _categoryController = TextEditingController();
  final _phoneController = TextEditingController();
  final _searchController = TextEditingController();
  final _portController = TextEditingController();
  final _apnController = TextEditingController();
  final _clientController = TextEditingController();
  final _groupController = TextEditingController();
  final Set<String> _selectedSensorKeys = <String>{};
  bool _isActive = true;
  String? _selectedMapIconKey;
  String? _selectedProtocol;
  String? _selectedOperator;
  String? _selectedManufacturer;
  String? _selectedModel;
  String _selectedTimezone = 'America/Sao_Paulo';

  bool _saving = false;
  _DevicesQuickFilter _activeFilter = _DevicesQuickFilter.all;
  bool _showFilterChips = false;

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    _identifierController.dispose();
    _categoryController.dispose();
    _phoneController.dispose();
    _searchController.dispose();
    _portController.dispose();
    _apnController.dispose();
    _clientController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  Future<void> _openDeviceDialog({TraccarDevice? editing}) async {
    if (editing == null) {
      _nameController.clear();
      _plateController.clear();
      _identifierController.clear();
      _categoryController.clear();
      _phoneController.clear();
      _portController.clear();
      _apnController.clear();
      _clientController.clear();
      _groupController.clear();
      _isActive = true;
      _selectedMapIconKey = null;
      _selectedProtocol = null;
      _selectedOperator = null;
      _selectedManufacturer = null;
      _selectedModel = null;
      _selectedTimezone = 'America/Sao_Paulo';
      _selectedSensorKeys
        ..clear()
        ..addAll(_defaultSensorKeys);
    } else {
      _nameController.text = editing.name;
      _plateController.text = _readPlate(editing);
      _identifierController.text = (editing.uniqueId ?? '').trim();
      _categoryController.text = (editing.category ?? '').trim();
      _phoneController.text = (editing.attributes?['phone'] ?? '').toString();
      _portController.text = (editing.attributes?['souPort'] ?? '').toString();
      _apnController.text = (editing.attributes?['souApn'] ?? '').toString();
      _clientController.text = (editing.attributes?['souClient'] ?? '').toString();
      _groupController.text = (editing.attributes?['souGroup'] ?? '').toString();
      _isActive = _readActiveFlag(editing);
      _selectedMapIconKey = _normalizeMapIconKey(
        editing.attributes?['souMapIcon']?.toString(),
      );
      _selectedProtocol = editing.attributes?['souProtocol']?.toString();
      _selectedOperator = editing.attributes?['souOperator']?.toString();
      _selectedManufacturer = editing.attributes?['souManufacturer']?.toString();
      _selectedModel = editing.attributes?['souModel']?.toString();
      _selectedTimezone =
          (editing.attributes?['souTimezone'] ?? 'America/Sao_Paulo').toString();
      _setSelectedSensorsFromDevice(editing);
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1060,
              maxHeight: 860,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  final hasImei =
                      _identifierController.text.trim().length >= 10;
                  final hasProtocol = _selectedProtocol != null &&
                      _portController.text.trim().isNotEmpty;
                  final hasSensors = _selectedSensorKeys.isNotEmpty;
                  final hasGroup = _groupController.text.trim().isNotEmpty;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  editing == null
                                      ? 'Criar Dispositivo'
                                      : 'Editar Dispositivo',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: const Color(0xFF1F2A44),
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Cadastre um novo rastreador e defina seus parâmetros iniciais.',
                                  style: TextStyle(
                                    color: Color(0xFF5A6B84),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFE8EEF6)),
                      const SizedBox(height: 16),
                      // ── Body ──
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Left: single scroll form ──
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Section: Dados Gerais
                                    _DeviceSection(
                                      icon: Icons.inventory_2_outlined,
                                      iconColor: const Color(0xFF176EEB),
                                      title: 'Dados Gerais',
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _clientController,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText:
                                                      'Cliente / Empresa',
                                                  hintText:
                                                      'Selecione o cliente',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextField(
                                                controller: _nameController,
                                                onChanged: (_) =>
                                                    setModalState(() {}),
                                                decoration:
                                                    const InputDecoration(
                                                  labelText:
                                                      'Nome do Veículo *',
                                                  hintText:
                                                      'Digite o nome do veículo',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextField(
                                                controller: _plateController,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Placa *',
                                                  hintText: 'ABC1D23',
                                                ),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .allow(RegExp(
                                                          r'[A-Za-z0-9-]')),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller:
                                                    _identifierController,
                                                onChanged: (_) =>
                                                    setModalState(() {}),
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'IMEI *',
                                                  hintText:
                                                      'Digite o IMEI do dispositivo',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _DeviceDropdown(
                                                label: 'Fabricante',
                                                value: _selectedManufacturer,
                                                options: _manufacturerOptions,
                                                onChanged: (v) =>
                                                    setModalState(() {
                                                  _selectedManufacturer = v;
                                                  _selectedModel = null;
                                                }),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _selectedManufacturer !=
                                                          null &&
                                                      (_modelsByManufacturer[
                                                                  _selectedManufacturer]
                                                              ?.isNotEmpty ??
                                                          false)
                                                  ? _DeviceDropdown(
                                                      label: 'Modelo',
                                                      value: _selectedModel,
                                                      options: (_modelsByManufacturer[
                                                                  _selectedManufacturer] ??
                                                              [])
                                                          .map((m) =>
                                                              MapEntry(m, m))
                                                          .toList(),
                                                      onChanged: (v) =>
                                                          setModalState(() =>
                                                              _selectedModel =
                                                                  v),
                                                    )
                                                  : TextField(
                                                      decoration:
                                                          InputDecoration(
                                                        labelText: 'Modelo',
                                                        hintText:
                                                            'Selecione o modelo',
                                                        enabled:
                                                            _selectedManufacturer !=
                                                                null,
                                                      ),
                                                      onChanged: (v) =>
                                                          setModalState(() =>
                                                              _selectedModel =
                                                                  v.isEmpty
                                                                      ? null
                                                                      : v),
                                                    ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: _groupController,
                                          onChanged: (_) =>
                                              setModalState(() {}),
                                          decoration: const InputDecoration(
                                            labelText: 'Grupo *',
                                            hintText: 'Selecione o grupo',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Section: Conectividade
                                    _DeviceSection(
                                      icon: Icons.wifi_rounded,
                                      iconColor: const Color(0xFF176EEB),
                                      title: 'Conectividade',
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _phoneController,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Chip / Telefone',
                                                  hintText:
                                                      '(DDD) 9 9999-9999',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _DeviceDropdown(
                                                label: 'Operadora',
                                                value: _selectedOperator,
                                                options: _operatorOptions,
                                                onChanged: (v) =>
                                                    setModalState(() {
                                                  _selectedOperator = v;
                                                  final apn =
                                                      _operatorApns[v];
                                                  if (apn != null &&
                                                      _apnController
                                                          .text.isEmpty) {
                                                    _apnController.text = apn;
                                                  }
                                                }),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextField(
                                                controller: _apnController,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'APN',
                                                  hintText: 'Digite o APN',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _DeviceDropdown(
                                                label: 'Protocolo',
                                                value: _selectedProtocol,
                                                options: _protocolOptions,
                                                onChanged: (v) =>
                                                    setModalState(() {
                                                  _selectedProtocol = v;
                                                  final port =
                                                      _protocolPorts[v];
                                                  if (port != null &&
                                                      _portController
                                                          .text.isEmpty) {
                                                    _portController.text =
                                                        port;
                                                  }
                                                }),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextField(
                                                controller: _portController,
                                                onChanged: (_) =>
                                                    setModalState(() {}),
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Porta',
                                                  hintText: 'Ex: 5023',
                                                ),
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _DeviceDropdown(
                                                label: 'Fuso Horário',
                                                value: _selectedTimezone,
                                                options: _timezoneOptions,
                                                onChanged: (v) =>
                                                    setModalState(() =>
                                                        _selectedTimezone = v ??
                                                            _selectedTimezone),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Text(
                                              'Ativo / Inativo',
                                              style: TextStyle(
                                                color: Color(0xFF1F2A44),
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Switch(
                                              value: _isActive,
                                              onChanged: _saving
                                                  ? null
                                                  : (v) => setModalState(
                                                      () => _isActive = v),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _isActive ? 'Ativo' : 'Inativo',
                                              style: TextStyle(
                                                color: _isActive
                                                    ? const Color(0xFF18A558)
                                                    : const Color(0xFF5A6B84),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Section: Sensores
                                    _DeviceSection(
                                      icon: Icons.sensors_rounded,
                                      iconColor: const Color(0xFF7B2FC4),
                                      title: 'Sensores',
                                      trailing: Tooltip(
                                        message:
                                            'Ative os sensores suportados pelo hardware do rastreador',
                                        child: const Icon(
                                          Icons.info_outline_rounded,
                                          size: 16,
                                          color: Color(0xFF8FA3BF),
                                        ),
                                      ),
                                      children: [
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            for (final option in _sensorOptions)
                                              _SensorCardV2(
                                                sensorKey: option.key,
                                                label: option.value,
                                                selected: _selectedSensorKeys
                                                    .contains(option.key),
                                                onToggle: _saving
                                                    ? null
                                                    : (v) =>
                                                        setModalState(() {
                                                          if (v) {
                                                            _selectedSensorKeys
                                                                .add(
                                                                    option.key);
                                                          } else {
                                                            _selectedSensorKeys
                                                                .remove(
                                                                    option.key);
                                                          }
                                                        }),
                                              ),
                                          ],
                                        ),
                                        if (_selectedSensorKeys.any((k) =>
                                            !_sensorOptions
                                                .any((o) => o.key == k))) ...[
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Sensores personalizados',
                                            style: TextStyle(
                                              color: Color(0xFF1F2A44),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          for (final sensorKey
                                              in _selectedSensorKeys
                                                  .where((k) => !_sensorOptions
                                                      .any((o) => o.key == k))
                                                  .toList()
                                                ..sort())
                                            _SelectedSensorRow(
                                              sensorKey: sensorKey,
                                              label: _sensorLabel(sensorKey),
                                              onEdit: _saving
                                                  ? null
                                                  : () async {
                                                      final updated =
                                                          await _openSensorInputDialog(
                                                        initialValue: sensorKey,
                                                      );
                                                      if (updated == null) {
                                                        return;
                                                      }
                                                      setModalState(() {
                                                        _selectedSensorKeys
                                                            .remove(sensorKey);
                                                        _selectedSensorKeys.add(
                                                          _normalizeSensorKey(
                                                              updated),
                                                        );
                                                      });
                                                    },
                                              onDelete: _saving
                                                  ? null
                                                  : () => setModalState(() =>
                                                      _selectedSensorKeys
                                                          .remove(sensorKey)),
                                            ),
                                        ],
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton.icon(
                                            onPressed: _saving
                                                ? null
                                                : () async {
                                                    final created =
                                                        await _openSensorInputDialog();
                                                    if (created == null) {
                                                      return;
                                                    }
                                                    setModalState(() {
                                                      _selectedSensorKeys.add(
                                                        _normalizeSensorKey(
                                                            created),
                                                      );
                                                    });
                                                  },
                                            icon: const Icon(
                                                Icons.add_rounded,
                                                size: 16),
                                            label: const Text(
                                                'Adicionar sensor personalizado'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            // ── Right: Summary Panel ──
                            SizedBox(
                              width: 240,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FBFF),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFD6E0EE)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Resumo do Dispositivo',
                                          style: TextStyle(
                                            color: Color(0xFF1F2A44),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        _DeviceSummaryRow(
                                          label: 'Status inicial',
                                          chip: _isActive ? 'Ativo' : 'Inativo',
                                          chipColor: _isActive
                                              ? const Color(0xFF18A558)
                                              : const Color(0xFF5E6B82),
                                        ),
                                        _DeviceSummaryRow(
                                          label: 'Grupo',
                                          value: _groupController.text
                                                  .trim()
                                                  .isEmpty
                                              ? 'Não definido'
                                              : _groupController.text.trim(),
                                        ),
                                        _DeviceSummaryRow(
                                          label: 'Protocolo',
                                          value: _selectedProtocol == null
                                              ? 'Não definido'
                                              : (_protocolOptions
                                                      .where((e) =>
                                                          e.key ==
                                                          _selectedProtocol)
                                                      .firstOrNull
                                                      ?.value ??
                                                  _selectedProtocol!),
                                        ),
                                        _DeviceSummaryRow(
                                          label: 'Porta',
                                          value: _portController.text
                                                  .trim()
                                                  .isEmpty
                                              ? 'Não definido'
                                              : _portController.text.trim(),
                                        ),
                                        const _DeviceSummaryRow(
                                          label: 'Última validação',
                                          value: '—',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _saving
                                          ? null
                                          : () async {
                                              final ok = editing == null
                                                  ? await _createDevice()
                                                  : await _updateDevice(
                                                      editing);
                                              if (!mounted ||
                                                  !dialogContext.mounted) {
                                                return;
                                              }
                                              if (ok) {
                                                Navigator.of(dialogContext)
                                                    .pop();
                                              }
                                            },
                                      icon: _saving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2),
                                            )
                                          : const Icon(Icons.save_outlined,
                                              size: 18),
                                      label: Text(
                                        _saving
                                            ? 'Salvando...'
                                            : (editing == null
                                                ? 'Salvar Dispositivo'
                                                : 'Salvar Alterações'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF176EEB)
                                                .withValues(alpha: 0.85),
                                      ),
                                      onPressed: _saving
                                          ? null
                                          : () async {
                                              final ok = editing == null
                                                  ? await _createDevice()
                                                  : await _updateDevice(
                                                      editing);
                                              if (!mounted ||
                                                  !dialogContext.mounted) {
                                                return;
                                              }
                                              if (ok) {
                                                Navigator.of(dialogContext)
                                                    .pop();
                                              }
                                            },
                                      icon: const Icon(
                                          Icons.settings_rounded,
                                          size: 18),
                                      label: const Text(
                                          'Salvar e Configurar Sensores'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _saving
                                          ? null
                                          : () =>
                                              Navigator.of(dialogContext)
                                                  .pop(),
                                      icon: const Icon(Icons.close_rounded,
                                          size: 16),
                                      label: const Text('Cancelar'),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FBFF),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFD6E0EE)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Checklist de Criação',
                                          style: TextStyle(
                                            color: Color(0xFF1F2A44),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        _ChecklistItem(
                                          label: 'Validar IMEI',
                                          checked: hasImei,
                                        ),
                                        _ChecklistItem(
                                          label: 'Confirmar protocolo e porta',
                                          checked: hasProtocol,
                                        ),
                                        _ChecklistItem(
                                          label: 'Revisar sensores padrão',
                                          checked: hasSensors,
                                        ),
                                        _ChecklistItem(
                                          label: 'Vincular grupo operacional',
                                          checked: hasGroup,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _readPlate(TraccarDevice device) {
    final raw = device.attributes?['plate'] ??
        device.attributes?['plateNumber'] ??
        device.attributes?['licensePlate'] ??
        device.attributes?['registration'];
    return raw?.toString().trim() ?? '';
  }

  bool _readActiveFlag(TraccarDevice device) {
    final raw = device.attributes?['souActive'];
    if (raw is bool) return raw;
    if (raw is num) return raw > 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'sim') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'nao') {
        return false;
      }
    }
    return true;
  }

  String? _normalizeMapIconKey(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return null;
    for (final choice in _mapIconChoices) {
      if (choice.key == value) {
        return value;
      }
    }
    return value;
  }

  void _setSelectedSensorsFromDevice(TraccarDevice device) {
    _selectedSensorKeys.clear();
    final rawSensors = device.attributes?['souSensors'];
    if (rawSensors is List) {
      for (final raw in rawSensors) {
        final key = raw.toString().trim();
        if (key.isNotEmpty) {
          _selectedSensorKeys.add(_normalizeSensorKey(key));
        }
      }
    }
    if (_selectedSensorKeys.isEmpty) {
      _selectedSensorKeys.addAll(_defaultSensorKeys);
    }
  }

  String _normalizeSensorKey(String key) {
    final normalized = key.trim().toLowerCase();
    switch (normalized) {
      case 'sat':
        return 'satellites';
      case 'hours':
        return 'totalHours';
      case 'distance':
        return 'odometer';
      default:
        return normalized;
    }
  }

  String _sensorLabel(String key) {
    for (final option in _sensorOptions) {
      if (option.key == key) {
        return option.value;
      }
    }
    return key;
  }

  Future<String?> _openSensorInputDialog({String? initialValue}) async {
    final controller = TextEditingController(text: initialValue ?? '');
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              initialValue == null ? 'Cadastrar sensor' : 'Editar sensor',
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Chave do sensor',
                hintText: 'Ex.: temperature, fuelLevel, door',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) {
                    return;
                  }
                  Navigator.of(dialogContext).pop(value);
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _createDevice() async {
    final name = _nameController.text.trim();
    final plate = _plateController.text.trim().toUpperCase();
    final identifier = _identifierController.text.trim();
    final category = _categoryController.text.trim();
    final phone = _phoneController.text.trim();
    final port = _portController.text.trim();
    final apn = _apnController.text.trim();
    final clientVal = _clientController.text.trim();
    final groupVal = _groupController.text.trim();
    final selectedSensors = (_selectedSensorKeys.isEmpty
            ? _defaultSensorKeys
            : _selectedSensorKeys)
        .toList()
      ..sort();

    if (name.isEmpty || identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe nome e identificador do equipamento.'),
        ),
      );
      return false;
    }

    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    setState(() => _saving = true);

    try {
      await client.createDevice(
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': name,
          'uniqueId': identifier,
          if (category.isNotEmpty) 'category': category,
          if (phone.isNotEmpty) 'phone': phone,
          'attributes': {
            if (phone.isNotEmpty) 'phone': phone,
            if (plate.isNotEmpty) 'plate': plate,
            'souActive': _isActive,
            if ((_selectedMapIconKey ?? '').trim().isNotEmpty)
              'souMapIcon': _selectedMapIconKey,
            'souSensors': selectedSensors,
            if (_selectedProtocol != null) 'souProtocol': _selectedProtocol,
            if (port.isNotEmpty) 'souPort': port,
            if (_selectedOperator != null) 'souOperator': _selectedOperator,
            if (apn.isNotEmpty) 'souApn': apn,
            if (_selectedManufacturer != null)
              'souManufacturer': _selectedManufacturer,
            if (_selectedModel != null) 'souModel': _selectedModel,
            if (clientVal.isNotEmpty) 'souClient': clientVal,
            if (groupVal.isNotEmpty) 'souGroup': groupVal,
            'souTimezone': _selectedTimezone,
          },
        },
      );

      ref.invalidate(devicesManagementProvider);
      ref.invalidate(devicesProvider);
      ref.invalidate(positionsProvider);
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipamento cadastrado com sucesso.')),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _updateDevice(TraccarDevice device) async {
    final name = _nameController.text.trim();
    final plate = _plateController.text.trim().toUpperCase();
    final identifier = _identifierController.text.trim();
    final category = _categoryController.text.trim();
    final phone = _phoneController.text.trim();
    final port = _portController.text.trim();
    final apn = _apnController.text.trim();
    final clientVal = _clientController.text.trim();
    final groupVal = _groupController.text.trim();
    final selectedSensors = (_selectedSensorKeys.isEmpty
            ? _defaultSensorKeys
            : _selectedSensorKeys)
        .toList()
      ..sort();

    if (name.isEmpty || identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe nome e identificador do equipamento.'),
        ),
      );
      return false;
    }

    final attributes = <String, dynamic>{
      ...?device.attributes,
      'souActive': _isActive,
      'souSensors': selectedSensors,
      'souTimezone': _selectedTimezone,
    };
    if (phone.isNotEmpty) {
      attributes['phone'] = phone;
    } else {
      attributes.remove('phone');
    }
    if (plate.isNotEmpty) {
      attributes['plate'] = plate;
    } else {
      attributes.remove('plate');
    }
    if ((_selectedMapIconKey ?? '').trim().isNotEmpty) {
      attributes['souMapIcon'] = _selectedMapIconKey;
    } else {
      attributes.remove('souMapIcon');
    }
    if (_selectedProtocol != null) {
      attributes['souProtocol'] = _selectedProtocol;
    } else {
      attributes.remove('souProtocol');
    }
    if (port.isNotEmpty) {
      attributes['souPort'] = port;
    } else {
      attributes.remove('souPort');
    }
    if (_selectedOperator != null) {
      attributes['souOperator'] = _selectedOperator;
    } else {
      attributes.remove('souOperator');
    }
    if (apn.isNotEmpty) {
      attributes['souApn'] = apn;
    } else {
      attributes.remove('souApn');
    }
    if (_selectedManufacturer != null) {
      attributes['souManufacturer'] = _selectedManufacturer;
    } else {
      attributes.remove('souManufacturer');
    }
    if (_selectedModel != null) {
      attributes['souModel'] = _selectedModel;
    } else {
      attributes.remove('souModel');
    }
    if (clientVal.isNotEmpty) {
      attributes['souClient'] = clientVal;
    } else {
      attributes.remove('souClient');
    }
    if (groupVal.isNotEmpty) {
      attributes['souGroup'] = groupVal;
    } else {
      attributes.remove('souGroup');
    }

    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    setState(() => _saving = true);

    try {
      await client.updateEntityById(
        path: '/devices',
        id: device.id,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'id': device.id,
          'name': name,
          'uniqueId': identifier,
          if (category.isNotEmpty) 'category': category,
          if (phone.isNotEmpty) 'phone': phone,
          'attributes': attributes,
        },
      );

      ref.invalidate(devicesManagementProvider);
      ref.invalidate(devicesProvider);
      ref.invalidate(positionsProvider);
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipamento atualizado com sucesso.')),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyError(Object error) {
    final code = _extractHttpStatusCode(error);
    if (code == 401) {
      return 'Sessao expirada. Faca login novamente.';
    }
    if (code == 403) {
      return 'Usuario sem permissao para editar equipamentos.';
    }
    if (code != null) {
      return 'Falha na operacao (codigo $code).';
    }
    return 'Falha ao concluir a operacao.';
  }

  int? _extractHttpStatusCode(Object error) {
    final raw = error.toString();
    final match =
        RegExp(r'(?:^|[^0-9])([1-5][0-9]{2})(?:[^0-9]|$)').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  Map<int, TraccarPosition> _latestPositionsByDevice(
    List<TraccarPosition> positions,
  ) {
    final latest = <int, TraccarPosition>{};
    for (final position in positions) {
      final current = latest[position.deviceId];
      if (current == null) {
        latest[position.deviceId] = position;
        continue;
      }
      final currentTime = _parseDate(current.fixTime);
      final nextTime = _parseDate(position.fixTime);
      if (nextTime != null &&
          (currentTime == null || nextTime.isAfter(currentTime))) {
        latest[position.deviceId] = position;
      }
    }
    return latest;
  }

  DateTime? _parseDate(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  DateTime? _deviceCommunicationAt(
    TraccarDevice device,
    TraccarPosition? position,
  ) {
    return _parseDate(device.lastUpdate ?? position?.fixTime);
  }

  String _formatRelative(DateTime? value) {
    if (value == null) return 'Não informado';
    final diff = DateTime.now().difference(value);
    if (diff.isNegative || diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    if (diff.inDays == 1) return 'há 1 dia';
    return 'há ${diff.inDays} dias';
  }

  String _formatDateTimeShort(DateTime? value) {
    if (value == null) return '--';
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m $hh:$mm';
  }

  double _speedKmh(TraccarPosition? position) => position?.speed ?? 0;

  bool _isMoving(TraccarPosition? position) => _speedKmh(position) >= 3;

  bool _isOffline(TraccarDevice device, TraccarPosition? position) {
    final status = device.status.trim().toLowerCase();
    if (status == 'offline' || status == 'unknown') return true;
    final at = _deviceCommunicationAt(device, position);
    if (at == null) return true;
    return DateTime.now().difference(at).inHours >= 24;
  }

  bool _isNoCommunication(TraccarDevice device, TraccarPosition? position) {
    final at = _deviceCommunicationAt(device, position);
    if (at == null || position == null) return true;
    return DateTime.now().difference(at).inHours >= 12;
  }

  Map<String, dynamic> _attrs(TraccarDevice device, TraccarPosition? position) {
    return <String, dynamic>{...?device.attributes, ...?position?.attributes};
  }

  dynamic _firstAttr(Map<String, dynamic> attrs, List<String> keys) {
    for (final key in keys) {
      final value = attrs[key];
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      return value;
    }
    return null;
  }

  bool? _asBool(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw > 0;
    if (raw is String) {
      final n = raw.trim().toLowerCase();
      if (n == 'true' || n == '1' || n == 'on' || n == 'sim') return true;
      if (n == 'false' || n == '0' || n == 'off' || n == 'nao') return false;
    }
    return null;
  }

  double? _asDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.replaceAll(',', '.'));
    return null;
  }

  bool _hasAlert(TraccarDevice device, TraccarPosition? position) {
    final attrs = _attrs(device, position);
    if (_firstAttr(attrs, const ['alarm', 'event']) != null) return true;
    if (_asBool(_firstAttr(attrs, const ['blocked'])) == true) return true;
    return device.status.trim().toLowerCase() == 'unknown';
  }

  String _statusLabel(TraccarDevice device, TraccarPosition? position) {
    if (_isNoCommunication(device, position)) return 'Sem comunicação';
    if (_hasAlert(device, position)) return 'Alerta';
    if (_isOffline(device, position)) return 'Offline';
    return 'Online';
  }

  Color _statusColor(String label) {
    switch (label) {
      case 'Online':
        return const Color(0xFF18A558);
      case 'Alerta':
        return const Color(0xFFE74B4B);
      case 'Offline':
        return const Color(0xFF5E6B82);
      case 'Sem comunicação':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF5E6B82);
    }
  }

  String _ignitionLabel(Map<String, dynamic> attrs) {
    final value = _asBool(_firstAttr(attrs, const ['ignition', 'engineOn']));
    if (value == null) return 'Não informado';
    return value ? 'Ligada' : 'Desligada';
  }

  Color _ignitionColor(Map<String, dynamic> attrs) {
    final value = _asBool(_firstAttr(attrs, const ['ignition', 'engineOn']));
    if (value == null) return const Color(0xFF7A879D);
    return value ? const Color(0xFF18A558) : const Color(0xFFE74B4B);
  }

  String _batteryLabel(Map<String, dynamic> attrs) {
    final percent = _asDouble(_firstAttr(attrs, const ['batteryLevel']));
    if (percent != null) return '${percent.round()}%';
    final voltage = _asDouble(_firstAttr(attrs, const ['battery', 'power']));
    if (voltage != null) return '${voltage.toStringAsFixed(1)} V';
    return 'Não informado';
  }

  Color _batteryColor(Map<String, dynamic> attrs) {
    final percent = _asDouble(_firstAttr(attrs, const ['batteryLevel']));
    if (percent != null) {
      if (percent <= 20) return const Color(0xFFE74B4B);
      if (percent <= 50) return const Color(0xFFF59E0B);
      return const Color(0xFF18A558);
    }
    return const Color(0xFF18A558);
  }

  String _gsmLabel(Map<String, dynamic> attrs) {
    final signal =
        _asDouble(_firstAttr(attrs, const ['gsm', 'rssi', 'signal']));
    if (signal == null) return '--';
    if (signal < 0) return '${signal.toStringAsFixed(0)} dBm';
    return signal.toStringAsFixed(0);
  }

  Color _gsmColor(Map<String, dynamic> attrs) {
    final signal =
        _asDouble(_firstAttr(attrs, const ['gsm', 'rssi', 'signal']));
    if (signal == null) return const Color(0xFF7A879D);
    if (signal < 0) {
      if (signal <= -95) return const Color(0xFFE74B4B);
      if (signal <= -80) return const Color(0xFFF59E0B);
      return const Color(0xFF18A558);
    }
    if (signal <= 20) return const Color(0xFFE74B4B);
    if (signal <= 40) return const Color(0xFFF59E0B);
    return const Color(0xFF18A558);
  }

  String _vehicleLabel(TraccarDevice device) {
    final value = _firstAttr(
      device.attributes ?? const <String, dynamic>{},
      const ['vehicle', 'plate', 'asset', 'model'],
    );
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
    return device.category?.trim().isNotEmpty == true
        ? device.category!.trim()
        : device.name;
  }

  String _groupLabel(TraccarDevice device) {
    final value = _firstAttr(
      device.attributes ?? const <String, dynamic>{},
      const ['group', 'groupName', 'department', 'fleet'],
    );
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
    return 'Sem grupo';
  }

  List<TraccarDevice> _filterByStatus(
    List<TraccarDevice> devices,
    Map<int, TraccarPosition> latestByDevice,
  ) {
    switch (_activeFilter) {
      case _DevicesQuickFilter.all:
        return devices;
      case _DevicesQuickFilter.online:
        return devices
            .where((it) => !_isOffline(it, latestByDevice[it.id]))
            .toList(growable: false);
      case _DevicesQuickFilter.moving:
        return devices
            .where((it) => _isMoving(latestByDevice[it.id]))
            .toList(growable: false);
      case _DevicesQuickFilter.alerts:
        return devices
            .where((it) => _hasAlert(it, latestByDevice[it.id]))
            .toList(growable: false);
      case _DevicesQuickFilter.offline:
        return devices
            .where((it) => _isOffline(it, latestByDevice[it.id]))
            .toList(growable: false);
      case _DevicesQuickFilter.noCommunication:
        return devices
            .where((it) => _isNoCommunication(it, latestByDevice[it.id]))
            .toList(growable: false);
    }
  }

  List<TraccarDevice> _filterBySearch(List<TraccarDevice> devices) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return devices;
    return devices.where((device) {
      return device.name.toLowerCase().contains(q) ||
          (device.uniqueId ?? '').toLowerCase().contains(q) ||
          (device.category ?? '').toLowerCase().contains(q);
    }).toList(growable: false);
  }

  int _count(
    _DevicesQuickFilter filter,
    List<TraccarDevice> devices,
    Map<int, TraccarPosition> latestByDevice,
  ) {
    switch (filter) {
      case _DevicesQuickFilter.all:
        return devices.length;
      case _DevicesQuickFilter.online:
        return devices
            .where((it) => !_isOffline(it, latestByDevice[it.id]))
            .length;
      case _DevicesQuickFilter.moving:
        return devices.where((it) => _isMoving(latestByDevice[it.id])).length;
      case _DevicesQuickFilter.alerts:
        return devices
            .where((it) => _hasAlert(it, latestByDevice[it.id]))
            .length;
      case _DevicesQuickFilter.offline:
        return devices
            .where((it) => _isOffline(it, latestByDevice[it.id]))
            .length;
      case _DevicesQuickFilter.noCommunication:
        return devices
            .where((it) => _isNoCommunication(it, latestByDevice[it.id]))
            .length;
    }
  }

  String _filterLabel(_DevicesQuickFilter filter) {
    switch (filter) {
      case _DevicesQuickFilter.all:
        return 'Todos os status';
      case _DevicesQuickFilter.online:
        return 'Online';
      case _DevicesQuickFilter.moving:
        return 'Em movimento';
      case _DevicesQuickFilter.alerts:
        return 'Alertas';
      case _DevicesQuickFilter.offline:
        return 'Offline';
      case _DevicesQuickFilter.noCommunication:
        return 'Sem comunicação';
    }
  }

  Future<void> _exportVisible(
    List<TraccarDevice> devices,
    Map<int, TraccarPosition> latestByDevice,
  ) async {
    final lines = <String>[
      'Status;Equipamento;IMEI_ID;Veículo_Ativo;Grupo;Última_Conexão;Velocidade;Ignição;Bateria;Sinal_GSM',
      for (final device in devices)
        [
          _statusLabel(device, latestByDevice[device.id]),
          device.name,
          (device.uniqueId ?? '').trim().isEmpty
              ? 'Não informado'
              : (device.uniqueId ?? '').trim(),
          _vehicleLabel(device),
          _groupLabel(device),
          _formatRelative(
              _deviceCommunicationAt(device, latestByDevice[device.id])),
          '${_speedKmh(latestByDevice[device.id]).toStringAsFixed(0)} km/h',
          _ignitionLabel(_attrs(device, latestByDevice[device.id])),
          _batteryLabel(_attrs(device, latestByDevice[device.id])),
          _gsmLabel(_attrs(device, latestByDevice[device.id])),
        ].map(_escapeCsv).join(';'),
    ];

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tabela copiada para a área de transferência.'),
      ),
    );
  }

  String _escapeCsv(String value) {
    if (value.contains(';') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesManagementProvider);
    final positionsAsync = ref.watch(positionsProvider);

    return SizedBox.expand(
      child: devicesAsync.when(
        data: (devices) {
          final positions =
              positionsAsync.valueOrNull ?? const <TraccarPosition>[];
          final latestByDevice = _latestPositionsByDevice(positions);

          if (devices.isEmpty) {
            return const _PanelMessageState(
              icon: Icons.devices_other_rounded,
              message: 'Nenhum equipamento cadastrado.',
            );
          }

          final total =
              _count(_DevicesQuickFilter.all, devices, latestByDevice);
          final online =
              _count(_DevicesQuickFilter.online, devices, latestByDevice);
          final moving =
              _count(_DevicesQuickFilter.moving, devices, latestByDevice);
          final alerts =
              _count(_DevicesQuickFilter.alerts, devices, latestByDevice);
          final offline =
              _count(_DevicesQuickFilter.offline, devices, latestByDevice);
          final noCommunication = _count(
              _DevicesQuickFilter.noCommunication, devices, latestByDevice);

          final visible = _filterBySearch(
            _filterByStatus(devices, latestByDevice),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 8.0;
                  final width = constraints.maxWidth;
                  final columns = width >= 1080
                      ? 6
                      : width >= 860
                          ? 4
                          : width >= 640
                              ? 3
                              : width >= 420
                                  ? 2
                                  : 1;
                  final cardWidth =
                      ((width - (columns - 1) * spacing) / columns)
                          .clamp(150.0, 220.0);

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.memory_rounded,
                        title: 'Total de Equipamentos',
                        value: total,
                        hint: '100% do total',
                        color: const Color(0xFF176EEB),
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.wifi_tethering_rounded,
                        title: 'Online',
                        value: online,
                        hint: total == 0
                            ? '0%'
                            : '${((online / total) * 100).round()}% do total',
                        color: const Color(0xFF18A558),
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.near_me_rounded,
                        title: 'Em movimento',
                        value: moving,
                        hint: total == 0
                            ? '0%'
                            : '${((moving / total) * 100).round()}% do total',
                        color: const Color(0xFF176EEB),
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.warning_amber_rounded,
                        title: 'Alertas Ativos',
                        value: alerts,
                        hint: total == 0
                            ? '0%'
                            : '${((alerts / total) * 100).round()}% do total',
                        color: const Color(0xFFE74B4B),
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.wifi_off_rounded,
                        title: 'Offline',
                        value: offline,
                        hint: total == 0
                            ? '0%'
                            : '${((offline / total) * 100).round()}% do total',
                        color: const Color(0xFF5E6B82),
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.portable_wifi_off_rounded,
                        title: 'Sem comunicação',
                        value: noCommunication,
                        hint: total == 0
                            ? '0%'
                            : '${((noCommunication / total) * 100).round()}% do total',
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 980;
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xCCFFFFFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD1DCEB)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Buscar equipamento, IMEI ou placa...',
                              hintStyle: TextStyle(
                                color: Color(0xFF74839B),
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: Color(0xFF60718D),
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _TopActionButton(
                              label: 'Filtros',
                              icon: Icons.filter_alt_outlined,
                              onTap: () => setState(
                                  () => _showFilterChips = !_showFilterChips),
                            ),
                            _TopActionButton(
                              label: 'Exportar',
                              icon: Icons.download_outlined,
                              onTap: () =>
                                  _exportVisible(visible, latestByDevice),
                            ),
                            _TopActionButton(
                              label: 'Novo Equipamento',
                              icon: Icons.add_rounded,
                              primary: true,
                              onTap:
                                  _saving ? () {} : () => _openDeviceDialog(),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xCCFFFFFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD1DCEB)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Buscar equipamento, IMEI ou placa...',
                              hintStyle: TextStyle(
                                color: Color(0xFF74839B),
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: Color(0xFF60718D),
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _TopActionButton(
                        label: 'Filtros',
                        icon: Icons.filter_alt_outlined,
                        onTap: () => setState(
                            () => _showFilterChips = !_showFilterChips),
                      ),
                      const SizedBox(width: 10),
                      _TopActionButton(
                        label: 'Exportar',
                        icon: Icons.download_outlined,
                        onTap: () => _exportVisible(visible, latestByDevice),
                      ),
                      const SizedBox(width: 10),
                      _TopActionButton(
                        label: 'Novo Equipamento',
                        icon: Icons.add_rounded,
                        primary: true,
                        onTap: _saving ? () {} : () => _openDeviceDialog(),
                      ),
                    ],
                  );
                },
              ),
              if (_showFilterChips) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filter in _DevicesQuickFilter.values)
                      ChoiceChip(
                        selectedColor: const Color(0xFFE8F1FF),
                        labelStyle: TextStyle(
                          color: _activeFilter == filter
                              ? const Color(0xFF176EEB)
                              : const Color(0xFF5A6B84),
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(
                          color: _activeFilter == filter
                              ? const Color(0xFFAAC9FF)
                              : const Color(0xFFD1DCEB),
                        ),
                        label: Text(
                          '${_filterLabel(filter)} (${_count(filter, devices, latestByDevice)})',
                        ),
                        selected: _activeFilter == filter,
                        onSelected: (_) =>
                            setState(() => _activeFilter = filter),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: visible.isEmpty
                    ? const _PanelMessageState(
                        icon: Icons.search_off_rounded,
                        message:
                            'Nenhum equipamento encontrado com os filtros atuais.',
                      )
                    : _DevicesTable(
                        devices: visible,
                        latestByDevice: latestByDevice,
                        onEdit: (device) => _openDeviceDialog(editing: device),
                        statusLabel: _statusLabel,
                        statusColor: _statusColor,
                        attrs: _attrs,
                        vehicleLabel: _vehicleLabel,
                        groupLabel: _groupLabel,
                        formatDateTimeShort: _formatDateTimeShort,
                        formatRelative: _formatRelative,
                        speedKmh: _speedKmh,
                        isMoving: _isMoving,
                        ignitionLabel: _ignitionLabel,
                        ignitionColor: _ignitionColor,
                        batteryLabel: _batteryLabel,
                        batteryColor: _batteryColor,
                        gsmLabel: _gsmLabel,
                        gsmColor: _gsmColor,
                        communicationAt: _deviceCommunicationAt,
                      ),
              ),
            ],
          );
        },
        loading: () => const _DevicesLoadingState(),
        error: (error, _) => _PanelMessageState(
          icon: Icons.info_outline_rounded,
          message: _friendlyError(error),
        ),
      ),
    );
  }
}

class _DevicesLoadingState extends StatelessWidget {
  const _DevicesLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 94,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            itemBuilder: (context, _) => Container(
              width: 188,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD1DCEB)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xCCFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1DCEB)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            for (var i = 0; i < 3; i++) ...[
              Container(
                width: i == 2 ? 156 : 116,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1DCEB)),
                ),
              ),
              if (i != 2) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 10),
        const Expanded(
          child: _PanelMessageState(
            icon: Icons.hourglass_top_rounded,
            message: 'Carregando equipamentos...',
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.hint,
    required this.color,
  });

  final double width;
  final IconData icon;
  final String title;
  final int value;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1DCEB)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5A6B84),
                    fontWeight: FontWeight.w700,
                    fontSize: 10.2,
                  ),
                ),
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    height: 0.98,
                  ),
                ),
                Text(
                  hint,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 9.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? const Color(0xFF2D8CFF) : const Color(0x99FFFFFF);
    final fg = primary ? Colors.white : const Color(0xFF1F2A44);
    final border = primary ? const Color(0xFF2D8CFF) : const Color(0xFFD1DCEB);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelMessageState extends StatelessWidget {
  const _PanelMessageState({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1DCEB)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF2D8CFF), size: 24),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF394B66),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared form widgets for device dialog ─────────────────────────────────

class _DeviceSection extends StatelessWidget {
  const _DeviceSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
    this.trailing,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1F2A44),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }
}

class _SensorCardV2 extends StatelessWidget {
  const _SensorCardV2({
    required this.sensorKey,
    required this.label,
    required this.selected,
    required this.onToggle,
  });
  final String sensorKey;
  final String label;
  final bool selected;
  final void Function(bool)? onToggle;

  static const Map<String, IconData> _icons = {
    'ignition': Icons.power_settings_new_rounded,
    'battery': Icons.battery_charging_full_rounded,
    'gsm': Icons.signal_cellular_alt_rounded,
    'speed': Icons.speed_rounded,
    'gps': Icons.gps_fixed_rounded,
    'door': Icons.sensor_door_rounded,
    'temperature': Icons.thermostat_rounded,
    'fuel': Icons.local_gas_station_rounded,
    'rpm': Icons.settings_rounded,
    'panic': Icons.warning_amber_rounded,
    'driver': Icons.badge_rounded,
    'hours': Icons.timer_rounded,
    'odometer': Icons.route_rounded,
    'motion': Icons.directions_run_rounded,
    'sos': Icons.emergency_rounded,
    'lock': Icons.lock_rounded,
    'seatbelt': Icons.airline_seat_recline_normal_rounded,
  };

  static const Map<String, Color> _colors = {
    'ignition': Color(0xFF176EEB),
    'battery': Color(0xFF18A558),
    'gsm': Color(0xFF7B2FC4),
    'speed': Color(0xFFE67E22),
    'gps': Color(0xFF176EEB),
    'door': Color(0xFF8FA3BF),
    'temperature': Color(0xFFE74C3C),
    'fuel': Color(0xFFE67E22),
    'rpm': Color(0xFF5A6B84),
    'panic': Color(0xFFE74C3C),
    'driver': Color(0xFF176EEB),
    'hours': Color(0xFF18A558),
    'odometer': Color(0xFF5A6B84),
    'motion': Color(0xFFE67E22),
    'sos': Color(0xFFE74C3C),
    'lock': Color(0xFF7B2FC4),
    'seatbelt': Color(0xFF176EEB),
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[sensorKey] ?? Icons.sensors_rounded;
    final color = _colors[sensorKey] ?? const Color(0xFF176EEB);
    return SizedBox(
      width: 108,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.06)
              : const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                selected ? color.withValues(alpha: 0.4) : const Color(0xFFD6E0EE),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 28,
                color: selected ? color : const Color(0xFFB0BED0)),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? const Color(0xFF1F2A44)
                    : const Color(0xFF8FA3BF),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: selected,
                onChanged: onToggle,
                activeThumbColor: color,
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: Text(
                'Configurar',
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? color : const Color(0xFFB0BED0),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceDropdown extends StatelessWidget {
  const _DeviceDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final List<MapEntry<String, String>> options;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _DeviceSummaryRow extends StatelessWidget {
  const _DeviceSummaryRow({
    required this.label,
    this.value,
    this.chip,
    this.chipColor,
  });
  final String label;
  final String? value;
  final String? chip;
  final Color? chipColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5A6B84),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (chip != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (chipColor ?? const Color(0xFF18A558))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                chip!,
                style: TextStyle(
                  color: chipColor ?? const Color(0xFF18A558),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Flexible(
              child: Text(
                value ?? '—',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: const Color(0xFF1F2A44),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.label, required this.checked});
  final String label;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: checked
                  ? const Color(0xFF18A558)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: checked
                    ? const Color(0xFF18A558)
                    : const Color(0xFFB0BED0),
                width: 1.5,
              ),
            ),
            child: checked
                ? const Icon(Icons.check_rounded,
                    size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: checked
                    ? const Color(0xFF18A558)
                    : const Color(0xFF5A6B84),
                fontWeight:
                    checked ? FontWeight.w600 : FontWeight.w400,
                decoration: checked
                    ? TextDecoration.none
                    : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map icon choice model ──────────────────────────────────────────────────

class _MapIconChoice {
  const _MapIconChoice(this.key, this.label);

  final String key;
  final String label;

  String get assetPath => 'assets/icons/map/$key.png';
}


class _SelectedSensorRow extends StatelessWidget {
  const _SelectedSensorRow({
    required this.sensorKey,
    required this.label,
    required this.onEdit,
    required this.onDelete,
  });

  final String sensorKey;
  final String label;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sensors_outlined,
            size: 18,
            color: Color(0xFF2D8CFF),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF1F2A44),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sensorKey,
                  style: const TextStyle(
                    color: Color(0xFF5A6B84),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar sensor',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Remover sensor',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

typedef _DeviceStatusLabel = String Function(
  TraccarDevice device,
  TraccarPosition? position,
);
typedef _StatusColor = Color Function(String label);
typedef _DeviceAttrs = Map<String, dynamic> Function(
  TraccarDevice device,
  TraccarPosition? position,
);
typedef _DeviceText = String Function(TraccarDevice device);
typedef _FormatDate = String Function(DateTime? value);
typedef _Speed = double Function(TraccarPosition? position);
typedef _IsMoving = bool Function(TraccarPosition? position);
typedef _ValueLabel = String Function(Map<String, dynamic> attrs);
typedef _ValueColor = Color Function(Map<String, dynamic> attrs);
typedef _CommunicationAt = DateTime? Function(
  TraccarDevice device,
  TraccarPosition? position,
);

class _DevicesTable extends StatelessWidget {
  const _DevicesTable({
    required this.devices,
    required this.latestByDevice,
    required this.onEdit,
    required this.statusLabel,
    required this.statusColor,
    required this.attrs,
    required this.vehicleLabel,
    required this.groupLabel,
    required this.formatDateTimeShort,
    required this.formatRelative,
    required this.speedKmh,
    required this.isMoving,
    required this.ignitionLabel,
    required this.ignitionColor,
    required this.batteryLabel,
    required this.batteryColor,
    required this.gsmLabel,
    required this.gsmColor,
    required this.communicationAt,
  });

  final List<TraccarDevice> devices;
  final Map<int, TraccarPosition> latestByDevice;
  final ValueChanged<TraccarDevice> onEdit;
  final _DeviceStatusLabel statusLabel;
  final _StatusColor statusColor;
  final _DeviceAttrs attrs;
  final _DeviceText vehicleLabel;
  final _DeviceText groupLabel;
  final _FormatDate formatDateTimeShort;
  final _FormatDate formatRelative;
  final _Speed speedKmh;
  final _IsMoving isMoving;
  final _ValueLabel ignitionLabel;
  final _ValueColor ignitionColor;
  final _ValueLabel batteryLabel;
  final _ValueColor batteryColor;
  final _ValueLabel gsmLabel;
  final _ValueColor gsmColor;
  final _CommunicationAt communicationAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1DCEB)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const statusWidth = 154.0;
          const equipmentWidth = 206.0;
          const imeiWidth = 176.0;
          const vehicleWidth = 170.0;
          const groupWidth = 126.0;
          const connectionWidth = 184.0;
          const speedWidth = 116.0;
          const ignitionWidth = 130.0;
          const batteryWidth = 126.0;
          const signalWidth = 126.0;
          const actionsWidth = 148.0;
          const contentPadding = 28.0;
          const tableWidth = statusWidth +
              equipmentWidth +
              imeiWidth +
              vehicleWidth +
              groupWidth +
              connectionWidth +
              speedWidth +
              ignitionWidth +
              batteryWidth +
              signalWidth +
              actionsWidth +
              contentPadding;
          final effectiveWidth = constraints.maxWidth > tableWidth
              ? constraints.maxWidth
              : tableWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: effectiveWidth,
              child: Column(
                children: [
                  const SizedBox(
                    height: 52,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          _H(statusWidth, 'Status'),
                          _H(equipmentWidth, 'Equipamento'),
                          _H(imeiWidth, 'IMEI / ID'),
                          _H(vehicleWidth, 'Veículo / Ativo'),
                          _H(groupWidth, 'Grupo'),
                          _H(connectionWidth, 'Última conexão'),
                          _H(speedWidth, 'Velocidade'),
                          _H(ignitionWidth, 'Ignição'),
                          _H(batteryWidth, 'Bateria'),
                          _H(signalWidth, 'Sinal GSM'),
                          _H(actionsWidth, 'Ações'),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFD8E3F1)),
                  Expanded(
                    child: ListView.separated(
                      itemCount: devices.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFDCE6F3)),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final position = latestByDevice[device.id];
                        final details = attrs(device, position);
                        final label = statusLabel(device, position);
                        final labelColor = statusColor(label);
                        final comm = communicationAt(device, position);
                        final ignitionCol = ignitionColor(details);
                        final batteryCol = batteryColor(details);
                        final gsmCol = gsmColor(details);

                        return SizedBox(
                          height: 58,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: statusWidth,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: labelColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: labelColor.withValues(
                                                alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: labelColor,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _R(equipmentWidth, device.name,
                                    weight: FontWeight.w800),
                                _R(
                                  imeiWidth,
                                  (device.uniqueId ?? '').trim().isEmpty
                                      ? 'Não informado'
                                      : (device.uniqueId ?? '').trim(),
                                  color: const Color(0xFF4F6483),
                                ),
                                _R(vehicleWidth, vehicleLabel(device),
                                    color: const Color(0xFF4F6483)),
                                _R(groupWidth, groupLabel(device),
                                    color: const Color(0xFF4F6483)),
                                SizedBox(
                                  width: connectionWidth,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formatDateTimeShort(comm),
                                        style: const TextStyle(
                                          color: Color(0xFF1F2A44),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.2,
                                        ),
                                      ),
                                      Text(
                                        formatRelative(comm),
                                        style: const TextStyle(
                                          color: Color(0xFF176EEB),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _R(
                                  speedWidth,
                                  '${speedKmh(position).toStringAsFixed(0)} km/h',
                                  color: isMoving(position)
                                      ? const Color(0xFF176EEB)
                                      : const Color(0xFF1F2A44),
                                  weight: isMoving(position)
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                ),
                                SizedBox(
                                  width: ignitionWidth,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.power_settings_new_rounded,
                                        size: 16,
                                        color: ignitionCol,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          ignitionLabel(details),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: ignitionCol,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: batteryWidth,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.battery_5_bar_rounded,
                                        size: 16,
                                        color: batteryCol,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          batteryLabel(details),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: batteryCol,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: signalWidth,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.network_cell_rounded,
                                        size: 16,
                                        color: gsmCol,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          gsmLabel(details),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: gsmCol,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: actionsWidth,
                                  child: Row(
                                    children: [
                                      _IconAction(
                                        icon: Icons.remove_red_eye_outlined,
                                        tooltip: 'Ver detalhes',
                                        onTap: () => onEdit(device),
                                      ),
                                      const SizedBox(width: 6),
                                      _IconAction(
                                        icon: Icons.edit_outlined,
                                        tooltip: 'Editar',
                                        onTap: () => onEdit(device),
                                      ),
                                      const SizedBox(width: 6),
                                      _IconAction(
                                        icon: Icons.more_horiz_rounded,
                                        tooltip: 'Mais',
                                        onTap: () => onEdit(device),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.width, this.text);
  final double width;
  final String text;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF52627C),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _R extends StatelessWidget {
  const _R(
    this.width,
    this.text, {
    this.color = const Color(0xFF1F2A44),
    this.weight = FontWeight.w700,
  });
  final double width;
  final String text;
  final Color color;
  final FontWeight weight;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: weight,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 17, color: const Color(0xFF2C5FA8)),
          ),
        ),
      ),
    );
  }
}
