import 'dart:convert';
import 'dart:ui' as ui;
import 'device_editor_sensor_dialog.dart';
import 'device_connectivity.dart';
import 'device_editor_reference_icons.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device_status.dart';
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

enum _DeviceEditorSection {
  vehicle,
  equipment,
  sensors,
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
    _MapIconChoice('excavator', 'Escavadeira'),
    _MapIconChoice('backhoe', 'Retroescavadeira'),
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
    'teltonika': [
      'FMB920',
      'FMB140',
      'FMC130',
      'FMB003',
      'FMB010',
      'FMB110',
      'FMC880'
    ],
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
  // "Configurar" por sensor -- so guarda TRADUCAO/significado (rotulo
  // customizado, o que cada valor bruto quer dizer, icone visual), NUNCA
  // regra de alerta. Regra fica pra outro menu (Automacoes), conforme
  // decidido na sessao. Chave = sensor key canonico (mesmo de
  // _selectedSensorKeys); valor = {label, trueLabel, falseLabel, icon}.
  final Map<String, Map<String, dynamic>> _sensorConfigs = {};
  bool _isActive = true;
  // Equipamento tem camera (MDVR) e deve ser espelhado no CMSV6 -- sem
  // isso marcado, o device fica so no Traccar (GPS puro). A licenca trial
  // do CMSV6 de teste tem limite de 10 devices; sincronizar todo mundo
  // sem distincao esgotou o limite so com rastreadores sem camera
  // nenhuma (2026-10-01). Ver souIsMdvr no Bridge (runCmsv6SyncTick).
  bool _isMdvr = false;
  String? _selectedMapIconKey;
  String? _selectedProtocol;
  String? _selectedOperator;
  String? _selectedManufacturer;
  String? _selectedModel;
  String _selectedTimezone = 'America/Sao_Paulo';
  // Foto do veículo (upload, 2026-09-05) -- data URL base64, salva em
  // attributes.souVehiclePhoto (Traccar não tem campo nativo de foto).
  // Mesmo padrão já usado no cadastro de motorista e no logo/imagem de
  // login do white-label.
  String? _vehiclePhoto;
  String? _vehiclePhotoFileName;

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
    List<TraccarPosition> positions =
        ref.read(positionsProvider).valueOrNull ?? const [];
    if (editing != null &&
        (editing.attributes?['souProtocol']?.toString().trim() ?? '').isEmpty &&
        !positions.any((p) => p.deviceId == editing.id)) {
      try {
        positions = await ref
            .read(positionsProvider.future)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Saved fields remain editable if telemetry is temporarily unavailable.
      }
      if (!mounted) return;
    }
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
      _isMdvr = false;
      _selectedMapIconKey = null;
      _selectedProtocol = null;
      _selectedOperator = null;
      _selectedManufacturer = null;
      _selectedModel = null;
      _selectedTimezone = 'America/Sao_Paulo';
      _vehiclePhoto = null;
      _vehiclePhotoFileName = null;
      _selectedSensorKeys
        ..clear()
        ..addAll(_defaultSensorKeys);
    } else {
      _nameController.text = editing.name;
      _plateController.text = _readPlate(editing);
      _identifierController.text = (editing.uniqueId ?? '').trim();
      _categoryController.text = (editing.category ?? '').trim();
      final connectivity =
          DeviceConnectivity.fromDevice(editing, positions, _operatorApns);
      _phoneController.text = connectivity.phone;
      _portController.text = connectivity.port;
      _apnController.text = connectivity.apn;
      _clientController.text =
          (editing.attributes?['souClient'] ?? '').toString();
      _groupController.text =
          (editing.attributes?['souGroup'] ?? '').toString();
      _isActive = _readActiveFlag(editing);
      _isMdvr = editing.attributes?['souIsMdvr'] == true;
      _vehiclePhoto = editing.attributes?['souVehiclePhoto']?.toString();
      _vehiclePhotoFileName = null;
      _selectedMapIconKey = _normalizeMapIconKey(
        editing.attributes?['souMapIcon']?.toString(),
      );
      _selectedProtocol = connectivity.protocol;
      _selectedOperator = connectivity.operator;
      _selectedManufacturer =
          editing.attributes?['souManufacturer']?.toString();
      _selectedModel = editing.attributes?['souModel']?.toString();
      _selectedTimezone =
          (editing.attributes?['souTimezone'] ?? 'America/Sao_Paulo')
              .toString();
      _setSelectedSensorsFromDevice(editing);
    }

    var activeEditorSection = _DeviceEditorSection.vehicle;
    var sensorsReviewed = false;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        final desktop = MediaQuery.sizeOf(dialogContext).width >= 1180;
        return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: desktop
                ? const EdgeInsets.fromLTRB(226, 104, 36, 38)
                : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: SizedBox(
                width: 1104,
                height: 540,
                child: StatefulBuilder(builder: (context, setModalState) {
                  final hasImei =
                      _identifierController.text.trim().length >= 10;
                  final hasProtocol = _selectedProtocol != null &&
                      _portController.text.trim().isNotEmpty;
                  final hasSensors = sensorsReviewed;
                  final hasGroup = _groupController.text.trim().isNotEmpty;
                  final isMobile = MediaQuery.sizeOf(context).width < 760;
                  return _DeviceEditorLayout(
                    title: editing == null
                        ? 'Novo equipamento'
                        : 'Editar equipamento',
                    isMobile: isMobile,
                    isEditing: editing != null,
                    onClose: _saving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    navigation: _DeviceEditorNavigation(
                        activeSection: activeEditorSection,
                        vertical: !isMobile,
                        vehicleReady: _nameController.text.trim().isNotEmpty &&
                            _plateController.text.trim().isNotEmpty,
                        equipmentReady: hasImei && hasProtocol,
                        sensorsReady: hasSensors,
                        onChanged: (section) =>
                            setModalState(() => activeEditorSection = section)),
                    form: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          if (activeEditorSection ==
                              _DeviceEditorSection.vehicle) ...[
                            const _PixelEditorHeading('Dados do veículo',
                                'Identificação, equipamento vinculado e visual no mapa.'),
                            const _PixelEditorGroup('car', 'DADOS GERAIS'),
                            const SizedBox(height: 11),
                            SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _clientController,
                                  decoration: const InputDecoration(
                                    labelText: 'Cliente / Empresa',
                                    hintText: 'Selecione o cliente',
                                  ),
                                )),
                            const SizedBox(height: 13),
                            Row(children: [
                              Expanded(
                                  child: SizedBox(
                                      height: 36,
                                      child: TextField(
                                        controller: _nameController,
                                        onChanged: (_) => setModalState(() {}),
                                        decoration: const InputDecoration(
                                          labelText: 'Nome do Veículo *',
                                          hintText: 'Digite o nome do veículo',
                                        ),
                                      ))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: SizedBox(
                                      height: 36,
                                      child: TextField(
                                        controller: _plateController,
                                        decoration: const InputDecoration(
                                          labelText: 'Placa *',
                                          hintText: 'ABC1D23',
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'[A-Za-z0-9-]')),
                                        ],
                                      )))
                            ]),
                            const _PixelEditorDivider(),
                            Row(children: [
                              Container(
                                  width: 66,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF9FBFF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFCCDBEE)
                                              .withValues(alpha: 1))),
                                  child: (_vehiclePhoto ?? '').isNotEmpty
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(7),
                                          child: Image.network(_vehiclePhoto!,
                                              fit: BoxFit.cover))
                                      : const Icon(Icons.image_outlined,
                                          size: 16, color: Color(0xFF9AAFCA))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    const Text('Foto do veículo',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF657E9F))),
                                    const SizedBox(height: 5),
                                    Row(children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                            minimumSize: const Size(0, 28),
                                            maximumSize:
                                                const Size(double.infinity, 28),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 11),
                                            textStyle: const TextStyle(
                                                fontFamily: 'DeviceEditorSegoe',
                                                fontSize: 10)),
                                        onPressed: () =>
                                            _pickVehiclePhoto(setModalState),
                                        icon: const Icon(
                                          Icons.image_outlined,
                                          size: 16,
                                        ),
                                        label: Text(
                                          (_vehiclePhoto ?? '').isEmpty
                                              ? 'Escolher foto'
                                              : 'Trocar foto',
                                        ),
                                      ),
                                      if ((_vehiclePhoto ?? '').isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () =>
                                              _clearVehiclePhoto(setModalState),
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 16,
                                          ),
                                          label: const Text('Remover'),
                                        )
                                      ]
                                    ]),
                                    if ((_vehiclePhotoFileName ?? '')
                                        .isNotEmpty)
                                      Text(_vehiclePhotoFileName!,
                                          style: const TextStyle(
                                              fontSize: 9,
                                              color: Color(0xFF8194B1)))
                                  ]))
                            ]),
                            const _PixelEditorDivider(),
                            const _PixelEditorGroup(
                                'chip', 'IDENTIFICAÇÃO DO RASTREADOR'),
                            const SizedBox(height: 11),
                            Row(children: [
                              Expanded(
                                  child: SizedBox(
                                      height: 36,
                                      child: TextField(
                                        controller: _identifierController,
                                        onChanged: (_) => setModalState(() {}),
                                        decoration: const InputDecoration(
                                          labelText: 'IMEI *',
                                          hintText:
                                              'Digite o IMEI do dispositivo',
                                        ),
                                      ))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: SizedBox(
                                      height: 36,
                                      child: _DeviceDropdown(
                                        label: 'Fabricante',
                                        value: _selectedManufacturer,
                                        options: _manufacturerOptions,
                                        onChanged: (v) => setModalState(() {
                                          _selectedManufacturer = v;
                                          _selectedModel = null;
                                        }),
                                      )))
                            ]),
                            const SizedBox(height: 13),
                            Row(children: [
                              Expanded(
                                  child: SizedBox(
                                      height: 36,
                                      child: _selectedManufacturer != null &&
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
                                                  .map((m) => MapEntry(m, m))
                                                  .toList(),
                                              onChanged: (v) => setModalState(
                                                  () => _selectedModel = v),
                                            )
                                          : TextField(
                                              decoration: InputDecoration(
                                                labelText: 'Modelo',
                                                hintText: 'Selecione o modelo',
                                                enabled:
                                                    _selectedManufacturer !=
                                                        null,
                                              ),
                                              onChanged: (v) => setModalState(
                                                  () => _selectedModel =
                                                      v.isEmpty ? null : v),
                                            ))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: SizedBox(
                                      height: 36,
                                      child: TextField(
                                        controller: _groupController,
                                        onChanged: (_) => setModalState(() {}),
                                        decoration: const InputDecoration(
                                          labelText: 'Frota / Grupo',
                                          hintText: 'Informe a frota ou grupo',
                                        ),
                                      )))
                            ]),
                            const _PixelEditorDivider(),
                            const _PixelEditorGroup('map', 'ÍCONE DO VEÍCULO'),
                            const SizedBox(height: 11),
                            _VehicleVisualPicker(
                              choices: _mapIconChoices,
                              selectedKey: _selectedMapIconKey,
                              onSelected: (key) => setModalState(() {
                                _selectedMapIconKey = key;
                              }),
                            )
                          ],
                          if (activeEditorSection ==
                              _DeviceEditorSection.equipment) ...[
                            const _PixelEditorHeading('Chip e equipamento',
                                'Parâmetros de conectividade do rastreador.',
                                gap: 11),
                            const _PixelEditorGroup('signal', 'CONECTIVIDADE'),
                            const SizedBox(height: 11),
                            Row(children: [
                              Expanded(
                                  child: SizedBox(
                                      height: 36,
                                      child: TextField(
                                        controller: _phoneController,
                                        decoration: const InputDecoration(
                                          labelText: 'Chip / Telefone',
                                          hintText: 'Ex: (11) 99999-9999',
                                        ),
                                      ))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: SizedBox(
                                      height: 36,
                                      child: _DeviceDropdown(
                                        label: 'Operadora',
                                        value: _selectedOperator,
                                        options: [
                                          ..._operatorOptions,
                                          if (_selectedOperator != null &&
                                              !_operatorOptions.any((o) =>
                                                  o.key == _selectedOperator))
                                            MapEntry(_selectedOperator!,
                                                _selectedOperator!),
                                        ],
                                        onChanged: (v) => setModalState(() {
                                          _selectedOperator = v;
                                          final apn = _operatorApns[v];
                                          if (apn != null) {
                                            _apnController.text = apn;
                                          }
                                        }),
                                      )))
                            ]),
                            const SizedBox(height: 10),
                            SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _apnController,
                                  decoration: const InputDecoration(
                                    labelText: 'APN',
                                    hintText: 'Digite o APN',
                                  ),
                                )),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                  child: SizedBox(
                                      height: 36,
                                      child: _DeviceDropdown(
                                        label: 'Protocolo',
                                        value: _selectedProtocol,
                                        options: [
                                          ..._protocolOptions,
                                          if (_selectedProtocol != null &&
                                              !_protocolOptions.any((o) =>
                                                  o.key == _selectedProtocol))
                                            MapEntry(_selectedProtocol!,
                                                _selectedProtocol!),
                                        ],
                                        onChanged: (v) => setModalState(() {
                                          _selectedProtocol = v;
                                          final port = _protocolPorts[v];
                                          if (editing == null &&
                                              port != null &&
                                              _portController.text.isEmpty) {
                                            _portController.text = port;
                                          }
                                        }),
                                      ))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: SizedBox(
                                      height: 36,
                                      child: TextField(
                                        controller: _portController,
                                        onChanged: (_) => setModalState(() {}),
                                        decoration: const InputDecoration(
                                          labelText: 'Porta',
                                          hintText:
                                              'Informe a porta configurada',
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                      )))
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                  child: SizedBox(
                                      height: 36,
                                      child: _DeviceDropdown(
                                        label: 'Fuso Horário',
                                        value: _selectedTimezone,
                                        options: _timezoneOptions,
                                        onChanged: (v) => setModalState(() =>
                                            _selectedTimezone =
                                                v ?? _selectedTimezone),
                                      ))),
                              const SizedBox(width: 12),
                              const Expanded(child: SizedBox())
                            ]),
                            if (editing != null) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: () => _openAccumulatorsDialog(
                                    editing,
                                    positions
                                        .where((p) => p.deviceId == editing.id)
                                        .cast<TraccarPosition?>()
                                        .firstOrNull,
                                  ),
                                  icon: const Icon(Icons.speed_outlined,
                                      size: 16),
                                  label: const Text(
                                      'Ajustar odômetro / horímetro'),
                                ),
                              ),
                            ],
                            const _PixelEditorDivider(space: 10),
                            _PixelEditorGroup(
                                'settings',
                                editing == null
                                    ? 'CONFIGURAÇÃO INICIAL'
                                    : 'CONFIGURAÇÃO DO EQUIPAMENTO'),
                            const SizedBox(height: 11),
                            _PixelEditorToggle(
                                title: 'Ativo / Inativo',
                                subtitle: _isActive ? 'Ativo' : 'Inativo',
                                control: Switch(
                                  value: _isActive,
                                  onChanged: _saving
                                      ? null
                                      : (v) =>
                                          setModalState(() => _isActive = v),
                                )),
                            const SizedBox(height: 9),
                            _PixelEditorToggle(
                                title: 'Equipamento com câmera (MDVR)',
                                subtitle: _isMdvr
                                    ? 'Câmeras habilitadas'
                                    : 'Sem câmeras',
                                control: Switch(
                                  value: _isMdvr,
                                  onChanged: _saving
                                      ? null
                                      : (v) => setModalState(() => _isMdvr = v),
                                ))
                          ],
                          if (activeEditorSection ==
                              _DeviceEditorSection.sensors) ...[
                            const _PixelEditorHeading('Sensores e atuadores',
                                'Ative os sensores suportados pelo hardware do rastreador.'),
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
                                SizedBox(
                                  child: Column(
                                    children: [
                                      for (var i = 0;
                                          i < _sensorOptions.length;
                                          i++)
                                        _SensorListRow(
                                          sensorKey: _sensorOptions[i].key,
                                          label: _sensorOptions[i].value,
                                          liveValue: editing == null
                                              ? null
                                              : _liveSensorValueLabel(editing,
                                                  _sensorOptions[i].key),
                                          customLabel: _sensorConfigs[
                                                  _sensorOptions[i].key]
                                              ?['label'] as String?,
                                          isLast:
                                              i == _sensorOptions.length - 1,
                                          selected: _selectedSensorKeys
                                              .contains(_sensorOptions[i].key),
                                          onToggle: _saving
                                              ? null
                                              : (v) => setModalState(() {
                                                    sensorsReviewed = true;
                                                    final key =
                                                        _sensorOptions[i].key;
                                                    if (v) {
                                                      _selectedSensorKeys
                                                          .add(key);
                                                    } else {
                                                      _selectedSensorKeys
                                                          .remove(key);
                                                    }
                                                  }),
                                          onConfigure: _saving
                                              ? null
                                              : () async {
                                                  final key =
                                                      _sensorOptions[i].key;
                                                  final label =
                                                      _sensorOptions[i].value;
                                                  final updated =
                                                      await _openSensorConfigDialog(
                                                    sensorKey: key,
                                                    sensorLabel: label,
                                                  );
                                                  if (updated == null) {
                                                    return;
                                                  }
                                                  setModalState(() {
                                                    sensorsReviewed = true;
                                                    _sensorConfigs[key] =
                                                        updated;
                                                    _selectedSensorKeys
                                                        .add(key);
                                                  });
                                                },
                                        ),
                                    ],
                                  ),
                                ),
                                if (_selectedSensorKeys.any((k) =>
                                    !_sensorOptions
                                        .any((o) => o.key == k))) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Sensores personalizados',
                                    style: TextStyle(
                                      color: Color(0xFF526D94),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
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
                                                sensorsReviewed = true;
                                                _selectedSensorKeys
                                                    .remove(sensorKey);
                                                _selectedSensorKeys.add(
                                                  _normalizeSensorKey(updated),
                                                );
                                              });
                                            },
                                      onDelete: _saving
                                          ? null
                                          : () => setModalState(() {
                                                sensorsReviewed = true;
                                                _selectedSensorKeys
                                                    .remove(sensorKey);
                                              }),
                                    ),
                                ],
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed: _saving
                                        ? null
                                        : () async {
                                            final created =
                                                await _openSensorInputDialog();
                                            if (created == null) {
                                              return;
                                            }
                                            setModalState(() {
                                              sensorsReviewed = true;
                                              _selectedSensorKeys.add(
                                                _normalizeSensorKey(created),
                                              );
                                            });
                                          },
                                    icon:
                                        const Icon(Icons.add_rounded, size: 16),
                                    label: const Text(
                                        'Adicionar sensor personalizado'),
                                  ),
                                ),
                              ],
                            )
                          ]
                        ])),
                    summary: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 13),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFF),
                              borderRadius: BorderRadius.circular(9),
                              border:
                                  Border.all(color: const Color(0xFFDDE5F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Resumo do Dispositivo',
                                  style: TextStyle(
                                    color: Color(0xFF1F2A44),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    height: 15 / 11,
                                  ),
                                ),
                                const SizedBox(height: 13),
                                _DeviceSummaryRow(
                                  label: editing == null
                                      ? 'Status inicial'
                                      : 'Status',
                                  chip: _isActive ? 'Ativo' : 'Inativo',
                                  chipColor: _isActive
                                      ? const Color(0xFF18A558)
                                      : const Color(0xFF5E6B82),
                                ),
                                _DeviceSummaryRow(
                                  label: 'Grupo',
                                  value: _groupController.text.trim().isEmpty
                                      ? 'Não definido'
                                      : _groupController.text.trim(),
                                ),
                                _DeviceSummaryRow(
                                  label: 'Protocolo',
                                  value: _selectedProtocol == null
                                      ? 'Não informado'
                                      : (_protocolOptions
                                              .where((e) =>
                                                  e.key == _selectedProtocol)
                                              .firstOrNull
                                              ?.value ??
                                          _selectedProtocol!),
                                ),
                                _DeviceSummaryRow(
                                  label: 'Porta',
                                  value: _portController.text.trim().isEmpty
                                      ? 'Não informada'
                                      : _portController.text.trim(),
                                ),
                                const _DeviceSummaryRow(
                                  label: 'Última validação',
                                  value: '—',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 13),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFF),
                              borderRadius: BorderRadius.circular(9),
                              border:
                                  Border.all(color: const Color(0xFFDDE5F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  editing == null
                                      ? 'Checklist de criação'
                                      : 'Checklist de edição',
                                  style: const TextStyle(
                                    color: Color(0xFF1F2A44),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    height: 15 / 11,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _ChecklistItem(
                                  label: 'IMEI informado',
                                  checked: hasImei,
                                ),
                                _ChecklistItem(
                                  label: 'Protocolo e porta informados',
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
                          )
                        ])),
                    actions: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => setModalState(() => activeEditorSection =
                                  _DeviceEditorSection.sensors),
                          icon: const DeviceEditorReferenceIcon('tune',
                              size: 14, color: Color(0xFF60718D)),
                          label: const Text('Configurar Sensores'),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving
                              ? null
                              : () async {
                                  final ok = editing == null
                                      ? await _createDevice()
                                      : await _updateDevice(editing);
                                  if (!mounted || !dialogContext.mounted) {
                                    return;
                                  }
                                  if (ok) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                },
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const DeviceEditorReferenceIcon('save',
                                  size: 14, color: Colors.white),
                          label: Text(
                            _saving
                                ? 'Salvando...'
                                : (editing == null
                                    ? 'Salvar Dispositivo'
                                    : 'Salvar Alterações'),
                          ),
                        ),
                      )
                    ],
                  );
                })));
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

    _sensorConfigs.clear();
    final rawConfigs = device.attributes?['souSensorConfig'];
    if (rawConfigs is Map) {
      for (final entry in rawConfigs.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty || entry.value is! Map) continue;
        _sensorConfigs[key] = Map<String, dynamic>.from(entry.value as Map);
      }
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

  // "Configurar" de um sensor catalogado -- só define TRADUÇÃO (rótulo
  // customizado + o que cada valor bruto significa + ícone de exibição),
  // nunca regra de alerta (isso fica pro motor de regras/Automações,
  // conforme decidido). Resultado salvo em attributes.souSensorConfig.
  Future<Map<String, dynamic>?> _openSensorConfigDialog({
    required String sensorKey,
    required String sensorLabel,
  }) async {
    final existing = _sensorConfigs[sensorKey] ?? const {};
    final labelCtrl = TextEditingController(
      text: (existing['label'] ?? '').toString(),
    );
    final trueLabelCtrl = TextEditingController(
      text: (existing['trueLabel'] ?? '').toString(),
    );
    final falseLabelCtrl = TextEditingController(
      text: (existing['falseLabel'] ?? '').toString(),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: const Color(0x38233852),
      builder: (dialogContext) {
        return BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Dialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: DeviceEditorSensorDialog(
                    sensorLabel: sensorLabel,
                    labelController: labelCtrl,
                    trueController: trueLabelCtrl,
                    falseController: falseLabelCtrl,
                    onClose: () => Navigator.of(dialogContext).pop(),
                    onSave: () {
                      final config = <String, dynamic>{
                        if (labelCtrl.text.trim().isNotEmpty)
                          'label': labelCtrl.text.trim(),
                        if (trueLabelCtrl.text.trim().isNotEmpty)
                          'trueLabel': trueLabelCtrl.text.trim(),
                        if (falseLabelCtrl.text.trim().isNotEmpty)
                          'falseLabel': falseLabelCtrl.text.trim(),
                      };
                      Navigator.of(dialogContext).pop(config);
                    })));
      },
    );
    labelCtrl.dispose();
    trueLabelCtrl.dispose();
    falseLabelCtrl.dispose();
    return result;
  }

  // Valor ao vivo de um sensor pra mostrar na linha da lista (ex: "11" pra
  // satélites) -- reaproveita o catálogo canônico já usado no painel de
  // telemetria do veículo, sem inventar formatação nova.
  String? _liveSensorValueLabel(TraccarDevice device, String sensorKey) {
    final sections = buildSensorDisplaySections(
      deviceAttributes: device.attributes,
      includeTechnical: true,
      preferredKeys: [sensorKey],
    );
    for (final section in sections) {
      for (final item in section.items) {
        if (item.key == sensorKey) return item.value;
      }
    }
    return null;
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

  Future<void> _pickVehiclePhoto(StateSetter setModalState) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    final base64Data = base64Encode(file.bytes!);
    final ext = (file.extension ?? 'jpg').toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    setModalState(() {
      _vehiclePhoto = 'data:$mime;base64,$base64Data';
      _vehiclePhotoFileName = file.name;
    });
  }

  void _clearVehiclePhoto(StateSetter setModalState) {
    setModalState(() {
      _vehiclePhoto = null;
      _vehiclePhotoFileName = null;
    });
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
            'souIsMdvr': _isMdvr,
            if ((_vehiclePhoto ?? '').trim().isNotEmpty)
              'souVehiclePhoto': _vehiclePhoto,
            if ((_selectedMapIconKey ?? '').trim().isNotEmpty)
              'souMapIcon': _selectedMapIconKey,
            'souSensors': selectedSensors,
            'souSensorConfig': _sensorConfigs,
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
      'souIsMdvr': _isMdvr,
      'souSensors': selectedSensors,
      'souSensorConfig': _sensorConfigs,
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
    if ((_vehiclePhoto ?? '').trim().isNotEmpty) {
      attributes['souVehiclePhoto'] = _vehiclePhoto;
    } else {
      attributes.remove('souVehiclePhoto');
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

  Future<void> _openAccumulatorsDialog(
    TraccarDevice device,
    TraccarPosition? position,
  ) async {
    final currentDistanceM =
        (position?.attributes?['totalDistance'] as num?)?.toDouble() ?? 0;
    final currentHoursMs =
        (position?.attributes?['hours'] as num?)?.toDouble() ?? 0;
    final odometerController = TextEditingController(
      text: (currentDistanceM / 1000).toStringAsFixed(1),
    );
    final hourmeterController = TextEditingController(
      text: (currentHoursMs / 3600000).toStringAsFixed(1),
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Ajustar odômetro e horímetro'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'O equipamento não envia odômetro/horímetro de fábrica -- '
                  'esses valores são calculados pela plataforma a partir do '
                  'trajeto GPS. Ajuste aqui para alinhar com o painel real '
                  'do veículo.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: odometerController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Odômetro (km)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hourmeterController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Horímetro (horas)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;

      final odometerKm = double.tryParse(
        odometerController.text.trim().replaceAll(',', '.'),
      );
      final hourmeterH = double.tryParse(
        hourmeterController.text.trim().replaceAll(',', '.'),
      );
      if (odometerKm == null || hourmeterH == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe valores numéricos válidos.')),
        );
        return;
      }

      final session = ref.read(sessionProvider);
      final client = ref.read(traccarClientProvider);
      try {
        await client.updateEntity(
          path: '/devices/${device.id}/accumulators',
          cookie: session.cookie,
          authHeader: session.authHeader,
          body: {
            'deviceId': device.id,
            'totalDistance': odometerKm * 1000,
            'hours': hourmeterH * 3600000,
          },
        );
        ref.invalidate(positionsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Odômetro e horímetro atualizados.'),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error))),
        );
      }
    } finally {
      odometerController.dispose();
      hourmeterController.dispose();
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
    if (isDeviceOffline(device.status)) return true;
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

    return _DeviceListSurface(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DeviceListHeading(),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 8.0;
                  final width = constraints.maxWidth;
                  final columns = width >= 1040
                      ? 6
                      : width >= 860
                          ? 4
                          : width >= 640
                              ? 3
                              : width >= 280
                                  ? 2
                                  : 1;
                  final cardWidth =
                      ((width - (columns - 1) * spacing) / columns)
                          .clamp(width < 420 ? 120.0 : 150.0, 220.0);

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
              const SizedBox(height: 12),
              Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFDDE5F0)),
                      borderRadius: BorderRadius.circular(9)),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 980;
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xCCFFFFFF),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFD6E2F2)),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText:
                                      'Buscar equipamento, IMEI ou placa...',
                                  hintStyle: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF74839B),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    size: 16,
                                    color: Color(0xFF60718D),
                                  ),
                                  border: InputBorder.none,
                                  filled: false,
                                  prefixIconConstraints: BoxConstraints(
                                      minWidth: 36, minHeight: 34),
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 0),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _TopActionButton(
                                  label: 'Filtros',
                                  icon: Icons.filter_alt_outlined,
                                  onTap: () => setState(() =>
                                      _showFilterChips = !_showFilterChips),
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
                                  onTap: _saving
                                      ? () {}
                                      : () => _openDeviceDialog(),
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
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xCCFFFFFF),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFD6E2F2)),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText:
                                      'Buscar equipamento, IMEI ou placa...',
                                  hintStyle: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF74839B),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    size: 16,
                                    color: Color(0xFF60718D),
                                  ),
                                  border: InputBorder.none,
                                  filled: false,
                                  prefixIconConstraints: BoxConstraints(
                                      minWidth: 36, minHeight: 34),
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 0),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _TopActionButton(
                            label: 'Filtros',
                            icon: Icons.filter_alt_outlined,
                            onTap: () => setState(
                                () => _showFilterChips = !_showFilterChips),
                          ),
                          const SizedBox(width: 8),
                          _TopActionButton(
                            label: 'Exportar',
                            icon: Icons.download_outlined,
                            onTap: () =>
                                _exportVisible(visible, latestByDevice),
                          ),
                          const SizedBox(width: 8),
                          _TopActionButton(
                            label: 'Novo Equipamento',
                            icon: Icons.add_rounded,
                            primary: true,
                            onTap: _saving ? () {} : () => _openDeviceDialog(),
                          ),
                        ],
                      );
                    },
                  )),
              if (_showFilterChips) ...[
                const SizedBox(height: 12),
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
                              : const Color(0xFFD6E2F2),
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
              const SizedBox(height: 12),
              Expanded(
                  child: _DeviceListTableArea(
                      count: visible.length,
                      total: devices.length,
                      child: visible.isEmpty
                          ? const SizedBox(
                              height: 240,
                              child: _PanelMessageState(
                                icon: Icons.search_off_rounded,
                                message:
                                    'Nenhum equipamento encontrado com os filtros atuais.',
                              ),
                            )
                          : _DevicesTable(
                              devices: visible,
                              latestByDevice: latestByDevice,
                              onEdit: (device) =>
                                  _openDeviceDialog(editing: device),
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
                            ))),
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

class _DeviceListSurface extends StatelessWidget {
  const _DeviceListSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
        data: base.copyWith(
            textTheme: base.textTheme
                .apply(fontFamily: 'DeviceEditorSegoe')
                .copyWith(
                    bodyLarge: const TextStyle(
                        fontFamily: 'DeviceEditorSegoe',
                        fontSize: 11,
                        color: Color(0xFF1F2A44))),
            chipTheme: base.chipTheme.copyWith(
                labelStyle: const TextStyle(
                    fontFamily: 'DeviceEditorSegoe', fontSize: 10)),
            inputDecorationTheme: base.inputDecorationTheme.copyWith(
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                filled: false)),
        child: DefaultTextStyle(
            style: const TextStyle(
                fontFamily: 'DeviceEditorSegoe',
                fontSize: 11,
                color: Color(0xFF1F2A44)),
            child: Padding(padding: const EdgeInsets.all(16), child: child)));
  }
}

