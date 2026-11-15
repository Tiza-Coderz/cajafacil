import 'package:cajafacil/core/auth/secret_hasher.dart';
import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/database/stock_ledger.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/sync/remote_sync_api.dart';
import 'package:cajafacil/core/sync/sync_engine.dart';
import 'package:cajafacil/core/utils/clock.dart';
import 'package:cajafacil/features/auth/data/auth_repository_impl.dart';
import 'package:cajafacil/features/products/data/product_repository_impl.dart';
import 'package:cajafacil/features/products/domain/entities/product.dart';
import 'package:cajafacil/features/products/domain/entities/product_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_sync_api.dart';
import '../../helpers/test_database.dart';

/// Un "dispositivo": su propia BD, reloj y repositorios.
class Device {
  Device(this.name, DateTime start, FakeSyncApi server)
    : clock = FixedClock(start),
      _server = server {
    db = createTestDatabase(clock: clock);
    products = ProductRepositoryImpl(db, StockLedger(db));
    sync = SyncEngine(db, _server);
  }

  final String name;
  final FixedClock clock;
  final FakeSyncApi _server;
  late final AppDatabase db;
  late final ProductRepositoryImpl products;
  late final SyncEngine sync;

  Future<Product> product(String id) async => (await products.getById(id))!;

  Future<void> sell(String productId, String userId, int qtyMilli) =>
      StockLedger(db).record(
        productId: productId,
        type: StockMovementType.sale,
        qtyDeltaMilli: -qtyMilli,
        unitCostUsdCents: 160,
        userId: userId,
      );
}

void main() {
  late FakeSyncApi server;
  late Device cajaA;
  late Device cajaB;
  late String ownerId;
  late Product arroz;

  ProductDraft draftOf(Product p, {String? name, int? priceCents}) =>
      ProductDraft(
        id: p.id,
        name: name ?? p.name,
        unit: p.unit,
        costUsd: p.costUsd,
        priceUsd: priceCents == null ? p.priceUsd : Money.usd(priceCents),
        cupPriceMode: p.cupPriceMode,
        minStockMilli: p.minStockMilli,
      );

  setUp(() async {
    server = FakeSyncApi();
    cajaA = Device('A', DateTime(2026, 11, 15, 8), server);
    cajaB = Device('B', DateTime(2026, 11, 15, 8), server);

    // La caja A crea el negocio y lo sube; la B lo descarga.
    ownerId = (await AuthRepositoryImpl(
      cajaA.db,
      hasher: const SecretHasher(iterations: 1),
    ).createUser(name: 'Carlos', role: UserRole.owner, pin: '1234')).id;
    arroz = await cajaA.products.save(
      const ProductDraft(
        name: 'Arroz 1 kg',
        unit: ProductUnit.pack,
        costUsd: Money.usd(160),
        priceUsd: Money.usd(220),
        cupPriceMode: CupPriceMode.auto,
        minStockMilli: 0,
        initialStockMilli: 10000,
      ),
      userId: ownerId,
    );
    await cajaA.sync.sync();
    await cajaB.sync.sync();
  });

  tearDown(() async {
    await cajaA.db.close();
    await cajaB.db.close();
  });

  test('la otra caja recibe usuarios, productos y existencia', () async {
    final enB = await cajaB.product(arroz.id);
    expect(enB.name, 'Arroz 1 kg');
    expect(enB.stockMilli, 10000);
    expect(await cajaB.db.select(cajaB.db.users).get(), hasLength(1));
    expect(await cajaA.sync.pendingCount(), 0);
  });

  test('ventas simultáneas sin conexión no se pierden', () async {
    // Ambas cajas venden el mismo producto sin conexión.
    await cajaA.sell(arroz.id, ownerId, 2000);
    await cajaB.sell(arroz.id, ownerId, 3000);

    await cajaA.sync.sync();
    await cajaB.sync.sync();
    await cajaA.sync.sync();

    // 10 − 2 − 3 = 5 en las dos cajas.
    expect((await cajaA.product(arroz.id)).stockMilli, 5000);
    expect((await cajaB.product(arroz.id)).stockMilli, 5000);
  });

  test('una venta en otra caja no pisa un cambio de precio', () async {
    cajaA.clock.advance(const Duration(hours: 1));
    cajaB.clock.advance(const Duration(hours: 2));
    await cajaA.products.save(
      draftOf(arroz, priceCents: 250),
      userId: ownerId,
    );
    await cajaB.sell(arroz.id, ownerId, 1000); // más tarde, pero solo stock

    await cajaA.sync.sync();
    await cajaB.sync.sync();
    await cajaA.sync.sync();

    for (final caja in [cajaA, cajaB]) {
      final p = await caja.product(arroz.id);
      expect(p.priceUsd, const Money.usd(250), reason: caja.name);
      expect(p.stockMilli, 9000, reason: caja.name);
    }
  });

  test('conflicto real: gana el último cambio en ambas cajas', () async {
    cajaA.clock.advance(const Duration(minutes: 10));
    cajaB.clock.advance(const Duration(minutes: 20));
    await cajaA.products.save(
      draftOf(arroz, name: 'Arroz (A)'),
      userId: ownerId,
    );
    await cajaB.products.save(
      draftOf(arroz, name: 'Arroz (B)'),
      userId: ownerId,
    );

    // Orden de sincronización desfavorable: B sube antes que A.
    await cajaB.sync.sync();
    final resultA = await cajaA.sync.sync();
    await cajaB.sync.sync();

    expect(resultA.applied, greaterThan(0));
    expect((await cajaA.product(arroz.id)).name, 'Arroz (B)');
    expect((await cajaB.product(arroz.id)).name, 'Arroz (B)');
    // El servidor tampoco aceptó la versión vieja de A.
    expect(
      server.records.singleWhere((r) => r.id == arroz.id).payload['name'],
      'Arroz (B)',
    );
  });

  test('sin conexión la cola se conserva y se reintenta después', () async {
    await cajaA.sell(arroz.id, ownerId, 1000);
    server.offline = true;
    await expectLater(
      cajaA.sync.sync(),
      throwsA(isA<SyncNetworkException>()),
    );
    expect(await cajaA.sync.pendingCount(), greaterThan(0));

    server.offline = false;
    final result = await cajaA.sync.sync();
    expect(result.pushed, greaterThan(0));
    expect(await cajaA.sync.pendingCount(), 0);
    expect(await cajaA.sync.lastSyncAt(), isNotNull);

    await cajaB.sync.sync();
    expect((await cajaB.product(arroz.id)).stockMilli, 9000);
  });

  test('cada registro sube una sola vez aunque cambie varias veces', () async {
    for (var i = 0; i < 5; i++) {
      cajaA.clock.advance(const Duration(minutes: 1));
      await cajaA.products.save(
        draftOf(arroz, priceCents: 220 + i),
        userId: ownerId,
      );
    }
    final result = await cajaA.sync.sync();
    expect(result.pushed, 1);
  });
}
