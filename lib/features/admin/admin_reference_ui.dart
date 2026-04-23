import 'dart:ui';

import 'package:flutter/material.dart';

import '../../data/models.dart';

class AdminReferenceScaffold extends StatelessWidget {
  const AdminReferenceScaffold({
    super.key,
    required this.title,
    this.breadcrumbs = const <String>[],
    this.action,
    required this.selectedMenu,
    required this.child,
    this.showSecondaryMenu = false,
  });

  final String title;
  final List<String> breadcrumbs;
  final Widget? action;
  final String selectedMenu;
  final Widget child;
  final bool showSecondaryMenu;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1120;
        final showDualMenuLayout = showSecondaryMenu && wide;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (breadcrumbs.isNotEmpty)
                  Text(
                    breadcrumbs.join('  >  '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFB8C5D9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: showDualMenuLayout
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 240,
                      child: AdminGlassPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        child: AdminSecondaryMenu(selectedKey: selectedMenu),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: AdminGlassPanel(
                        padding: const EdgeInsets.all(20),
                        child: content,
                      ),
                    ),
                  ],
                )
              : AdminGlassPanel(
                  padding: const EdgeInsets.all(20),
                  child: content,
                ),
        );
      },
    );
  }
}

class AdminGlassPanel extends StatelessWidget {
  const AdminGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    const panelSurface = Color(0xEB12161D);
    const panelBorder = Color(0x40FFFFFF);

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? panelSurface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: borderColor ?? panelBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220F172A),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class AdminSecondaryMenu extends StatelessWidget {
  const AdminSecondaryMenu({super.key, required this.selectedKey});

  final String selectedKey;

  static const _items = <_AdminMenuItem>[
    _AdminMenuItem('users', 'Usuários Internos', Icons.people_alt_outlined),
    _AdminMenuItem('profiles', 'Perfis e Usuários', Icons.badge_outlined),
    _AdminMenuItem(
      'permissions-access',
      'Permissões',
      Icons.verified_user_outlined,
    ),
    _AdminMenuItem('preferences', 'Preferências', Icons.tune_outlined),
    _AdminMenuItem(
      'notifications',
      'Notificações',
      Icons.notifications_none_outlined,
    ),
    _AdminMenuItem('announcement', 'Anúncio', Icons.campaign_outlined),
    _AdminMenuItem('logs', 'Logs', Icons.article_outlined),
    _AdminMenuItem('server', 'Servidor', Icons.dns_outlined),
    _AdminMenuItem('audit', 'Auditoria', Icons.policy_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0x1400BFA5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Color(0xFF0DAF9F),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Administração',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        for (final item in _items)
          _AdminMenuTile(item: item, selected: item.key == selectedKey),
      ],
    );
  }
}

class _AdminMenuTile extends StatelessWidget {
  const _AdminMenuTile({required this.item, required this.selected});

  final _AdminMenuItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: selected ? const Color(0x2E8EC5FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? const Color(0x6697CBFF) : Colors.transparent,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          item.icon,
          color: selected ? const Color(0xFF9FCEFF) : Colors.white70,
          size: 18,
        ),
        title: Text(
          item.label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class AdminActionButton extends StatelessWidget {
  const AdminActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF3E8BFF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class AdminTableHeader extends StatelessWidget {
  const AdminTableHeader({super.key, required this.columns});

  final List<FlexColumnWidth> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F9FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: columns[i].value.round(),
              child: Text(
                _headers[i],
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF7A8CA8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<String> get _headers => const [];
}

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AdminAvatar extends StatelessWidget {
  const AdminAvatar({super.key, required this.name, this.size = 38});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final color = _avatarColor(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.58)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AdminRoleSummary {
  const AdminRoleSummary({
    required this.key,
    required this.label,
    required this.count,
    required this.color,
  });

  final String key;
  final String label;
  final int count;
  final Color color;
}

List<AdminRoleSummary> buildRoleSummaries(List<TraccarUser> users) {
  final counts = <String, int>{
    'Administrador': 0,
    'Supervisor': 0,
    'Operador': 0,
    'Cliente Final': 0,
  };

  for (final user in users) {
    counts[deriveUserRole(user)] = (counts[deriveUserRole(user)] ?? 0) + 1;
  }

  return [
    AdminRoleSummary(
      key: 'admin',
      label: 'Administrador',
      count: counts['Administrador'] ?? 0,
      color: const Color(0xFF4C84FF),
    ),
    AdminRoleSummary(
      key: 'supervisor',
      label: 'Supervisor',
      count: counts['Supervisor'] ?? 0,
      color: const Color(0xFF3FC7B4),
    ),
    AdminRoleSummary(
      key: 'operator',
      label: 'Operador',
      count: counts['Operador'] ?? 0,
      color: const Color(0xFFF7B84B),
    ),
    AdminRoleSummary(
      key: 'client',
      label: 'Cliente Final',
      count: counts['Cliente Final'] ?? 0,
      color: const Color(0xFF9AA8BC),
    ),
  ];
}

String deriveUserRole(TraccarUser user) {
  if (user.administrator) {
    return 'Administrador';
  }
  if (user.readonly) {
    return 'Supervisor';
  }
  if (user.disabled) {
    return 'Cliente Final';
  }
  return 'Operador';
}

String deriveUserStatus(TraccarUser user) {
  if (user.disabled) {
    return 'Inativo';
  }
  if (user.administrator) {
    return 'Especial';
  }
  if (user.readonly) {
    return 'Supervisor';
  }
  return 'Operacional';
}

Color statusColorFor(TraccarUser user) {
  if (user.disabled) {
    return const Color(0xFF9AA8BC);
  }
  if (user.administrator) {
    return const Color(0xFF37C999);
  }
  if (user.readonly) {
    return const Color(0xFFF7B84B);
  }
  return const Color(0xFF20B79A);
}

String deterministicLastAccess(TraccarUser user) {
  final day = ((user.id * 7) % 27) + 1;
  final month = ((user.id * 3) % 9) + 1;
  return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/2024';
}

String _initials(String value) {
  final parts = value
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'ST';
  }
  final first = parts.first.characters.first;
  final second = parts.length > 1
      ? parts.last.characters.first
      : parts.first.characters.last;
  return '${first.toUpperCase()}${second.toUpperCase()}';
}

Color _avatarColor(String seed) {
  final palette = [
    const Color(0xFF4D8BFF),
    const Color(0xFF00B9A7),
    const Color(0xFFFFB649),
    const Color(0xFF7C68EE),
    const Color(0xFF0EA5E9),
  ];
  return palette[seed.hashCode.abs() % palette.length];
}

class _AdminMenuItem {
  const _AdminMenuItem(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}
