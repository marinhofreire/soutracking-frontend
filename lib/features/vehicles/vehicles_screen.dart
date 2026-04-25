import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';
import '../../widgets/status_pill.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  final _nameController = TextEditingController();
  final _uniqueIdController = TextEditingController();
  final _groupIdController = TextEditingController();
  final _categoryController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _operatorController = TextEditingController();
  final _notesController = TextEditingController();
  final _simController = TextEditingController();
  final _apnController = TextEditingController();
  final _chipProviderController = TextEditingController();
  final _fuelCostController = TextEditingController(text: '4.00');
  final _odometerController = TextEditingController();
  bool _saving = false;
  bool _isFormExpanded = false;
  int? _selectedDeviceId;
  int? _deletingDeviceId;

  @override
  void dispose() {
    _nameController.dispose();
    _uniqueIdController.dispose();
    _groupIdController.dispose();
    _categoryController.dispose();
    _manufacturerController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _operatorController.dispose();
    _notesController.dispose();
    _simController.dispose();
    _apnController.dispose();
    _chipProviderController.dispose();
    _fuelCostController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  Future<void> _createDevice() async {
    final name = _nameController.text.trim();
    final uniqueId = _uniqueIdController.text.trim();
    final groupId = int.tryParse(_groupIdController.text.trim());
    final category = _categoryController.text.trim();
    final manufacturer = _manufacturerController.text.trim();
    final model = _modelController.text.trim();
    final plate = _plateController.text.trim();
    final operator = _operatorController.text.trim();
    final notes = _notesController.text.trim();
    final sim = _simController.text.trim();
    final apn = _apnController.text.trim();
    final chipProvider = _chipProviderController.text.trim();
    final fuelCost = double.tryParse(_fuelCostController.text.trim());
    final odometer = double.tryParse(_odometerController.text.trim());

    if (name.isEmpty || uniqueId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome e identificador são obrigatórios.')),
      );
      return;
    }

    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      await client.createDevice(
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': name,
          'uniqueId': uniqueId,
          if (groupId != null) 'groupId': groupId,
          if (category.isNotEmpty) 'category': category,
          'attributes': {
            if (manufacturer.isNotEmpty) 'manufacturer': manufacturer,
            if (model.isNotEmpty) 'model': model,
            if (plate.isNotEmpty) 'plate': plate,
            if (operator.isNotEmpty) 'operator': operator,
            if (notes.isNotEmpty) 'notes': notes,
            if (sim.isNotEmpty) 'sim': sim,
            if (apn.isNotEmpty) 'apn': apn,
            if (chipProvider.isNotEmpty) 'chipProvider': chipProvider,
            if (fuelCost != null) 'fuelCost': fuelCost,
            if (odometer != null) 'odometer': odometer,
          },
        },
      );
      ref.invalidate(devicesProvider);
      _nameController.clear();
      _uniqueIdController.clear();
      _groupIdController.clear();
      _categoryController.clear();
      _manufacturerController.clear();
      _modelController.clear();
      _plateController.clear();
      _operatorController.clear();
      _notesController.clear();
      _simController.clear();
      _apnController.clear();
      _chipProviderController.clear();
      _fuelCostController.text = '4.00';
      _odometerController.clear();
      setState(() => _isFormExpanded = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispositivo criado com sucesso.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao criar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteDevice(dynamic device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir dispositivo'),
        content: Text(
          'Excluir "${device.name}" do Traccar real? Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingDeviceId = device.id);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    try {
      await client.deleteEntity(
        path: '/devices/${device.id}',
        cookie: session.cookie,
        authHeader: session.authHeader,
      );
      ref.invalidate(devicesProvider);
      if (_selectedDeviceId == device.id) {
        setState(() => _selectedDeviceId = null);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispositivo excluído.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao excluir: $error')),
      );
    } finally {
      if (mounted) setState(() => _deletingDeviceId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);

    final list = devicesAsync.when(
      data: (devices) {
        if (devices.isEmpty) {
          return const Center(child: Text('Nenhum dispositivo encontrado'));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dispositivos',
                    style: Theme.of(context).textTheme.headlineSmall),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _isFormExpanded = true;
                      _selectedDeviceId = null;
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Novo Dispositivo'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                itemCount: devices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDeviceId = device.id;
                        _isFormExpanded = false;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF183153).withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: _selectedDeviceId == device.id
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_shipping_outlined,
                            size: 28,
                            color: Color(0xFF526684),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          color: const Color(0xFF1F2A44)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  device.uniqueId ?? 'Sem identificador',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          StatusPill(status: device.status),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Excluir dispositivo',
                            onPressed: _deletingDeviceId == device.id
                                ? null
                                : () => _deleteDevice(device),
                            icon: _deletingDeviceId == device.id
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFEF4444),
                                  ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF8A99AD),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      error: (error, _) => Center(child: Text('Erro: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );

    final devices = devicesAsync.value ?? const [];
    final selectedMatches = _selectedDeviceId == null
        ? const []
        : devices.where((device) => device.id == _selectedDeviceId).toList();
    final selectedDevice =
        selectedMatches.isEmpty ? null : selectedMatches.first;

    final sidePanel = (_isFormExpanded || selectedDevice != null)
        ? Container(
            margin: const EdgeInsets.only(top: 24, bottom: 24, right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF183153).withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            width: 400,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _isFormExpanded
                  ? _buildSmartAddDeviceForm()
                  : selectedDevice == null
                      ? const Text(
                          'Selecione um dispositivo para ver detalhes.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    selectedDevice.name,
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() => _selectedDeviceId = null);
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            StatusPill(status: selectedDevice.status),
                            const SizedBox(height: 12),
                            _detailRow('Identificador',
                                selectedDevice.uniqueId ?? '-'),
                            _detailRow('Última comunicação',
                                selectedDevice.lastUpdate ?? '-'),
                            _detailRow('Velocidade', '60 km/h'),
                            _detailRow('Ignição', 'Ligada'),
                            _detailRow('Bateria', '82%'),
                            _detailRow('Combustível', '57%'),
                            _detailRow('Odômetro', '123.456 km'),
                          ],
                        ),
            ),
          )
        : const SizedBox.shrink();

    return Container(
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: list),
          if (_isFormExpanded || selectedDevice != null) ...[
            const SizedBox(width: 24),
            sidePanel,
          ],
        ],
      ),
    );
  }

  Widget _buildSmartAddDeviceForm() {
    return DefaultTabController(
      length: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Adicionar novo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _isFormExpanded = false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Principal'),
              Tab(text: 'Ícones'),
              Tab(text: 'Avançado'),
              Tab(text: 'Sensores'),
              Tab(text: 'Serviços'),
              Tab(text: 'Exatidão'),
              Tab(text: 'Rastro'),
              Tab(text: 'Despesas'),
              Tab(text: 'Câmeras'),
              Tab(text: 'Chip/Veículo'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 430,
            child: TabBarView(
              children: [
                ListView(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição*',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _uniqueIdController,
                      decoration: const InputDecoration(
                        labelText: 'IMEI / ID do rastreador*',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _groupIdController,
                      decoration: const InputDecoration(
                        labelText: 'Grupo (ID)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _createDevice,
                        icon: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _saving ? 'Criando...' : 'Salvar dispositivo',
                        ),
                      ),
                    ),
                  ],
                ),
                const Center(
                  child: Text(
                      'Ícones por categoria/veículo são definidos no mapa.'),
                ),
                ListView(
                  children: [
                    TextField(
                      controller: _manufacturerController,
                      decoration: const InputDecoration(
                        labelText: 'Fabricante do rastreador',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Modelo do rastreador',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _operatorController,
                      decoration: const InputDecoration(
                        labelText: 'Operadora',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Notas administrativas',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                const Center(
                    child: Text('Sensores configuráveis após criação.')),
                const Center(
                    child: Text(
                        'Serviços/manutenção configuráveis após criação.')),
                ListView(
                  children: [
                    const Text('Parâmetros de precisão e combustível'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _fuelCostController,
                      decoration: const InputDecoration(
                        labelText: 'Custo por litro',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _odometerController,
                      decoration: const InputDecoration(
                        labelText: 'Odômetro inicial (km)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
                const Center(
                    child: Text('Rastro pode ser ajustado na tela de mapa.')),
                const Center(
                    child:
                        Text('Despesas podem ser adicionadas após cadastro.')),
                const Center(
                    child: Text('Câmeras podem ser vinculadas após cadastro.')),
                ListView(
                  children: [
                    TextField(
                      controller: _chipProviderController,
                      decoration: const InputDecoration(
                        labelText: 'Fornecedor do chip',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _simController,
                      decoration: const InputDecoration(
                        labelText: 'Número SIM',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _apnController,
                      decoration: const InputDecoration(
                        labelText: 'APN',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _plateController,
                      decoration: const InputDecoration(
                        labelText: 'Placa do veículo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF60718D)),
            ),
          ),
          Text(value, style: const TextStyle(color: Color(0xFF1F2A44))),
        ],
      ),
    );
  }
}
