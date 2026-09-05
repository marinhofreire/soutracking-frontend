import 'package:flutter/material.dart';

import '../models/driver_models.dart';

class DriversTable extends StatelessWidget {
  const DriversTable({super.key, required this.records});

  final List<DriverRecord> records;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E1EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text(
              'Lista de motoristas',
              style: TextStyle(
                color: Color(0xFF1F2A44),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFDCE6F3)),
          const _DriverTableHeader(),
          const Divider(height: 1, color: Color(0xFFDCE6F3)),
          if (records.isEmpty)
            const SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  'Nenhum motorista cadastrado ainda.',
                  style: TextStyle(
                    color: Color(0xFF60718D),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            for (final record in records) _DriverTableRow(record: record),
        ],
      ),
    );
  }
}

class _DriverTableHeader extends StatelessWidget {
  const _DriverTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          _HeaderCell(width: 2.4, label: 'Motorista'),
          _HeaderCell(width: 1.7, label: 'Telefone'),
          _HeaderCell(width: 1.5, label: 'CNH'),
          _HeaderCell(width: 1.8, label: 'Veiculo vinculado'),
          _HeaderCell(width: 1.8, label: 'Validade CNH'),
          _HeaderCell(width: 0.9, label: 'Acoes'),
        ],
      ),
    );
  }
}

class _DriverTableRow extends StatelessWidget {
  const _DriverTableRow({required this.record});

  final DriverRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2EAF4))),
      ),
      child: Row(
        children: [
          _Cell(
            width: 2.4,
            child: Text(
              record.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1F2A44),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _Cell(width: 1.7, child: _Value(record.phone)),
          _Cell(width: 1.5, child: _Value(record.cnh)),
          _Cell(width: 1.8, child: _Value(record.vehicle)),
          _Cell(
              width: 1.8,
              child:
                  _CnhState(value: record.cnhExpiry, state: record.cnhState)),
          _Cell(
            width: 0.9,
            child: Row(
              children: const [
                _ActionIcon(icon: Icons.visibility_outlined),
                SizedBox(width: 6),
                _ActionIcon(icon: Icons.edit_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.width, required this.label});
  final double width;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        flex: (width * 10).round(),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF60718D),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => Expanded(
        flex: (width * 10).round(),
        child: child,
      );
}

class _Value extends StatelessWidget {
  const _Value(this.value);
  final String value;

  @override
  Widget build(BuildContext context) => Text(
        value.trim().isEmpty ? 'Nao informado' : value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF50647E),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _CnhState extends StatelessWidget {
  const _CnhState({required this.value, required this.state});
  final DateTime? value;
  final CnhState state;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const _Value('Nao informado');
    final color = switch (state) {
      CnhState.valid => const Color(0xFF18A558),
      CnhState.expiring => const Color(0xFFF59E0B),
      CnhState.expired => const Color(0xFFE74B4B),
      CnhState.unknown => const Color(0xFF8291A8),
    };
    final formatted =
        '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return Text(
      formatted,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 29,
        height: 29,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F6FD),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF176EEB)),
      );
}
