import 'package:cajafacil/core/auth/secret_hasher.dart';
import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/database/stock_ledger.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/rounding.dart';
import 'package:cajafacil/features/auth/data/auth_repository_impl.dart';
import 'package:cajafacil/features/cash_register/data/cash_register_repository_impl.dart';
import 'package:cajafacil/features/cash_register/domain/services/cash_reconciliation.dart';
import 'package:cajafacil/features/pos/data/sale_repository_impl.dart';
import 'package:cajafacil/features/pos/domain/entities/cart_line.dart';
import 'package:cajafacil/features/pos/domain/repositories/sale_repository.dart';
import 'package:cajafacil/features/pos/domain/services/payment_calculator.dart';
import 'package:cajafacil/features/pos/domain/services/sale_calculator.dart';
import 'package:cajafacil/features/products/data/product_repository_impl.dart';
import 'package:cajafacil/features/products/domain/entities/product.dart';
import 'package:cajafacil/features/products/domain/entities/product_draft.dart';
import 'package:cajafacil/features/reports/data/reports_repository.dart';
import 'package:cajafacil/features/reports/domain/report_csv.dart';
import 'package:cajafacil/features/reports/domain/report_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  group('ReportRange', () {
    final now = DateTime(2026, 11, 15, 18, 30);

    test('hoy cubre el día completo', () {
      final r = ReportRange.today(now);
      expect(r.from, DateTime(2026, 11, 15));
      expect(r.to, DateTime(2026, 11, 16));
      expect(r.dayCount, 1);
    });

    test('últimos 14 días incluye hoy', () {
      final r = ReportRange.lastDays(now, 14);
      expect(r.from, DateTime(2026, 11, 2));
      expect(r.dayCount, 14);
    });

    test('este mes empieza el día 1', () {
      expect(ReportRange.thisMonth(now).from, DateTime(2026, 11));
    });
  });

  group('SalesSummary', () {
    test('margen, ticket promedio y ganancia', () {
      const s = SalesSummary(
        salesCount: 4,
        totalUsd: Money.usd(4000),
        totalCup: Money.cup(1760000),
        costUsd: Money.usd(3000),
        discountUsd: Money.usd(0),
        voidedCount: 0,
      );
      expect(s.grossProfitUsd, const Money.usd(1000));
      expect(s.marginBasisPoints, 2500);
      expect(s.averageTicketUsd, const Money.usd(1000));
      expect(s.averageTicketCup, const Money.cup(440000));
    });

    test('sin ventas no divide por cero', () {
      expect(SalesSummary.empty.marginBasisPoints, 0);
      expect(SalesSummary.empty.averageTicketCup, const Money.cup(0));
    });
  });

  test('LowStockItem sugiere pedir hasta el doble del mínimo', () {
    const item = LowStockItem(
      productId: 'p',
      name: 'Aceite',
      unit: ProductUnit.unit,
      stockMilli: 6000,
      minStockMilli: 12000,
    );
    expect(item.suggestedOrderMilli, 18000);
  });

  group('ReportsRepository con ventas reales', () {
    late AppDatabase db;
    late ReportsRepository reports;
    late SaleRepositoryImpl sales;
    late String sessionId;
    late String userId;
    late Product arroz;
    late Product cerveza;
    final rate = ExchangeRate.units(440);
    final day1 = DateTime(2026, 11, 13, 10);
    final day2 = DateTime(2026, 11, 14, 11);

    setUp(() async {
      db = createTestDatabase();
      final ledger = StockLedger(db);
      reports = ReportsRepository(db);
      sales = SaleRepositoryImpl(db, ledger);
      final products = ProductRepositoryImpl(db, ledger);
      userId = (await AuthRepositoryImpl(
        db,
        hasher: const SecretHasher(iterations: 1),
      ).createUser(name: 'Yoandry', role: UserRole.cashier, pin: '3333')).id;
      sessionId = (await CashRegisterRepositoryImpl(db).open(
        opening: CurrencyPair(usd: const Money.usd(0), cup: const Money.cup(0)),
        userId: userId,
      )).id;
      ProductDraft draft(String name, int cost, int price) => ProductDraft(
        name: name,
        unit: ProductUnit.unit,
        costUsd: Money.usd(cost),
        priceUsd: Money.usd(price),
        cupPriceMode: CupPriceMode.auto,
        minStockMilli: 5000,
        initialStockMilli: 6000,
      );
      arroz = await products.save(draft('Arroz', 160, 220), userId: userId);
      cerveza = await products.save(draft('Cerveza', 65, 100), userId: userId);
    });
    tearDown(() => db.close());

    Future<void> sell(
      Product p,
      int qty,
      DateTime at,
      PaymentMethod method,
    ) async {
      final lines = [
        CartLine(
          productId: p.id,
          name: p.name,
          unit: p.unit,
          qtyMilli: qty * 1000,
          unitPriceUsd: p.priceUsd,
          unitPriceCup: rate.toCup(p.priceUsd),
          unitCostUsd: p.costUsd,
        ),
      ];
      final totals = SaleCalculator.totals(
        lines: lines,
        rate: rate,
        rounding: CupRounding.none,
      );
      await sales.completeSale(
        CompleteSaleCommand(
          sessionId: sessionId,
          cashierId: userId,
          rate: rate,
          lines: lines,
          totals: totals,
          payments: [Payment(method: method, amount: totals.totalCup)],
          changeCurrency: Currency.cup,
          change: const Money.cup(0),
          createdAt: at,
        ),
      );
    }

    test('agrega resumen, días, productos, cajeros y pagos', () async {
      await sell(arroz, 2, day1, PaymentMethod.cashCup);
      await sell(cerveza, 3, day2, PaymentMethod.transfermovil);
      await sell(arroz, 1, day2, PaymentMethod.cashCup);

      final r = await reports.build(
        ReportRange.days(DateTime(2026, 11, 12), DateTime(2026, 11, 14), 'x'),
      );

      expect(r.summary.salesCount, 3);
      // 2×2.20 + 3×1.00 + 1×2.20 = 9.60 USD ; costo 3×1.60 + 3×0.65 = 6.75
      expect(r.summary.totalUsd, const Money.usd(960));
      expect(r.summary.costUsd, const Money.usd(675));

      expect(r.daily, hasLength(3)); // incluye el día 12 sin ventas
      expect(r.daily.first.salesCount, 0);
      expect(r.daily[1].totalUsd, const Money.usd(440));
      expect(r.daily[2].salesCount, 2);

      expect(r.byProduct.first.name, 'Arroz');
      expect(r.byProduct.first.qtyMilli, 3000);
      expect(r.byProduct.first.grossProfitUsd, const Money.usd(180));

      expect(r.byCashier.single.salesCount, 3);
      final methods = r.byPaymentMethod.map((p) => p.method).toSet();
      expect(methods, {PaymentMethod.cashCup, PaymentMethod.transfermovil});

      // Arroz quedó en 3 u y cerveza en 3 u, ambos con mínimo 5.
      expect(r.lowStock.map((l) => l.name), ['Arroz', 'Cerveza']);
    });

    test('excluye ventas anuladas y fuera de rango', () async {
      await sell(arroz, 1, day1, PaymentMethod.cashCup);
      await sell(arroz, 1, DateTime(2026, 10, 2), PaymentMethod.cashCup);
      final inRange = await (db.select(
        db.sales,
      )..where((s) => s.createdAt.equalsValue(day1))).getSingle();
      await sales.voidSale(saleId: inRange.id, reason: 'x', userId: userId);

      final r = await reports.build(
        ReportRange.days(DateTime(2026, 11, 13), DateTime(2026, 11, 13), 'x'),
      );
      expect(r.summary.salesCount, 0);
      expect(r.summary.voidedCount, 1);
    });

    test('CSV listo para Excel en español', () async {
      await sell(arroz, 2, day1, PaymentMethod.cashCup);
      final r = await reports.build(
        ReportRange.days(day1, day1, 'x'),
      );
      final csv = ReportCsv.byProduct(r, includeCosts: true);
      expect(csv.startsWith('﻿'), isTrue);
      final lines = csv.substring(1).split('\r\n');
      expect(
        lines.first,
        'Producto;Cantidad;Unidad;Venta USD;Venta CUP;Costo USD;Ganancia USD',
      );
      expect(lines[1], 'Arroz;2;u;4,40;1936,00;3,20;1,20');

      final noCosts = ReportCsv.byProduct(r, includeCosts: false);
      expect(noCosts, isNot(contains('Ganancia')));
    });
  });

  test('CSV escapa separadores y comillas', () {
    final r = SalesReport(
      range: ReportRange.today(DateTime(2026)),
      summary: SalesSummary.empty,
      daily: const [],
      byProduct: const [
        ProductSales(
          productId: 'x',
          name: 'Ron "Santiago"; 700 ml',
          unit: ProductUnit.unit,
          qtyMilli: 1000,
          totalUsd: Money.usd(850),
          totalCup: Money.cup(374000),
          costUsd: Money.usd(600),
        ),
      ],
      byCashier: const [],
      byPaymentMethod: const [],
      lowStock: const [],
    );
    expect(
      ReportCsv.byProduct(r, includeCosts: false),
      contains('"Ron ""Santiago""; 700 ml";1;u;8,50;3740,00'),
    );
  });
}
