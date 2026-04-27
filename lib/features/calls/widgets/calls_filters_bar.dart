import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';

class CallsFiltersBar extends StatelessWidget {
  const CallsFiltersBar({
    super.key,
    required this.searchController,
    required this.status,
    required this.priority,
    required this.category,
    required this.attendant,
    required this.client,
    required this.statusOptions,
    required this.priorityOptions,
    required this.categoryOptions,
    required this.attendantOptions,
    required this.clientOptions,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onCategoryChanged,
    required this.onAttendantChanged,
    required this.onClientChanged,
    required this.onMoreFilters,
  });

  final TextEditingController searchController;
  final String status;
  final String priority;
  final String category;
  final String attendant;
  final String client;
  final List<String> statusOptions;
  final List<String> priorityOptions;
  final List<String> categoryOptions;
  final List<String> attendantOptions;
  final List<String> clientOptions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onAttendantChanged;
  final ValueChanged<String> onClientChanged;
  final VoidCallback onMoreFilters;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Buscar chamados',
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
            label: 'Categoria',
            value: category,
            options: categoryOptions,
            onChanged: onCategoryChanged,
          ),
          _FilterField(
            label: 'Atendente',
            value: attendant,
            options: attendantOptions,
            onChanged: onAttendantChanged,
          ),
          _FilterField(
            label: 'Cliente',
            value: client,
            options: clientOptions,
            onChanged: onClientChanged,
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
