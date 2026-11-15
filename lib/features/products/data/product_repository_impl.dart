import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/database/stock_ledger.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/features/products/domain/entities/product.dart';
import 'package:cajafacil/features/products/domain/entities/product_draft.dart';
import 'package:cajafacil/features/products/domain/repositories/product_repository.dart';
import 'package:drift/drift.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._db, this._ledger);

  final AppDatabase _db;
  final StockLedger _ledger;

  JoinedSelectStatement<HasResultSet, dynamic> _baseQuery() {
    final p = _db.products;
    return _db.select(p).join([
      leftOuterJoin(_db.categories, _db.categories.id.equalsExp(p.categoryId)),
    ])..where(p.deletedAt.isNull());
  }

  Product _map(TypedResult row) {
    final p = row.readTable(_db.products);
    final c = row.readTableOrNull(_db.categories);
    return Product(
      id: p.id,
      name: p.name,
      unit: p.unit,
      costUsd: Money.usd(p.costUsdCents),
      priceUsd: Money.usd(p.priceUsdCents),
      cupPriceMode: p.cupPriceMode,
      manualPriceCup: p.priceCupCents == null
          ? null
          : Money.cup(p.priceCupCents!),
      stockMilli: p.stockMilli,
      minStockMilli: p.minStockMilli,
      categoryId: p.categoryId,
      categoryName: c?.name,
      barcode: p.barcode,
      photo: p.photoData,
      active: p.active,
    );
  }

  @override
  Stream<List<Product>> watchProducts([
    ProductFilter filter = const ProductFilter(),
  ]) {
    final p = _db.products;
    final query = _baseQuery();
    if (!filter.includeInactive) query.where(p.active.equals(true));
    if (filter.categoryId != null) {
      query.where(p.categoryId.equals(filter.categoryId!));
    }
    if (filter.lowStockOnly) {
      query.where(p.stockMilli.isSmallerOrEqual(p.minStockMilli));
    }
    final q = filter.query.trim();
    if (q.isNotEmpty) {
      query.where(p.name.like('%$q%') | p.barcode.equals(q));
    }
    query.orderBy([OrderingTerm.asc(p.name)]);
    return query.watch().map((rows) => rows.map(_map).toList());
  }

  @override
  Stream<Product?> watchById(String id) {
    final query = _baseQuery()..where(_db.products.id.equals(id));
    return query.watchSingleOrNull().map((r) => r == null ? null : _map(r));
  }

  @override
  Future<Product?> getById(String id) async {
    final query = _baseQuery()..where(_db.products.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<Product?> findByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final query = _baseQuery()
      ..where(
        _db.products.barcode.equals(code) & _db.products.active.equals(true),
      )
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<Product> save(ProductDraft draft, {required String userId}) {
    return _db.transaction(() async {
      final barcode = draft.barcode?.trim();
      final cleanBarcode = (barcode?.isEmpty ?? true) ? null : barcode;
      if (cleanBarcode != null) {
        await _ensureUniqueBarcode(cleanBarcode, draft.id);
      }

      final now = _db.clock.now();
      final existing = draft.id == null
          ? null
          : await (_db.select(
              _db.products,
            )..where((p) => p.id.equals(draft.id!))).getSingle();
      final id = existing?.id ?? _db.ids.newId();

      final row = ProductRow(
        id: id,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        deviceId: await _db.deviceId(),
        name: draft.name.trim(),
        categoryId: draft.categoryId,
        barcode: cleanBarcode,
        photoPath: existing?.photoPath,
        photoData: draft.photo,
        unit: draft.unit,
        costUsdCents: draft.costUsd.cents,
        priceUsdCents: draft.priceUsd.cents,
        cupPriceMode: draft.cupPriceMode,
        priceCupCents: draft.cupPriceMode == CupPriceMode.manual
            ? draft.manualPriceCup?.cents
            : null,
        // La existencia nunca se edita desde el formulario.
        stockMilli: existing?.stockMilli ?? 0,
        minStockMilli: draft.minStockMilli,
        active: draft.active,
      );
      await _db.writeSynced(_db.products, row, entityId: id);

      if (existing == null && draft.initialStockMilli > 0) {
        await _ledger.record(
          productId: id,
          type: StockMovementType.initial,
          qtyDeltaMilli: draft.initialStockMilli,
          unitCostUsdCents: draft.costUsd.cents,
          userId: userId,
        );
      }
      return (await getById(id))!;
    });
  }

  Future<void> _ensureUniqueBarcode(String barcode, String? exceptId) async {
    final query = _db.select(_db.products)
      ..where((p) => p.barcode.equals(barcode) & p.deletedAt.isNull())
      ..limit(1);
    if (exceptId != null) query.where((p) => p.id.equals(exceptId).not());
    final clash = await query.getSingleOrNull();
    if (clash != null) throw DuplicateBarcodeException(clash.name);
  }

  @override
  Future<void> setActive(String id, {required bool active}) async {
    final row = await (_db.select(
      _db.products,
    )..where((p) => p.id.equals(id))).getSingle();
    await _db.writeSynced(
      _db.products,
      row.copyWith(active: active, updatedAt: _db.clock.now()),
      entityId: id,
    );
  }

  @override
  Stream<List<Category>> watchCategories() {
    final query = _db.select(_db.categories)
      ..where((c) => c.deletedAt.isNull())
      ..orderBy([
        (c) => OrderingTerm.asc(c.sortOrder),
        (c) => OrderingTerm.asc(c.name),
      ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (c) => Category(
              id: c.id,
              name: c.name,
              iconKey: c.iconKey,
              color: c.color,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<Category> createCategory(
    String name, {
    String iconKey = 'category',
    int? color,
  }) async {
    final now = _db.clock.now();
    final count = await _db.categories.count().getSingle();
    final row = CategoryRow(
      id: _db.ids.newId(),
      createdAt: now,
      updatedAt: now,
      deviceId: await _db.deviceId(),
      name: name.trim(),
      iconKey: iconKey,
      color: color ?? 0xFF0F4C75,
      sortOrder: count,
    );
    await _db.writeSynced(_db.categories, row, entityId: row.id);
    return Category(
      id: row.id,
      name: row.name,
      iconKey: row.iconKey,
      color: row.color,
    );
  }
}
