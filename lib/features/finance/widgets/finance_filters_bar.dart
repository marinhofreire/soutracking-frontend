import 'package:flutter/material.dart';

import '../../admin/admin_reference_ui.dart';

class FinanceFiltersBar extends StatelessWidget {
  const FinanceFiltersBar({
    super.key,
    required this.searchController,
    required this.status,
    required this.period,
    required this.paymentMethod,
    required this.client,
    required this.statusOptions,
    required this.periodOptions,
    required this.paymentMethodOptions,
    required this.clientOptions,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onPeriodChanged,
    required this.onPaymentMethodChanged,
    required this.onClientChanged,
    required this.onMoreFilters,
    required this.onNewCharge,
    required this.onPaymentLink,
    required this.onRecurrence,
    required this.onExport,
  });

  final TextEditingController searchController;
  final String status;
  final String period;
  final String paymentMethod;
  final String client;
  final List<String> statusOptions;
  final List<String> periodOptions;
  final List<String> paymentMethodOptions;
  final List<String> clientOptions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<String> onClientChanged;
  final VoidCallback onMoreFilters;
  final VoidCallback onNewCharge;
  final VoidCallback onPaymentLink;
  final VoidCallback onRecurrence;
  final VoidCallback onExport;

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
              SizedBox(
                width: 280,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: const InputDecoration(
                    labelText: 'Buscar cliente/cobranca',
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
                label: 'Periodo',
                value: period,
                options: periodOptions,
                onChanged: onPeriodChanged,
              ),
              _FilterField(
                label: 'Forma de pagamento',
                value: paymentMethod,
                options: paymentMethodOptions,
                onChanged: onPaymentMethodChanged,
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AdminActionButton(
                label: 'Nova cobranca',
                icon: Icons.add_card_outlined,
                onPressed: onNewCharge,
              ),
              OutlinedButton.icon(
                onPressed: onPaymentLink,
                icon: const Icon(Icons.link_outlined, size: 18),
                label: const Text('Criar link de pagamento'),
              ),
              OutlinedButton.icon(
                onPressed: onRecurrence,
                icon: const Icon(Icons.repeat_outlined, size: 18),
                label: const Text('Criar recorrencia'),
              ),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Exportar'),
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
