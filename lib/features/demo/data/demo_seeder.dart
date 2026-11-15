import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/features/auth/domain/entities/app_user.dart';
import 'package:cajafacil/features/auth/domain/repositories/auth_repository.dart';
import 'package:cajafacil/features/cash_register/domain/repositories/cash_register_repository.dart';
import 'package:cajafacil/features/demo/data/demo_catalog.dart';
import 'package:cajafacil/features/demo/data/demo_sales_simulator.dart';
import 'package:cajafacil/features/demo/domain/demo_credentials.dart';
import 'package:cajafacil/features/exchange_rate/domain/repositories/exchange_rate_repository.dart';
import 'package:cajafacil/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:cajafacil/features/pos/domain/repositories/sale_repository.dart';
import 'package:cajafacil/features/products/domain/entities/product_draft.dart';
import 'package:cajafacil/features/products/domain/repositories/product_repository.dart';
import 'package:drift/drift.dart';

/// Siembra los datos de "Mini-mercado La Esquina, Playa".
///
/// Es idempotente: `seedIfEmpty` solo actúa sobre una BD vacía, y `reset`
/// borra todo y vuelve a sembrar (botón "Restablecer demo").
class DemoSeeder {
  DemoSeeder(
    this._db,
    this._auth,
    this._rates,
    this._products, {
    required SaleRepository sales,
    required CashRegisterRepository cash,
    required InventoryRepository inventory,
    this.simulateSales = true,
  }) : _sales = sales,
       _cash = cash,
       _inventory = inventory;

  final AppDatabase _db;
  final AuthRepository _auth;
  final ExchangeRateRepository _rates;
  final ProductRepository _products;
  final SaleRepository _sales;
  final CashRegisterRepository _cash;
  final InventoryRepository _inventory;

  /// En tests se desactiva para que el seed sea instantáneo.
  final bool simulateSales;

  /// Tasa informal USD→CUP de los últimos 15 días (de más antigua a hoy).
  static const rateHistory = [
    415,
    415,
    418,
    420,
    420,
    422,
    425,
    425,
    428,
    430,
    432,
    435,
    435,
    438,
    440,
  ];

  /// Marca en `sync_state` con la fecha "ahora" del plan pendiente. Permite
  /// retomar el historial si la app se cierra a mitad (el plan es
  /// determinista: misma fecha + misma semilla = mismas ventas).
  static const _pendingKey = 'demo_history_pending_at';

  Future<bool> seedIfEmpty() async {
    final count = await _db.users.count().getSingle();
    if (count > 0) return false;
    await seed();
    return true;
  }

  Future<void> reset() async {
    await _db.wipeAll();
    await seed();
  }

  /// Fase 1 (rápida, en primer plano): negocio, usuarios, tasas y catálogo.
  /// Si [simulateSales], deja pendiente la fase 2 ([seedHistory]).
  Future<void> seed() => AppDatabase.withoutOutbox(
    () => _db.transaction(() async {
      await _seedBusiness();
      final users = <UserRole, AppUser>{};
      for (final user in DemoCredentials.users) {
        users[user.role] = await _auth.createUser(
          name: user.name,
          role: user.role,
          pin: user.pin,
          email: user.email,
          password: user.password,
        );
      }
      await _seedRates(users[UserRole.manager]!);

      final now = _db.clock.now();
      final simulator = DemoSalesSimulator(now: now);
      if (simulateSales) simulator.plan();
      await _seedCatalog(users[UserRole.owner]!, simulator);
      if (!simulateSales) return;

      // El inventario inicial se registra antes del período simulado.
      final openingDay = simulator.startDay.subtract(const Duration(hours: 4));
      await _db.customStatement(
        "UPDATE stock_movements SET created_at = ? WHERE type = 'initial'",
        [openingDay.toUtc().millisecondsSinceEpoch],
      );
      await _db
          .into(_db.syncState)
          .insertOnConflictUpdate(
            SyncStateCompanion.insert(
              key: _pendingKey,
              value: '${now.millisecondsSinceEpoch}',
            ),
          );
    }),
  );

