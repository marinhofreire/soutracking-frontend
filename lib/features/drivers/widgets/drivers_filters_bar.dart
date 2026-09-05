import 'package:flutter/material.dart';

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
    required this.onCreateDriver,
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
  final VoidCallback onCreateDriver;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final search = Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD1DCEB)),
          ),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Buscar motorista, telefone ou CNH...',
              hintStyle: TextStyle(
                color: Color(0xFF74839B),
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF60718D)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );
        final filters = OutlinedButton.icon(
          onPressed: onMoreFilters,
          icon: const Icon(Icons.filter_alt_outlined, size: 18),
          label: const Text('Filtros'),
        );
        final create = FilledButton.icon(
          onPressed: onCreateDriver,
          icon: const Icon(Icons.add_rounded, size: 17),
          label: const Text('Novo motorista'),
        );
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              search,
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: [filters, create]),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 10),
            filters,
            const SizedBox(width: 10),
            create,
          ],
        );
      },
    );
  }
}
