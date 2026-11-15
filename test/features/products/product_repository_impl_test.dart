import 'package:cajafacil/core/auth/secret_hasher.dart';
import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/database/stock_ledger.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/features/auth/data/auth_repository_impl.dart';
import 'package:cajafacil/features/products/data/product_repository_impl.dart';
import 'package:cajafacil/features/products/domain/entities/product_draft.dart';
import 'package:cajafacil/features/products/domain/repositories/product_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProductRepositoryImpl repo;
  late StockLedger ledger;
  late String userId;

  setUp(() async {
    db = createTestDatabase();
    ledger = StockLedger(db);
    repo = ProductRepositoryImpl(db, ledger);
    userId = (await AuthRepositoryImpl(
      db,
      hasher: const SecretHasher(iterations: 1),
    ).createUser(name: 'Carlos', role: UserRole.owner, pin: '1234')).id;
  });
  tearDown(() => db.close());

  ProductDraft draft({
    String name = 'Arroz 1 kg',
    String? barcode,
    int initial = 0,
    int min = 0,
    String? id,
  }) => ProductDraft(
    id: id,
    name: name,
    unit: ProductUnit.pack,
    costUsd: const Money.usd(160),
    priceUsd: const Money.usd(220),
    cupPriceMode: CupPriceMode.auto,
    minStockMilli: min,
    initialStockMilli: initial,
    barcode: barcode,
  );

  test('crear con existencia inicial registra el kardex', () async {
    final p = await repo.save(draft(initial: 80000), userId: userId);

    expect(p.stockMilli, 80000);
    final moves = await db.select(db.stockMovements).get();
    expect(moves.single.type, StockMovementType.initial);
    expect(moves.single.qtyDeltaMilli, 80000);
    expect(moves.single.balanceAfterMilli, 80000);
  });

  test('editar no toca la existencia ni crea movimientos', () async {
    final p = await repo.save(draft(initial: 10000), userId: userId);
    final edited = await repo.save(
      draft(id: p.id, name: 'Arroz Premium 1 kg', initial: 999000),
      userId: userId,
    );
    expect(edited.name, 'Arroz Premium 1 kg');
    expect(edited.stockMilli, 10000);
    expect(await db.select(db.stockMovements).get(), hasLength(1));
  });

  test('no permite códigos de barras repetidos', () async {
    await repo.save(draft(barcode: '8501234000017'), userId: userId);
    await expectLater(
      repo.save(
        draft(name: 'Otro', barcode: '8501234000017'),
        userId: userId,
      ),
      throwsA(isA<DuplicateBarcodeException>()),
    );
  });

  test('al editar, el propio código no cuenta como duplicado', () async {
    final p = await repo.save(draft(barcode: '8501234000017'), userId: userId);
    await repo.save(
      draft(id: p.id, barcode: '8501234000017', name: 'Arroz'),
      userId: userId,
    );
  });

  test('busca por nombre parcial o código exacto', () async {
    await repo.save(draft(name: 'Cerveza Cristal'), userId: userId);
    await repo.save(
      draft(name: 'Malta Bucanero', barcode: '8501234000024'),
      userId: userId,
    );

    final byName = await repo
        .watchProducts(const ProductFilter(query: 'crist'))
        .first;
    final byCode = await repo
        .watchProducts(const ProductFilter(query: '8501234000024'))
        .first;
    expect(byName.single.name, 'Cerveza Cristal');
    expect(byCode.single.name, 'Malta Bucanero');
  });

  test('filtro de bajo stock', () async {
    await repo.save(
      draft(name: 'Aceite', initial: 6000, min: 12000),
      userId: userId,
    );
    await repo.save(
      draft(name: 'Arroz', initial: 80000, min: 20000),
      userId: userId,
    );
    final low = await repo
        .watchProducts(const ProductFilter(lowStockOnly: true))
        .first;
    expect(low.map((p) => p.name), ['Aceite']);
  });

  test('inactivos se ocultan salvo que se pidan', () async {
    final p = await repo.save(draft(), userId: userId);
    await repo.setActive(p.id, active: false);
    expect(await repo.watchProducts().first, isEmpty);
    expect(
      await repo
          .watchProducts(const ProductFilter(includeInactive: true))
          .first,
      hasLength(1),
    );
    expect(await repo.findByBarcode(p.barcode ?? 'x'), isNull);
  });

  test('ledger: recomputeStock reconstruye desde el kardex', () async {
    final p = await repo.save(draft(initial: 10000), userId: userId);
    await ledger.record(
      productId: p.id,
      type: StockMovementType.sale,
      qtyDeltaMilli: -3000,
      unitCostUsdCents: 160,
      userId: userId,
    );
    // Simula una caché desalineada tras sincronizar.
    await db.customStatement('UPDATE products SET stock_milli = 0');
    expect(await ledger.recomputeStock(p.id), 7000);
  });
}
