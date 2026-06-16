import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant_config.dart';

enum MenuItemType { nativeTraccar, customOurs, later }

enum MenuPriority { p0, p1, p2, p3 }

enum MenuAvailability { now, backend, later }

enum MenuAccessState { hidden, locked, visible, enabled }

enum MenuAction { view, create, edit, delete, approve, export, command, admin }

const Set<MenuAction> _emptyActionSet = {};
const List<String> kMenuActionOrder = [
  'view',
  'create',
  'edit',
  'delete',
  'approve',
  'export',
  'command',
  'admin',
];

MenuItemType _parseMenuItemType(String value) {
  switch (value.trim()) {
    case 'native_traccar':
      return MenuItemType.nativeTraccar;
    case 'later':
      return MenuItemType.later;
    case 'custom_ours':
    default:
      return MenuItemType.customOurs;
  }
}

MenuPriority _parseMenuPriority(String value) {
  switch (value.trim().toUpperCase()) {
    case 'P1':
      return MenuPriority.p1;
    case 'P2':
      return MenuPriority.p2;
    case 'P3':
      return MenuPriority.p3;
    case 'P0':
    default:
      return MenuPriority.p0;
  }
}

MenuAvailability _parseMenuAvailability(String value) {
  switch (value.trim()) {
    case 'backend':
      return MenuAvailability.backend;
    case 'later':
      return MenuAvailability.later;
    case 'now':
    default:
      return MenuAvailability.now;
  }
}

MenuAction? _parseMenuAction(String value) {
  switch (value.trim()) {
    case 'view':
      return MenuAction.view;
    case 'create':
      return MenuAction.create;
    case 'edit':
      return MenuAction.edit;
    case 'delete':
      return MenuAction.delete;
    case 'approve':
      return MenuAction.approve;
    case 'export':
      return MenuAction.export;
    case 'command':
      return MenuAction.command;
    case 'admin':
      return MenuAction.admin;
    default:
      return null;
  }
}

String normalizeProfileCode(String? raw) {
  final value = (raw ?? '').trim().toUpperCase();
  switch (value) {
    case 'MASTER_ADMIN':
    case 'MASTER':
    case 'MA':
      return 'MA';
    case 'ADMIN_EMPRESA':
    case 'ADMIN':
    case 'AE':
      return 'AE';
    case 'SUPERVISOR':
    case 'SO':
      return 'SO';
    case 'OPERADOR':
    case 'OM':
      return 'OM';
    case 'ATENDIMENTO':
    case 'SAC':
      return 'SAC';
    case 'TECNICO':
    case 'TEC':
      return 'TEC';
    case 'COMERCIAL':
    case 'COM':
      return 'COM';
    case 'FINANCEIRO':
    case 'FIN':
      return 'FIN';
    case 'ESTOQUE':
    case 'EST':
      return 'EST';
    case 'GESTOR_CLIENTE':
    case 'GC':
      return 'GC';
    case 'CLIENTE_FINAL':
    case 'CF':
      return 'CF';
    default:
      return value.isEmpty ? 'OM' : value;
  }
}

class MenuGroupConfig {
  const MenuGroupConfig({
    required this.id,
    required this.label,
    required this.order,
    required this.collapsible,
  });

  final String id;
  final String label;
  final int order;
  final bool collapsible;

  factory MenuGroupConfig.fromJson(Map<String, dynamic> json) {
    return MenuGroupConfig(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      order: (json['order'] as num?)?.toInt() ?? 0,
      collapsible: json['collapsible'] != false,
    );
  }
}

class MenuItemConfig {
  const MenuItemConfig({
    required this.id,
    required this.label,
    required this.group,
    required this.parentId,
    required this.type,
    required this.route,
    required this.icon,
    required this.priority,
    required this.order,
    required this.tenantScoped,
    required this.featureFlag,
    required this.visibleProfiles,
    required this.actionPolicyRef,
    required this.availability,
    required this.hideWhenFeatureOff,
  });

