import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  final _nameController = TextEditingController();
  final _startController = TextEditingController();
  final _periodController = TextEditingController();

  String _type = 'distance';
  int? _deviceId;
  bool _saving = false;
  int? _deletingId;
  _MaintenanceTemplate? _selectedTemplate;

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  double? _parseNumber(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String _compactNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String _displayNumber(double value, {int decimals = 2}) {
    return value.toStringAsFixed(decimals).replaceAll('.', ',');
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'distance':
        return 'Distancia (km)';
      case 'engineHours':
        return 'Horimetro (h)';
      case 'days':
        return 'Intervalo em dias';
      default:
        return type;
    }
  }

  String _formatPeriodValue(double value, String type) {
    switch (type) {
      case 'distance':
        return '${_compactNumber(value)} km';
      case 'engineHours':
        return '${_compactNumber(value)} h';
      case 'days':
        return '${_compactNumber(value)} dias';
      default:
        return _compactNumber(value);
    }
  }

  String _formulaPreview() {
    final start = _parseNumber(_startController.text);
    final period = _parseNumber(_periodController.text);
    if (start == null || period == null) {
      return 'Formula: proxima manutencao = valor inicial + periodo.';
    }

    final next = start + period;
    switch (_type) {
      case 'distance':
        return 'Proxima manutencao em ${_displayNumber(next)} km '
            '(inicio ${_displayNumber(start)} + periodo ${_displayNumber(period)}).';
      case 'engineHours':
        return 'Proxima manutencao em ${_displayNumber(next)} h '
            '(inicio ${_displayNumber(start)} + periodo ${_displayNumber(period)}).';
      case 'days':
        return 'Proxima manutencao apos ${_displayNumber(next, decimals: 0)} dias '
            '(inicio ${_displayNumber(start, decimals: 0)} + periodo ${_displayNumber(period, decimals: 0)}).';
      default:
        return 'Formula: proxima manutencao = $start + $period.';
    }
  }

  void _applyTemplate(_MaintenanceTemplate template) {
    _nameController.text = template.name;
    _periodController.text = _compactNumber(template.period);
    setState(() {
      _selectedTemplate = template;
      _type = template.type;
    });
  }

  Future<void> _createMaintenance() async {
    final name = _nameController.text.trim();
    final start = _parseNumber(_startController.text);
    final period = _parseNumber(_periodController.text);

    if (name.isEmpty || start == null || period == null || _deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nome, dispositivo, valor inicial e periodo sao obrigatorios.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      await client.createEntity(
        path: '/maintenance',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': name,
          'type': _type,
          'start': start,
          'period': period,
          'deviceId': _deviceId,
        },
      );
      ref.invalidate(maintenanceProvider);
      _nameController.clear();
      _startController.clear();
      _periodController.clear();
      setState(() {
        _selectedTemplate = null;
        _type = 'distance';
        _deviceId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plano criado com sucesso.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao criar plano: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteMaintenance(Map<String, dynamic> item) async {
    final idValue = item['id'];
    final id = idValue is int ? idValue : int.tryParse('$idValue');
    if (id == null) return;

    final name = '${item['name'] ?? 'Manutencao #$id'}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir manutencao'),
        content: Text('Excluir "$name" do servidor de rastreamento?'),
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

    setState(() => _deletingId = id);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      await client.deleteEntity(
        path: '/maintenance/$id',
        cookie: session.cookie,
        authHeader: session.authHeader,
      );
      ref.invalidate(maintenanceProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manutencao excluida.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao excluir manutencao: $error')),
      );
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  Widget _buildTemplateCatalog() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E1EF)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modelos prontos de manutencao',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Itens ja mapeados (pneu, correia, oleo e outros). '
            'Selecione um modelo e preencha apenas os dados faltantes.',
            style: TextStyle(color: Color(0xFF51607A)),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final columns = maxWidth >= 1120
                  ? 4
                  : maxWidth >= 780
                      ? 3
                      : maxWidth >= 520
                          ? 2
                          : 1;
              const spacing = 10.0;
              final cardWidth = columns == 1
                  ? maxWidth
                  : (maxWidth - (spacing * (columns - 1))) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final template in _maintenanceTemplates)
                    SizedBox(
                      width: cardWidth,
                      child: _MaintenanceTemplateCard(
                        template: template,
                        selected: _selectedTemplate?.id == template.id,
                        typeLabel: _typeLabel(template.type),
                        periodLabel:
                            _formatPeriodValue(template.period, template.type),
                        onUse: () => _applyTemplate(template),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maintenanceAsync = ref.watch(maintenanceProvider);
    final devicesAsync = ref.watch(devicesProvider);

    final list = maintenanceAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Nenhum plano de manutencao'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final idValue = item['id'];
            final id = idValue is int ? idValue : int.tryParse('$idValue');
            final title = '${item['name'] ?? 'Manutencao'}';

            final type = '${item['type'] ?? ''}'.trim();
            final start = _parseNumber('${item['start'] ?? ''}');
            final period = _parseNumber('${item['period'] ?? ''}');
            final device = item['deviceId'];

            final subtitleParts = <String>[
              if (type.isNotEmpty) 'Tipo: ${_typeLabel(type)}',
              if (start != null)
                'Inicio: ${_formatPeriodValue(start, type.isEmpty ? _type : type)}',
              if (period != null)
                'Periodo: ${_formatPeriodValue(period, type.isEmpty ? _type : type)}',
              if (device != null) 'Dispositivo: $device',
            ];

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.build_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (subtitleParts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitleParts.join(' | '),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: const Color(0xFF60718D)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Excluir manutencao',
                    onPressed: _deletingId == id
                        ? null
                        : () => _deleteMaintenance(item),
                    icon: _deletingId == id
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFEF4444),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
      error: (error, _) => Center(child: Text('Erro: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );

    final form = Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manutencao',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: const Color(0xFF1F2A44)),
          ),
          const SizedBox(height: 12),
          _buildTemplateCatalog(),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Nome do plano'),
            style: const TextStyle(color: Color(0xFF1F2A44)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('maintenance-type-$_type'),
            initialValue: _type,
            items: const [
              DropdownMenuItem(value: 'distance', child: Text('Distancia')),
              DropdownMenuItem(
                  value: 'engineHours', child: Text('Horas motor')),
              DropdownMenuItem(value: 'days', child: Text('Dias')),
            ],
            onChanged: (value) {
              setState(() => _type = value ?? 'distance');
            },
            decoration: const InputDecoration(labelText: 'Tipo'),
            dropdownColor: Colors.white,
            style: const TextStyle(color: Color(0xFF1F2A44)),
          ),
          const SizedBox(height: 12),
          devicesAsync.when(
            data: (devices) {
              return DropdownButtonFormField<int>(
                key: ValueKey('maintenance-device-${_deviceId ?? 'all'}'),
                initialValue: _deviceId,
                items: devices
                    .map(
                      (device) => DropdownMenuItem<int>(
                        value: device.id,
                        child: Text(device.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _deviceId = value),
                decoration: const InputDecoration(labelText: 'Dispositivo'),
                dropdownColor: Colors.white,
                style: const TextStyle(color: Color(0xFF1F2A44)),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text(
              'Erro: $error',
              style: const TextStyle(color: Color(0xFF1F2A44)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _startController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Valor inicial atual (km / h / dias)',
              helperText: 'Preencha com o valor atual do veiculo.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Color(0xFF1F2A44)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _periodController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Periodo',
              helperText: 'Intervalo entre manutencoes.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Color(0xFF1F2A44)),
          ),
          const SizedBox(height: 8),
          Text(
            _formulaPreview(),
            style: const TextStyle(
              color: Color(0xFF4D5D78),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _createMaintenance,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Criar plano'),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 540,
                margin: const EdgeInsets.only(left: 16, right: 20, top: 24),
                child: form,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, right: 16),
                  child: list,
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            form,
            const SizedBox(height: 20),
            SizedBox(height: 460, child: list),
          ],
        );
      },
    );
  }
}

class _MaintenanceTemplate {
  const _MaintenanceTemplate({
    required this.id,
    required this.name,
    required this.group,
    required this.type,
    required this.period,
    required this.formula,
  });

  final String id;
  final String name;
  final String group;
  final String type;
  final double period;
  final String formula;
}

class _MaintenanceTemplateCard extends StatelessWidget {
  const _MaintenanceTemplateCard({
    required this.template,
    required this.selected,
    required this.typeLabel,
    required this.periodLabel,
    required this.onUse,
  });

  final _MaintenanceTemplate template;
  final bool selected;
  final String typeLabel;
  final String periodLabel;
  final VoidCallback onUse;

  IconData _groupIcon(String group) {
    final normalized = group.trim().toLowerCase();
    if (normalized.contains('pneu')) {
      return Icons.tire_repair_outlined;
    }
    if (normalized.contains('transmiss')) {
      return Icons.settings_outlined;
    }
    if (normalized.contains('freio')) {
      return Icons.car_repair_outlined;
    }
    if (normalized.contains('eletric')) {
      return Icons.bolt_outlined;
    }
    if (normalized.contains('motor')) {
      return Icons.precision_manufacturing_outlined;
    }
    if (normalized.contains('checklist')) {
      return Icons.fact_check_outlined;
    }
    if (normalized.contains('lubr')) {
      return Icons.opacity_outlined;
    }
    return Icons.build_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE7F0FF) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xFF2E6DFF) : const Color(0xFFD5DFEE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_groupIcon(template.group),
                  size: 16, color: const Color(0xFF41536F)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  template.group,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF60718D),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            template.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2A44),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$typeLabel | $periodLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4D5D78),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            template.formula,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6A7A95),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onUse,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('Usar'),
            ),
          ),
        ],
      ),
    );
  }
}