  Future<bool> historyPending() async {
    final row = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.equals(_pendingKey))).getSingleOrNull();
    return row != null;
  }

  /// Fase 2 (lenta, en segundo plano): 2 semanas de ventas, entradas y
  /// cierres de caja. Una transacción por día para no bloquear la interfaz.
  Future<void> seedHistory({void Function(int day, int total)? onProgress}) =>
      AppDatabase.withoutOutbox(() async {
        final row = await (_db.select(
          _db.syncState,
        )..where((s) => s.key.equals(_pendingKey))).getSingleOrNull();
        if (row == null) return;
        final now = DateTime.fromMillisecondsSinceEpoch(int.parse(row.value));
        final simulator = DemoSalesSimulator(now: now)..plan();
        final users = {
          for (final u in await _db.select(_db.users).get()) u.role: u.id,
        };
        await simulator.execute(
          db: _db,
          products: await _products.watchProducts().first,
          sales: _sales,
          cash: _cash,
          inventory: _inventory,
          rateHistory: rateHistory,
          cashierId: users[UserRole.cashier]!,
          managerId: users[UserRole.manager]!,
          ownerId: users[UserRole.owner]!,
          onProgress: onProgress,
        );
        await (_db.delete(
          _db.syncState,
        )..where((s) => s.key.equals(_pendingKey))).go();
      });

  Future<void> _seedCatalog(AppUser owner, DemoSalesSimulator sim) async {
    final categoryIds = <String, String>{};
    for (final c in DemoCatalog.categories) {
      final category = await _products.createCategory(
        c.name,
        iconKey: c.iconKey,
        color: c.color,
      );
      categoryIds[c.key] = category.id;
    }
    for (final (i, p) in DemoCatalog.products.indexed) {
      final manual = p.manualCupPesos;
      await _products.save(
        ProductDraft(
          name: p.name,
          unit: p.unit,
          costUsd: Money.usd(p.costCents),
          priceUsd: Money.usd(p.priceCents),
          cupPriceMode: manual == null
              ? CupPriceMode.auto
              : CupPriceMode.manual,
          manualPriceCup: manual == null
              ? null
              : Money.units(manual, Currency.cup),
          minStockMilli: Qty.units(p.minStock),
          initialStockMilli: simulateSales
              ? sim.initialStockMilli(i, Qty.units(p.stock))
              : Qty.units(p.stock),
          categoryId: categoryIds[p.category],
          barcode: DemoCatalog.barcodeFor(i),
        ),
        userId: owner.id,
      );
    }
  }

  Future<void> _seedRates(AppUser manager) async {
    final now = _db.clock.now();
    final today = DateTime(now.year, now.month, now.day, 8, 30);
    for (var i = 0; i < rateHistory.length; i++) {
      final daysAgo = rateHistory.length - 1 - i;
      await _rates.setRate(
        rate: ExchangeRate.units(rateHistory[i]),
        userId: manager.id,
        effectiveDate: today.subtract(Duration(days: daysAgo)),
        note: daysAgo == 0 ? 'Tasa informal de la mañana' : null,
      );
    }
  }

  Future<void> _seedBusiness() async {
    final now = _db.clock.now();
    final row = BusinessSettingsRow(
      id: 'business',
      createdAt: now,
      updatedAt: now,
      deviceId: await _db.deviceId(),
      name: 'Mini-mercado La Esquina',
      address: 'Calle 42 #1504 e/ 15 y 17, Playa, La Habana',
      nit: '01234567890',
      phone: '+53 7 203 4567',
      whatsapp: '5352345678',
      primaryCurrency: Currency.cup,
      receiptFooter: '¡Gracias por su compra! Vuelva pronto.',
      cupRoundingPesos: 5,
    );
    await _db.writeSynced(_db.businessSettings, row, entityId: row.id);
  }
}
