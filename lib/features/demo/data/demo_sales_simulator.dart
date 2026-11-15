import 'dart:math';

import 'package:cajafacil/core/database/app_database.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/rounding.dart';
import 'package:cajafacil/features/cash_register/domain/repositories/cash_register_repository.dart';
import 'package:cajafacil/features/cash_register/domain/services/cash_reconciliation.dart';
import 'package:cajafacil/features/demo/data/demo_catalog.dart';
import 'package:cajafacil/features/inventory/domain/entities/inventory_entities.dart';
import 'package:cajafacil/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:cajafacil/features/pos/domain/entities/cart_line.dart';
import 'package:cajafacil/features/pos/domain/repositories/sale_repository.dart';
import 'package:cajafacil/features/pos/domain/services/payment_calculator.dart';
import 'package:cajafacil/features/pos/domain/services/sale_calculator.dart';
import 'package:cajafacil/features/products/domain/entities/product.dart';
import 'package:drift/drift.dart';

/// Venta planificada (por índice de producto del catálogo demo).
class _PlannedSale {
  _PlannedSale(this.at, this.lines, this.method);

  final DateTime at;
  final List<(int productIndex, int qtyMilli)> lines;
  final PaymentMethod method;

  /// La anulación devuelve la mercancía: no cuenta como salida neta.
  bool voided = false;
}

class _PlannedPurchase {
  _PlannedPurchase(this.at, this.supplier, this.lines);

  final DateTime at;
  final String supplier;
  final List<(int productIndex, int qtyMilli)> lines;
}

/// Genera ~2 semanas de actividad realista para que los reportes y el
/// historial de caja de la demo se vean llenos.
///
/// Funciona en dos fases:
/// 1. [plan] decide en memoria qué se vende y se compra cada día. Con eso
///    el seeder calcula la existencia inicial necesaria para que, al final,
///    cada producto quede con la existencia "actual" del catálogo (y los de
///    bajo stock sigan apareciendo así).
/// 2. [execute] registra todo con los repositorios reales (ventas, kardex,
///    turnos de caja, entradas), con fechas pasadas.
class DemoSalesSimulator {
  DemoSalesSimulator({required DateTime now, int seed = 42})
    : _now = now,
      _random = Random(seed);

  final DateTime _now;
  final Random _random;
  static const days = 14;

  late final List<_PlannedSale> _sales;
  late final List<_PlannedPurchase> _purchases;

  /// Cantidad neta que el plan saca del inventario por producto
  /// (ventas − entradas), en milésimas.
  final Map<int, int> netOutflowMilli = {};

  DateTime get startDay => DateTime(
    _now.year,
    _now.month,
    _now.day,
  ).subtract(const Duration(days: days - 1));

  /// Popularidad relativa: lo que más se mueve en una bodega de barrio.
  static int _weight(DemoProduct p) {
    final n = p.name.toLowerCase();
    if (n.contains('cerveza') && n.contains('lata')) return 12;
    if (n.contains('malta')) return 9;
    if (n.contains('refresco de cola')) return 8;
    if (n.contains('muslo de pollo')) return 8;
    if (n.startsWith('arroz')) return 7;
    if (n.contains('huevos') || n.contains('aceite')) return 5;
    if (n.contains('picadillo') || n.contains('salchichas')) return 4;
    if (n.contains('frijoles') || n.contains('azúcar') || n.contains('café')) {
      return 4;
    }
    if (n.contains('ron')) return 3;
    if (n.contains('caja')) return 1;
    return 2;
  }

