import 'dart:math' as math;

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
  String _formatThousands(double value) {
    if (value != value.roundToDouble()) {
      return _displayNumber(value);
    }
    final digits = value.round().abs().toString();
    final chunks = <String>[];
    for (var i = digits.length; i > 0; i -= 3) {
      final start = i - 3 < 0 ? 0 : i - 3;
      chunks.insert(0, digits.substring(start, i));
    }
    final joined = chunks.join('.');
    return value < 0 ? '-$joined' : joined;
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'distance':
        return 'Distância';
      case 'engineHours':
        return 'Horímetro';
      case 'days':
        return 'Intervalo em dias';
      default:
        return type;
    }
  }

  String _formatPeriodValue(double value, String type) {
    switch (type) {
      case 'distance':
        return '${_formatThousands(value)} km';
      case 'engineHours':
        return '${_formatThousands(value)} h';
      case 'days':
        return '${_formatThousands(value)} dias';
      default:
        return _compactNumber(value);
    }
  }

  String _templateMetricLabel(String type, double value) {
    final formatted = _formatPeriodValue(value, type);
    switch (type) {
      case 'distance':
        return 'Distância: $formatted';
      case 'engineHours':
        return 'Horímetro: $formatted';
      case 'days':
        return 'Intervalo: $formatted';
      default:
        return formatted;
    }
  }

  String _formulaPreview() {
    final start = _parseNumber(_startController.text);
    final period = _parseNumber(_periodController.text);
    if (start == null || period == null) {
      return 'Fórmula: próxima manutenção = valor inicial + período.';
    }

    final next = start + period;
    switch (_type) {
      case 'distance':
        return 'Próxima manutenção em ${_displayNumber(next)} km '
            '(início ${_displayNumber(start)} + período ${_displayNumber(period)}).';
      case 'engineHours':
        return 'Próxima manutenção em ${_displayNumber(next)} h '
            '(início ${_displayNumber(start)} + período ${_displayNumber(period)}).';
      case 'days':
        return 'Próxima manutenção após ${_displayNumber(next, decimals: 0)} dias '
            '(início ${_displayNumber(start, decimals: 0)} + período ${_displayNumber(period, decimals: 0)}).';
      default:
        return 'Fórmula: próxima manutenção = $start + $period.';
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
            'Nome, dispositivo, valor inicial e período são obrigatórios.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      final created = await client.createEntity(
        path: '/maintenance',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': name,
          'type': _type,
          'start': start,
          'period': period,
        },
      );
      // O Traccar nao aceita deviceId dentro do objeto de manutencao -- o
      // vinculo com o veiculo e uma entidade de permissao separada, igual
      // acontece com usuario/dispositivo. Sem isso o plano fica criado mas
      // nunca aparece vinculado a nenhum veiculo.
      final createdId = created['id'];
      if (createdId != null) {
        await client.createEntity(
          path: '/permissions',
          cookie: session.cookie,
          authHeader: session.authHeader,
          body: {'deviceId': _deviceId, 'maintenanceId': createdId},
        );
      }
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

    final name = '${item['name'] ?? 'Manutenção #$id'}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir manutenção'),
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
        const SnackBar(content: Text('Manutenção excluída.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao excluir manutenção: $error')),
      );
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  Widget _buildTemplateCatalog() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE6F2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modelos prontos de manutenção',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Itens já mapeados (pneu, correia, óleo e outros). '
            'Selecione um modelo e preencha apenas os dados faltantes.',
            style: TextStyle(color: Color(0xFF51607A)),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              const spacing = 8.0;
              const minCardWidth = 150.0;
              final columns = math.max(
                  1, (maxWidth + spacing) ~/ (minCardWidth + spacing));
              final cardWidth =
                  (maxWidth - spacing * (columns - 1)) / columns;

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
                        metricLabel: _templateMetricLabel(template.type, template.period),
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
          return const Center(child: Text('Nenhum plano de manutenção ativo'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final idValue = item['id'];
            final id = idValue is int ? idValue : int.tryParse('$idValue');
            final title = '${item['name'] ?? 'Manutenção'}';

            final type = '${item['type'] ?? ''}'.trim();
            final start = _parseNumber('${item['start'] ?? ''}');
            final period = _parseNumber('${item['period'] ?? ''}');
            final device = item['deviceId'];

            final subtitleParts = <String>[
              if (type.isNotEmpty) 'Tipo: ${_typeLabel(type)}',
              if (start != null)
                'Início: ${_formatPeriodValue(start, type.isEmpty ? _type : type)}',
              if (period != null)
                'Período: ${_formatPeriodValue(period, type.isEmpty ? _type : type)}',
              if (device != null) 'Dispositivo: $device',
            ];

            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFDDE6F2),
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: const Color(0xFF5F738F)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Excluir manutenção',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE6F2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manutenção',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: const Color(0xFF25344A)),
          ),
          const SizedBox(height: 10),
          _buildTemplateCatalog(),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Nome do plano'),
            style: const TextStyle(color: Color(0xFF25344A)),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey('maintenance-type-$_type'),
            initialValue: _type,
            items: const [
              DropdownMenuItem(value: 'distance', child: Text('Distância')),
              DropdownMenuItem(
                  value: 'engineHours', child: Text('Horas motor')),
              DropdownMenuItem(value: 'days', child: Text('Dias')),
            ],
            onChanged: (value) {
              setState(() => _type = value ?? 'distance');
            },
            decoration: const InputDecoration(labelText: 'Tipo'),
            dropdownColor: Colors.white,
            style: const TextStyle(color: Color(0xFF25344A)),
          ),
          const SizedBox(height: 10),
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
                style: const TextStyle(color: Color(0xFF25344A)),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text(
              'Erro: $error',
              style: const TextStyle(color: Color(0xFF25344A)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _startController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Valor inicial atual (km / h / dias)',
              helperText: 'Preencha com o valor atual do veículo.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Color(0xFF25344A)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _periodController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Periodo',
              helperText: 'Intervalo entre manutenções.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Color(0xFF25344A)),
          ),
          const SizedBox(height: 6),
          Text(
            _formulaPreview(),
            style: const TextStyle(
              color: Color(0xFF4D5D78),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
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
        final isWide = constraints.maxWidth >= 1200;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 16, top: 16),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: SingleChildScrollView(child: form),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, right: 12),
                  child: list,
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            form,
            const SizedBox(height: 12),
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
    required this.metricLabel,
    required this.onUse,
  });

  final _MaintenanceTemplate template;
  final bool selected;
  final String metricLabel;
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
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFEAF3FF)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? const Color(0xFFBBD7FF) : const Color(0xFFDDE6F2),
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
                    color: Color(0xFF5F738F),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            template.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Color(0xFF25344A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            metricLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF4D5D78),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onUse,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(fontSize: 11),
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
    name: 'Troca de óleo do motor',
    group: 'Lubrificação',
    type: 'distance',
    period: 10000,
    formula: 'Fórmula: km atual + 10.000 km.',
  ),
  _MaintenanceTemplate(
    id: 'oil-filter',
    name: 'Troca do filtro de óleo',
    group: 'Lubrificação',
    type: 'distance',
    period: 10000,
    formula: 'Fórmula: km atual + 10.000 km.',
  ),
  _MaintenanceTemplate(
    id: 'air-filter',
    name: 'Troca do filtro de ar',
    group: 'Lubrificação',
    type: 'distance',
    period: 15000,
    formula: 'Fórmula: km atual + 15.000 km.',
  ),
  _MaintenanceTemplate(
    id: 'fuel-filter',
    name: 'Troca do filtro de combustível',
    group: 'Lubrificação',
    type: 'distance',
    period: 20000,
    formula: 'Fórmula: km atual + 20.000 km.',
  ),
  _MaintenanceTemplate(
    id: 'timing-belt',
    name: 'Correia dentada',
    group: 'Transmissão',
    type: 'distance',
    period: 60000,
    formula: 'Fórmula: km atual + 60.000 km.',
  ),
  _MaintenanceTemplate(
    id: 'accessory-belt',
    name: 'Correia auxiliar',
    group: 'Transmissão',
    type: 'distance',
    period: 40000,
    formula: 'Fórmula: km atual + 40.000 km.',
  ),
  _MaintenanceTemplate(
    id: 'clutch-inspection',
    name: 'Inspeção da embreagem',
    group: 'Transmissão',
    type: 'distance',
    period: 30000,
    formula: 'Fórmula: km atual + 30.000 km.',
  ),
  _MaintenanceTemplate(
    id: 'tire-rotation',
    name: 'Rodízio de pneus',
    group: 'Pneus',
    type: 'distance',
    period: 10000,
    formula: 'Fórmula: km atual + 10.000 km.',
  ),
  _MaintenanceTemplate(
    id: 'tire-replacement',
    name: 'Troca de pneus',
    group: 'Pneus',
    type: 'distance',
    period: 40000,
    formula: 'Fórmula: km atual + 40.000 km.',
  ),
  _MaintenanceTemplate(
    id: 'alignment',
    name: 'Alinhamento e balanceamento',
    group: 'Pneus',
    type: 'distance',
    period: 10000,
    formula: 'Fórmula: km atual + 10.000 km.',
  ),
  _MaintenanceTemplate(
    id: 'brake-pad',
    name: 'Pastilhas de freio',
    group: 'Freios',
    type: 'distance',
    period: 25000,
    formula: 'Fórmula: km atual + 25.000 km.',
  ),
  _MaintenanceTemplate(
    id: 'brake-fluid',
    name: 'Fluido de freio',
    group: 'Freios',
    type: 'days',
    period: 730,
    formula: 'Fórmula: dias atuais + 730 dias.',
  ),
  _MaintenanceTemplate(
    id: 'battery-check',
    name: 'Bateria veicular',
    group: 'Elétrico',
    type: 'days',
    period: 365,
    formula: 'Fórmula: dias atuais + 365 dias.',
  ),
  _MaintenanceTemplate(
    id: 'coolant',
    name: 'Fluido de arrefecimento',
    group: 'Motor',
    type: 'days',
    period: 365,
    formula: 'Fórmula: dias atuais + 365 dias.',
  ),
  _MaintenanceTemplate(
    id: 'general-review',
    name: 'Revisão geral',
    group: 'Checklist',
    type: 'days',
    period: 180,
    formula: 'Fórmula: dias atuais + 180 dias.',
  ),
  _MaintenanceTemplate(
    id: 'engine-hours-oil',
    name: 'Troca de óleo por horímetro',
    group: 'Operação pesada',
    type: 'engineHours',
    period: 250,
    formula: 'Fórmula: horímetro atual + 250 h.',
  ),
  _MaintenanceTemplate(
    id: 'engine-hours-review',
    name: 'Revisão por horímetro',
    group: 'Operação pesada',
    type: 'engineHours',
    period: 500,
    formula: 'Fórmula: horímetro atual + 500 h.',
  ),
];