const List<_MaintenanceTemplate> _maintenanceTemplates = [
  _MaintenanceTemplate(
    id: 'oil-engine',
    name: 'Troca de oleo do motor',
    group: 'Lubrificacao',
    type: 'distance',
    period: 10000,
    formula: 'Formula: km atual + 10000 km.',
  ),
  _MaintenanceTemplate(
    id: 'oil-filter',
    name: 'Troca do filtro de oleo',
    group: 'Lubrificacao',
    type: 'distance',
    period: 10000,
    formula: 'Formula: km atual + 10000 km.',
  ),
  _MaintenanceTemplate(
    id: 'air-filter',
    name: 'Troca do filtro de ar',
    group: 'Lubrificacao',
    type: 'distance',
    period: 15000,
    formula: 'Formula: km atual + 15000 km.',
  ),
  _MaintenanceTemplate(
    id: 'fuel-filter',
    name: 'Troca do filtro de combustivel',
    group: 'Lubrificacao',
    type: 'distance',
    period: 20000,
    formula: 'Formula: km atual + 20000 km.',
  ),
  _MaintenanceTemplate(
    id: 'timing-belt',
    name: 'Correia dentada',
    group: 'Transmissao',
    type: 'distance',
    period: 60000,
    formula: 'Formula: km atual + 60000 km.',
  ),
  _MaintenanceTemplate(
    id: 'accessory-belt',
    name: 'Correia auxiliar',
    group: 'Transmissao',
    type: 'distance',
    period: 40000,
    formula: 'Formula: km atual + 40000 km.',
  ),
  _MaintenanceTemplate(
    id: 'clutch-inspection',
    name: 'Inspecao da embreagem',
    group: 'Transmissao',
    type: 'distance',
    period: 30000,
    formula: 'Formula: km atual + 30000 km.',
  ),
  _MaintenanceTemplate(
    id: 'tire-rotation',
    name: 'Rodizio de pneus',
    group: 'Pneus',
    type: 'distance',
    period: 10000,
    formula: 'Formula: km atual + 10000 km.',
  ),
  _MaintenanceTemplate(
    id: 'tire-replacement',
    name: 'Troca de pneus',
    group: 'Pneus',
    type: 'distance',
    period: 40000,
    formula: 'Formula: km atual + 40000 km.',
  ),
  _MaintenanceTemplate(
    id: 'alignment',
    name: 'Alinhamento e balanceamento',
    group: 'Pneus',
    type: 'distance',
    period: 10000,
    formula: 'Formula: km atual + 10000 km.',
  ),
  _MaintenanceTemplate(
    id: 'brake-pad',
    name: 'Pastilhas de freio',
    group: 'Freios',
    type: 'distance',
    period: 25000,
    formula: 'Formula: km atual + 25000 km.',
  ),
  _MaintenanceTemplate(
    id: 'brake-fluid',
    name: 'Fluido de freio',
    group: 'Freios',
    type: 'days',
    period: 730,
    formula: 'Formula: dias atuais + 730 dias.',
  ),
  _MaintenanceTemplate(
    id: 'battery-check',
    name: 'Bateria veicular',
    group: 'Eletrico',
    type: 'days',
    period: 365,
    formula: 'Formula: dias atuais + 365 dias.',
  ),
  _MaintenanceTemplate(
    id: 'coolant',
    name: 'Fluido de arrefecimento',
    group: 'Motor',
    type: 'days',
    period: 365,
    formula: 'Formula: dias atuais + 365 dias.',
  ),
  _MaintenanceTemplate(
    id: 'general-review',
    name: 'Revisao geral',
    group: 'Checklist',
    type: 'days',
    period: 180,
    formula: 'Formula: dias atuais + 180 dias.',
  ),
  _MaintenanceTemplate(
    id: 'engine-hours-oil',
    name: 'Troca de oleo por horimetro',
    group: 'Operacao pesada',
    type: 'engineHours',
    period: 250,
    formula: 'Formula: horimetro atual + 250 h.',
  ),
  _MaintenanceTemplate(
    id: 'engine-hours-review',
    name: 'Revisao por horimetro',
    group: 'Operacao pesada',
    type: 'engineHours',
    period: 500,
    formula: 'Formula: horimetro atual + 500 h.',
  ),
];
