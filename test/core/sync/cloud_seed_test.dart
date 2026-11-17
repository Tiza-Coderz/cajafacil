import 'package:cajafacil/core/auth/secret_hasher.dart';
import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/database/stock_ledger.dart';
import 'package:cajafacil/core/sync/sync_engine.dart';
import 'package:cajafacil/core/sync/sync_registry.dart';
import 'package:cajafacil/core/utils/clock.dart';
import 'package:cajafacil/features/auth/data/auth_repository_impl.dart';
import 'package:cajafacil/features/cash_register/data/cash_register_repository_impl.dart';
import 'package:cajafacil/features/demo/data/demo_seeder.dart';
import 'package:cajafacil/features/exchange_rate/data/exchange_rate_repository_impl.dart';
import 'package:cajafacil/features/inventory/data/inventory_repository_impl.dart';
import 'package:cajafacil/features/pos/data/sale_repository_impl.dart';
import 'package:cajafacil/features/products/data/product_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_sync_api.dart';
import '../../helpers/test_database.dart';

/// Lo que hace `tool/seed_supabase.dart`: sembrar en una BD aparte, subir la
/// foto completa y que un equipo nuevo la descargue al vincularse.
void main() {
  final now = DateTime(2026, 11, 15, 16, 30);
  late AppDatabase seedDb;
  late AppDatabase device;
  late FakeSyncApi server;

  setUp(() async {
    server = FakeSyncApi();
    seedDb = createTestDatabase(clock: FixedClock(now));
    device = createTestDatabase(clock: FixedClock(now));
    final ledger = StockLedger(seedDb);
    final seeder = DemoSeeder(
      seedDb,
      AuthRepositoryImpl(seedDb, hasher: const SecretHasher(iterations: 1)),
      ExchangeRateRepositoryImpl(seedDb),
      ProductRepositoryImpl(seedDb, ledger),
      sales: SaleRepositoryImpl(seedDb, ledger),
      cash: CashRegisterRepositoryImpl(seedDb),
      inventory: InventoryRepositoryImpl(seedDb, ledger),
    );
    await seeder.seed();
    await seeder.seedHistory();
  });

  tearDown(() async {
    await seedDb.close();
    await device.close();
  });

  test('la foto respeta el orden de dependencias', () async {
    final records = await snapshotAll(seedDb);
    final order = [for (final e in syncEntities(seedDb)) e.name];
    final positions = records.map((r) => order.indexOf(r.entity)).toList();
    expect(positions, orderedEquals([...positions]..sort()));
    expect(records.where((r) => r.entity == 'products'), hasLength(60));
  });

  test(
    'un equipo vacío descarga todo el negocio y queda igual',
    () async {
      final records = await snapshotAll(seedDb);
      // Igual que el script: lotes de 200.
      for (var i = 0; i < records.length; i += 200) {
        await server.push(
          records.sublist(i, (i + 200).clamp(0, records.length)),
        );
      }

      // Páginas pequeñas: las claves foráneas deben cumplirse entre páginas.
      await SyncEngine(device, server).pull(pageSize: 150);

      for (final entity in syncEntities(seedDb)) {
        expect(
          await device.select(entity.table).get(),
          hasLength((await seedDb.select(entity.table).get()).length),
          reason: entity.name,
        );
      }

      // El stock (proyección del kardex) coincide producto a producto.
      Map<String, int> stockOf(List<ProductRow> rows) => {
        for (final p in rows) p.id: p.stockMilli,
      };
      expect(
        stockOf(await device.select(device.products).get()),
        stockOf(await seedDb.select(seedDb.products).get()),
      );

      // Los PIN de prueba funcionan en el equipo nuevo.
      final auth = AuthRepositoryImpl(
        device,
        hasher: const SecretHasher(iterations: 1),
      );
      final owner = (await device.select(device.users).get()).firstWhere(
        (u) => u.name == 'Carlos Pérez',
      );
      expect(await auth.verifyPin(owner.id, '1234'), isNotNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
