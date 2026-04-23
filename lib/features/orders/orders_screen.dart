import 'package:flutter/material.dart';

import '../../state/session_state.dart';
import '../common/json_crud_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return JsonCrudScreen(
      title: 'Ordens',
      endpointPath: '/orders',
      listProvider: ordersProvider,
      titleField: 'description',
      subtitleField: 'type',
      typeOptions: const ['service', 'delivery', 'pickup'],
      template: {
        'description': 'Ordem de serviço',
        'deviceId': null,
        'type': 'service',
        'attributes': {},
      },
    );
  }
}
