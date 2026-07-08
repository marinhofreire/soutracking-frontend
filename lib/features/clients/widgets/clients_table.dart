import 'package:flutter/material.dart';

import '../models/client_models.dart';

// Stub widget — clients_screen.dart renders the table inline.
// Kept to avoid breaking any future imports.
class ClientsTable extends StatelessWidget {
  const ClientsTable({super.key, required this.records});
  final List<ClientRecord> records;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
