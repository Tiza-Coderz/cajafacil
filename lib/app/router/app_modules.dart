import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/core/auth/permissions.dart';
import 'package:flutter/material.dart';

/// Módulos navegables de la app y el permiso que exige cada uno.
/// Es la única fuente para el menú de inicio y las guardas del router.
class AppModule {
  const AppModule({
    required this.route,
    required this.title,
    required this.description,
    required this.icon,
    required this.permission,
  });

  final String route;
  final String title;
  final String description;
  final IconData icon;
  final Permission permission;
}

const appModules = [
  AppModule(
    route: Routes.pos,
    title: 'Vender',
    description: 'Punto de venta',
    icon: Icons.point_of_sale,
    permission: Permission.sell,
  ),
  AppModule(
    route: Routes.cashRegister,
    title: 'Caja',
    description: 'Apertura y cierre',
    icon: Icons.account_balance_wallet_outlined,
    permission: Permission.openCashSession,
  ),
  AppModule(
    route: Routes.products,
    title: 'Productos',
    description: 'Catálogo y precios',
    icon: Icons.inventory_2_outlined,
    permission: Permission.manageProducts,
  ),
  AppModule(
    route: Routes.inventory,
    title: 'Inventario',
    description: 'Entradas, ajustes y kardex',
    icon: Icons.warehouse_outlined,
    permission: Permission.manageInventory,
  ),
  AppModule(
    route: Routes.exchangeRate,
    title: 'Tasa de cambio',
    description: 'Dólar a CUP del día',
    icon: Icons.currency_exchange,
    permission: Permission.setExchangeRate,
  ),
  AppModule(
    route: Routes.reports,
    title: 'Reportes',
    description: 'Ventas y ganancias',
    icon: Icons.bar_chart,
    permission: Permission.viewReports,
  ),
  AppModule(
    route: Routes.settings,
    title: 'Ajustes',
    description: 'Datos del negocio',
    icon: Icons.settings_outlined,
    permission: Permission.manageSettings,
  ),
];

/// Permiso requerido para una ruta, o `null` si solo pide sesión.
Permission? permissionForLocation(String location) {
  for (final module in appModules) {
    if (location == module.route || location.startsWith('${module.route}/')) {
      return module.permission;
    }
  }
  return null;
}
