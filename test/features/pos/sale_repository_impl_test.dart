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
import 'package:cajafacil/features/cash_register/domain/repositories/cash_register_repository.dart';
import 'package:cajafacil/features/cash_register/domain/services/cash_reconciliation.dart';
import 'package:cajafacil/features/pos/data/sale_repository_impl.dart';
import 'package:cajafacil/features/pos/domain/entities/cart_line.dart';
import 'package:cajafacil/features/pos/domain/repositories/sale_repository.dart';
import 'package:cajafacil/features/pos/domain/services/payment_calculator.dart';
import 'package:cajafacil/features/pos/domain/services/receipt_formatter.dart';
import 'package:cajafacil/features/pos/domain/services/sale_calculator.dart';
import 'package:cajafacil/features/products/data/product_repository_impl.dart';
import 'package:cajafacil/features/products/domain/entities/product.dart';
import 'package:cajafacil/features/products/domain/entities/product_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SaleRepositoryImpl sales;
  late CashRegisterRepositoryImpl cash;
  late ProductRepositoryImpl products;
  late String userId;
  late Product arroz;
  final rate = ExchangeRate.units(440);

  setUpAll(() => initializeDateFormatting('es'));

  setUp(() async {
    db = createTestDatabase();
    final ledger = StockLedger(db);
    sales = SaleRepositoryImpl(db, ledger);
    cash = CashRegisterRepositoryImpl(db);
    products = ProductRepositoryImpl(db, ledger);
    userId = (await AuthRepositoryImpl(
      db,
      hasher: const SecretHasher(iterations: 1),
    ).createUser(name: 'Yoandry', role: UserRole.cashier, pin: '3333')).id;
    arroz = await products.save(
      const ProductDraft(
        name: 'Arroz 1 kg',
        unit: ProductUnit.pack,
        costUsd: Money.usd(160),
        priceUsd: Money.usd(220),
        cupPriceMode: CupPriceMode.auto,
        minStockMilli: 0,
        initialStockMilli: 10000,
      ),
      userId: userId,
    );
  });
  tearDown(() => db.close());

  CompleteSaleCommand command(String sessionId, {int qty = 2000}) {
    final lines = [
      CartLine(
        productId: arroz.id,
        name: arroz.name,
        unit: arroz.unit,
        qtyMilli: qty,
        unitPriceUsd: arroz.priceUsd,
        unitPriceCup: const Money.cup(97000),
        unitCostUsd: arroz.costUsd,
      ),
    ];
    final totals = SaleCalculator.totals(
      lines: lines,
      rate: rate,
      rounding: CupRounding.five,
    );
    return CompleteSaleCommand(
      sessionId: sessionId,
      cashierId: userId,
      rate: rate,
      lines: lines,
      totals: totals,
      payments: const [
        Payment(method: PaymentMethod.cashCup, amount: Money.cup(200000)),
      ],
      changeCurrency: Currency.cup,
      change: const Money.cup(6000),
    );
  }

  Future<String> openSession() async => (await cash.open(
    opening: CurrencyPair(usd: const Money.usd(0), cup: const Money.cup(0)),
    userId: userId,
  )).id;

  test('registra venta, líneas, pagos y descuenta el stock', () async {
    final sessionId = await openSession();
    final r = await sales.completeSale(command(sessionId));

    expect(r.totalCup, const Money.cup(194000));
    expect(r.lines.single.totalCup, const Money.cup(194000));
    expect(r.payments.single.method, PaymentMethod.cashCup);
    expect(r.change, const Money.cup(6000));
    expect((await products.getById(arroz.id))!.stockMilli, 8000);

    final moves = await (db.select(
      db.stockMovements,
    )..where((m) => m.type.equalsValue(StockMovementType.sale))).get();
    expect(moves.single.refId, r.id);
    expect(moves.single.qtyDeltaMilli, -2000);
  });

  test('numera las ventas de forma correlativa', () async {
    final sessionId = await openSession();
    final a = await sales.completeSale(command(sessionId, qty: 1000));
    final b = await sales.completeSale(command(sessionId, qty: 1000));
    expect(a.number, endsWith('-000001'));
    expect(b.number, endsWith('-000002'));
  });

  test('no vende con la caja cerrada', () async {
    final sessionId = await openSession();
    await cash.close(
      sessionId: sessionId,
      counted: CurrencyPair(usd: const Money.usd(0), cup: const Money.cup(0)),
      userId: userId,
    );
    await expectLater(
      sales.completeSale(command(sessionId)),
      throwsA(isA<CashSessionNotOpenException>()),
    );
    expect((await products.getById(arroz.id))!.stockMilli, 10000);
  });

  test('anular devuelve el stock y saca la venta del cuadre', () async {
    final sessionId = await openSession();
    final r = await sales.completeSale(command(sessionId));
    await sales.voidSale(saleId: r.id, reason: 'Error', userId: userId);

    final voided = await sales.receipt(r.id);
    expect(voided!.isVoided, isTrue);
    expect(voided.voidReason, 'Error');
    expect((await products.getById(arroz.id))!.stockMilli, 10000);

    final summary = await cash.watchSummary(sessionId).first;
    expect(summary.salesCount, 0);
    expect(summary.expected.cup, const Money.cup(0));
  });

  test('no se anula dos veces ni fuera del turno abierto', () async {
    final sessionId = await openSession();
    final r = await sales.completeSale(command(sessionId));
    await sales.voidSale(saleId: r.id, reason: 'x', userId: userId);
    await expectLater(
      sales.voidSale(saleId: r.id, reason: 'x', userId: userId),
      throwsA(isA<SaleNotVoidableException>()),
    );

    final r2 = await sales.completeSale(command(sessionId, qty: 1000));
    await cash.close(
      sessionId: sessionId,
      counted: CurrencyPair(usd: const Money.usd(0), cup: const Money.cup(0)),
      userId: userId,
    );
    await expectLater(
      sales.voidSale(saleId: r2.id, reason: 'x', userId: userId),
      throwsA(isA<SaleNotVoidableException>()),
    );
  });

  test('el cuadre de caja refleja el vuelto entregado', () async {
    final sessionId = await openSession();
    await sales.completeSale(command(sessionId));
    final summary = await cash.watchSummary(sessionId).first;
    // Recibió 2 000 CUP y dio 60 de vuelto.
    expect(summary.expected.cup, const Money.cup(194000));
  });

  test('el ticket en texto incluye negocio, líneas, total y vuelto', () async {
    final sessionId = await openSession();
    final r = await sales.completeSale(command(sessionId));
    final text = ReceiptFormatter.plainText(
      r,
      const ReceiptHeader(
        businessName: 'Mini-mercado La Esquina',
        nit: '01234567890',
        footer: '¡Gracias!',
      ),
    );
    expect(text, contains('*Mini-mercado La Esquina*'));
    expect(text, contains('NIT: 01234567890'));
    expect(text, contains('Arroz 1 kg'));
    expect(text, contains('2 paq x 970 CUP'));
    expect(text, contains('TOTAL: 1 940 CUP'));
    expect(text, contains('Vuelto: 60 CUP'));
    expect(text, endsWith('¡Gracias!'));
  });
}
