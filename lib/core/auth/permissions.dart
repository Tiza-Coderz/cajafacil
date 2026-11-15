import 'package:cajafacil/core/domain/enums.dart';

/// Acciones protegidas de la app. Las pantallas y casos de uso preguntan
/// por permisos, nunca por roles: así cambiar la matriz no toca la UI.
enum Permission {
  sell,
  openCashSession,
  closeOwnCashSession,
  manageProducts,
  manageInventory,
  setExchangeRate,
  voidSale,
  viewAllCashSessions,
  viewReports,
  viewCostsAndProfit,
  manageUsers,
  manageSettings,
  resetDemo,
}

const Set<Permission> _cashierPermissions = {
  Permission.sell,
  Permission.openCashSession,
  Permission.closeOwnCashSession,
};

const Set<Permission> _managerPermissions = {
  ..._cashierPermissions,
  Permission.manageProducts,
  Permission.manageInventory,
  Permission.setExchangeRate,
  Permission.voidSale,
  Permission.viewAllCashSessions,
  Permission.viewReports,
};

const Set<Permission> _ownerPermissions = {
  ..._managerPermissions,
  Permission.viewCostsAndProfit,
  Permission.manageUsers,
  Permission.manageSettings,
  Permission.resetDemo,
};

extension RolePermissions on UserRole {
  Set<Permission> get permissions => switch (this) {
    UserRole.owner => _ownerPermissions,
    UserRole.manager => _managerPermissions,
    UserRole.cashier => _cashierPermissions,
  };

  bool can(Permission permission) => permissions.contains(permission);
}
