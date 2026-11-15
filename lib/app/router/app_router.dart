import 'package:cajafacil/app/router/app_modules.dart';
import 'package:cajafacil/app/router/route_guards.dart';
import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/core/widgets/placeholder_screen.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/auth/presentation/screens/login_screen.dart';
import 'package:cajafacil/features/cash_register/presentation/screens/cash_history_screen.dart';
import 'package:cajafacil/features/cash_register/presentation/screens/cash_register_screen.dart';
import 'package:cajafacil/features/cash_register/presentation/screens/close_cash_screen.dart';
import 'package:cajafacil/features/demo/presentation/demo_history_gate.dart';
import 'package:cajafacil/features/exchange_rate/presentation/screens/exchange_rate_screen.dart';
import 'package:cajafacil/features/home/presentation/home_screen.dart';
import 'package:cajafacil/features/inventory/presentation/screens/adjustment_screen.dart';
import 'package:cajafacil/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:cajafacil/features/inventory/presentation/screens/kardex_screen.dart';
import 'package:cajafacil/features/inventory/presentation/screens/purchase_form_screen.dart';
import 'package:cajafacil/features/pos/presentation/screens/checkout_screen.dart';
import 'package:cajafacil/features/pos/presentation/screens/pos_screen.dart';
import 'package:cajafacil/features/pos/presentation/screens/receipt_screen.dart';
import 'package:cajafacil/features/pos/presentation/screens/session_sales_screen.dart';
import 'package:cajafacil/features/products/presentation/screens/product_form_screen.dart';
import 'package:cajafacil/features/products/presentation/screens/products_screen.dart';
import 'package:cajafacil/features/reports/presentation/reports_screen.dart';
import 'package:cajafacil/features/settings/presentation/settings_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    redirect: (context, state) => authRedirect(
      user: ref.read(sessionProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      for (final module in appModules)
        GoRoute(
          path: module.route,
          builder: (context, state) => _moduleScreen(module),
          routes: _moduleSubRoutes(module),
        ),
    ],
  );

  // Re-evaluar las guardas al iniciar o cerrar sesión.
  ref
    ..listen(sessionProvider, (_, _) => router.refresh())
    ..onDispose(router.dispose);
  return router;
});

/// Pantalla de cada módulo. Los no implementados muestran un aviso.
Widget _moduleScreen(AppModule module) {
  final screen = _moduleBody(module);
  // Estos módulos dependen del historial de ventas de ejemplo.
  const gated = {
    Routes.pos,
    Routes.cashRegister,
    Routes.inventory,
    Routes.reports,
  };
  return gated.contains(module.route)
      ? DemoHistoryGate(title: module.title, child: screen)
      : screen;
}

Widget _moduleBody(AppModule module) => switch (module.route) {
  Routes.exchangeRate => const ExchangeRateScreen(),
  Routes.products => const ProductsScreen(),
  Routes.cashRegister => const CashRegisterScreen(),
  Routes.pos => const PosScreen(),
  Routes.inventory => const InventoryScreen(),
  Routes.reports => const ReportsScreen(),
  Routes.settings => const SettingsScreen(),
  _ => PlaceholderScreen(title: module.title),
};

List<RouteBase> _moduleSubRoutes(AppModule module) => switch (module.route) {
  Routes.products => [
    GoRoute(
      path: 'nuevo',
      builder: (context, state) => ProductFormScreen(
        initialBarcode: state.uri.queryParameters['codigo'],
      ),
    ),
    GoRoute(
      path: ':id',
      builder: (context, state) =>
          ProductFormScreen(productId: state.pathParameters['id']),
    ),
  ],
  Routes.inventory => [
    GoRoute(
      path: 'entrada',
      builder: (context, state) => const PurchaseFormScreen(),
    ),
    GoRoute(
      path: 'ajuste',
      builder: (context, state) => const AdjustmentScreen(),
    ),
    GoRoute(
      path: 'kardex/:id',
      builder: (context, state) =>
          KardexScreen(productId: state.pathParameters['id']!),
    ),
  ],
  Routes.pos => [
    GoRoute(
      path: 'carrito',
      builder: (context, state) => const CartScreen(),
    ),
    GoRoute(
      path: 'cobrar',
      builder: (context, state) => const CheckoutScreen(),
    ),
    GoRoute(
      path: 'ticket/:id',
      builder: (context, state) =>
          ReceiptScreen(saleId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: 'ventas',
      builder: (context, state) => const SessionSalesScreen(),
    ),
  ],
  Routes.cashRegister => [
    GoRoute(
      path: 'historial',
      builder: (context, state) => const CashHistoryScreen(),
    ),
    GoRoute(
      path: 'cerrar/:id',
      builder: (context, state) =>
          CloseCashScreen(sessionId: state.pathParameters['id']!),
    ),
  ],
  _ => const [],
};
