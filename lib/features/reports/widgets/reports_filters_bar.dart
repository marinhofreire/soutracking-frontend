import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';

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
    return AdminGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _FilterField(
                label: 'Período',
                value: period,
                options: periodOptions,
                onChanged: onPeriodChanged,
              ),
              _FilterField(
                label: 'Veículo',
                value: vehicle,
                options: vehicleOptions,
                onChanged: onVehicleChanged,
              ),
              _FilterField(
                label: 'Motorista',
                value: driver,
                options: driverOptions,
                onChanged: onDriverChanged,
              ),
              _FilterField(
                label: 'Tipo de relatório',
                value: type,
                options: typeOptions,
                onChanged: onTypeChanged,
              ),
              _FilterField(
                label: 'Status',
                value: status,
                options: statusOptions,
                onChanged: onStatusChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AdminActionButton(
                label: 'Buscar',
                icon: Icons.search_outlined,
                onPressed: onSearch,
              ),
              OutlinedButton.icon(
                onPressed: canExport ? onExportCsv : null,
                icon: const Icon(Icons.grid_on_outlined, size: 18),
                label: const Text('Exportar'),
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
                label: const Text('Limpar filtros'),
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
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String>(
        initialValue: value,
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
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
