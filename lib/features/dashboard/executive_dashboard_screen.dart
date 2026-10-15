import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/session_state.dart';
import '../../ui/module_scaffold.dart';

/// Per-user display opt-in. Nothing is granted merely by being an administrator.
final executiveViewEnabledProvider = Provider<bool>((ref) {
  final session = ref.watch(sessionProvider);
  final users = ref.watch(usersProvider).valueOrNull;
  final email = session.email?.trim().toLowerCase();
  if (email == null || email.isEmpty || users == null) return false;
  return users
          .where((u) => u.email.trim().toLowerCase() == email)
          .firstOrNull
          ?.attributes?['souExecutiveView'] ==
      true;
});

/// Display-only shell. Aggregated history and delivery are supplied by the
/// application services when available; no fabricated production metrics.
class ExecutiveDashboardScreen extends StatefulWidget {
  const ExecutiveDashboardScreen({super.key, this.onPeriodChanged});
  final ValueChanged<int>? onPeriodChanged;
  @override
  State<ExecutiveDashboardScreen> createState() =>
      _ExecutiveDashboardScreenState();
}

class _ExecutiveDashboardScreenState extends State<ExecutiveDashboardScreen> {
  int days = 14;
  @override
  Widget build(BuildContext context) => ModuleScaffold(
        title: 'Visão executiva',
        subtitle:
            'Para donos e gestores · últimos $days dias comparados ao período anterior.',
        headerActions: [
          SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 dias')),
                ButtonSegment(value: 14, label: Text('14 dias')),
                ButtonSegment(value: 30, label: Text('30 dias'))
              ],
              selected: {
                days
              },
              onSelectionChanged: (values) {
                setState(() => days = values.first);
                widget.onPeriodChanged?.call(days);
              })
        ],
        content: LayoutBuilder(builder: (context, size) {
          final cards = [
            for (final title in [
              'Eventos críticos no período',
              'Tempo médio de resposta a alerta',
              'Manutenções'
            ])
              ModuleCard(
                  title: title,
                  child: const ModuleEmpty('Ainda sem histórico suficiente',
                      'Os indicadores serão exibidos quando houver dados disponíveis.'))
          ];
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (size.maxWidth < 760)
                  ...cards
                else
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final card in cards)
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: card))
                  ]),
                const ModuleCard(
                    title: 'Eventos críticos por semana',
                    child: ModuleEmpty('Ainda sem histórico suficiente',
                        'O histórico será comparado com o período anterior.')),
                const ModuleCard(
                    title: 'Precisa de decisão',
                    child: ModuleEmpty('Ainda sem histórico suficiente',
                        'Ocorrências e manutenções que exigirem uma decisão aparecerão aqui.')),
              ]);
        }),
        actions: [
          OutlinedButton(onPressed: null, child: Text('Exportar PDF')),
          FilledButton(
              onPressed: null, child: Text('Enviar resumo semanal no WhatsApp'))
        ],
      );
}