  final String id;
  final String label;
  final String group;
  final String? parentId;
  final MenuItemType type;
  final String route;
  final String icon;
  final MenuPriority priority;
  final int order;
  final bool tenantScoped;
  final String featureFlag;
  final List<String> visibleProfiles;
  final String actionPolicyRef;
  final MenuAvailability availability;
  final bool hideWhenFeatureOff;

  factory MenuItemConfig.fromJson(Map<String, dynamic> json) {
    final profiles = (json['visibleProfiles'] as List<dynamic>? ?? const [])
        .map((it) => normalizeProfileCode(it.toString()))
        .toList(growable: false);

    return MenuItemConfig(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      group: (json['group'] ?? '').toString(),
      parentId: json['parentId'] == null ? null : json['parentId'].toString(),
      type: _parseMenuItemType((json['type'] ?? '').toString()),
      route: (json['route'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      priority: _parseMenuPriority((json['priority'] ?? 'P0').toString()),
      order: (json['order'] as num?)?.toInt() ?? 0,
      tenantScoped: json['tenantScoped'] != false,
      featureFlag: (json['featureFlag'] ?? '').toString(),
      visibleProfiles: profiles,
      actionPolicyRef: (json['actionPolicyRef'] ?? '').toString(),
      availability: _parseMenuAvailability(
        (json['availability'] ?? 'now').toString(),
      ),
      hideWhenFeatureOff: json['hideWhenFeatureOff'] == true,
    );
  }
}

class MenuPolicyConfig {
  const MenuPolicyConfig({
    required this.id,
    required this.actionsByProfile,
  });

  final String id;
  final Map<String, Set<MenuAction>> actionsByProfile;

  Set<MenuAction> actionsForProfile(String profileCode) {
    return actionsByProfile[normalizeProfileCode(profileCode)] ??
        _emptyActionSet;
  }

  factory MenuPolicyConfig.fromJson(String id, Map<String, dynamic> json) {
    final parsed = <String, Set<MenuAction>>{};
    json.forEach((rawProfile, rawActions) {
      final profile = normalizeProfileCode(rawProfile);
      final actions = <MenuAction>{};
      if (rawActions is List) {
        for (final action in rawActions) {
          final mapped = _parseMenuAction(action.toString());
          if (mapped != null) {
            actions.add(mapped);
          }
        }
      }
      parsed[profile] = actions;
    });
    return MenuPolicyConfig(
      id: id,
      actionsByProfile: parsed,
    );
  }
}

class TenantMenuOverride {
  const TenantMenuOverride({
    this.hideItems = const [],
    this.lockItems = const [],
    this.backendReadyItems = const [],
    this.featureOverrides = const {},
  });

  final List<String> hideItems;
  final List<String> lockItems;
  final List<String> backendReadyItems;
  final Map<String, bool> featureOverrides;

  factory TenantMenuOverride.fromJson(Map<String, dynamic> json) {
    List<String> _toList(dynamic value) {
      if (value is List) {
        return value.map((it) => it.toString()).toList(growable: false);
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          return const [];
        }
        return <String>[trimmed];
      }
      return const [];
    }

    Map<String, bool> _toBoolMap(dynamic value) {
      if (value is Map) {
        return value.map(
          (key, item) => MapEntry(
            key.toString(),
            item == true || item == 1 || item.toString() == 'true',
          ),
        );
      }
      return const {};
    }

    return TenantMenuOverride(
      hideItems: _toList(json['hideItems']),
      lockItems: _toList(json['lockItems']),
      backendReadyItems: _toList(json['backendReadyItems']),
      featureOverrides: _toBoolMap(json['featureOverrides']),
    );
  }
}

class MenuMasterConfig {
  const MenuMasterConfig({
    required this.version,
    required this.actionOrder,
    required this.profiles,
    required this.featureDefaults,
    required this.groups,
    required this.items,
    required this.policies,
    required this.tenantOverrides,
  });

