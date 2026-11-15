import 'dart:async';

import 'package:cajafacil/core/config/env.dart';
import 'package:cajafacil/core/database/database_providers.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/cash_register/presentation/providers/cash_register_providers.dart';
import 'package:cajafacil/features/demo/data/demo_seeder.dart';
import 'package:cajafacil/features/exchange_rate/presentation/providers/exchange_rate_providers.dart';
import 'package:cajafacil/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:cajafacil/features/pos/presentation/providers/cart_controller.dart';
import 'package:cajafacil/features/products/presentation/providers/product_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'demo_providers.g.dart';

@Riverpod(keepAlive: true)
DemoSeeder demoSeeder(Ref ref) => DemoSeeder(
  ref.watch(appDatabaseProvider),
  ref.watch(authRepositoryProvider),
  ref.watch(exchangeRateRepositoryProvider),
  ref.watch(productRepositoryProvider),
  sales: ref.watch(saleRepositoryProvider),
  cash: ref.watch(cashRegisterRepositoryProvider),
  inventory: ref.watch(inventoryRepositoryProvider),
);

/// Inicialización de la app: abre la BD y siembra la base de la demo si
/// hace falta. La UI muestra un splash mientras esto no termine (es rápido).
@Riverpod(keepAlive: true)
Future<void> appStartup(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  await db.deviceId();
  if (Env.demoMode) {
    await ref.watch(demoSeederProvider).seedIfEmpty();
    // El historial de ventas se genera en segundo plano.
    unawaited(ref.read(demoHistoryProvider.notifier).start());
  }
}

/// Progreso del historial de ventas de ejemplo (fase 2 del seed).
class DemoHistoryState {
  const DemoHistoryState({this.running = false, this.day = 0, this.total = 0});

  final bool running;
  final int day;
  final int total;

  double? get progress => total == 0 ? null : day / total;
}

@Riverpod(keepAlive: true)
class DemoHistory extends _$DemoHistory {
  @override
  DemoHistoryState build() => const DemoHistoryState();

  Future<void> start() async {
    if (state.running) return;
    final seeder = ref.read(demoSeederProvider);
    if (!await seeder.historyPending()) return;
    state = const DemoHistoryState(running: true);
    try {
      await seeder.seedHistory(
        onProgress: (day, total) =>
            state = DemoHistoryState(running: true, day: day, total: total),
      );
    } finally {
      state = const DemoHistoryState();
    }
  }

  /// "Restablecer demo": borra todo, siembra la base y relanza el historial.
  Future<void> reset() async {
    await ref.read(demoSeederProvider).reset();
    unawaited(start());
  }
}
