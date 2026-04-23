import 'package:flutter/material.dart';

import '../../state/session_state.dart';
import '../common/json_crud_screen.dart';

class AttributesScreen extends StatelessWidget {
  const AttributesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return JsonCrudScreen(
      title: 'Atributos',
      endpointPath: '/attributes',
      listProvider: attributesProvider,
      titleField: 'description',
      subtitleField: 'attribute',
      typeOptions: const ['string', 'number', 'boolean', 'date', 'time'],
      template: {
        'description': 'Consumo médio',
        'attribute': 'avgFuel',
        'type': 'number',
        'expression': '',
      },
    );
  }
}
