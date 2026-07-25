// Hierarquia de papéis e matrix de permissões do SouTracking.
// Papel armazenado em TraccarUser.attributes['soutracking_role'].

enum AppUserRole { superAdmin, master, operator, client, viewer }

enum AppFeature {
  dashboard,
  map,
  vehicles,
  devices,
  alerts,
  geofences,
  maintenance,
  reports,
  commands,
  communication,
  tickets,
  users,
  automations,
  finance,
  telemetry,
  mdvr,
  aiOps,
  inventory,
  logs,
  settings,
  tpms,
}

enum AppAction { view, add, edit, delete, command, export }

// Bit flags internos para compor permissões.
const int _none = 0;
const int _v = 1;
const int _a = 2;
const int _e = 4;
const int _x = 8;
const int _c = 16;
const int _exp = 32;
const int _ve = _v | _e;
const int _va = _v | _a;
const int _vae = _v | _a | _e;
const int _vaex = _v | _a | _e | _x;

// Matriz de permissões: role → feature → bitmask de ações permitidas.
const _matrix = <AppUserRole, Map<AppFeature, int>>{
  AppUserRole.superAdmin: {
    AppFeature.dashboard: _v,
    AppFeature.map: _v,
    AppFeature.vehicles: _vaex,
    AppFeature.devices: _vaex,
    AppFeature.alerts: _vaex,
    AppFeature.geofences: _vaex,
    AppFeature.maintenance: _vaex,
    AppFeature.reports: _vaex | _exp,
    AppFeature.commands: _c,
    AppFeature.communication: _vaex,
    AppFeature.tickets: _vaex,
    AppFeature.users: _vaex,
    AppFeature.automations: _vaex,
    AppFeature.finance: _vaex,
    AppFeature.telemetry: _v | _exp,
    AppFeature.mdvr: _vaex,
    AppFeature.aiOps: _vaex,
    AppFeature.inventory: _vaex,
    AppFeature.logs: _v | _exp,
    AppFeature.settings: _vaex,
    AppFeature.tpms: _v,
  },
  AppUserRole.master: {
    AppFeature.dashboard: _v,
    AppFeature.map: _v,
    AppFeature.vehicles: _vaex,
    AppFeature.devices: _vaex,
    AppFeature.alerts: _vaex,
    AppFeature.geofences: _vaex,
    AppFeature.maintenance: _vaex,
    AppFeature.reports: _v | _exp,
    AppFeature.commands: _c,
    AppFeature.communication: _vaex,
    AppFeature.tickets: _vaex,
    AppFeature.users: _vaex,
    AppFeature.automations: _vaex,
    AppFeature.finance: _v,
    AppFeature.telemetry: _v,
    AppFeature.mdvr: _vaex,
    AppFeature.aiOps: _none,
    AppFeature.inventory: _none,
    AppFeature.logs: _v,
    AppFeature.settings: _ve,
    AppFeature.tpms: _v,
  },
  AppUserRole.operator: {
    AppFeature.dashboard: _v,
    AppFeature.map: _v,
    AppFeature.vehicles: _ve,
    AppFeature.devices: _v,
    AppFeature.alerts: _vae,
    AppFeature.geofences: _vae,
    AppFeature.maintenance: _vae,
    AppFeature.reports: _v | _exp,
    AppFeature.commands: _c,
    AppFeature.communication: _va,
    AppFeature.tickets: _vae,
    AppFeature.users: _none,
    AppFeature.automations: _none,
    AppFeature.finance: _none,
    AppFeature.telemetry: _v,
    AppFeature.mdvr: _v,
    AppFeature.aiOps: _none,
    AppFeature.inventory: _none,
    AppFeature.logs: _none,
    AppFeature.settings: _none,
    AppFeature.tpms: _v,
  },
  AppUserRole.client: {
    AppFeature.dashboard: _v,
    AppFeature.map: _v,
    AppFeature.vehicles: _ve,
    AppFeature.devices: _none,
    AppFeature.alerts: _v,
    AppFeature.geofences: _v,
    AppFeature.maintenance: _none,
    AppFeature.reports: _v,
    AppFeature.commands: _none, // habilitado por plano via enabledByPlan()
    AppFeature.communication: _none,
    AppFeature.tickets: _va,
    AppFeature.users: _none,
    AppFeature.automations: _none,
    AppFeature.finance: _none,
    AppFeature.telemetry: _none, // habilitado por plano
    AppFeature.mdvr: _none,      // habilitado por plano
    AppFeature.aiOps: _none,
    AppFeature.inventory: _none,
    AppFeature.logs: _none,
    AppFeature.settings: _none,
    AppFeature.tpms: _none, // habilitado por plano
  },
  AppUserRole.viewer: {
    AppFeature.dashboard: _v,
    AppFeature.map: _v,
    AppFeature.vehicles: _v,
    AppFeature.devices: _none,
    AppFeature.alerts: _none,
    AppFeature.geofences: _none,
    AppFeature.maintenance: _none,
    AppFeature.reports: _none,
    AppFeature.commands: _none,
    AppFeature.communication: _none,
    AppFeature.tickets: _none,
    AppFeature.users: _none,
    AppFeature.automations: _none,
    AppFeature.finance: _none,
    AppFeature.telemetry: _none,
    AppFeature.mdvr: _none,
    AppFeature.aiOps: _none,
    AppFeature.inventory: _none,
    AppFeature.logs: _none,
    AppFeature.settings: _none,
    AppFeature.tpms: _none,
  },
};

