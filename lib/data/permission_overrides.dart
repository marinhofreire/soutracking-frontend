import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_permissions.dart';

const _kMenuPrefix = 'permov_menu_';
const _kActionPrefix = 'permov_action_';

/// Overrides do admin em cima da matrix padrão (`AppPermissions`) — o que
/// for tocado na aba Permissões some daqui e some por cima do default.
class PermissionOverrides {
  const PermissionOverrides({
    this.menu = const {},
    this.action = const {},
  });

  final Map<AppUserRole, Map<AppFeature, bool>> menu;
  final Map<AppUserRole, Map<String, bool>> action;

  bool menuEnabled(AppUserRole role, AppFeature feature) =>
      menu[role]?[feature] ?? AppPermissions.canView(role, feature);

  PermissionOverrides withMenu(AppUserRole role, AppFeature feature, bool value) {
    final updatedRole = Map<AppFeature, bool>.from(menu[role] ?? {})
      ..[feature] = value;
    return PermissionOverrides(
      menu: {...menu, role: updatedRole},
      action: action,
    );
  }

  PermissionOverrides withAction(AppUserRole role, String key, bool value) {
    final updatedRole = Map<String, bool>.from(action[role] ?? {})..[key] = value;
    return PermissionOverrides(
      menu: menu,
      action: {...action, role: updatedRole},
    );
  }

  PermissionOverrides clearingRole(AppUserRole role) {
    final updatedMenu = {...menu}..remove(role);
    final updatedAction = {...action}..remove(role);
    return PermissionOverrides(menu: updatedMenu, action: updatedAction);
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    for (final role in AppUserRole.values) {
      final menuForRole = menu[role];
      if (menuForRole != null) {
        for (final entry in menuForRole.entries) {
          await p.setBool(
            '$_kMenuPrefix${role.name}_${entry.key.name}',
            entry.value,
          );
        }
      }
      final actionForRole = action[role];
      if (actionForRole != null) {
        for (final entry in actionForRole.entries) {
          await p.setBool('$_kActionPrefix${role.name}_${entry.key}', entry.value);
        }
      }
    }
  }

  static Future<PermissionOverrides> load() async {
    final p = await SharedPreferences.getInstance();
    final menu = <AppUserRole, Map<AppFeature, bool>>{};
    final action = <AppUserRole, Map<String, bool>>{};

    for (final role in AppUserRole.values) {
      for (final feature in AppFeature.values) {
        final key = '$_kMenuPrefix${role.name}_${feature.name}';
        if (p.containsKey(key)) {
          menu.putIfAbsent(role, () => {})[feature] = p.getBool(key) ?? true;
        }
      }
      for (final actionKey in _knownActionKeys) {
        final key = '$_kActionPrefix${role.name}_$actionKey';
        if (p.containsKey(key)) {
          action.putIfAbsent(role, () => {})[actionKey] = p.getBool(key) ?? true;
        }
      }
    }

    return PermissionOverrides(menu: menu, action: action);
  }
}

// Chaves das "permissões adicionais" — precisa bater com _permActionItems
// em settings_screen.dart pra carregar certo do disco.
const _knownActionKeys = [
  'users_add',
  'vehicles_edit',
  'vehicles_delete',
  'reports_export',
  'commands_cmd',
];

final permissionOverridesProvider =
    StateNotifierProvider<PermissionOverridesNotifier, PermissionOverrides>(
  (ref) => PermissionOverridesNotifier(),
);

class PermissionOverridesNotifier extends StateNotifier<PermissionOverrides> {
  PermissionOverridesNotifier() : super(const PermissionOverrides()) {
    _load();
  }

  Future<void> _load() async => state = await PermissionOverrides.load();

  void setMenuEnabled(AppUserRole role, AppFeature feature, bool value) {
    state = state.withMenu(role, feature, value);
  }

  void setActionEnabled(AppUserRole role, String key, bool value) {
    state = state.withAction(role, key, value);
  }

  void clearRole(AppUserRole role) {
    state = state.clearingRole(role);
  }

  Future<void> save() async {
    await state.save();
  }
}