  void plan() {
    const catalog = DemoCatalog.products;
    final weights = [for (final p in catalog) _weight(p)];
    final totalWeight = weights.fold(0, (a, b) => a + b);
    int pickProduct() {
      var r = _random.nextInt(totalWeight);
      for (var i = 0; i < weights.length; i++) {
        r -= weights[i];
        if (r < 0) return i;
      }
      return weights.length - 1;
    }

    int qtyFor(DemoProduct p) {
      if (p.unit.allowsFraction) return (1 + _random.nextInt(6)) * 500;
      final n = p.name.toLowerCase();
      if (n.contains('lata') || n.contains('malta')) {
        return (1 + _random.nextInt(6)) * 1000;
      }
      return (1 + (_random.nextDouble() < 0.75 ? 0 : _random.nextInt(3))) *
          1000;
    }

    PaymentMethod pickMethod() {
      final r = _random.nextInt(100);
      if (r < 50) return PaymentMethod.cashCup;
      if (r < 72) return PaymentMethod.transfermovil;
      if (r < 84) return PaymentMethod.cashUsd;
      if (r < 94) return PaymentMethod.enzona;
      return PaymentMethod.transfer;
    }

    _sales = [];
    for (var d = 0; d < days; d++) {
      final day = startDay.add(Duration(days: d));
      final weekend =
          day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
      final count = weekend
          ? 32 + _random.nextInt(11)
          : 22 + _random.nextInt(9);
      final times = [
        for (var i = 0; i < count; i++)
          day.add(Duration(minutes: 8 * 60 + 30 + _random.nextInt(11 * 60))),
      ]..sort();
      for (final at in times) {
        if (!at.isBefore(_now)) continue;
        final lineCount =
            1 + _random.nextInt(_random.nextDouble() < 0.3 ? 4 : 2);
        final lines = <int, int>{};
        for (var l = 0; l < lineCount; l++) {
          final i = pickProduct();
          lines[i] = (lines[i] ?? 0) + qtyFor(catalog[i]);
        }
        _sales.add(
          _PlannedSale(at, [
            for (final e in lines.entries) (e.key, e.value),
          ], pickMethod()),
        );
      }
    }

    // Dos reposiciones durante el período (lo más vendido).
    int idx(String name) => catalog.indexWhere((p) => p.name == name);
    _purchases = [
      _PlannedPurchase(
        startDay.add(const Duration(days: 4, hours: 9)),
        'Cervecería Bucanero (distribuidor)',
        [
          (idx('Cerveza Cristal (lata)'), 96000),
          (idx('Cerveza Bucanero (lata)'), 72000),
          (idx('Malta Bucanero 355 ml'), 48000),
        ],
      ),
      _PlannedPurchase(
        startDay.add(const Duration(days: 9, hours: 10)),
        'Distribuidora Habana Sur',
        [
          (idx('Muslo de pollo'), 80000),
          (idx('Arroz 1 kg'), 40000),
          (idx('Huevos (cartón de 30)'), 10000),
          (idx('Aceite de soya 1 L'), 24000),
        ],
      ),
    ];

    // Se anula la primera venta de hace dos días (cliente que devuelve).
    final voidDay = startDay.add(const Duration(days: days - 3));
    final toVoid = _sales
        .where(
          (s) =>
              !s.at.isBefore(voidDay) &&
              s.at.isBefore(voidDay.add(const Duration(days: 1))),
        )
        .firstOrNull;
    toVoid?.voided = true;

    for (final s in _sales.where((s) => !s.voided)) {
      for (final (i, q) in s.lines) {
        netOutflowMilli[i] = (netOutflowMilli[i] ?? 0) + q;
      }
    }
    for (final p in _purchases) {
      for (final (i, q) in p.lines) {
        netOutflowMilli[i] = (netOutflowMilli[i] ?? 0) - q;
      }
    }
  }

  /// Existencia inicial para que al final quede la del catálogo. Si las
  /// entradas superan lo vendido, se evita arrancar en negativo.
  int initialStockMilli(int index, int finalStockMilli) {
    final initial = finalStockMilli + (netOutflowMilli[index] ?? 0);
    return initial < 0 ? 0 : initial;
  }

