import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/core/widgets/placeholder_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) =>
            const PlaceholderScreen(title: 'CajaFácil'),
      ),
    ],
  );
});
