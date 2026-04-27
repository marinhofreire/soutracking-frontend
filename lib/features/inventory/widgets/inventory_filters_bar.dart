import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';

class InventoryFiltersBar extends StatelessWidget {
  const InventoryFiltersBar({
    super.key,
    required this.searchController,
    required this.category,
    required this.status,
    required this.location,
    required this.supplier,
    required this.categoryOptions,
    required this.statusOptions,
    required this.locationOptions,
    required this.supplierOptions,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onLocationChanged,
    required this.onSupplierChanged,
    required this.onMoreFilters,
    required this.onEntry,
    required this.onExit,
    required this.onTransfer,
    required this.onReserve,
  });

  final TextEditingController searchController;
  final String category;
  final String status;
  final String location;
  final String supplier;
  final List<String> categoryOptions;
  final List<String> statusOptions;
  final List<String> locationOptions;
  final List<String> supplierOptions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<String> onSupplierChanged;
  final VoidCallback onMoreFilters;
  final VoidCallback onEntry;
  final VoidCallback onExit;
  final VoidCallback onTransfer;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      backgroundColor: const Color(0xF2F8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: const InputDecoration(
                    labelText: 'Buscar item',
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
                label: 'Categoria',
                value: category,
                options: categoryOptions,
                onChanged: onCategoryChanged,
              ),
              _FilterField(
                label: 'Status',
                value: status,
                options: statusOptions,
                onChanged: onStatusChanged,
              ),
              _FilterField(
                label: 'Local',
                value: location,
                options: locationOptions,
                onChanged: onLocationChanged,
              ),
              _FilterField(
                label: 'Fornecedor',
                value: supplier,
                options: supplierOptions,
                onChanged: onSupplierChanged,
              ),
              OutlinedButton.icon(
                onPressed: onMoreFilters,
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: const Text('Mais filtros'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AdminActionButton(
                label: 'Entrada',
                icon: Icons.add_box_outlined,
                onPressed: onEntry,
              ),
              OutlinedButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.indeterminate_check_box_outlined,
                    size: 18),
                label: const Text('Saida'),
              ),
              OutlinedButton.icon(
                onPressed: onTransfer,
                icon: const Icon(Icons.swap_horiz_outlined, size: 18),
                label: const Text('Transferir'),
              ),
              OutlinedButton.icon(
                onPressed: onReserve,
                icon: const Icon(Icons.bookmark_border_outlined, size: 18),
                label: const Text('Reservar'),
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
