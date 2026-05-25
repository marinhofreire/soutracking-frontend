import 'package:flutter/material.dart';

class ReportsFiltersBar extends StatelessWidget {
  const ReportsFiltersBar({
    super.key,
    required this.period,
    required this.vehicle,
    required this.driver,
    required this.type,
    required this.status,
    required this.periodOptions,
    required this.vehicleOptions,
    required this.driverOptions,
    required this.typeOptions,
    required this.statusOptions,
    required this.onPeriodChanged,
    required this.onVehicleChanged,
    required this.onDriverChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onSearch,
    required this.onExportCsv,
    required this.onExportHtml,
    required this.onExportPdf,
    required this.canExport,
    required this.pdfEnabled,
    required this.onClearFilters,
  });

  final String period;
  final String vehicle;
  final String driver;
  final String type;
  final String status;
  final List<String> periodOptions;
  final List<String> vehicleOptions;
  final List<String> driverOptions;
  final List<String> typeOptions;
  final List<String> statusOptions;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<String> onVehicleChanged;
  final ValueChanged<String> onDriverChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onSearch;
  final VoidCallback onExportCsv;
  final VoidCallback onExportHtml;
  final VoidCallback onExportPdf;
  final bool canExport;
  final bool pdfEnabled;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
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
              _FilterField(
                label: 'Período',
                value: period,
                options: periodOptions,
                onChanged: onPeriodChanged,
                width: 190,
              ),
              _FilterField(
                label: 'Equipamento',
                value: vehicle,
                options: vehicleOptions,
                onChanged: onVehicleChanged,
                width: 220,
              ),
              _FilterField(
                label: 'Tipo de relatório',
                value: type,
                options: typeOptions,
                onChanged: onTypeChanged,
                width: 200,
              ),
              _FilterField(
                label: 'Severidade',
                value: status,
                options: statusOptions,
                onChanged: onStatusChanged,
                width: 200,
              ),
              _FilterField(
                label: 'Motorista',
                value: driver,
                options: driverOptions,
                onChanged: onDriverChanged,
                width: 200,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onSearch,
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
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({
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
          if (next != null) onChanged(next);
        },
        decoration: InputDecoration(
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }
}
