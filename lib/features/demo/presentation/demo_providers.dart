import 'package:cajafacil/core/config/env.dart';
import 'package:cajafacil/core/database/database_providers.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/demo/data/demo_seeder.dart';
import 'package:cajafacil/features/exchange_rate/presentation/providers/exchange_rate_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'demo_providers.g.dart';

@Riverpod(keepAlive: true)
DemoSeeder demoSeeder(Ref ref) => DemoSeeder(
  ref.watch(appDatabaseProvider),
  ref.watch(authRepositoryProvider),
  ref.watch(exchangeRateRepositoryProvider),
);

/// Inicialización de la app: abre la BD y siembra la demo si hace falta.
/// La UI muestra un splash mientras esto no termine.
@Riverpod(keepAlive: true)
Future<void> appStartup(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  await db.deviceId();
  if (Env.demoMode) {
    await ref.watch(demoSeederProvider).seedIfEmpty();
  }
}
