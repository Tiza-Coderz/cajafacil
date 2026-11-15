import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:meta/meta.dart';

/// Importes por moneda (USD y CUP) que se manejan juntos en caja.
@immutable
class CurrencyPair {
  CurrencyPair({required this.usd, required this.cup}) {
    if (usd.currency != Currency.usd || cup.currency != Currency.cup) {
      throw ArgumentError(
        'CurrencyPair espera (USD, CUP), recibió ($usd, $cup)',
      );
    }
  }

  const CurrencyPair.zero()
    : usd = const Money.usd(0),
      cup = const Money.cup(0);

  final Money usd;
  final Money cup;

  Money of(Currency currency) => currency == Currency.usd ? usd : cup;

  CurrencyPair add(Money money) => money.currency == Currency.usd
      ? CurrencyPair(usd: usd + money, cup: cup)
      : CurrencyPair(usd: usd, cup: cup + money);

  CurrencyPair operator +(CurrencyPair other) =>
      CurrencyPair(usd: usd + other.usd, cup: cup + other.cup);

  CurrencyPair operator -(CurrencyPair other) =>
      CurrencyPair(usd: usd - other.usd, cup: cup - other.cup);

  bool get isZero => usd.isZero && cup.isZero;

  @override
  bool operator ==(Object other) =>
      other is CurrencyPair && other.usd == usd && other.cup == cup;

  @override
  int get hashCode => Object.hash(usd, cup);

  @override
  String toString() => '($usd, $cup)';
}

/// Un pago registrado en una venta (para el cuadre).
@immutable
class PaymentLine {
  const PaymentLine(this.method, this.amount);

  final PaymentMethod method;
  final Money amount;
}

/// Entrada o salida manual de efectivo durante el turno.
@immutable
class CashMovementLine {
  const CashMovementLine(this.type, this.amount);

  final CashMovementType type;
  final Money amount;
}

/// Resumen de un turno de caja y el efectivo que debería haber.
@immutable
class CashSummary {
  const CashSummary({
    required this.opening,
    required this.cashSales,
    required this.changeGiven,
    required this.cashIn,
    required this.cashOut,
    required this.electronicByMethod,
    required this.salesCount,
  });

  final CurrencyPair opening;

  /// Efectivo recibido de clientes (antes de dar vuelto).
  final CurrencyPair cashSales;

  /// Vuelto entregado, por moneda.
  final CurrencyPair changeGiven;
  final CurrencyPair cashIn;
  final CurrencyPair cashOut;

  /// Transferencia, Transfermóvil y EnZona: no están en la gaveta.
  final Map<PaymentMethod, CurrencyPair> electronicByMethod;
  final int salesCount;

  /// Efectivo que debería haber en la gaveta.
  CurrencyPair get expected =>
      opening + cashSales - changeGiven + cashIn - cashOut;

  /// Efectivo neto vendido (recibido menos vuelto).
  CurrencyPair get netCashSales => cashSales - changeGiven;
}

/// Lógica de cuadre de caja. Dart puro: sin BD ni Flutter.
abstract final class CashReconciliation {
  /// Construye el resumen a partir de pagos, vueltos y movimientos de
  /// ventas **no anuladas** del turno.
  static CashSummary summarize({
    required CurrencyPair opening,
    required Iterable<PaymentLine> payments,
    required Iterable<Money> changes,
    required Iterable<CashMovementLine> movements,
    required int salesCount,
  }) {
    var cashSales = const CurrencyPair.zero();
    final electronic = <PaymentMethod, CurrencyPair>{};
    for (final p in payments) {
      if (p.method.isCash) {
        cashSales = cashSales.add(p.amount);
      } else {
        electronic[p.method] =
            (electronic[p.method] ?? const CurrencyPair.zero()).add(p.amount);
      }
    }

    var changeGiven = const CurrencyPair.zero();
    for (final c in changes) {
      changeGiven = changeGiven.add(c);
    }

    var cashIn = const CurrencyPair.zero();
    var cashOut = const CurrencyPair.zero();
    for (final m in movements) {
      if (m.type == CashMovementType.cashIn) {
        cashIn = cashIn.add(m.amount);
      } else {
        cashOut = cashOut.add(m.amount);
      }
    }

    return CashSummary(
      opening: opening,
      cashSales: cashSales,
      changeGiven: changeGiven,
      cashIn: cashIn,
      cashOut: cashOut,
      electronicByMethod: electronic,
      salesCount: salesCount,
    );
  }

  /// Diferencia contado − esperado (negativa = faltante).
  static CurrencyPair difference({
    required CurrencyPair counted,
    required CurrencyPair expected,
  }) => counted - expected;
}

/// Denominaciones en circulación para el conteo por billetes.
abstract final class Denominations {
  /// Billetes y monedas de peso cubano en uso (en pesos).
  static const cup = [1000, 500, 200, 100, 50, 20, 10, 5, 3, 1];

  /// Billetes de dólar (en dólares).
  static const usd = [100, 50, 20, 10, 5, 2, 1];

  static List<int> of(Currency currency) =>
      currency == Currency.usd ? usd : cup;

  /// Total de un conteo `{denominación: cantidad}`.
  static Money total(Currency currency, Map<int, int> counts) {
    var cents = 0;
    counts.forEach((denomination, count) {
      if (count < 0) {
        throw ArgumentError.value(count, 'count', 'no puede ser negativo');
      }
      cents += denomination * 100 * count;
    });
    return Money(cents, currency);
  }
}
