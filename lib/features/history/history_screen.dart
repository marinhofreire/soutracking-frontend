import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int? _deviceId;
  DateTime _from = DateTime.now().subtract(const Duration(hours: 24));
  DateTime _to = DateTime.now();
  bool _loading = false;
  List<Map<String, dynamic>> _routeRows = [];
  List<Map<String, dynamic>> _eventRows = [];

  Future<void> _pickDateTime({required bool isFrom}) async {
    final current = isFrom ? _from : _to;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isFrom) {
        _from = selected;
      } else {
        _to = selected;
      }
    });
  }

  Future<void> _loadHistory() async {
    if (_deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um dispositivo.')),
      );
      return;
    }
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    final query = {
      'deviceId': '$_deviceId',
      'from': _from.toUtc().toIso8601String(),
      'to': _to.toUtc().toIso8601String(),
    };

    setState(() => _loading = true);
    try {
      final routeData = await client.getList(
        path: '/reports/route',
        cookie: session.cookie,
        authHeader: session.authHeader,
        query: query,
      );
      final eventData = await client.getList(
        path: '/reports/events',
        cookie: session.cookie,
        authHeader: session.authHeader,
        query: query,
      );
      if (!mounted) return;
      setState(() {
        _routeRows = routeData;
        _eventRows = eventData;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao carregar historico: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 360,
          margin: const EdgeInsets.only(top: 20, right: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Historico',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              devicesAsync.when(
                data: (devices) => DropdownButtonFormField<int>(
                  initialValue: _deviceId,
                  decoration: const InputDecoration(labelText: 'Dispositivo'),
                  items: [
                    for (final d in devices)
                      DropdownMenuItem(value: d.id, child: Text(d.name)),
                  ],
                  onChanged: (v) => setState(() => _deviceId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Erro: $e'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _pickDateTime(isFrom: true),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('De: ${_fmt(_from)}'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pickDateTime(isFrom: false),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('Ate: ${_fmt(_to)}'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _loading ? null : _loadHistory,
                icon: const Icon(Icons.history_outlined),
                label: const Text('Mostrar historico'),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: _eventRows.length,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (context, index) {
                          final e = _eventRows[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.timeline_outlined),
                            title: Text('${e['type'] ?? 'evento'}'),
                            subtitle: Text(
                              '${e['eventTime'] ?? e['serverTime'] ?? ''}',
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _routeRows.isEmpty
                    ? const Center(
                        child: Text('Sem registros de rota no periodo.'))
                    : ListView(
                        children: [
                          Text(
                            'Registros de rota (${_routeRows.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Inicio')),
                                DataColumn(label: Text('Fim')),
                                DataColumn(label: Text('Distancia')),
                                DataColumn(label: Text('Vel. media')),
                                DataColumn(label: Text('Vel. max')),
                              ],
                              rows: [
                                for (final row in _routeRows)
                                  DataRow(
                                    cells: [
                                      DataCell(
                                          Text('${row['startTime'] ?? ''}')),
                                      DataCell(Text('${row['endTime'] ?? ''}')),
                                      DataCell(Text('${row['distance'] ?? 0}')),
                                      DataCell(
                                          Text('${row['averageSpeed'] ?? 0}')),
                                      DataCell(Text('${row['maxSpeed'] ?? 0}')),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}