class _DeviceListHeading extends StatelessWidget {
  const _DeviceListHeading();
  @override
  Widget build(BuildContext context) =>
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Dispositivos',
            style: TextStyle(
                fontSize: 18,
                height: 24 / 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -.3,
                color: Color(0xFF1F2A44))),
        SizedBox(height: 3),
        Text('Equipamentos, comunicação e status da frota.',
            style:
                TextStyle(fontSize: 10, height: 1.4, color: Color(0xFF7E91AD)))
      ]);
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.width,
      required this.icon,
      required this.title,
      required this.value,
      required this.hint,
      required this.color});
  final double width;
  final IconData icon;
  final String title, hint;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      width: width,
      height: 65,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDE5F0)),
          borderRadius: BorderRadius.circular(9)),
      child: Row(children: [
        Container(
            width: 29,
            height: 29,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 9),
        Expanded(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 9, height: 13 / 9, color: Color(0xFF60718D))),
              Text('$value',
                  style: const TextStyle(
                      fontSize: 20,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2A44))),
              Text(hint,
                  style: TextStyle(fontSize: 9, height: 12 / 9, color: color))
            ]))
      ]));
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton(
      {required this.label,
      required this.icon,
      required this.onTap,
      this.primary = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) {
    final color = primary
        ? Theme.of(context).colorScheme.onPrimary
        : const Color(0xFF60718D);
    return Material(
        color: primary ? Theme.of(context).colorScheme.primary : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
                color: primary
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFFD6E2F2))),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
                height: 33,
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 7),
                      Text(label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color))
                    ])))));
  }
}

