import 'package:cajafacil/app/app.dart';
import 'package:cajafacil/core/database/database_providers.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/cash_register/presentation/providers/cash_register_providers.dart';
import 'package:cajafacil/features/demo/data/demo_seeder.dart';
import 'package:cajafacil/features/demo/presentation/demo_providers.dart';
import 'package:cajafacil/features/exchange_rate/presentation/providers/exchange_rate_providers.dart';
import 'package:cajafacil/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:cajafacil/features/pos/presentation/providers/cart_controller.dart';
import 'package:cajafacil/features/products/presentation/providers/product_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  testWidgets('arranca, siembra la demo y muestra el acceso por usuario', (
    tester,
  ) async {
    final db = createTestDatabase();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          // Sin simular 2 semanas de ventas: el smoke test debe ser rápido.
          demoSeederProvider.overrideWith(
            (ref) => DemoSeeder(
              db,
              ref.watch(authRepositoryProvider),
              ref.watch(exchangeRateRepositoryProvider),
              ref.watch(productRepositoryProvider),
              sales: ref.watch(saleRepositoryProvider),
              cash: ref.watch(cashRegisterRepositoryProvider),
              inventory: ref.watch(inventoryRepositoryProvider),
              simulateSales: false,
            ),
          ),
        ],
        child: const CajaFacilApp(),
      ),
    );
    // El hash de PIN del seed corre fuera del reloj falso del test.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pumpAndSettle();

    expect(find.text('¿Quién va a trabajar?'), findsOneWidget);
    expect(find.text('Carlos Pérez'), findsOneWidget);
    expect(find.text('Yoandry Fernández'), findsOneWidget);
    expect(find.text('Modo demostración'), findsOneWidget);

    // Drift cierra sus streams con un timer de 0 ms al desmontar.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
