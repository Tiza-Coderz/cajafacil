import 'package:cajafacil/core/auth/secret_hasher.dart';
import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/database/stock_ledger.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/features/auth/data/auth_repository_impl.dart';
import 'package:cajafacil/features/inventory/data/inventory_repository_impl.dart';
import 'package:cajafacil/features/inventory/domain/entities/inventory_entities.dart';
import 'package:cajafacil/features/products/data/product_repository_impl.dart';
import 'package:cajafacil/features/products/domain/entities/product.dart';
import 'package:cajafacil/features/products/domain/entities/product_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late InventoryRepositoryImpl inventory;
  late ProductRepositoryImpl products;
  late String userId;
  late Product pollo;

  setUp(() async {
    db = createTestDatabase();
    final ledger = StockLedger(db);
    inventory = InventoryRepositoryImpl(db, ledger);
    products = ProductRepositoryImpl(db, ledger);
    userId = (await AuthRepositoryImpl(
      db,
      hasher: const SecretHasher(iterations: 1),
    ).createUser(name: 'Yamilé', role: UserRole.manager, pin: '2222')).id;
    pollo = await products.save(
      const ProductDraft(
        name: 'Muslo de pollo',
        unit: ProductUnit.pound,
        costUsd: Money.usd(110),
        priceUsd: Money.usd(150),
        cupPriceMode: CupPriceMode.auto,
        minStockMilli: 30000,
        initialStockMilli: 10000,
      ),
      userId: userId,
    );
  });
  tearDown(() => db.close());

  test('una entrada suma existencia y actualiza el costo promedio', () async {
    final supplier = await inventory.createSupplier(
      name: 'Distribuidora Habana Sur',
      phone: '+53 5 234 5678',
    );
    await inventory.registerPurchase(
      PurchaseDraft(
        supplierId: supplier.id,
        invoiceRef: 'F-0042',
        items: [
          PurchaseItemDraft(
            productId: pollo.id,
            productName: pollo.name,
            unit: pollo.unit,
            qtyMilli: 30000,
            unitCostUsd: const Money.usd(130),
          ),
        ],
      ),
      userId: userId,
    );

    final updated = (await products.getById(pollo.id))!;
    expect(updated.stockMilli, 40000);
    // (10 × 1.10 + 30 × 1.30) / 40 = 1.25
    expect(updated.costUsd, const Money.usd(125));

    final list = await inventory.watchPurchases().first;
    expect(list.single.supplierName, 'Distribuidora Habana Sur');
    expect(list.single.invoiceRef, 'F-0042');
    expect(list.single.itemCount, 1);
    expect(list.single.totalCostUsd, const Money.usd(3900));
  });

  test('ajuste por merma resta y queda en el kardex con motivo', () async {
    final stock = await inventory.adjust(
      productId: pollo.id,
      reason: AdjustmentReason.waste,
      quantityMilli: 1500,
      userId: userId,
      note: 'Apagón de 8 horas',
    );
    expect(stock, 8500);

    final kardex = await inventory.watchKardex(pollo.id).first;
    expect(kardex.first.reason, AdjustmentReason.waste);
    expect(kardex.first.label, 'Merma');
    expect(kardex.first.qtyDeltaMilli, -1500);
    expect(kardex.first.balanceAfterMilli, 8500);
    expect(kardex.first.note, 'Apagón de 8 horas');
    expect(kardex.first.userName, 'Yamilé');
  });

  test('conteo físico sin diferencia no crea movimiento', () async {
    final stock = await inventory.adjust(
      productId: pollo.id,
      reason: AdjustmentReason.recount,
      quantityMilli: 10000,
      userId: userId,
    );
    expect(stock, 10000);
    expect(await inventory.watchKardex(pollo.id).first, hasLength(1));
  });

  test('no registra entradas vacías ni con cantidades inválidas', () async {
    expect(
      () => inventory.registerPurchase(
        const PurchaseDraft(items: []),
        userId: userId,
      ),
      throwsArgumentError,
    );
    expect(
      () => inventory.registerPurchase(
        PurchaseDraft(
          items: [
            PurchaseItemDraft(
              productId: pollo.id,
              productName: pollo.name,
              unit: pollo.unit,
              qtyMilli: 0,
              unitCostUsd: const Money.usd(100),
            ),
          ],
        ),
        userId: userId,
      ),
      throwsArgumentError,
    );
  });
}