class _DeviceListTableArea extends StatelessWidget {
  const _DeviceListTableArea(
      {required this.child, required this.count, required this.total});
  final Widget child;
  final int count, total;
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDE5F0)),
          borderRadius: BorderRadius.circular(9)),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(children: [
            Expanded(child: SingleChildScrollView(child: child)),
            Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                    color: Color(0xFFFBFCFF),
                    border: Border(top: BorderSide(color: Color(0xFFE8EEF7)))),
                child: Row(children: [
                  Text('$count de $total equipamentos',
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF8B9CB2))),
                  const Spacer(),
                  const Expanded(
                      child: Text('Colunas adicionais na rolagem horizontal',
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 9, color: Color(0xFF8B9CB2))))
                ]))
          ])));
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

// Measures copied from the approved HTML preview; theme scoped to this editor.
class _DeviceEditorLayout extends StatelessWidget {
  const _DeviceEditorLayout(
      {required this.title,
      required this.isMobile,
      required this.isEditing,
      required this.onClose,
      required this.navigation,
      required this.form,
      required this.summary,
      required this.actions});
  final String title;
  final bool isMobile;
  final bool isEditing;
  final VoidCallback? onClose;
  final Widget navigation, form, summary;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    const line = Color(0xFFDDE5F0);
    final accent = Theme.of(context).colorScheme.primary;
    final base = Theme.of(context);
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Color(0xFFD6E2F2)));
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    final theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'DeviceEditorSegoe').copyWith(
          bodyLarge: TextStyle(
              fontFamily: 'DeviceEditorSegoe',
              fontSize: 11,
              height: 14 / 11,
              color: Color(0xFF1F2A44)),
          bodyMedium: TextStyle(
              fontFamily: 'DeviceEditorSegoe',
              fontSize: 11,
              height: 14 / 11,
              color: Color(0xFF1F2A44))),
      primaryTextTheme:
          base.primaryTextTheme.apply(fontFamily: 'DeviceEditorSegoe'),
      inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: Color(0xFFF8FAFF),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          labelStyle: TextStyle(
              fontFamily: 'DeviceEditorSegoe',
              fontSize: 12,
              color: Color(0xFF6D82A3)),
          floatingLabelStyle: TextStyle(
              fontFamily: 'DeviceEditorSegoe',
              fontSize: 12,
              color: Color(0xFF6D82A3)),
          hintStyle: TextStyle(
              fontFamily: 'DeviceEditorSegoe',
              fontSize: 11,
              color: Color(0xFF97A7BD)),
          border: border,
          enabledBorder: border,
          focusedBorder:
              border.copyWith(borderSide: BorderSide(color: accent))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: shape,
              minimumSize: Size(0, 33),
              maximumSize: Size(double.infinity, 33),
              padding: EdgeInsets.symmetric(horizontal: 15),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: TextStyle(
                  fontFamily: 'DeviceEditorSegoe',
                  fontSize: 11,
                  fontWeight: FontWeight.w600))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: Color(0xFF60718D),
              side: BorderSide(color: Color(0xFFD6E2F2)),
              shape: shape,
              minimumSize: Size(0, 33),
              maximumSize: Size(double.infinity, 33),
              padding: EdgeInsets.symmetric(horizontal: 15),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: TextStyle(
                  fontFamily: 'DeviceEditorSegoe',
                  fontSize: 11,
                  fontWeight: FontWeight.w600))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: Color(0xFF60718D),
              textStyle:
                  TextStyle(fontFamily: 'DeviceEditorSegoe', fontSize: 10))),
      switchTheme: SwitchThemeData(
          trackOutlineWidth: WidgetStatePropertyAll(0),
          thumbColor: WidgetStatePropertyAll(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? accent
                  : Color(0xFFE7EDF6))),
    );
    final styledForm = Theme(
        data: theme,
        child: DefaultTextStyle(
            style: TextStyle(
                fontFamily: 'DeviceEditorSegoe',
                fontSize: 11,
                color: Color(0xFF1F2A44)),
            child: form));
    final left = Container(
        width: 194,
        padding: EdgeInsets.fromLTRB(10, 17, 10, 17),
        decoration:
            BoxDecoration(border: Border(right: BorderSide(color: line))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              height: 12,
              child: _DeviceEditorCaption(isEditing
                  ? 'EDIÇÃO DO DISPOSITIVO'
                  : 'CADASTRO DO DISPOSITIVO')),
          SizedBox(height: 13),
          navigation,
          Spacer(),
          Divider(height: 1, color: Color(0xFFEDF1F6)),
          SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  fontSize: 10, height: 1.6, color: Color(0xFF536E93))),
          Text(
              isEditing
                  ? 'Revise os dados e a configuração deste equipamento.'
                  : 'Cadastre um novo rastreador e defina seus parâmetros iniciais.',
              style: TextStyle(
                  fontSize: 10, height: 1.6, color: Color(0xFF8A9BB2)))
        ]));
    final right = Container(
        width: 232,
        padding: EdgeInsets.fromLTRB(10, 17, 10, 17),
        decoration:
            BoxDecoration(border: Border(left: BorderSide(color: line))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              height: 12, child: _DeviceEditorCaption('RESUMO DO DISPOSITIVO')),
          SizedBox(height: 13),
          Expanded(child: summary)
        ]));
    final content = isMobile
        ? Column(children: [
            Padding(padding: EdgeInsets.all(10), child: navigation),
            Expanded(
                child: Column(children: [
              Expanded(
                  flex: 3,
                  child:
                      Padding(padding: EdgeInsets.all(12), child: styledForm)),
              Expanded(flex: 2, child: summary)
            ]))
          ])
        : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            left,
            Expanded(
                child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 17, 16, 17),
                    child: styledForm)),
            right
          ]);
    return Theme(
        data: theme,
        child: DefaultTextStyle(
            style: TextStyle(
                fontFamily: 'DeviceEditorSegoe',
                fontSize: 12,
                color: Color(0xFF1F2A44)),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.white.withValues(alpha: .5),
                          spreadRadius: 11)
                    ]),
                child: Column(children: [
                  Container(
                      height: 48,
                      padding: EdgeInsets.symmetric(horizontal: 25),
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: line))),
                      child: Row(children: [
                        Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                border: Border(
                                    bottom:
                                        BorderSide(color: accent, width: 3))),
                            child: Text(title,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: accent))),
                        Spacer(),
                        SizedBox(
                            width: 28,
                            height: 28,
                            child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: onClose,
                                icon: DeviceEditorReferenceIcon('close',
                                    size: 16, color: Color(0xFF8194AF)),
                                color: Color(0xFF8194AF)))
                      ])),
                  Expanded(child: content),
                  Container(
                      height: isMobile ? null : 54,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: line))),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                  for (var i = 0; i < actions.length; i++) ...[
                                    if (i > 0) SizedBox(height: 6),
                                    actions[i]
                                  ]
                                ])
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                  for (var i = 0; i < actions.length; i++) ...[
                                    if (i > 0) SizedBox(width: 9),
                                    SizedBox(
                                        width: [74.7, 153.58, 141.08][i],
                                        height: 33,
                                        child: actions[i])
                                  ]
                                ]))
                ]))));
  }
}

