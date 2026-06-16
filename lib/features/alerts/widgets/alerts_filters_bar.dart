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
        spacing: 10,
        runSpacing: 10,
        children: [
          _FilterField(
            label: 'Período',
            value: period,
            options: periodOptions,
            onChanged: onPeriodChanged,
            width: 160,
          ),
          _FilterField(
            label: 'Tipo',
            value: type,
            options: typeOptions,
            onChanged: onTypeChanged,
            width: 170,
          ),
          _FilterField(
            label: 'Prioridade',
            value: severity,
            options: severityOptions,
            onChanged: onSeverityChanged,
            width: 170,
          ),
          _FilterField(
            label: 'Status',
            value: status,
            options: statusOptions,
            onChanged: onStatusChanged,
            width: 170,
          ),
          _FilterField(
            label: 'Equipamento',
            value: vehicle,
            options: vehicleOptions,
            onChanged: onVehicleChanged,
            width: 220,
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
        initialValue: value,
        dropdownColor: const Color(0xFF102039),
        style: const TextStyle(
          color: Color(0xFFE7F2FF),
          fontWeight: FontWeight.w600,
        ),
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
          labelStyle: const TextStyle(color: Color(0xFF9DB6D5)),
          filled: true,
          fillColor: const Color(0xB30D1B31),
          isDense: true,
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF294A73)),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF294A73)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF4A95FF)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }
}
