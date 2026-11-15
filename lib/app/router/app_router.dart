import 'package:cajafacil/app/router/app_modules.dart';
import 'package:cajafacil/app/router/route_guards.dart';
import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/core/widgets/placeholder_screen.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/auth/presentation/screens/login_screen.dart';
import 'package:cajafacil/features/cash_register/presentation/screens/cash_history_screen.dart';
import 'package:cajafacil/features/cash_register/presentation/screens/cash_register_screen.dart';
import 'package:cajafacil/features/cash_register/presentation/screens/close_cash_screen.dart';
import 'package:cajafacil/features/exchange_rate/presentation/screens/exchange_rate_screen.dart';
import 'package:cajafacil/features/home/presentation/home_screen.dart';
import 'package:cajafacil/features/products/presentation/screens/product_form_screen.dart';
import 'package:cajafacil/features/products/presentation/screens/products_screen.dart';
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
Widget _moduleScreen(AppModule module) => switch (module.route) {
  Routes.exchangeRate => const ExchangeRateScreen(),
  Routes.products => const ProductsScreen(),
  Routes.cashRegister => const CashRegisterScreen(),
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
