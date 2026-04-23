import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_router.dart';
import 'assist_dispatch_state.dart';

class AssistCreateRequestScreen extends ConsumerStatefulWidget {
  const AssistCreateRequestScreen({super.key});

  @override
  ConsumerState<AssistCreateRequestScreen> createState() =>
      _AssistCreateRequestScreenState();
}

class _AssistCreateRequestScreenState
    extends ConsumerState<AssistCreateRequestScreen> {
  String _service = kDemandServiceCatalog.first;
  String _mode = 'Agora';
  AssistPriority _priority = AssistPriority.media;
  AssistSplitMode _splitMode = AssistSplitMode.automatico;
  AssistDispatchMode _dispatchMode = AssistDispatchMode.equilibrado;
  final _customerController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latController = TextEditingController(text: '-23.5615');
  final _lonController = TextEditingController(text: '-46.6554');
  final _destinationLatController = TextEditingController(text: '-23.5712');
  final _destinationLonController = TextEditingController(text: '-46.6760');
  final _serviceAmountController = TextEditingController(text: '100');
  final _platformFeeController = TextEditingController(text: '18');
  final _fotoLocalController = TextEditingController();
  final _fotoChicoteController = TextEditingController();
  final _fotoAcabamentoController = TextEditingController();
  final _obsChecklistController = TextEditingController();
  bool _fixacaoSegura = false;
  bool _chicoteProtegido = false;
  bool _semInterferenciaEletrica = false;
  bool _testeComunicacaoOk = false;
  String _regionKey = kDemandRegionCatalog.first;
  bool _preferredPartnersOnly = false;
  final Set<String> _preferredPartnerIds = {};

  @override
  void dispose() {
    _customerController.dispose();
    _descriptionController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _destinationLatController.dispose();
    _destinationLonController.dispose();
    _serviceAmountController.dispose();
    _platformFeeController.dispose();
    _fotoLocalController.dispose();
    _fotoChicoteController.dispose();
    _fotoAcabamentoController.dispose();
    _obsChecklistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsChecklist = demandServiceRequiresInstallationChecklist(_service);
    final dispatchState = ref.watch(assistDispatchProvider);

    final originLat = double.tryParse(_latController.text.replaceAll(',', '.'));
    final originLon = double.tryParse(_lonController.text.replaceAll(',', '.'));
    final destinationLat =
        double.tryParse(_destinationLatController.text.replaceAll(',', '.'));
    final destinationLon =
        double.tryParse(_destinationLonController.text.replaceAll(',', '.'));
    final routeDistanceEstimate = originLat != null &&
            originLon != null &&
            destinationLat != null &&
            destinationLon != null
        ? _calcDistanceKm(
            originLat,
            originLon,
            destinationLat,
            destinationLon,
          )
        : null;
    final tableQuote = routeDistanceEstimate == null
        ? null
        : ref.read(assistDispatchProvider.notifier).estimateServiceAmount(
              regionKey: _regionKey,
              service: _service,
              routeDistanceKm: routeDistanceEstimate,
            );

    return SingleChildScrollView(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Criar chamado',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _service,
                decoration: const InputDecoration(labelText: 'Tipo de chamado'),
                items: kDemandServiceCatalog
                    .map((service) =>
                        DropdownMenuItem(value: service, child: Text(service)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _service = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _regionKey,
                decoration:
                    const InputDecoration(labelText: 'Região de precificação'),
                items: kDemandRegionCatalog
                    .map(
                      (region) => DropdownMenuItem(
                        value: region,
                        child: Text(region),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _regionKey = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _serviceAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Valor do serviço (BRL)',
                        hintText: 'Ex: 100',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _platformFeeController,
                      decoration: const InputDecoration(
                        labelText: 'Taxa plataforma (%)',
                        hintText: 'Ex: 18',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (tableQuote != null)
                Text(
                  'Tabela sugerida: R\$ ${tableQuote.toStringAsFixed(2)} (${routeDistanceEstimate!.toStringAsFixed(1)} km)',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              if (tableQuote != null) const SizedBox(height: 8),
              DropdownButtonFormField<AssistSplitMode>(
                initialValue: _splitMode,
                decoration: const InputDecoration(labelText: 'Repasse / split'),
                items: AssistSplitMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(assistSplitModeLabel(mode)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _splitMode = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AssistDispatchMode>(
                initialValue: _dispatchMode,
                decoration:
                    const InputDecoration(labelText: 'Perfil de despacho'),
                items: AssistDispatchMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(assistDispatchModeLabel(mode)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _dispatchMode = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                _dispatchMode == AssistDispatchMode.agressivo
                    ? 'Agressivo: mais parceiros por rodada e janela curta para reduzir SLA.'
                    : _dispatchMode == AssistDispatchMode.tranquilo
                        ? 'Tranquilo: menos concorrência por rodada e janela maior de resposta.'
                        : 'Equilibrado: concorrência moderada entre velocidade e custo operacional.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Agora', label: Text('Agora')),
                  ButtonSegment(value: 'Agendado', label: Text('Agendado')),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() => _mode = selection.first);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customerController,
                decoration: const InputDecoration(
                  labelText: 'Cliente / operação',
                  hintText: 'Ex: Linha Amarela - Frente 3',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AssistPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Prioridade'),
                items: AssistPriority.values
                    .map(
                      (priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(assistPriorityLabel(priority)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _priority = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Detalhes da ocorrência',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latController,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lonController,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _destinationLatController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude destino',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _destinationLonController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude destino',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Preferência de parceiros (empresa pode priorizar favoritos e depois abrir para todos):',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final partner in dispatchState.partners)
                    FilterChip(
                      label: Text(
                        '${partner.name}${partner.isBusy ? ' (ocupado)' : ''}',
                      ),
                      selected: _preferredPartnerIds.contains(partner.id),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _preferredPartnerIds.add(partner.id);
                          } else {
                            _preferredPartnerIds.remove(partner.id);
                          }
                        });
                      },
                    ),
                ],
              ),
              CheckboxListTile(
                value: _preferredPartnersOnly,
                onChanged: (value) {
                  setState(() => _preferredPartnersOnly = value ?? false);
                },
                title: const Text('Aceitar apenas parceiros preferidos'),
                subtitle: const Text(
                  'Se marcado e os preferidos estiverem ocupados/offline, o chamado fica aberto sem despacho automático.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              Text(
                'Despacho justo: primeiro favoritos disponíveis (se existirem), depois o parceiro mais próximo e livre.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
              if (needsChecklist) ...[
                const SizedBox(height: 16),
                Text(
                  'Checklist obrigatório de instalação (dossiê do veículo)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _fixacaoSegura,
                  onChanged: (value) {
                    setState(() => _fixacaoSegura = value ?? false);
                  },
                  title: const Text('Fixação segura do rastreador'),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _chicoteProtegido,
                  onChanged: (value) {
                    setState(() => _chicoteProtegido = value ?? false);
                  },
                  title: const Text('Chicote protegido e identificado'),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _semInterferenciaEletrica,
                  onChanged: (value) {
                    setState(() => _semInterferenciaEletrica = value ?? false);
                  },
                  title: const Text('Sem interferência elétrica no veículo'),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _testeComunicacaoOk,
                  onChanged: (value) {
                    setState(() => _testeComunicacaoOk = value ?? false);
                  },
                  title: const Text('Teste de comunicação concluído'),
                  contentPadding: EdgeInsets.zero,
                ),
                TextField(
                  controller: _fotoLocalController,
                  decoration: const InputDecoration(
                    labelText: 'Foto local da instalação (URL)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _fotoChicoteController,
                  decoration: const InputDecoration(
                    labelText: 'Foto chicote/fiação (URL)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _fotoAcabamentoController,
                  decoration: const InputDecoration(
                    labelText: 'Foto acabamento final (URL)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _obsChecklistController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observações do dossiê',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  final latitude =
                      double.tryParse(_latController.text.replaceAll(',', '.'));
                  final longitude =
                      double.tryParse(_lonController.text.replaceAll(',', '.'));
                  final destinationLatitude = double.tryParse(
                    _destinationLatController.text.replaceAll(',', '.'),
                  );
                  final destinationLongitude = double.tryParse(
                    _destinationLonController.text.replaceAll(',', '.'),
                  );
                  final serviceAmount = double.tryParse(
                    _serviceAmountController.text.replaceAll(',', '.'),
                  );
                  final platformFeePercent = double.tryParse(
                    _platformFeeController.text.replaceAll(',', '.'),
                  );
                  if (latitude == null ||
                      longitude == null ||
                      destinationLatitude == null ||
                      destinationLongitude == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Informe origem e destino com latitude/longitude válidas.',
                        ),
                      ),
                    );
                    return;
                  }

                  if (serviceAmount == null || serviceAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Informe valor do serviço válido.'),
                      ),
                    );
                    return;
                  }

                  if (platformFeePercent == null ||
                      platformFeePercent < 0 ||
                      platformFeePercent > 100) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Taxa da plataforma deve estar entre 0 e 100.'),
                      ),
                    );
                    return;
                  }

                  final checklist = needsChecklist
                      ? AssistInstallationChecklist(
                          fixacaoSegura: _fixacaoSegura,
                          chicoteProtegido: _chicoteProtegido,
                          semInterferenciaEletrica: _semInterferenciaEletrica,
                          testeComunicacaoOk: _testeComunicacaoOk,
                          fotoLocalInstalacao: _fotoLocalController.text.trim(),
                          fotoChicote: _fotoChicoteController.text.trim(),
                          fotoAcabamento: _fotoAcabamentoController.text.trim(),
                          observacoes: _obsChecklistController.text.trim(),
                        )
                      : null;

                  AssistRequest request;
                  try {
                    request = ref
                        .read(assistDispatchProvider.notifier)
                        .createRequest(
                          customer: _customerController.text.trim().isEmpty
                              ? 'Cliente sem nome'
                              : _customerController.text.trim(),
                          service: _service,
                          priority: _priority,
                          description: _descriptionController.text.trim(),
                          originLatitude: latitude,
                          originLongitude: longitude,
                          destinationLatitude: destinationLatitude,
                          destinationLongitude: destinationLongitude,
                          regionKey: _regionKey,
                          platformFeePercent: platformFeePercent,
                          splitMode: _splitMode,
                          dispatchMode: _dispatchMode,
                          serviceAmountOverride: serviceAmount,
                          installationChecklist: checklist,
                          preferredPartnerIds: _preferredPartnerIds.toList(),
                          preferredPartnersOnly: _preferredPartnersOnly,
                        );
                  } on ArgumentError catch (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.message.toString())),
                    );
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        request.assignedPartnerId != null
                            ? 'Chamado criado e despachado: plataforma R\$ ${request.platformFeeAmount.toStringAsFixed(2)} / parceiro R\$ ${request.partnerNetAmount.toStringAsFixed(2)} • ETA ${request.estimatedArrivalMinutes ?? '--'} min.'
                            : request.waitingAcceptance
                                ? 'Chamado criado e ofertado ao parceiro mais próximo. Aguardando aceite.'
                                : 'Chamado criado sem parceiro disponível no raio atual.',
                      ),
                    ),
                  );

                  Navigator.of(context).pushReplacementNamed(
                    AppRoutes.assistRequest(request.id),
                  );
                },
                icon: const Icon(Icons.local_shipping_outlined),
                label: Text(
                  _mode == 'Agora'
                      ? 'Criar e despachar agora'
                      : 'Criar chamado agendado',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _calcDistanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371.0;
  final dLat = _degreesToRadians(lat2 - lat1);
  final dLon = _degreesToRadians(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _degreesToRadians(double degrees) => degrees * pi / 180.0;
