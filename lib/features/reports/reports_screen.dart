import 'package:flutter/material.dart';

import '../common/report_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({
    super.key,
    required this.title,
    required this.endpointPath,
  });

  final String title;
  final String endpointPath;

  @override
  Widget build(BuildContext context) {
    return ReportScreen(title: title, endpointPath: endpointPath);
  }
}