  final String version;
  final List<String> actionOrder;
  final Map<String, String> profiles;
  final Map<String, bool> featureDefaults;
  final List<MenuGroupConfig> groups;
  final List<MenuItemConfig> items;
  final Map<String, MenuPolicyConfig> policies;
  final Map<String, TenantMenuOverride> tenantOverrides;

  MenuPolicyConfig? policyById(String id) => policies[id];

  TenantMenuOverride tenantOverrideFor(String tenantId) {
    return tenantOverrides[tenantId] ??
        tenantOverrides['default'] ??
        const TenantMenuOverride();
  }

  factory MenuMasterConfig.fromJson(Map<String, dynamic> json) {
    Map<String, String> _profiles(dynamic value) {
      if (value is Map) {
        return value.map(
          (key, item) =>
              MapEntry(normalizeProfileCode(key.toString()), item.toString()),
        );
      }
      return const {};
    }

    Map<String, bool> _features(dynamic value) {
      if (value is Map) {
        return value.map(
          (key, item) => MapEntry(
            key.toString(),
            item == true || item == 1 || item.toString() == 'true',
          ),
        );
      }
      return const {};
    }

    final groups = (json['groups'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((it) => MenuGroupConfig.fromJson(it.cast<String, dynamic>()))
        .toList(growable: false)
      ..sort((a, b) => a.order.compareTo(b.order));

    final items = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((it) => MenuItemConfig.fromJson(it.cast<String, dynamic>()))
        .toList(growable: false);

    final policiesRaw = json['policies'];
    final policies = <String, MenuPolicyConfig>{};
    if (policiesRaw is Map) {
      policiesRaw.forEach((key, value) {
        if (value is Map) {
          policies[key.toString()] = MenuPolicyConfig.fromJson(
            key.toString(),
            value.cast<String, dynamic>(),
          );
        }
      });
    }

    final overridesRaw = json['tenantOverrides'];
    final overrides = <String, TenantMenuOverride>{};
    if (overridesRaw is Map) {
      overridesRaw.forEach((key, value) {
        if (value is Map) {
          overrides[key.toString()] = TenantMenuOverride.fromJson(
            value.cast<String, dynamic>(),
          );
        }
      });
    }

    return MenuMasterConfig(
      version: (json['version'] ?? '1.0.0').toString(),
      actionOrder: (json['actionOrder'] as List<dynamic>? ?? kMenuActionOrder)
          .map((it) => it.toString())
          .toList(growable: false),
      profiles: _profiles(json['profiles']),
      featureDefaults: _features(json['featureDefaults']),
      groups: groups,
      items: items,
      policies: policies,
      tenantOverrides: overrides,
    );
  }
}

class MenuItemDecision {
  const MenuItemDecision({
    required this.state,
    required this.actions,
    this.reason,
  });

  final MenuAccessState state;
  final Set<MenuAction> actions;
  final String? reason;
}

class ResolvedMenuItem {
  const ResolvedMenuItem({
    required this.item,
    required this.decision,
    required this.children,
  });

  final MenuItemConfig item;
  final MenuItemDecision decision;
  final List<ResolvedMenuItem> children;
}

class ResolvedMenuGroup {
  const ResolvedMenuGroup({
    required this.group,
    required this.items,
  });

  final MenuGroupConfig group;
  final List<ResolvedMenuItem> items;
}

final menuMasterConfigProvider = FutureProvider<MenuMasterConfig>((ref) async {
  final raw = await rootBundle.loadString('assets/config/menu_master.json');
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('menu_master.json inválido.');
  }
  return MenuMasterConfig.fromJson(decoded);
});

List<ResolvedMenuGroup> resolveMenuForContext({
  required MenuMasterConfig config,
  required TenantConfig tenant,
  required String profileCode,
}) {
  final byParent = <String?, List<MenuItemConfig>>{};
  for (final item in config.items) {
    byParent.putIfAbsent(item.parentId, () => []).add(item);
  }

  for (final children in byParent.values) {
    children.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.label.compareTo(b.label);
    });
  }

