import 'package:cajafacil/core/database/converters.dart';
import 'package:cajafacil/core/database/tables/business_tables.dart';
import 'package:cajafacil/core/database/tables/sync_columns.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:drift/drift.dart';

@DataClassName('CategoryRow')
class Categories extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 40)();

  /// Clave de ícono de un catálogo fijo (permite tree-shaking de íconos).
  TextColumn get iconKey => text().withDefault(const Constant('category'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF0F4C75))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ProductRow')
@TableIndex(name: 'idx_products_barcode', columns: {#barcode})
@TableIndex(name: 'idx_products_name', columns: {#name})
class Products extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  /// La unicidad se valida en el repositorio entre productos no borrados.
  TextColumn get barcode => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get unit => textEnum<ProductUnit>()();
  IntColumn get costUsdCents => integer().withDefault(const Constant(0))();
  IntColumn get priceUsdCents => integer()();
  TextColumn get cupPriceMode =>
      textEnum<CupPriceMode>().withDefault(Constant(CupPriceMode.auto.name))();

  /// Solo se usa cuando `cupPriceMode == manual`.
  IntColumn get priceCupCents => integer().nullable()();

  /// Existencia en milésimas de la unidad (1,5 lb = 1500).
  IntColumn get stockMilli => integer().withDefault(const Constant(0))();
  IntColumn get minStockMilli => integer().withDefault(const Constant(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SupplierRow')
class Suppliers extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PurchaseRow')
class Purchases extends Table with SyncColumns {
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();
  TextColumn get userId => text().references(Users, #id)();
  IntColumn get date => integer().map(const EpochMsConverter())();
  TextColumn get invoiceRef => text().nullable()();
  IntColumn get totalCostUsdCents => integer()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PurchaseItemRow')
class PurchaseItems extends Table with SyncColumns {
  TextColumn get purchaseId => text().references(Purchases, #id)();
  TextColumn get productId => text().references(Products, #id)();
  IntColumn get qtyMilli => integer()();
  IntColumn get unitCostUsdCents => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Kardex: cada cambio de existencia queda registrado (solo inserción).
@DataClassName('StockMovementRow')
@TableIndex(
  name: 'idx_stock_movements_product',
  columns: {#productId, #createdAt},
)
class StockMovements extends Table with SyncColumns {
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get type => textEnum<StockMovementType>()();
  TextColumn get reason => textEnum<AdjustmentReason>().nullable()();
  IntColumn get qtyDeltaMilli => integer()();
  IntColumn get unitCostUsdCents => integer()();
  IntColumn get balanceAfterMilli => integer()();

  /// Id de la venta o entrada que originó el movimiento.
  TextColumn get refId => text().nullable()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