  Future<void> execute({
    required AppDatabase db,
    required List<Product> products,
    required SaleRepository sales,
    required CashRegisterRepository cash,
    required InventoryRepository inventory,
    required List<int> rateHistory,
    required String cashierId,
    required String managerId,
    required String ownerId,
    void Function(int day, int total)? onProgress,
  }) async {
    final byName = {for (final p in products) p.name: p};
    Product productAt(int i) => byName[DemoCatalog.products[i].name]!;

    final suppliers = <String, String>{};
    for (final name in [
      'Cervecería Bucanero (distribuidor)',
      'Distribuidora Habana Sur',
      'Mipyme Granos La Lisa',
    ]) {
      suppliers[name] = (await inventory.createSupplier(
        name: name,
        phone: '+53 5${_random.nextInt(9000000) + 1000000}',
      )).id;
    }

    for (var d = 0; d < days; d++) {
      onProgress?.call(d + 1, days);
      final stop = await db.transaction(
        () => _executeDay(
          d: d,
          db: db,
          sales: sales,
          cash: cash,
          inventory: inventory,
          rateHistory: rateHistory,
          cashierId: cashierId,
          managerId: managerId,
          suppliers: suppliers,
          productAt: productAt,
        ),
      );
      if (stop) break;
    }
  }

  int _purchaseIndex = 0;

  /// Registra un día; devuelve true si hay que detenerse (hoy o futuro).
  Future<bool> _executeDay({
    required int d,
    required AppDatabase db,
    required SaleRepository sales,
    required CashRegisterRepository cash,
    required InventoryRepository inventory,
    required List<int> rateHistory,
    required String cashierId,
    required String managerId,
    required Map<String, String> suppliers,
    required Product Function(int) productAt,
  }) async {
    final day = startDay.add(Duration(days: d));
    final isToday = d == days - 1;
    final rate = ExchangeRate.units(
      rateHistory[(rateHistory.length - days + d).clamp(
        0,
        rateHistory.length - 1,
      )],
    );

    // Turno del día: Yamilé los lunes, Yoandry el resto.
    final opener = day.weekday == DateTime.monday ? managerId : cashierId;
    final sessionId = db.ids.newId();
    final openedAt = day.add(const Duration(hours: 8));
    if (openedAt.isAfter(_now)) return true;
    await db.writeSynced(
      db.cashSessions,
      CashSessionRow(
        id: sessionId,
        createdAt: openedAt,
        updatedAt: openedAt,
        deviceId: await db.deviceId(),
        openedBy: opener,
        openedAt: openedAt,
        openingUsdCents: 2000,
        openingCupCents: 300000,
        status: CashSessionStatus.open,
      ),
      entityId: sessionId,
    );

    while (_purchaseIndex < _purchases.length &&
        _purchases[_purchaseIndex].at.isBefore(
          day.add(const Duration(days: 1)),
        )) {
      final p = _purchases[_purchaseIndex++];
      await inventory.registerPurchase(
        PurchaseDraft(
          supplierId: suppliers[p.supplier],
          invoiceRef: 'F-${1040 + _purchaseIndex}',
          date: p.at,
          items: [
            for (final (i, q) in p.lines)
              PurchaseItemDraft(
                productId: productAt(i).id,
                productName: productAt(i).name,
                unit: productAt(i).unit,
                qtyMilli: q,
                unitCostUsd: productAt(i).costUsd,
              ),
          ],
        ),
        userId: managerId,
      );
    }

    for (final s in _sales.where(
      (s) =>
          !s.at.isBefore(day) &&
          s.at.isBefore(day.add(const Duration(days: 1))),
    )) {
      final id = await _sell(s, sales, sessionId, opener, rate, productAt);
      if (s.voided) {
        await sales.voidSale(
          saleId: id,
          reason: 'Cliente devolvió la mercancía',
          userId: managerId,
        );
      }
    }

    if (d.isEven) {
      await cash.addMovement(
        sessionId: sessionId,
        type: CashMovementType.cashOut,
        amount: const Money.cup(120000),
        reason: 'Pago del pan al proveedor',
        userId: opener,
      );
    }

    if (isToday) return true; // El turno de hoy queda abierto.

    final summary = await cash.watchSummary(sessionId).first;
    final expected = summary.expected;
    // Casi siempre cuadra; algunos días hay pequeñas diferencias.
    final counted = switch (d) {
      3 => CurrencyPair(
        usd: expected.usd,
        cup: expected.cup - const Money.cup(5000),
      ),
      8 => CurrencyPair(
        usd: expected.usd,
        cup: expected.cup + const Money.cup(2000),
      ),
      _ => expected,
    };
    await cash.close(
      sessionId: sessionId,
      counted: counted,
      userId: opener,
      note: d == 3 ? 'Faltan 50 CUP, posible error en un vuelto' : null,
    );
    final closedAt = day.add(const Duration(hours: 20, minutes: 15));
    await (db.update(
      db.cashSessions,
    )..where((s) => s.id.equals(sessionId))).write(
      CashSessionsCompanion(
        closedAt: Value(closedAt),
        updatedAt: Value(closedAt),
      ),
    );
    return false;
  }

