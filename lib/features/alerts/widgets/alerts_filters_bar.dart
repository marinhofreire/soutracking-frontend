import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';

class AlertsFiltersBar extends StatelessWidget {
  const AlertsFiltersBar({
    super.key,
    required this.period,
    required this.type,
    required this.severity,
    required this.status,
    required this.vehicle,
    required this.periodOptions,
    required this.typeOptions,
    required this.severityOptions,
    required this.statusOptions,
    required this.vehicleOptions,
    required this.onPeriodChanged,
    required this.onTypeChanged,
    required this.onSeverityChanged,
    required this.onStatusChanged,
    required this.onVehicleChanged,
  });

  final String period;
  final String type;
  final String severity;
  final String status;
  final String vehicle;

  final List<String> periodOptions;
  final List<String> typeOptions;
  final List<String> severityOptions;
  final List<String> statusOptions;
  final List<String> vehicleOptions;

  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onSeverityChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onVehicleChanged;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _FilterField(
            label: 'Periodo',
            value: period,
            options: periodOptions,
            onChanged: onPeriodChanged,
          ),
          _FilterField(
            label: 'Tipo',
            value: type,
            options: typeOptions,
            onChanged: onTypeChanged,
          ),
          _FilterField(
            label: 'Severidade',
            value: severity,
            options: severityOptions,
            onChanged: onSeverityChanged,
          ),
          _FilterField(
            label: 'Status',
            value: status,
            options: statusOptions,
            onChanged: onStatusChanged,
          ),
          _FilterField(
            label: 'Veiculo',
            value: vehicle,
            options: vehicleOptions,
            onChanged: onVehicleChanged,
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
      width: 210,
      child: DropdownButtonFormField<String>(
        value: value,
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