class _PixelEditorHeading extends StatelessWidget {
  const _PixelEditorHeading(this.title, this.subtitle, {this.gap = 14});
  final String title, subtitle;
  final double gap;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            height: 24,
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    height: 24 / 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.3))),
        const SizedBox(height: 4),
        SizedBox(
            height: 15,
            child: Text(subtitle,
                style: const TextStyle(
                    fontSize: 10, height: 1.5, color: Color(0xFF7E91AD)))),
        SizedBox(height: gap)
      ]);
}

class _PixelEditorGroup extends StatelessWidget {
  const _PixelEditorGroup(this.icon, this.text);
  final String icon;
  final String text;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 14,
      child: Row(children: [
        DeviceEditorReferenceIcon(icon,
            size: 14, color: const Color(0xFF7C97BD)),
        const SizedBox(width: 7),
        Text(text,
            style: const TextStyle(
                fontSize: 10,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF526D94)))
      ]));
}

class _PixelEditorDivider extends StatelessWidget {
  const _PixelEditorDivider({this.space = 13});
  final double space;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.symmetric(vertical: space),
      child: const Divider(height: 1, thickness: 1, color: Color(0xFFE8EEF7)));
}

class _PixelEditorToggle extends StatelessWidget {
  const _PixelEditorToggle(
      {required this.title, required this.subtitle, required this.control});
  final String title, subtitle;
  final Widget control;
  @override
  Widget build(BuildContext context) => Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDDE5F0)),
          borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11, height: 15 / 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 9, height: 13 / 9, color: Color(0xFF91A0B7)))
        ])),
        _PixelEditorSwitch(child: control)
      ]));
}

