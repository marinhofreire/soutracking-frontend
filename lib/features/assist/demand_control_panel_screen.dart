import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_router.dart';
import '../../core/map_config.dart';
import 'assist_dispatch_state.dart';

class DemandControlPanelScreen extends ConsumerStatefulWidget {
  const DemandControlPanelScreen({super.key});

  @override
  ConsumerState<DemandControlPanelScreen> createState() =>
      _DemandControlPanelScreenState();
}

class _DemandControlPanelScreenState
    extends ConsumerState<DemandControlPanelScreen> {
  String? _selectedRequestId;

  @override
  Widget build(BuildContext context) {
    final dispatchState = ref.watch(assistDispatchProvider);
    final requests = dispatchState.requests;
    final selectedRequest = _selectedRequest(requests);

    int countByStatus(AssistRequestStatus status) {
      return requests.where((item) => item.status == status).length;
    }

    final openCount = countByStatus(AssistRequestStatus.aberto);
    final waitingCount = countByStatus(AssistRequestStatus.aguardandoAceite);
    final inExecutionCount = requests.where(_isExecutionStatus).length;
    final doneCount = countByStatus(AssistRequestStatus.finalizado);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 920;
        final detailWidth = constraints.maxWidth < 1180 ? 330.0 : 390.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            _OperationalMapBackdrop(
              requests: requests,
              selectedRequest: selectedRequest,
            ),
            const _DemandBackdropOverlay(),
            Padding(
              padding: EdgeInsets.all(compact ? 12 : 18),
              child: compact
                  ? SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DemandHeader(
                            compact: true,
                            onCreate: _openCreateRequest,
                            onOpenQueue: _openRequestsQueue,
                          ),
                          const SizedBox(height: 12),
                          _KpiGrid(
                            compact: true,
                            metrics: [
                              _DemandMetric(
                                label: 'Abertos',
                                value: '$openCount',
                                icon: Icons.inbox_outlined,
                                color: _DemandColors.cyan,
                              ),
                              _DemandMetric(
                                label: 'Aguardando aceite',
                                value: '$waitingCount',
                                icon: Icons.hourglass_top_outlined,
                                color: _DemandColors.amber,
                              ),
                              _DemandMetric(
                                label: 'Em execução',
                                value: '$inExecutionCount',
                                icon: Icons.route_outlined,
                                color: _DemandColors.blue,
                              ),
                              _DemandMetric(
                                label: 'Finalizados',
                                value: '$doneCount',
                                icon: Icons.task_alt_outlined,
                                color: _DemandColors.green,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 520,
                            child: _RequestsPanel(
                              requests: requests,
                              selectedRequestId: selectedRequest?.id,
                              onSelect: _selectRequest,
                              partnerNameFor: _partnerNameFor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SelectedRequestPanel(
                            request: selectedRequest,
                            partnerName: selectedRequest == null
                                ? null
                                : _partnerNameFor(selectedRequest),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DemandHeader(
                          compact: false,
                          onCreate: _openCreateRequest,
                          onOpenQueue: _openRequestsQueue,
                        ),
                        const SizedBox(height: 16),
                        _KpiGrid(
                          compact: false,
                          metrics: [
                            _DemandMetric(
                              label: 'Abertos',
                              value: '$openCount',
                              icon: Icons.inbox_outlined,
                              color: _DemandColors.cyan,
                            ),
                            _DemandMetric(
                              label: 'Aguardando aceite',
                              value: '$waitingCount',
                              icon: Icons.hourglass_top_outlined,
                              color: _DemandColors.amber,
                            ),
                            _DemandMetric(
                              label: 'Em execução',
                              value: '$inExecutionCount',
                              icon: Icons.route_outlined,
                              color: _DemandColors.blue,
                            ),
                            _DemandMetric(
                              label: 'Finalizados',
                              value: '$doneCount',
                              icon: Icons.task_alt_outlined,
                              color: _DemandColors.green,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _RequestsPanel(
                                  requests: requests,
                                  selectedRequestId: selectedRequest?.id,
                                  onSelect: _selectRequest,
                                  partnerNameFor: _partnerNameFor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: detailWidth,
                                child: _SelectedRequestPanel(
                                  request: selectedRequest,
                                  partnerName: selectedRequest == null
                                      ? null
                                      : _partnerNameFor(selectedRequest),
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
    );
  }

  AssistRequest? _selectedRequest(List<AssistRequest> requests) {
    if (requests.isEmpty) {
      return null;
    }
    final selectedId = _selectedRequestId;
    if (selectedId != null) {
      for (final request in requests) {
        if (request.id == selectedId) {
          return request;
        }
      }
    }
    return requests.first;
  }

  String _partnerNameFor(AssistRequest request) {
    final partner = ref
        .read(assistDispatchProvider.notifier)
        .partnerById(request.assignedPartnerId);
    return partner?.name ?? 'Aguardando técnico';
  }

  void _selectRequest(AssistRequest request) {
    setState(() {
      _selectedRequestId = request.id;
    });
  }

  void _openCreateRequest() {
    Navigator.of(context).pushNamed(AppRoutes.assistCreate);
  }

  void _openRequestsQueue() {
    Navigator.of(context).pushNamed(AppRoutes.assistRequests);
  }
}

class _DemandHeader extends StatelessWidget {
  const _DemandHeader({
    required this.compact,
    required this.onCreate,
    required this.onOpenQueue,
  });

  final bool compact;
  final VoidCallback onCreate;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: compact ? WrapAlignment.start : WrapAlignment.end,
      children: [
        FilledButton.icon(
          onPressed: onCreate,
          style: FilledButton.styleFrom(
            backgroundColor: _DemandColors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.add_task_outlined, size: 18),
          label: const Text('Novo chamado'),
        ),
        OutlinedButton.icon(
          onPressed: onOpenQueue,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0x33FFFFFF)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.list_alt_outlined, size: 18),
          label: const Text('Ver fila completa'),
        ),
      ],
    );

    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeaderCopy(),
                const SizedBox(height: 14),
                actions,
              ],
            )
          : Row(
              children: [
                const Expanded(child: _HeaderCopy()),
                const SizedBox(width: 18),
                actions,
              ],
            ),
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _DemandColors.blue.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _DemandColors.blue.withValues(alpha: 0.38),
                ),
              ),
              child: const Icon(
                Icons.hub_outlined,
                color: _DemandColors.blue,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Central operacional de demandas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Instalação, manutenção, retirada, vistoria e assistência em uma fila única de despacho.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.68),
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.compact,
    required this.metrics,
  });

  final bool compact;
  final List<_DemandMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = compact ? 10.0 : 12.0;
        final columns = compact ? 2 : 4;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _KpiCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.metric});

  final _DemandMetric metric;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: metric.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: metric.color.withValues(alpha: 0.34),
                  ),
                ),
                child: Icon(metric.icon, color: metric.color, size: 18),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: metric.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: metric.color.withValues(alpha: 0.45),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _RequestsPanel extends StatelessWidget {
  const _RequestsPanel({
    required this.requests,
    required this.selectedRequestId,
    required this.onSelect,
    required this.partnerNameFor,
  });

  final List<AssistRequest> requests;
  final String? selectedRequestId;
  final ValueChanged<AssistRequest> onSelect;
  final String Function(AssistRequest request) partnerNameFor;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Text(
                  'Chamados operacionais',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                _SoftBadge(
                  label: '${requests.length} na fila',
                  color: _DemandColors.blue,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          Expanded(
            child: requests.isEmpty
                ? const _EmptyRequestsState()
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return _RequestTile(
                        request: request,
                        selected: request.id == selectedRequestId,
                        partnerName: partnerNameFor(request),
                        onTap: () => onSelect(request),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.selected,
    required this.partnerName,
    required this.onTap,
  });

  final AssistRequest request;
  final bool selected;
  final String partnerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(request.status);
    final serviceColor = _serviceColor(request.service);
    final serviceType = _serviceType(request.service);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.13)
                : Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? _DemandColors.blue.withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.09),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _DemandColors.blue.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: serviceColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: serviceColor.withValues(alpha: 0.34),
                  ),
                ),
                child: Icon(
                  _serviceIcon(request.service),
                  color: serviceColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '#${request.id} - ${request.customer}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        _SoftBadge(
                          label: assistStatusLabel(request.status),
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SoftBadge(label: serviceType, color: serviceColor),
                        _SoftBadge(
                          label: assistPriorityLabel(request.priority),
                          color: _priorityColor(request.priority),
                        ),
                        _SoftBadge(
                          label: assistChannelLabel(request.channel),
                          color: _DemandColors.slate,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      request.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.64),
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.engineering_outlined,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.52),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            partnerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Text(
                          request.estimatedArrivalMinutes == null
                              ? 'ETA --'
                              : 'ETA ${request.estimatedArrivalMinutes} min',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _DemandColors.green,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedRequestPanel extends StatelessWidget {
  const _SelectedRequestPanel({
    required this.request,
    required this.partnerName,
  });

  final AssistRequest? request;
  final String? partnerName;

  @override
  Widget build(BuildContext context) {
    final current = request;
    if (current == null) {
      return const _GlassPanel(
        child: Center(
          child: Text(
            'Nenhum chamado selecionado.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final statusColor = _statusColor(current.status);
    final serviceColor = _serviceColor(current.service);

    return _GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: serviceColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: serviceColor.withValues(alpha: 0.38),
                  ),
                ),
                child: Icon(
                  _serviceIcon(current.service),
                  color: serviceColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${current.id}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.54),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      current.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SoftBadge(
                label: assistStatusLabel(current.status),
                color: statusColor,
              ),
              _SoftBadge(
                label: _serviceType(current.service),
                color: serviceColor,
              ),
              _SoftBadge(
                label: assistDispatchModeLabel(current.dispatchMode),
                color: _DemandColors.blue,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StatusRail(status: current.status),
          const SizedBox(height: 18),
          _DetailLine(
            icon: Icons.design_services_outlined,
            label: 'Serviço',
            value: current.service,
          ),
          _DetailLine(
            icon: Icons.engineering_outlined,
            label: 'Prestador / técnico',
            value: partnerName ?? 'Aguardando técnico',
          ),
          _DetailLine(
            icon: Icons.route_outlined,
            label: 'Distância',
            value: '${current.routeDistanceKm.toStringAsFixed(1)} km',
          ),
          _DetailLine(
            icon: Icons.schedule_outlined,
            label: 'ETA',
            value: current.estimatedArrivalMinutes == null
                ? 'Não definido'
                : '${current.estimatedArrivalMinutes} min',
          ),
          _DetailLine(
            icon: Icons.payments_outlined,
            label: 'Valor operacional',
            value: 'R\$ ${current.serviceAmount.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 14),
          Text(
            'Resumo do chamado',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            current.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 18),
          _TimelinePreview(request: current),
        ],
      ),
    );
  }
}

class _TimelinePreview extends StatelessWidget {
  const _TimelinePreview({required this.request});

  final AssistRequest request;

  @override
  Widget build(BuildContext context) {
    final entries = request.dispatchTimeline.take(3).toList(growable: false);
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Últimos eventos',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: const BoxDecoration(
                      color: _DemandColors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.62),
                            height: 1.25,
                          ),
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

class _StatusRail extends StatelessWidget {
  const _StatusRail({required this.status});

  final AssistRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final steps = [
      AssistRequestStatus.aberto,
      AssistRequestStatus.aguardandoAceite,
      AssistRequestStatus.despachado,
      AssistRequestStatus.emDeslocamento,
      AssistRequestStatus.emAtendimento,
      AssistRequestStatus.finalizado,
    ];
    final activeIndex = steps.indexOf(status);

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i <= activeIndex
                    ? _statusColor(status)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          if (i < steps.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.46)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.48),
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationalMapBackdrop extends StatelessWidget {
  const _OperationalMapBackdrop({
    required this.requests,
    required this.selectedRequest,
  });

  final List<AssistRequest> requests;
  final AssistRequest? selectedRequest;

  @override
  Widget build(BuildContext context) {
    final selected = selectedRequest;
    final center = selected == null
        ? const LatLng(-23.55052, -46.633308)
        : LatLng(selected.originLatitude, selected.originLongitude);

    return IgnorePointer(
      child: FlutterMap(
        key: ValueKey(selected?.id ?? 'demand-map'),
        options: MapOptions(
          initialCenter: center,
          initialZoom: 12.2,
          minZoom: MapConfig.minZoom,
          maxZoom: MapConfig.maxZoom,
        ),
        children: [
          TileLayer(
            urlTemplate: MapConfig.openStreetMapTileUrl,
            userAgentPackageName: 'com.soutracking.app',
          ),
          CircleLayer(
            circles: [
              if (selected != null)
                CircleMarker(
                  point: LatLng(
                    selected.originLatitude,
                    selected.originLongitude,
                  ),
                  radius: 70,
                  color: _statusColor(selected.status).withValues(alpha: 0.16),
                  borderColor:
                      _statusColor(selected.status).withValues(alpha: 0.42),
                  borderStrokeWidth: 2,
                ),
            ],
          ),
          MarkerLayer(
            markers: [
              for (final request in requests)
                Marker(
                  point: LatLng(
                    request.originLatitude,
                    request.originLongitude,
                  ),
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _statusColor(request.status),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _statusColor(request.status)
                              .withValues(alpha: 0.45),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Icon(
                      _serviceIcon(request.service),
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DemandBackdropOverlay extends StatelessWidget {
  const _DemandBackdropOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF05080F).withValues(alpha: 0.90),
            const Color(0xFF061322).withValues(alpha: 0.76),
            const Color(0xFF020408).withValues(alpha: 0.92),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.1,
            colors: [
              _DemandColors.blue.withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
      ),
    );
  }
}

class _EmptyRequestsState extends StatelessWidget {
  const _EmptyRequestsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.radar_outlined,
            size: 36,
            color: Colors.white.withValues(alpha: 0.38),
          ),
          const SizedBox(height: 10),
          Text(
            'Nenhuma demanda ativa no momento.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                ),
          ),
        ],
      ),
    );
  }
}

class _DemandMetric {
  const _DemandMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _DemandColors {
  static const blue = Color(0xFF2D7DFF);
  static const cyan = Color(0xFF22D3EE);
  static const green = Color(0xFF4ADE80);
  static const amber = Color(0xFFFBBF24);
  static const red = Color(0xFFFF4D4D);
  static const violet = Color(0xFFA78BFA);
  static const slate = Color(0xFF94A3B8);
}

bool _isExecutionStatus(AssistRequest request) {
  return request.status == AssistRequestStatus.despachado ||
      request.status == AssistRequestStatus.emDeslocamento ||
      request.status == AssistRequestStatus.emAtendimento;
}

Color _statusColor(AssistRequestStatus status) {
  switch (status) {
    case AssistRequestStatus.aberto:
      return _DemandColors.cyan;
    case AssistRequestStatus.aguardandoAceite:
      return _DemandColors.amber;
    case AssistRequestStatus.despachado:
      return _DemandColors.blue;
    case AssistRequestStatus.emDeslocamento:
      return _DemandColors.violet;
    case AssistRequestStatus.emAtendimento:
      return _DemandColors.green;
    case AssistRequestStatus.finalizado:
      return _DemandColors.slate;
  }
}

Color _priorityColor(AssistPriority priority) {
  switch (priority) {
    case AssistPriority.baixa:
      return _DemandColors.slate;
    case AssistPriority.media:
      return _DemandColors.blue;
    case AssistPriority.alta:
      return _DemandColors.amber;
    case AssistPriority.critica:
      return _DemandColors.red;
  }
}

String _serviceType(String service) {
  final value = service.toLowerCase();
  if (value.contains('instala') || value.contains('rastreador')) {
    return 'Instalação';
  }
  if (value.contains('vistoria')) {
    return 'Vistoria';
  }
  if (value.contains('retirada') || value.contains('remoção')) {
    return 'Retirada';
  }
  if (value.contains('manutenção') ||
      value.contains('mecan') ||
      value.contains('elétr') ||
      value.contains('bateria')) {
    return 'Manutenção';
  }
  return 'Assistência';
}

IconData _serviceIcon(String service) {
  switch (_serviceType(service)) {
    case 'Instalação':
      return Icons.settings_input_component_outlined;
    case 'Manutenção':
      return Icons.handyman_outlined;
    case 'Retirada':
      return Icons.remove_circle_outline;
    case 'Vistoria':
      return Icons.fact_check_outlined;
    default:
      return Icons.support_agent_outlined;
  }
}

Color _serviceColor(String service) {
  switch (_serviceType(service)) {
    case 'Instalação':
      return _DemandColors.blue;
    case 'Manutenção':
      return _DemandColors.amber;
    case 'Retirada':
      return _DemandColors.red;
    case 'Vistoria':
      return _DemandColors.violet;
    default:
      return _DemandColors.green;
  }
}