class AppPermissions {
  const AppPermissions._();

  static bool can(AppUserRole role, AppFeature feature, AppAction action) {
    final bits = _matrix[role]?[feature] ?? _none;
    return switch (action) {
      AppAction.view => bits & _v != 0,
      AppAction.add => bits & _a != 0,
      AppAction.edit => bits & _e != 0,
      AppAction.delete => bits & _x != 0,
      AppAction.command => bits & _c != 0,
      AppAction.export => bits & _exp != 0,
    };
  }

  static bool canView(AppUserRole role, AppFeature feature) =>
      can(role, feature, AppAction.view);

  static bool canAdd(AppUserRole role, AppFeature feature) =>
      can(role, feature, AppAction.add);

  static bool canEdit(AppUserRole role, AppFeature feature) =>
      can(role, feature, AppAction.edit);

  static bool canDelete(AppUserRole role, AppFeature feature) =>
      can(role, feature, AppAction.delete);

  static bool canCommand(AppUserRole role, AppFeature feature) =>
      can(role, feature, AppAction.command);

  static bool canExport(AppUserRole role, AppFeature feature) =>
      can(role, feature, AppAction.export);

  // Features visíveis (ao menos view) para o role.
  static Set<AppFeature> visibleFeatures(AppUserRole role) =>
      AppFeature.values.where((f) => canView(role, f)).toSet();
}

// Conversão entre AppUserRole e profile code do menu_master.json.
AppUserRole roleFromProfileCode(String code) {
  return switch (code.toUpperCase().trim()) {
    'MA' => AppUserRole.superAdmin,
    'AE' || 'GC' => AppUserRole.master,
    'SO' || 'OM' || 'SAC' || 'TEC' || 'COM' => AppUserRole.operator,
    'CF' => AppUserRole.client,
    _ => AppUserRole.viewer,
  };
}

String profileCodeFromRole(AppUserRole role) {
  return switch (role) {
    AppUserRole.superAdmin => 'MA',
    AppUserRole.master => 'AE',
    AppUserRole.operator => 'OM',
    AppUserRole.client => 'CF',
    AppUserRole.viewer => 'SO',
  };
}

// Conversão entre string raw do Traccar e AppUserRole.
AppUserRole roleFromSoutrackingAttr(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'superadmin' || 'super_admin' || 'ma' => AppUserRole.superAdmin,
    'master' || 'ae' || 'gc' => AppUserRole.master,
    'operator' || 'operador' || 'om' || 'sac' || 'tec' || 'com' =>
      AppUserRole.operator,
    'client' || 'cliente' || 'cf' => AppUserRole.client,
    'viewer' || 'visualizador' || 'so' => AppUserRole.viewer,
    _ => AppUserRole.operator,
  };
}

String soutrackingAttrFromRole(AppUserRole role) {
  return switch (role) {
    AppUserRole.superAdmin => 'superadmin',
    AppUserRole.master => 'master',
    AppUserRole.operator => 'operator',
    AppUserRole.client => 'client',
    AppUserRole.viewer => 'viewer',
  };
}

// Label legível para exibição na UI.
String labelFromRole(AppUserRole role) {
  return switch (role) {
    AppUserRole.superAdmin => 'SuperAdmin',
    AppUserRole.master => 'Master (Revenda)',
    AppUserRole.operator => 'Operador',
    AppUserRole.client => 'Cliente',
    AppUserRole.viewer => 'Visualizador',
  };
}

// Flags Traccar necessárias para cada papel.
Map<String, dynamic> traccarFlagsFromRole(AppUserRole role) {
  return switch (role) {
    AppUserRole.superAdmin => {
        'administrator': true,
        'readonly': false,
        'disabled': false,
      },
    AppUserRole.master => {
        'administrator': true,
        'readonly': false,
        'disabled': false,
      },
    AppUserRole.operator => {
        'administrator': false,
        'readonly': false,
        'disabled': false,
      },
    AppUserRole.client => {
        'administrator': false,
        'readonly': false,
        'disabled': false,
      },
    AppUserRole.viewer => {
        'administrator': false,
        'readonly': true,
        'disabled': false,
      },
  };
}