  Future<String> _sell(
    _PlannedSale s,
    SaleRepository sales,
    String sessionId,
    String cashierId,
    ExchangeRate rate,
    Product Function(int) productAt,
  ) async {
    final lines = [
      for (final (i, q) in s.lines)
        () {
          final p = productAt(i);
          return CartLine(
            productId: p.id,
            name: p.name,
            unit: p.unit,
            qtyMilli: q,
            unitPriceUsd: p.priceUsd,
            unitPriceCup: p.priceCup(rate, CupRounding.five)!,
            unitCostUsd: p.costUsd,
          );
        }(),
    ];
    final totals = SaleCalculator.totals(
      lines: lines,
      rate: rate,
      rounding: CupRounding.five,
    );

    // Lo que entrega el cliente: billetes redondos en efectivo, exacto en
    // pagos electrónicos; a veces mixto (USD + resto en CUP).
    final payments = switch (s.method) {
      PaymentMethod.cashUsd when _random.nextDouble() < 0.3 => [
        const Payment(method: PaymentMethod.cashUsd, amount: Money.usd(500)),
      ],
      PaymentMethod.cashUsd => [
        Payment(
          method: PaymentMethod.cashUsd,
          amount: _roundUp(totals.totalUsd, _random.nextBool() ? 100 : 500),
        ),
      ],
      PaymentMethod.cashCup => [
        Payment(
          method: PaymentMethod.cashCup,
          amount: _roundUp(totals.totalCup, _random.nextBool() ? 10000 : 50000),
        ),
      ],
      final method => [
        Payment(
          method: method,
          amount: totals.totalCup,
          reference: method == PaymentMethod.cashCup
              ? null
              : 'TX${100000 + _random.nextInt(899999)}',
        ),
      ],
    };
    var status = PaymentCalculator.evaluate(
      totals: totals,
      payments: payments,
      rate: rate,
      changeCurrency: Currency.cup,
      rounding: CupRounding.five,
    );
    if (!status.isPaid) {
      // Pago mixto: completa en CUP lo que faltó.
      payments.add(
        Payment(
          method: PaymentMethod.cashCup,
          amount: _roundUp(status.remainingCup, 10000),
        ),
      );
      status = PaymentCalculator.evaluate(
        totals: totals,
        payments: payments,
        rate: rate,
        changeCurrency: Currency.cup,
        rounding: CupRounding.five,
      );
    }
    final receipt = await sales.completeSale(
      CompleteSaleCommand(
        sessionId: sessionId,
        cashierId: cashierId,
        rate: rate,
        lines: lines,
        totals: totals,
        payments: payments,
        changeCurrency: Currency.cup,
        change: status.change,
        createdAt: s.at,
      ),
    );
    return receipt.id;
  }

  static Money _roundUp(Money m, int stepCents) => Money(
    ((m.cents + stepCents - 1) ~/ stepCents) * stepCents,
    m.currency,
  );
}
