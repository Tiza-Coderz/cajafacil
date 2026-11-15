import 'package:cajafacil/app/router/app_modules.dart';
import 'package:cajafacil/app/router/route_guards.dart';
import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/core/widgets/placeholder_screen.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/auth/presentation/screens/login_screen.dart';
import 'package:cajafacil/features/home/presentation/home_screen.dart';
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
      // Módulos aún no implementados: se irán reemplazando por feature.
      for (final module in appModules)
        GoRoute(
          path: module.route,
          builder: (context, state) => PlaceholderScreen(title: module.title),
        ),
    ],
  );

  // Re-evaluar las guardas al iniciar o cerrar sesión.
  ref
    ..listen(sessionProvider, (_, _) => router.refresh())
    ..onDispose(router.dispose);
  return router;
});
