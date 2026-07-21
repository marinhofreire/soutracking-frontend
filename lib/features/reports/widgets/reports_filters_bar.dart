import 'package:flutter/material.dart';

import '../models/report_models.dart';

class ReportsFiltersBar extends StatelessWidget {
  const ReportsFiltersBar({
    super.key,
    required this.startDateTime,
    required this.endDateTime,
    required this.vehicle,
    required this.driver,
    required this.type,
    required this.eventType,
    required this.status,
    required this.vehicleOptions,
    required this.driverOptions,
    required this.typeOptions,
    required this.eventTypeOptions,
    required this.statusOptions,
    required this.onPickStartDate,
    required this.onPickStartTime,
    required this.onPickEndDate,
    required this.onPickEndTime,
    required this.onVehicleChanged,
    required this.onDriverChanged,
    required this.onTypeChanged,
    required this.onEventTypeChanged,
    required this.onStatusChanged,
    required this.onApplyFilters,
    required this.onExportCsv,
    required this.onExportHtml,
    required this.onExportPdf,
    required this.canExport,
    required this.pdfEnabled,
    required this.onClearFilters,
  });

  final DateTime startDateTime;
  final DateTime endDateTime;
  final String vehicle;
  final String driver;
  final String type;
  final String eventType;
  final String status;
  final List<ReportFilterOption> vehicleOptions;
  final List<String> driverOptions;
  final List<String> typeOptions;
  final List<String> eventTypeOptions;
  final List<String> statusOptions;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickEndDate;
  final VoidCallback onPickEndTime;
  final ValueChanged<String> onVehicleChanged;
  final ValueChanged<String> onDriverChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onEventTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onApplyFilters;
  final VoidCallback onExportCsv;
  final VoidCallback onExportHtml;
  final VoidCallback onExportPdf;
  final bool canExport;
  final bool pdfEnabled;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final appliedPeriod =
        '${_formatDate(startDateTime)} ${_formatTime(startDateTime)}'
        ' ate ${_formatDate(endDateTime)} ${_formatTime(endDateTime)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PickerField(
                label: 'Data inicial',
                value: _formatDate(startDateTime),
                icon: Icons.calendar_today_outlined,
                width: 164,
                onTap: onPickStartDate,
              ),
              _PickerField(
                label: 'Hora inicial',
                value: _formatTime(startDateTime),
                icon: Icons.schedule_outlined,
                width: 138,
                onTap: onPickStartTime,
              ),
              _PickerField(
                label: 'Data final',
                value: _formatDate(endDateTime),
                icon: Icons.event_outlined,
                width: 164,
                onTap: onPickEndDate,
              ),
              _PickerField(
                label: 'Hora final',
                value: _formatTime(endDateTime),
                icon: Icons.more_time_outlined,
                width: 138,
                onTap: onPickEndTime,
              ),
              _SelectOptionField(
                label: 'Veículo/equipamento',
                value: vehicle,
                options: vehicleOptions,
                onChanged: onVehicleChanged,
                width: 228,
              ),
              _SelectField(
                label: 'Motorista',
                value: driver,
                options: driverOptions,
                onChanged: onDriverChanged,
                width: 190,
              ),
              _SelectField(
                label: 'Tipo de relatório',
                value: type,
                options: typeOptions,
                onChanged: onTypeChanged,
                width: 196,
              ),
              _SelectField(
                label: 'Tipo de evento',
                value: eventType,
                options: eventTypeOptions,
                onChanged: onEventTypeChanged,
                width: 196,
              ),
              _SelectField(
                label: 'Severidade/status',
                value: status,
                options: statusOptions,
                onChanged: onStatusChanged,
                width: 182,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onApplyFilters,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Buscar'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2D8CFF),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: canExport ? onExportCsv : null,
                icon: const Icon(Icons.grid_on_outlined, size: 18),
                label: const Text('CSV'),
              ),
              OutlinedButton.icon(
                onPressed: canExport ? onExportHtml : null,
                icon: const Icon(Icons.language_outlined, size: 18),
                label: const Text('HTML'),
              ),
              OutlinedButton.icon(
                onPressed: pdfEnabled ? onExportPdf : null,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: Text(pdfEnabled ? 'PDF' : 'PDF em desenvolvimento'),
              ),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Limpar'),
              ),
              _InfoField(
                label: 'Intervalo aplicado',
                value: appliedPeriod,
                width: 360,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.width,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: _fieldDecoration(label),
          child: Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF60718D)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF25344A),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.width,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: options.contains(value)
            ? value
            : (options.isEmpty ? null : options.first),
        items: [
          for (final option in options)
            DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            ),
        ],
        onChanged: (next) {
          if (next != null) {
            onChanged(next);
          }
        },
        decoration: _fieldDecoration(label),
      ),
    );
  }
}

class _SelectOptionField extends StatelessWidget {
  const _SelectOptionField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.width,
  });

  final String label;
  final String value;
  final List<ReportFilterOption> options;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    final resolvedValue = options.any((option) => option.value == value)
        ? value
        : (options.isEmpty ? null : options.first.value);

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: resolvedValue,
        items: [
          for (final option in options)
            DropdownMenuItem<String>(
              value: option.value,
              child: Text(option.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (next) {
          if (next != null) {
            onChanged(next);
          }
        },
        decoration: _fieldDecoration(label),
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({
    required this.label,
    required this.value,
    required this.width,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: _fieldDecoration(label),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF60718D),
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFF8FBFF),
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFD6E0EE)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFD6E0EE)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF7CB0FF)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  );
}