class _PixelEditorSwitch extends StatelessWidget {
  const _PixelEditorSwitch({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 29,
      height: 17,
      child: OverflowBox(
          minWidth: 52,
          maxWidth: 52,
          minHeight: 32,
          maxHeight: 32,
          child: Transform.scale(scale: .55, child: child)));
}

class _DeviceEditorCaption extends StatelessWidget {
  const _DeviceEditorCaption(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 9,
          letterSpacing: .35,
          color: Color(0xFF62799C),
          fontWeight: FontWeight.w600));
}

class _DeviceEditorNavigation extends StatelessWidget {
  const _DeviceEditorNavigation(
      {required this.activeSection,
      required this.vehicleReady,
      required this.equipmentReady,
      required this.sensorsReady,
      required this.onChanged,
      this.vertical = false});
  final _DeviceEditorSection activeSection;
  final bool vehicleReady, equipmentReady, sensorsReady, vertical;
  final ValueChanged<_DeviceEditorSection> onChanged;
  @override
  Widget build(BuildContext context) {
    final items = [
      _item(context,
          section: _DeviceEditorSection.vehicle,
          icon: 'car',
          title: 'Veículo',
          subtitle: 'Dados e visual',
          ready: vehicleReady),
      _item(context,
          section: _DeviceEditorSection.equipment,
          icon: 'chip',
          title: 'Chip e equipamento',
          subtitle: 'Rastreador e rede',
          ready: equipmentReady),
      _item(context,
          section: _DeviceEditorSection.sensors,
          icon: 'tune',
          title: 'Sensores e atuadores',
          subtitle: 'Entradas e comandos',
          ready: sensorsReady),
    ];
    return vertical
        ? Column(children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(height: 6),
              items[i]
            ]
          ])
        : Row(children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(width: 6),
              Expanded(child: items[i])
            ]
          ]);
  }

  Widget _item(BuildContext context,
      {required _DeviceEditorSection section,
      required String icon,
      required String title,
      required String subtitle,
      required bool ready}) {
    final selected = activeSection == section;
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
        button: true,
        selected: selected,
        label: title,
        child: Material(
            color: selected ? Color(0xFFEAF2FF) : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
                side: BorderSide(color: selected ? accent : Color(0xFFDDE5F0))),
            child: InkWell(
                onTap: () => onChanged(section),
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 12),
                    child: Row(children: [
                      DeviceEditorReferenceIcon(icon,
                          size: 14,
                          color: selected ? accent : Color(0xFF8299BB)),
                      SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title,
                                style: TextStyle(
                                    fontSize: 10,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        selected ? accent : Color(0xFF1F2A44))),
                            SizedBox(height: 4),
                            Text(subtitle,
                                style: TextStyle(
                                    fontSize: 9,
                                    height: 4 / 3,
                                    color: Color(0xFF8194B1)))
                          ])),
                      if (selected)
                        DeviceEditorReferenceIcon('chevron',
                            size: 14, color: accent),
                    ])))));
  }
}

