import 'package:cajafacil/core/auth/permissions.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el dueño puede hacerlo todo', () {
    expect(UserRole.owner.permissions, containsAll(Permission.values));
  });

  test('el cajero solo vende y maneja su caja', () {
    expect(UserRole.cashier.permissions, {
      Permission.sell,
      Permission.openCashSession,
      Permission.closeOwnCashSession,
    });
  });

  test('el encargado gestiona inventario pero no ve costos ni ajustes', () {
    const manager = UserRole.manager;
    expect(manager.can(Permission.manageInventory), isTrue);
    expect(manager.can(Permission.setExchangeRate), isTrue);
    expect(manager.can(Permission.viewCostsAndProfit), isFalse);
    expect(manager.can(Permission.manageSettings), isFalse);
    expect(manager.can(Permission.resetDemo), isFalse);
  });

  test('cada rol incluye los permisos del rol inferior', () {
    expect(
      UserRole.manager.permissions,
      containsAll(UserRole.cashier.permissions),
    );
    expect(
      UserRole.owner.permissions,
      containsAll(UserRole.manager.permissions),
    );
  });
}
