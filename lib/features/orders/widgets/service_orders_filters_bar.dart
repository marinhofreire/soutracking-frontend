import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';

class ServiceOrdersFiltersBar extends StatelessWidget {
  const ServiceOrdersFiltersBar({
    super.key,
    required this.searchController,
    required this.status,
    required this.priority,
    required this.technician,
    required this.client,
    required this.vehicle,
    required this.period,
    required this.statusOptions,
    required this.priorityOptions,
    required this.technicianOptions,
    required this.clientOptions,
    required this.vehicleOptions,
    required this.periodOptions,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onTechnicianChanged,
    required this.onClientChanged,
    required this.onVehicleChanged,
    required this.onPeriodChanged,
    required this.onMoreFilters,
  });

  final TextEditingController searchController;
  final String status;
  final String priority;
  final String technician;
  final String client;
  final String vehicle;
  final String period;
  final List<String> statusOptions;
  final List<String> priorityOptions;
  final List<String> technicianOptions;
  final List<String> clientOptions;
  final List<String> vehicleOptions;
  final List<String> periodOptions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<String> onTechnicianChanged;
  final ValueChanged<String> onClientChanged;
  final ValueChanged<String> onVehicleChanged;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onMoreFilters;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Buscar OS',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          _FilterField(
            label: 'Status',
            value: status,
            options: statusOptions,
            onChanged: onStatusChanged,
          ),
          _FilterField(
            label: 'Prioridade',
            value: priority,
            options: priorityOptions,
            onChanged: onPriorityChanged,
          ),
          _FilterField(
            label: 'Tecnico',
            value: technician,
            options: technicianOptions,
            onChanged: onTechnicianChanged,
          ),
          _FilterField(
            label: 'Cliente',
            value: client,
            options: clientOptions,
            onChanged: onClientChanged,
          ),
          _FilterField(
            label: 'Veiculo',
            value: vehicle,
            options: vehicleOptions,
            onChanged: onVehicleChanged,
          ),
          _FilterField(
            label: 'Periodo',
            value: period,
            options: periodOptions,
            onChanged: onPeriodChanged,
          ),
          OutlinedButton.icon(
            onPressed: onMoreFilters,
            icon: const Icon(Icons.tune_outlined, size: 18),
            label: const Text('Mais filtros'),
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
      width: 180,
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
