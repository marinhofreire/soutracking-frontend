import 'package:flutter/material.dart';

import '../../state/session_state.dart';
import '../common/json_crud_screen.dart';

class CalendarsScreen extends StatelessWidget {
  const CalendarsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return JsonCrudScreen(
      title: 'Calendários',
      endpointPath: '/calendars',
      listProvider: calendarsProvider,
      titleField: 'name',
      template: {'name': 'Calendário padrão', 'data': []},
    );
  }
}
