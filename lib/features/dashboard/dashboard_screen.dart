import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';
import '../../widgets/status_pill.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);
    final positionsAsync = ref.watch(positionsProvider);

    final devices = devicesAsync.valueOrNull ?? const <TraccarDevice>[];
    final positions = positionsAsync.valueOrNull ?? const <TraccarPosition>[];
    final positionByDeviceId = {
      for (final position in positions) position.deviceId: position,
    };

    final total = devices.length;
    final online =
        devices.where((d) => d.status.toLowerCase() == 'online').length;
    final offline =
        devices.where((d) => d.status.toLowerCase() == 'offline').length;
    final moving = positions.where((p) => (p.speed ?? 0) > 1).length;
    final alerts =
        devices.where((d) => d.status.toLowerCase() != 'online').length;

    final fleet = devices.take(6).toList(growable: false);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 2 : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: columns == 2 ? 2.25 : 3.2,
              children: [
                _OpsKpiCard(
                  title: 'Frota',
                  value: '$total',
                  detail: 'ativos monitorados',
                  icon: Icons.directions_car_outlined,
                ),
                _OpsKpiCard(
                  title: 'Online',
                  value: '$online',
                  detail: '$offline offline',
                  icon: Icons.wifi_tethering_rounded,
                  color: Colors.greenAccent,
                ),
                _OpsKpiCard(
                  title: 'Movimento',
                  value: '$moving',
                  detail: 'veículos em rota',
                  icon: Icons.near_me_outlined,
                  color: Colors.lightBlueAccent,
                ),
                _OpsKpiCard(
                  title: 'Alertas',
                  value: '$alerts',
                  detail: alerts == 0 ? 'operação normal' : 'pedem atenção',
                  icon: Icons.warning_amber_rounded,
                  color: alerts == 0 ? Colors.greenAccent : Colors.redAccent,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _OpsSection(
          title: 'Visão operacional',
          icon: Icons.radar_outlined,
          child: Column(
            children: [
              _InfoLine(label: 'Cobertura do mapa', value: 'Sempre ativa'),
              _InfoLine(label: 'Última leitura', value: _lastFix(positions)),
              _InfoLine(label: 'Fila de comandos', value: '3 prontos'),
              _InfoLine(label: 'SLA de resposta', value: '94% no prazo'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _OpsSection(
          title: 'Alertas recentes',
          icon: Icons.notifications_active_outlined,
          child: Column(
            children: [
              if (alerts == 0)
                const _AlertTile(
                  title: 'Sem alertas críticos',
                  detail: 'A frota não tem eventos críticos no momento.',
                  color: Colors.greenAccent,
                )
              else
                for (final device
                    in devices.where((d) => d.status.toLowerCase() != 'online'))
                  _AlertTile(
                    title: device.name,
                    detail: 'Status ${device.status} - validar comunicação',
                    color: Colors.redAccent,
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _OpsSection(
          title: 'Ordens de serviço',
          icon: Icons.assignment_outlined,
          child: const Column(
            children: [
              _OrderTile(
                code: 'OS-1842',
                title: 'Instalação agendada',
                detail: 'Técnico em deslocamento',
              ),
              _OrderTile(
                code: 'OS-1843',
                title: 'Manutenção preventiva',
                detail: 'Aguardando janela do cliente',
              ),
              _OrderTile(
                code: 'OS-1844',
                title: 'Retirada de equipamento',
                detail: 'Documentação pendente',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _OpsSection(
          title: 'Frota em destaque',
          icon: Icons.list_alt_outlined,
          child: Column(
            children: [
              if (fleet.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Nenhum veículo encontrado.'),
                )
              else
                for (final device in fleet)
                  _FleetRow(
                    device: device,
                    position: positionByDeviceId[device.id],
                  ),
            ],
          ),
        ),
      ],
    );
  }

  static String _lastFix(List<TraccarPosition> positions) {
    if (positions.isEmpty) return '-';
    final value = positions.first.fixTime.trim();
    return value.isEmpty ? '-' : value;
  }
}

class _OpsKpiCard extends StatelessWidget {
  const _OpsKpiCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    this.color = Colors.white,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpsSection extends StatelessWidget {
  const _OpsSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Icon(icon, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          child,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.title,
    required this.detail,
    required this.color,
  });

  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.code,
    required this.title,
    required this.detail,
  });

  final String code;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FleetRow extends StatelessWidget {
  const _FleetRow({
    required this.device,
    required this.position,
  });

  final TraccarDevice device;
  final TraccarPosition? position;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${(position?.speed ?? 0).toStringAsFixed(0)} km/h',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          StatusPill(status: device.status),
        ],
      ),
    );
  }
}