class _VehicleVisualPicker extends StatelessWidget {
  const _VehicleVisualPicker(
      {required this.choices,
      required this.selectedKey,
      required this.onSelected});
  final List<_MapIconChoice> choices;
  final String? selectedKey;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, c) => Wrap(spacing: 6, runSpacing: 6, children: [
            for (final choice in choices)
              SizedBox(
                  width: (c.maxWidth - 30) / 6,
                  height: 50,
                  child: _VehicleVisualChoiceCard(
                      choice: choice,
                      selected: selectedKey == choice.key,
                      onTap: () => onSelected(choice.key)))
          ]));
}

class _VehicleVisualChoiceCard extends StatelessWidget {
  const _VehicleVisualChoiceCard(
      {required this.choice, required this.selected, required this.onTap});
  final _MapIconChoice choice;
  final bool selected;
  final VoidCallback onTap;
  static const Map<String, String> _spriteTypes = {
    'car': 'car',
    'motorcycle': 'motorcycle',
    'truck': 'truck',
    'pickup': 'pickup',
    'van': 'van',
    'tractor': 'tractor',
    'crane': 'crane',
    'offroad': 'offroad',
    'boat': 'boat',
    'scooter': 'scooter',
    'excavator': 'excavator',
    'backhoe': 'backhoe',
  };
  @override
  Widget build(BuildContext context) {
    final color =
        selected ? Theme.of(context).colorScheme.primary : Color(0xFF768BAA);
    final assetType = _spriteTypes[choice.key];
    return Semantics(
        button: true,
        selected: selected,
        label: 'Visual do mapa: ${choice.label}',
        child: Material(
            color: selected ? Color(0xFFEEF5FF) : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
                side: BorderSide(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Color(0xFFDDE5F0))),
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(7),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 24,
                          height: 24,
                          child: assetType == null
                              ? Icon(_fallbackIcon(choice.key),
                                  size: 24, color: color)
                              : Image.asset(
                                  'assets/icons/map_sprites/$assetType/${assetType}_0.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high)),
                      SizedBox(height: 4),
                      Text(choice.label,
                          style: TextStyle(
                              fontSize: 9, height: 13 / 9, color: color))
                    ]))));
  }

  IconData _fallbackIcon(String key) {
    return switch (key) {
      'animal' => Icons.pets_rounded,
      'bus' || 'trolleybus' => Icons.directions_bus_rounded,
      'camper' => Icons.rv_hookup_rounded,
      'helicopter' => Icons.flight_rounded,
      'bicycle' => Icons.pedal_bike_rounded,
      'plane' => Icons.flight_rounded,
      'ship' => Icons.directions_boat_filled_rounded,
      'train' || 'tram' => Icons.train_rounded,
      'person' => Icons.person_rounded,
      _ => Icons.location_on_rounded,
    };
  }
}

