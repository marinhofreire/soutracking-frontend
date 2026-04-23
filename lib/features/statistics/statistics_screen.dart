import 'package:flutter/material.dart';

import '../../state/session_state.dart';
import '../common/json_crud_screen.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return JsonCrudScreen(
      title: 'Estatísticas',
      endpointPath: '/statistics',
      listProvider: statisticsProvider,
      titleField: 'name',
      subtitleField: 'description',
      template: {},
      enableCreate: false,
    );
  }
}
