import 'package:cajafacil/core/database/converters.dart';
import 'package:cajafacil/core/database/tables/business_tables.dart';
import 'package:cajafacil/core/database/tables/catalog_tables.dart';
import 'package:cajafacil/core/database/tables/sync_columns.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:drift/drift.dart';

@DataClassName('CashSessionRow')
class CashSessions extends Table with SyncColumns {
  TextColumn get openedBy => text().references(Users, #id)();
  IntColumn get openedAt => integer().map(const EpochMsConverter())();
  IntColumn get openingUsdCents => integer()();
  IntColumn get openingCupCents => integer()();
  TextColumn get status => textEnum<CashSessionStatus>()();
  TextColumn get closedBy => text().nullable().references(Users, #id)();
  IntColumn get closedAt =>
      integer().map(const EpochMsConverter()).nullable()();
  IntColumn get expectedUsdCents => integer().nullable()();
  IntColumn get expectedCupCents => integer().nullable()();
  IntColumn get countedUsdCents => integer().nullable()();
  IntColumn get countedCupCents => integer().nullable()();
  IntColumn get diffUsdCents => integer().nullable()();
  IntColumn get diffCupCents => integer().nullable()();

  /// Desglose del conteo por denominación (JSON), para auditoría.
  TextColumn get countDetailJson => text().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CashMovementRow')
class CashMovements extends Table with SyncColumns {
  TextColumn get sessionId => text().references(CashSessions, #id)();
  TextColumn get type => textEnum<CashMovementType>()();
  TextColumn get currency => textEnum<Currency>()();
  IntColumn get amountCents => integer()();
  TextColumn get reason => text()();
  TextColumn get userId => text().references(Users, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SaleRow')
@TableIndex(name: 'idx_sales_created', columns: {#createdAt})
@TableIndex(name: 'idx_sales_session', columns: {#sessionId})
class Sales extends Table with SyncColumns {
  /// Número legible por el cliente, ej. "A-000123".
  TextColumn get number => text()();
  TextColumn get sessionId => text().references(CashSessions, #id)();
  TextColumn get cashierId => text().references(Users, #id)();

  /// Tasa congelada al momento de la venta.
  IntColumn get rateCupPerUsdX100 => integer()();
  IntColumn get subtotalUsdCents => integer()();
  TextColumn get discountType => textEnum<DiscountType>().nullable()();
  IntColumn get discountValue => integer().withDefault(const Constant(0))();

  /// Descuento total aplicado (líneas + global) en USD.
  IntColumn get discountUsdCents => integer().withDefault(const Constant(0))();
  IntColumn get totalUsdCents => integer()();
  IntColumn get totalCupCents => integer()();

  /// Costo total (snapshot) para calcular ganancia bruta sin joins.
  IntColumn get totalCostUsdCents => integer()();
  TextColumn get changeCurrency => textEnum<Currency>().nullable()();
  IntColumn get changeCents => integer().withDefault(const Constant(0))();
  TextColumn get status => textEnum<SaleStatus>()();
  TextColumn get voidReason => text().nullable()();
  TextColumn get voidedBy => text().nullable().references(Users, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SaleItemRow')
@TableIndex(name: 'idx_sale_items_sale', columns: {#saleId})
@TableIndex(name: 'idx_sale_items_product', columns: {#productId})
class SaleItems extends Table with SyncColumns {
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get nameSnapshot => text()();
  IntColumn get qtyMilli => integer()();
  IntColumn get unitPriceUsdCents => integer()();
  IntColumn get unitCostUsdCents => integer()();
  TextColumn get discountType => textEnum<DiscountType>().nullable()();
  IntColumn get discountValue => integer().withDefault(const Constant(0))();
  IntColumn get discountUsdCents => integer().withDefault(const Constant(0))();
  IntColumn get lineTotalUsdCents => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SalePaymentRow')
@TableIndex(name: 'idx_sale_payments_sale', columns: {#saleId})
class SalePayments extends Table with SyncColumns {
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get method => textEnum<PaymentMethod>()();
  TextColumn get currency => textEnum<Currency>()();
  IntColumn get amountCents => integer()();

  /// Nº de transacción de Transfermóvil/EnZona, si aplica.
  TextColumn get reference => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
