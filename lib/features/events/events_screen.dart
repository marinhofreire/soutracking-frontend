import 'package:flutter/material.dart';

import '../common/report_screen.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReportScreen(
      title: 'Eventos',
      endpointPath: '/events',
    );
  }
}
