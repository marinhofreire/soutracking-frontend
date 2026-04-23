import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/session_state.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({
    super.key,
    required this.title,
    required this.endpointPath,
    this.enableDeviceFilter = true,
  });

  final String title;
  final String endpointPath;
  final bool enableDeviceFilter;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(hours: 24));
  DateTime _to = DateTime.now();
  int? _deviceId;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  Future<void> _pickDateTime({required bool isFrom}) async {
    final current = isFrom ? _from : _to;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    if (!mounted) return;
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      final query = {
        'from': _from.toUtc().toIso8601String(),
        'to': _to.toUtc().toIso8601String(),
        if (widget.enableDeviceFilter && _deviceId != null)
          'deviceId': '$_deviceId',
      };
      final data = await client.getList(
        path: widget.endpointPath,
        cookie: session.cookie,
        authHeader: session.authHeader,
        query: query,
      );
      setState(() {
        _results = data;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDateTime(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _buildHtmlReport() {
    final columns = <String>{};
    for (final item in _results) {
      for (final key in item.keys) {
        columns.add(key);
      }
    }

    final orderedColumns = columns.toList()..sort();
    final buffer = StringBuffer();
    buffer.writeln('<!doctype html>');
    buffer.writeln('<html lang="pt-BR">');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="utf-8">');
    buffer.writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
    );
    buffer.writeln('<title>${_escapeHtml(widget.title)}</title>');
    buffer.writeln('<style>');
    buffer.writeln(
      'body{font-family:Segoe UI,Arial,sans-serif;padding:24px;background:#0f1115;color:#e9eef5;}',
    );
    buffer.writeln(
      '.card{background:#171b22;border:1px solid #2c3440;border-radius:12px;padding:16px;margin-bottom:16px;}',
    );
    buffer.writeln(
      'table{width:100%;border-collapse:collapse;background:#171b22;border:1px solid #2c3440;}',
    );
    buffer.writeln(
      'th,td{border:1px solid #2c3440;padding:8px;text-align:left;vertical-align:top;font-size:13px;}',
    );
    buffer.writeln('th{background:#202733;color:#f7fbff;}');
    buffer.writeln('tr:nth-child(even){background:#141920;}');
    buffer.writeln('.muted{color:#97a4b3;font-size:12px;}');
    buffer.writeln('</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('<h1>${_escapeHtml(widget.title)}</h1>');
    buffer.writeln('<div class="card">');
    buffer.writeln(
      '<div><strong>Período:</strong> ${_escapeHtml(_formatDateTime(_from))} até ${_escapeHtml(_formatDateTime(_to))}</div>',
    );
    buffer.writeln(
      '<div><strong>Dispositivo:</strong> ${_escapeHtml(_deviceId?.toString() ?? 'Todos')}</div>',
    );
    buffer.writeln(
      '<div class="muted">Gerado em ${_escapeHtml(_formatDateTime(DateTime.now()))}</div>',
    );
    buffer.writeln('</div>');

    buffer.writeln('<table>');
    buffer.writeln('<thead><tr>');
    for (final column in orderedColumns) {
      buffer.writeln('<th>${_escapeHtml(column)}</th>');
    }
    buffer.writeln('</tr></thead>');
    buffer.writeln('<tbody>');
    for (final item in _results) {
      buffer.writeln('<tr>');
      for (final column in orderedColumns) {
        final value = item[column];
        buffer.writeln('<td>${_escapeHtml(value?.toString() ?? '')}</td>');
      }
      buffer.writeln('</tr>');
    }
    buffer.writeln('</tbody>');
    buffer.writeln('</table>');
    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  Future<void> _openHtmlReport() async {
    if (_results.isEmpty) return;
    final html = _buildHtmlReport();
    final uri = Uri.dataFromString(
      html,
      mimeType: 'text/html',
      encoding: utf8,
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel abrir o HTML.')),
      );
    }
  }

  Future<void> _copyHtmlReport() async {
    if (_results.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _buildHtmlReport()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('HTML do relatorio copiado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);

    final list = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text('Erro: $_error'))
            : _results.isEmpty
                ? const Center(child: Text('Nenhum resultado no período'))
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      final title = item['type'] ?? item['name'] ?? 'Item';
                      final subtitle = [
                        if (item['deviceId'] != null)
                          'Device: ${item['deviceId']}',
                        if (item['serverTime'] != null)
                          'Server: ${item['serverTime']}',
                        if (item['startTime'] != null)
                          'Início: ${item['startTime']}',
                        if (item['endTime'] != null) 'Fim: ${item['endTime']}',
                      ].join(' • ');
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
                            const Icon(Icons.receipt_long_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$title',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  if (subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.white70),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final form = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickDateTime(isFrom: true),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('De: ${_formatDateTime(_from)}'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDateTime(isFrom: false),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('Até: ${_formatDateTime(_to)}'),
                ),
              ],
            ),
            if (widget.enableDeviceFilter) ...[
              const SizedBox(height: 12),
              devicesAsync.when(
                data: (devices) {
                  return DropdownButtonFormField<int?>(
                    key: ValueKey('report-device-${_deviceId ?? 'all'}'),
                    initialValue: _deviceId,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todos os dispositivos'),
                      ),
                      ...devices.map(
                        (d) => DropdownMenuItem<int?>(
                          value: d.id,
                          child: Text(d.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _deviceId = value),
                    decoration: const InputDecoration(labelText: 'Dispositivo'),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Erro: $error'),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.search),
                  label: const Text('Gerar relatório'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _loading || _results.isEmpty ? null : _openHtmlReport,
                  icon: const Icon(Icons.language_outlined),
                  label: const Text('Abrir HTML'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _loading || _results.isEmpty ? null : _copyHtmlReport,
                  icon: const Icon(Icons.content_copy_outlined),
                  label: const Text('Copiar HTML'),
                ),
              ],
            ),
          ],
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 380,
                margin: const EdgeInsets.only(left: 16, right: 20, top: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(child: form),
                  ),
                ),
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
          children: [
            form,
            const SizedBox(height: 20),
            SizedBox(height: 420, child: list),
          ],
        );
      },
    );
  }
}
