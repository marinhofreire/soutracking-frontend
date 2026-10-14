import 'package:flutter/material.dart';

/// Linha de lista com icone + label + badge de status, no padrao visual de
/// Configuracoes > Permissoes -- a tela mais consistente do app hoje (ver
/// auditoria 2026-10-12/13). Extraido daqui pra virar a base de um design
/// system unico em vez de cada tela reinventar seu proprio card/badge.
class StatusListItem extends StatelessWidget {
  const StatusListItem({
    super.key,
    required this.icon,
    required this.label,
    required this.statusLabel,
    required this.isPositive,
    this.onTap,
    this.trailingIcon,
  });

  final IconData icon;
  final String label;
  final String statusLabel;
  final bool isPositive;
  final VoidCallback? onTap;
  final IconData? trailingIcon;

  static const _textColor = Color(0xFF1F2A44);
  static const _iconColor = Color(0xFF7A8CA8);
  static const _borderColor = Color(0xFFEEF1F6);
  static const _positiveBg = Color(0xFFF0FDF4);
  static const _positiveBorder = Color(0xFFBBF7D0);
  static const _positiveText = Color(0xFF16A34A);
  static const _negativeBg = Color(0xFFFEF2F2);
  static const _negativeBorder = Color(0xFFFECACA);
  static const _negativeText = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final badgeBg = isPositive ? _positiveBg : _negativeBg;
    final badgeBorder = isPositive ? _positiveBorder : _negativeBorder;
    final badgeText = isPositive ? _positiveText : _negativeText;
    final badgeIcon = trailingIcon ??
        (isPositive ? Icons.check_circle_outline : Icons.lock_outline);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _iconColor),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badgeIcon, size: 11, color: badgeText),
                  const SizedBox(width: 3),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: badgeText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
