import 'report_export_downloader_stub.dart'
    if (dart.library.html) 'report_export_downloader_web.dart' as downloader;
import '../models/report_models.dart';

enum ReportExportFormat {
  csv,
  html,
  pdf,
}

enum ReportExportStatus {
  exported,
  missingData,
  unsupported,
  technicalFailure,
}

class ReportExportResult {
  const ReportExportResult({
    required this.status,
    required this.message,
    this.fileName,
  });

  final ReportExportStatus status;
  final String message;
  final String? fileName;

  bool get success => status == ReportExportStatus.exported;
}

Future<ReportExportResult> exportReports({
  required List<ReportRecord> records,
  required ReportExportFormat format,
  required String scopeLabel,
}) async {
  if (records.isEmpty) {
    return const ReportExportResult(
      status: ReportExportStatus.missingData,
      message: 'Busque um relatorio antes de exportar',
    );
  }

  if (format == ReportExportFormat.pdf) {
    return const ReportExportResult(
      status: ReportExportStatus.unsupported,
      message: 'PDF em desenvolvimento',
    );
  }

  final timestamp = _timestampForFile(DateTime.now());
  final safeScope = _sanitizeForFile(scopeLabel);
  final extension = format == ReportExportFormat.csv ? 'csv' : 'html';
  final fileName = 'relatorios_${safeScope}_$timestamp.$extension';

  final content = format == ReportExportFormat.csv
      ? _buildCsv(records)
      : _buildHtml(records);
  final mimeType = format == ReportExportFormat.csv
      ? 'text/csv;charset=utf-8'
      : 'text/html;charset=utf-8';

  try {
    await downloader.downloadTextFile(
      fileName: fileName,
      mimeType: mimeType,
      content: content,
    );
    return ReportExportResult(
      status: ReportExportStatus.exported,
      message: format == ReportExportFormat.csv
          ? 'CSV exportado com sucesso'
          : 'HTML exportado com sucesso',
      fileName: fileName,
    );
  } catch (_) {
    return const ReportExportResult(
      status: ReportExportStatus.technicalFailure,
      message: 'Falha ao gerar download. Verifique o navegador e tente novamente.',
    );
  }
}

String _buildCsv(List<ReportRecord> records) {
  const headers = [
    'tipo_relatorio',
    'veiculo_dispositivo',
    'data_hora',
    'latitude',
    'longitude',
    'velocidade_kmh',
    'ignicao',
    'bateria',
    'evento_status',
    'endereco',
    'attributes',
  ];

  final rows = <String>[
    '\ufeff${headers.join(',')}',
  ];

  for (final record in records) {
    final values = <String>[
      record.type.label,
      record.vehicle,
      _formatDateTime(record.createdAt),
      record.latitudeLabel,
      record.longitudeLabel,
      record.speedKmhLabel,
      record.ignitionLabel,
      record.batteryLabel,
      _eventStatusLabel(record),
      record.addressLabel,
      record.attributesSummaryLabel,
    ];
    rows.add(values.map(_escapeCsv).join(','));
  }

  return rows.join('\n');
}

String _buildHtml(List<ReportRecord> records) {
  final rows = records.map((record) {
    final values = <String>[
      record.type.label,
      record.vehicle,
      _formatDateTime(record.createdAt),
      record.latitudeLabel,
      record.longitudeLabel,
      record.speedKmhLabel,
      record.ignitionLabel,
      record.batteryLabel,
      _eventStatusLabel(record),
      record.addressLabel,
      record.attributesSummaryLabel,
    ];
    return '<tr>${values.map((value) => '<td>${_escapeHtml(value)}</td>').join()}</tr>';
  }).join('\n');

  return '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <title>Relatorios SouTracking</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; color: #1f2a44; }
    h1 { font-size: 20px; margin-bottom: 12px; }
    table { border-collapse: collapse; width: 100%; font-size: 12px; }
    th, td { border: 1px solid #d7e1ef; padding: 6px; text-align: left; vertical-align: top; }
    th { background: #f4f7fc; font-weight: 700; }
    tr:nth-child(even) { background: #fbfcfe; }
  </style>
</head>
<body>
  <h1>Relatorios SouTracking</h1>
  <table>
    <thead>
      <tr>
        <th>Tipo do relatorio</th>
        <th>Veiculo/dispositivo</th>
        <th>Data/hora</th>
        <th>Latitude</th>
        <th>Longitude</th>
        <th>Velocidade</th>
        <th>Ignicao</th>
        <th>Bateria</th>
        <th>Evento/Status</th>
        <th>Endereco</th>
        <th>Attributes</th>
      </tr>
    </thead>
    <tbody>
      $rows
    </tbody>
  </table>
</body>
</html>
''';
}

String _eventStatusLabel(ReportRecord record) {
  final event = record.eventType?.trim() ?? '';
  if (event.isNotEmpty) {
    return event;
  }
  return record.status.label;
}

String _escapeCsv(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _sanitizeForFile(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return normalized.isEmpty ? 'geral' : normalized;
}

String _timestampForFile(DateTime dateTime) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${dateTime.year}${two(dateTime.month)}${two(dateTime.day)}_'
      '${two(dateTime.hour)}${two(dateTime.minute)}${two(dateTime.second)}';
}

String _formatDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString().padLeft(4, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute:$second';
}