class _DeviceSection extends StatelessWidget {
  const _DeviceSection(
      {required this.icon,
      required this.iconColor,
      required this.title,
      required this.children,
      this.trailing});
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            height: 25,
            child: Align(
                alignment: Alignment.topLeft,
                child: Row(children: [
                  const _PixelEditorGroup('sensor', 'SENSORES'),
                  const Spacer(),
                  Tooltip(
                      message:
                          'Ative os sensores suportados pelo hardware do rastreador',
                      child: const Text('Tratamento das informações recebidas',
                          style:
                              TextStyle(fontSize: 9, color: Color(0xFF8C9CB3))))
                ]))),
        const SizedBox(height: 14),
        ...children
      ]);
}

class _SensorListRow extends StatelessWidget {
  const _SensorListRow(
      {required this.sensorKey,
      required this.label,
      required this.selected,
      required this.onToggle,
      required this.isLast,
      this.liveValue,
      this.customLabel,
      this.onConfigure});
  final String sensorKey, label;
  final String? customLabel, liveValue;
  final bool selected, isLast;
  final void Function(bool)? onToggle;
  final VoidCallback? onConfigure;
  @override
  Widget build(BuildContext context) {
    final displayLabel = (customLabel != null && customLabel!.trim().isNotEmpty)
        ? customLabel!.trim()
        : label;
    const names = {
      'ignition': 'power',
      'motion': 'car',
      'door': 'door',
      'blocked': 'lock',
      'power': 'battery',
      'battery': 'battery',
      'batteryLevel': 'battery',
      'charge': 'battery',
      'gsm': 'signal',
      'rssi': 'signal',
      'odometer': 'route',
      'totalHours': 'clock'
    };
    return Container(
        height: (liveValue ?? '').trim().isEmpty ? 42 : 56,
        margin: EdgeInsets.only(bottom: isLast ? 0 : 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5EBF5)),
            borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          DeviceEditorReferenceIcon(names[sensorKey] ?? 'sensor',
              size: 14, color: const Color(0xFF8098BC)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(displayLabel,
                    style: const TextStyle(
                        fontSize: 11,
                        height: 15 / 11,
                        fontWeight: FontWeight.w500)),
                if (liveValue != null && liveValue!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(liveValue!,
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF60718D)))
                ]
              ])),
          const SizedBox(width: 10),
          Container(
              width: 62,
              height: 20,
              decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFF0FCF5)
                      : const Color(0xFFF6F8FB),
                  border: Border.all(
                      color: selected
                          ? const Color(0xFFB8E8CE)
                          : const Color(0xFFE0E6F0)),
                  borderRadius: BorderRadius.circular(5)),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                DeviceEditorReferenceIcon(selected ? 'check' : 'clock',
                    size: 11,
                    color: selected
                        ? const Color(0xFF18A558)
                        : const Color(0xFF8798AF)),
                const SizedBox(width: 4),
                Text(selected ? 'Tratado' : 'Ignorado',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? const Color(0xFF18A558)
                            : const Color(0xFF8798AF)))
              ])),
          const SizedBox(width: 11),
          _PixelEditorSwitch(
              child: Switch(value: selected, onChanged: onToggle)),
          const SizedBox(width: 10),
          SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                  tooltip: 'Configurar',
                  padding: EdgeInsets.zero,
                  onPressed: onConfigure,
                  icon: const DeviceEditorReferenceIcon('settings',
                      size: 16, color: Color(0xFF8DA0BD))))
        ]));
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
      isExpanded: true,
      style: const TextStyle(
          fontFamily: 'DeviceEditorSegoe',
          fontSize: 11,
          color: Color(0xFF1F2A44)),
      hint: const Text('Selecione', style: TextStyle(fontSize: 11)),
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
  const _DeviceSummaryRow(
      {required this.label, this.value, this.chip, this.chipColor});
  final String label;
  final String? value, chip;
  final Color? chipColor;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: label == 'Última validação' ? 0 : 12),
      child: SizedBox(
          height: chip == null ? 14 : 20,
          child: Row(children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, height: 1.4, color: Color(0xFF7185A3))),
            const SizedBox(width: 10),
            if (chip != null) const Spacer(),
            if (chip != null)
              Container(
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0FCF5),
                      border: Border.all(color: const Color(0xFFB8E8CE)),
                      borderRadius: BorderRadius.circular(5)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    DeviceEditorReferenceIcon('check',
                        size: 11, color: chipColor),
                    const SizedBox(width: 4),
                    Text(chip!,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: chipColor))
                  ]))
            else
              Expanded(
                  child: Text(value ?? '—',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3D567C))))
          ])));
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.label, required this.checked});
  final String label;
  final bool checked;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(
          bottom: label == 'Vincular grupo operacional' ? 0 : 12),
      child: SizedBox(
          height: 13.05,
          child: Row(children: [
            DeviceEditorReferenceIcon(checked ? 'check' : 'clock',
                size: 12,
                color: checked
                    ? const Color(0xFF18A558)
                    : const Color(0xFFB2BED0)),
            const SizedBox(width: 7),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 9,
                        height: 1.45,
                        color: checked
                            ? const Color(0xFF617D9E)
                            : const Color(0xFF8798AF))))
          ])));
}

