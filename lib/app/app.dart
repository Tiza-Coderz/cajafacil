import 'package:cajafacil/app/router/app_router.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/demo/presentation/demo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CajaFacilApp extends ConsumerWidget {
  const CajaFacilApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'CajaFácil',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => _StartupGate(child: child!),
    );
  }
}

/// Muestra un splash hasta que la BD esté lista (y la demo sembrada).
class _StartupGate extends ConsumerWidget {
  const _StartupGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(appStartupProvider);
    return startup.when(
      data: (_) => child,
      loading: () => const Scaffold(
        body: LoadingView(message: 'Preparando su negocio…'),
      ),
      error: (error, _) => Scaffold(
        body: ErrorView(
          message:
              'No se pudo abrir la base de datos.\n'
              'Cierre la app y vuelva a abrirla.',
          onRetry: () => ref.invalidate(appStartupProvider),
        ),
      ),
    );
  }
}
