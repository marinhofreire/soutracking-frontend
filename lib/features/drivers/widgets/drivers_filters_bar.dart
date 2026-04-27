import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';

class DriversFiltersBar extends StatelessWidget {
  const DriversFiltersBar({
    super.key,
    required this.searchController,
    required this.status,
    required this.vehicle,
    required this.cnh,
    required this.statusOptions,
    required this.vehicleOptions,
    required this.cnhOptions,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onVehicleChanged,
    required this.onCnhChanged,
    required this.onMoreFilters,
  });

  final TextEditingController searchController;
  final String status;
  final String vehicle;
  final String cnh;
  final List<String> statusOptions;
  final List<String> vehicleOptions;
  final List<String> cnhOptions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onVehicleChanged;
  final ValueChanged<String> onCnhChanged;
  final VoidCallback onMoreFilters;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Buscar por nome, telefone ou CNH',
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
            label: 'Veiculo',
            value: vehicle,
            options: vehicleOptions,
            onChanged: onVehicleChanged,
          ),
          _FilterField(
            label: 'CNH',
            value: cnh,
            options: cnhOptions,
            onChanged: onCnhChanged,
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
      width: 190,
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