// ── Map icon choice model ──────────────────────────────────────────────────

class _MapIconChoice {
  const _MapIconChoice(this.key, this.label);

  final String key;
  final String label;

  String get assetPath => 'assets/icons/map/$key.png';
}

class _SelectedSensorRow extends StatelessWidget {
  const _SelectedSensorRow(
      {required this.sensorKey,
      required this.label,
      required this.onEdit,
      required this.onDelete});
  final String sensorKey, label;
  final VoidCallback? onEdit, onDelete;
  @override
  Widget build(BuildContext context) {
    final showKey = label != sensorKey;
    return Container(
        height: showKey ? 56 : 42,
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5EBF5))),
        child: Row(children: [
          const Icon(Icons.sensors_outlined,
              size: 14, color: Color(0xFF8098BC)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        height: 15 / 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2A44))),
                if (showKey) ...[
                  const SizedBox(height: 2),
                  Text(sensorKey,
                      style: const TextStyle(
                          fontSize: 9,
                          height: 12 / 9,
                          color: Color(0xFF60718D)))
                ]
              ])),
          SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                  tooltip: 'Editar sensor',
                  padding: EdgeInsets.zero,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  color: const Color(0xFF8DA0BD))),
          const SizedBox(width: 10),
          SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                  tooltip: 'Remover sensor',
                  padding: EdgeInsets.zero,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  color: const Color(0xFF8DA0BD)))
        ]));
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
        color: Colors.white,
        borderRadius: BorderRadius.zero,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const statusWidth = 138.0;
          const equipmentWidth = 155.0;
          const imeiWidth = 155.0;
          const vehicleWidth = 155.0;
          const groupWidth = 115.0;
          const connectionWidth = 150.0;
          const speedWidth = 82.0;
          const ignitionWidth = 84.0;
          const batteryWidth = 84.0;
          const signalWidth = 71.0;
          const actionsWidth = 102.0;
          // Coluna "Ações" fica FORA da área que rola horizontalmente --
          // arrastar pra ver/editar era facil no trackpad (swipe) mas ruim
          // no mouse (sem gesto horizontal nativo). Editar/ver fica sempre
          // visivel, so as colunas de dado rolam.
          const scrollableColumnsWidth = statusWidth +
              equipmentWidth +
              imeiWidth +
              vehicleWidth +
              groupWidth +
              connectionWidth +
              speedWidth +
              ignitionWidth +
              batteryWidth +
              signalWidth;
          const leftPad = 12.0;
          const rightPad = 12.0;
          final scrollableWidth = scrollableColumnsWidth + leftPad;
          final fixedActionsColumnWidth = actionsWidth + rightPad;
          final availableForScroll =
              (constraints.maxWidth - fixedActionsColumnWidth)
                  .clamp(0.0, double.infinity);
          final effectiveScrollableWidth = availableForScroll > scrollableWidth
              ? availableForScroll
              : scrollableWidth;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: effectiveScrollableWidth,
                    child: Column(
                      children: [
                        const ColoredBox(
                            color: Color(0xFFF8FAFF),
                            child: SizedBox(
                              height: 36,
                              child: Padding(
                                padding: EdgeInsets.only(left: leftPad),
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
                                  ],
                                ),
                              ),
                            )),
                        const Divider(height: 1, color: Color(0xFFD8E3F1)),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: devices.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, color: Color(0xFFDCE6F3)),
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
                              height: 52,
                              child: Padding(
                                padding: const EdgeInsets.only(left: leftPad),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: labelColor.withValues(
                                                    alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: labelColor,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _R(equipmentWidth, device.name,
                                        weight: FontWeight.w600),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            formatDateTimeShort(comm),
                                            style: const TextStyle(
                                              color: Color(0xFF1F2A44),
                                              fontWeight: FontWeight.w500,
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            formatRelative(comm),
                                            style: const TextStyle(
                                              color: Color(0xFF176EEB),
                                              fontWeight: FontWeight.w500,
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
                                          ? FontWeight.w600
                                          : FontWeight.w500,
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
                                                fontWeight: FontWeight.w600,
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
                                                fontWeight: FontWeight.w600,
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
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.5,
                                              ),
                                            ),
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
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: fixedActionsColumnWidth,
                child: Column(
                  children: [
                    SizedBox(
                      height: 36,
                      child: Padding(
                        padding: const EdgeInsets.only(right: rightPad),
                        child: Row(
                          children: [_H(actionsWidth, 'Ações')],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFD8E3F1)),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: devices.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFDCE6F3)),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return SizedBox(
                          height: 52,
                          child: Padding(
                            padding: const EdgeInsets.only(right: rightPad),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: actionsWidth,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
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
                  ],
                ),
              ),
            ],
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
        textAlign: text == 'Ações' ? TextAlign.center : TextAlign.left,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF6D82A3),
          fontWeight: FontWeight.w500,
          fontSize: 10,
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
    this.weight = FontWeight.w400,
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
          fontSize: 11,
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
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: SizedBox(
            width: 26,
            height: 26,
            child: Icon(icon, size: 14, color: const Color(0xFF6D91C5)),
          ),
        ),
      ),
    );
  }
}
