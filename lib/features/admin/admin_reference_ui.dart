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
    this.hideHeader = false,
  });

  final String title;
  final List<String> breadcrumbs;
  final Widget? action;
  final String selectedMenu;
  final Widget child;
  final bool showSecondaryMenu;
  final bool hideHeader;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1120;
        final showDualMenuLayout = showSecondaryMenu && wide;

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hideHeader && breadcrumbs.isNotEmpty)
              Text(
                breadcrumbs.join('  >  '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5F738F),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            if (!hideHeader) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF25344A),
                              ),
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1560),
              child: showDualMenuLayout
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 248,
                          child: AdminGlassPanel(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            child:
                                AdminSecondaryMenu(selectedKey: selectedMenu),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AdminGlassPanel(
                            padding: const EdgeInsets.all(18),
                            child: content,
                          ),
                        ),
                      ],
                    )
                  : AdminGlassPanel(
                      padding: const EdgeInsets.all(18),
                      child: content,
                    ),
            ),
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
    final panelSurface = Colors.white.withValues(alpha: 0.84);
    const panelBorder = Color(0xFFDCE6F4);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? panelSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor ?? panelBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A1A2B44),
                blurRadius: 18,
                offset: Offset(0, 8),
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
    _AdminMenuItem('users', 'UsuÃ¡rios Internos', Icons.people_alt_outlined),
    _AdminMenuItem('profiles', 'Perfis e UsuÃ¡rios', Icons.badge_outlined),
    _AdminMenuItem(
      'permissions-access',
      'PermissÃµes',
      Icons.verified_user_outlined,
    ),
    _AdminMenuItem('preferences', 'PreferÃªncias', Icons.tune_outlined),
    _AdminMenuItem(
      'notifications',
      'NotificaÃ§Ãµes',
      Icons.notifications_none_outlined,
    ),
    _AdminMenuItem('announcement', 'AnÃºncio', Icons.campaign_outlined),
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
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Color(0xFF176EEB),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'AdministraÃ§Ã£o',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF25344A),
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
        color: selected ? const Color(0xFFEAF3FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFFC7DAF7) : Colors.transparent,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          item.icon,
          color: selected ? const Color(0xFF176EEB) : const Color(0xFF5F738F),
          size: 18,
        ),
        title: Text(
          item.label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected
                    ? const Color(0xFF25344A)
                    : const Color(0xFF5F738F),
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
        backgroundColor: const Color(0xFF2C7BEA),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: columns[i].value.round(),
              child: Text(
                _headers[i],
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF5F738F),
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
    'SuperAdmin': 0,
    'Master': 0,
    'Operador': 0,
    'Cliente': 0,
    'Visualizador': 0,
  };

  for (final user in users) {
    final role = deriveUserRole(user);
    counts[role] = (counts[role] ?? 0) + 1;
  }

  return [
    AdminRoleSummary(
      key: 'superadmin',
      label: 'SuperAdmin',
      count: counts['SuperAdmin'] ?? 0,
      color: const Color(0xFF4C84FF),
    ),
    AdminRoleSummary(
      key: 'master',
      label: 'Master',
      count: counts['Master'] ?? 0,
      color: const Color(0xFF7C5CFF),
    ),
    AdminRoleSummary(
      key: 'operator',
      label: 'Operador',
      count: counts['Operador'] ?? 0,
      color: const Color(0xFF3FC7B4),
    ),
    AdminRoleSummary(
      key: 'client',
      label: 'Cliente',
      count: counts['Cliente'] ?? 0,
      color: const Color(0xFFF7B84B),
    ),
    AdminRoleSummary(
      key: 'viewer',
      label: 'Visualizador',
      count: counts['Visualizador'] ?? 0,
      color: const Color(0xFF9AA8BC),
    ),
  ];
}

String deriveUserRole(TraccarUser user) {
  // Prioridade: atributo soutracking_role gravado pelo SouTracking.
  final souRole = user.soutrackingRole;
  if (souRole.isNotEmpty) {
    return switch (souRole) {
      'superadmin' || 'super_admin' => 'SuperAdmin',
      'master' => 'Master',
      'operator' || 'operador' => 'Operador',
      'client' || 'cliente' => 'Cliente',
      'viewer' || 'visualizador' => 'Visualizador',
      _ => 'Operador',
    };
  }

  // Fallback: flags booleanos do Traccar.
  if (user.administrator) return 'SuperAdmin';
  if (user.readonly) return 'Visualizador';
  if (user.disabled) return 'Inativo';
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
