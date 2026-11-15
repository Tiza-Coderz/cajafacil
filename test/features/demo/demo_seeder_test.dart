import 'package:cajafacil/core/auth/secret_hasher.dart';
import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/database/stock_ledger.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/utils/clock.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/features/auth/data/auth_repository_impl.dart';
import 'package:cajafacil/features/cash_register/data/cash_register_repository_impl.dart';
import 'package:cajafacil/features/demo/data/demo_catalog.dart';
import 'package:cajafacil/features/demo/data/demo_seeder.dart';
import 'package:cajafacil/features/exchange_rate/data/exchange_rate_repository_impl.dart';
import 'package:cajafacil/features/inventory/data/inventory_repository_impl.dart';
import 'package:cajafacil/features/pos/data/sale_repository_impl.dart';
import 'package:cajafacil/features/products/data/product_repository_impl.dart';
import 'package:cajafacil/features/reports/data/reports_repository.dart';
import 'package:cajafacil/features/reports/domain/report_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DemoSeeder seeder;
  // Domingo por la tarde: el turno de hoy ya tiene ventas.
  final now = DateTime(2026, 11, 15, 16, 30);

  setUp(() {
    db = createTestDatabase(clock: FixedClock(now));
    final ledger = StockLedger(db);
    seeder = DemoSeeder(
      db,
      AuthRepositoryImpl(db, hasher: const SecretHasher(iterations: 1)),
      ExchangeRateRepositoryImpl(db),
      ProductRepositoryImpl(db, ledger),
      sales: SaleRepositoryImpl(db, ledger),
      cash: CashRegisterRepositoryImpl(db),
      inventory: InventoryRepositoryImpl(db, ledger),
    );
  });
  tearDown(() => db.close());

  test(
    'siembra 2 semanas de actividad y deja el stock del catálogo',
    () async {
      await seeder.seed();
      expect(await seeder.historyPending(), isTrue);
      final progress = <int>[];
      await seeder.seedHistory(onProgress: (day, _) => progress.add(day));
      expect(await seeder.historyPending(), isFalse);
      expect(progress, [for (var d = 1; d <= 14; d++) d]);

      // Los datos de demostración nunca se encolan para sincronizar.
      expect(await db.select(db.syncOutbox).get(), isEmpty);

      final products = await db.select(db.products).get();
      expect(products, hasLength(60));

      // Propiedad clave: tras simular ventas y entradas, cada producto
      // termina con la existencia "actual" del catálogo.
      for (final p in DemoCatalog.products) {
        final row = products.singleWhere((r) => r.name == p.name);
        expect(row.stockMilli, Qty.units(p.stock), reason: p.name);
      }

      // Y el stock coincide con la suma del kardex.
      final ledger = StockLedger(db);
      for (final row in products.take(5)) {
        expect(await ledger.recomputeStock(row.id), row.stockMilli);
      }

      final sessions = await db.select(db.cashSessions).get();
      expect(sessions, hasLength(14));
      expect(
        sessions.where((s) => s.status == CashSessionStatus.open),
        hasLength(1),
      );

      final report = await ReportsRepository(
        db,
      ).build(ReportRange.lastDays(now, 14));
      expect(report.summary.salesCount, greaterThan(300));
      expect(report.summary.voidedCount, 1);
      expect(report.summary.grossProfitUsd.isPositive, isTrue);
      expect(report.byPaymentMethod.length, greaterThanOrEqualTo(4));
      expect(report.byCashier.length, 2);
      expect(report.lowStock, isNotEmpty);
      expect(report.top10.first.name, contains('Cerveza'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('reset borra y vuelve a sembrar', () async {
    await seeder.seed();
    await seeder.seedHistory();
    await seeder.reset();
    expect(await seeder.historyPending(), isTrue);
    expect(await db.select(db.users).get(), hasLength(3));
    expect(await db.select(db.products).get(), hasLength(60));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