  final normalizedProfile = normalizeProfileCode(profileCode);
  final tenantOverride = config.tenantOverrideFor(tenant.tenantId);
  final backendReadyItems = tenantOverride.backendReadyItems.toSet();
  final backendReadyAll = backendReadyItems.contains('*');
  final hiddenItems = tenantOverride.hideItems.toSet();
  final lockedItems = tenantOverride.lockItems.toSet();
  final featureFlags = <String, bool>{
    ...config.featureDefaults,
    ...tenant.modules,
    ...tenantOverride.featureOverrides,
  };

  bool _featureEnabled(String featureFlag) {
    if (featureFlag.trim().isEmpty) {
      return true;
    }
    return featureFlags[featureFlag] == true;
  }

  MenuItemDecision _evaluate(MenuItemConfig item) {
    if (hiddenItems.contains(item.id)) {
      return const MenuItemDecision(
        state: MenuAccessState.hidden,
        actions: _emptyActionSet,
        reason: 'hidden_by_tenant',
      );
    }

    if (item.visibleProfiles.isNotEmpty &&
        !item.visibleProfiles.contains(normalizedProfile)) {
      return const MenuItemDecision(
        state: MenuAccessState.hidden,
        actions: _emptyActionSet,
        reason: 'hidden_by_profile',
      );
    }

    final featureEnabled = _featureEnabled(item.featureFlag);
    if (!featureEnabled) {
      return MenuItemDecision(
        state: item.hideWhenFeatureOff
            ? MenuAccessState.hidden
            : MenuAccessState.locked,
        actions: _emptyActionSet,
        reason: item.hideWhenFeatureOff
            ? 'hidden_by_feature'
            : 'locked_by_feature',
      );
    }

    final policy = config.policyById(item.actionPolicyRef);
    final actions =
        policy?.actionsForProfile(normalizedProfile) ?? _emptyActionSet;
    if (actions.isEmpty) {
      return const MenuItemDecision(
        state: MenuAccessState.visible,
        actions: _emptyActionSet,
        reason: 'visible_without_actions',
      );
    }

    if (lockedItems.contains(item.id)) {
      return MenuItemDecision(
        state: MenuAccessState.locked,
        actions: actions,
        reason: 'locked_by_tenant',
      );
    }

    switch (item.availability) {
      case MenuAvailability.now:
        return MenuItemDecision(
          state: MenuAccessState.enabled,
          actions: actions,
        );
      case MenuAvailability.backend:
        final backendReady =
            backendReadyAll || backendReadyItems.contains(item.id);
        return MenuItemDecision(
          state:
              backendReady ? MenuAccessState.enabled : MenuAccessState.locked,
          actions: actions,
          reason: backendReady ? null : 'backend_pending',
        );
      case MenuAvailability.later:
        return MenuItemDecision(
          state: MenuAccessState.locked,
          actions: actions,
          reason: 'implementation_pending',
        );
    }
  }

  ResolvedMenuItem? _resolveNode(MenuItemConfig item) {
    final decision = _evaluate(item);
    if (decision.state == MenuAccessState.hidden) {
      return null;
    }

    final children = (byParent[item.id] ?? const <MenuItemConfig>[])
        .where((child) => child.group == item.group)
        .map(_resolveNode)
        .whereType<ResolvedMenuItem>()
        .toList(growable: false);

    return ResolvedMenuItem(
      item: item,
      decision: decision,
      children: children,
    );
  }

  final resolvedGroups = <ResolvedMenuGroup>[];
  for (final group in config.groups) {
    final roots = (byParent[null] ?? const <MenuItemConfig>[])
        .where((item) => item.group == group.id)
        .map(_resolveNode)
        .whereType<ResolvedMenuItem>()
        .toList(growable: false);

    if (roots.isEmpty) {
      continue;
    }

    resolvedGroups.add(
      ResolvedMenuGroup(group: group, items: roots),
    );
  }

  return resolvedGroups;
}
