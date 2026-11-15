import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/rounding.dart';
import 'package:cajafacil/features/pos/domain/services/sale_calculator.dart';
import 'package:meta/meta.dart';

/// Un pago entregado por el cliente.
@immutable
class Payment {
  const Payment({required this.method, required this.amount, this.reference});

  final PaymentMethod method;
  final Money amount;

  /// Nº de operación de Transfermóvil/EnZona.
  final String? reference;
}

/// Estado del cobro: lo que falta o el vuelto a entregar.
@immutable
class PaymentStatus {
  const PaymentStatus({
    required this.remainingCup,
    required this.remainingUsd,
    required this.change,
    required this.overpaidElectronic,
  });

  /// Lo que falta por pagar, expresado en cada moneda (0 si está pagado).
  final Money remainingCup;
  final Money remainingUsd;

  /// Vuelto a entregar en la moneda elegida (0 si no hay).
  final Money change;

  /// Un pago electrónico supera lo debido: no se da vuelto de una
  /// transferencia, hay que corregir el importe.
  final bool overpaidElectronic;

  bool get isPaid => remainingCup.isZero && remainingUsd.isZero;

  bool get canComplete => isPaid && !overpaidElectronic;
}

/// Cálculo de cobro con pago mixto y vuelto multi-moneda.
///
/// Reglas:
/// 1. Si todo se paga en USD, se compara contra el total en USD (exacto).
///    Si todo se paga en CUP, contra el total en CUP. Si se mezclan, todo
///    se lleva a CUP con la tasa congelada de la venta.
/// 2. El vuelto se entrega en la moneda que elija el cliente y siempre se
///    redondea **hacia abajo** (nunca se entrega de más). En CUP se respeta
///    el redondeo del negocio (ej. múltiplos de 5).
/// 3. Solo el efectivo genera vuelto. Si un pago electrónico ya cubre más
///    de lo debido, se marca para corregirlo.
abstract final class PaymentCalculator {
  static PaymentStatus evaluate({
    required SaleTotals totals,
    required List<Payment> payments,
    required ExchangeRate rate,
    required Currency changeCurrency,
    required CupRounding rounding,
  }) {
    // Sin pagos, lo que falta es exactamente el total de cada moneda (no
    // una conversión, que podría diferir por precios fijos o redondeos).
    if (payments.isEmpty) {
      return PaymentStatus(
        remainingCup: totals.totalCup,
        remainingUsd: totals.totalUsd,
        change: Money.zero(changeCurrency),
        overpaidElectronic: false,
      );
    }
    final currencies = payments.map((p) => p.amount.currency).toSet();
    final settleIn = currencies.length == 1 && currencies.first == Currency.usd
        ? Currency.usd
        : Currency.cup;
    final due = settleIn == Currency.usd ? totals.totalUsd : totals.totalCup;

    Money toSettle(Money m) => rate.convert(m, settleIn);
    final paid = payments
        .map((p) => toSettle(p.amount))
        .fold(Money.zero(settleIn), (a, b) => a + b);
    final electronicPaid = payments
        .where((p) => !p.method.isCash)
        .map((p) => toSettle(p.amount))
        .fold(Money.zero(settleIn), (a, b) => a + b);

    final balance = paid - due;
    if (balance.isNegative) {
      // Lo que falta en CUP se calcula SIEMPRE en CUP: el siguiente pago en
      // CUP hará la venta mixta y se liquidará en CUP. Convertir el saldo en
      // USD daría otra cifra cuando los totales no son conversión exacta.
      final paidAsCup = payments
          .map((p) => rate.toCup(p.amount))
          .fold(const Money.cup(0), (a, b) => a + b);
      var remainingCup = totals.totalCup - paidAsCup;
      if (!remainingCup.isPositive) {
        // Solo pasa si en USD aún falta un centavo: pedir el mínimo en CUP.
        remainingCup = const Money.cup(1);
      }
      // En USD: exacto si todo se pagó en USD; si no, hacia arriba para
      // no cobrar de menos.
      final remainingUsd = settleIn == Currency.usd
          ? -balance
          : Money.usd(_ceilDiv(-balance.cents * 100, rate.cupPerUsdX100));
      return PaymentStatus(
        remainingCup: remainingCup.roundUpCup(rounding),
        remainingUsd: remainingUsd,
        change: Money.zero(changeCurrency),
        overpaidElectronic: false,
      );
    }

    return PaymentStatus(
      remainingCup: const Money.cup(0),
      remainingUsd: const Money.usd(0),
      change: _change(balance, changeCurrency, rate, rounding),
      overpaidElectronic: electronicPaid > due,
    );
  }

  static Money _change(
    Money balance,
    Currency changeCurrency,
    ExchangeRate rate,
    CupRounding rounding,
  ) {
    if (balance.isZero) return Money.zero(changeCurrency);
    if (changeCurrency == Currency.cup) {
      final cup = balance.currency == Currency.cup
          ? balance
          : Money.cup(balance.cents * rate.cupPerUsdX100 ~/ 100);
      return cup.floorCup(rounding);
    }
    // Vuelto en USD: centavos hacia abajo.
    return balance.currency == Currency.usd
        ? balance
        : Money.usd(balance.cents * 100 ~/ rate.cupPerUsdX100);
  }

  static int _ceilDiv(int a, int b) => a % b == 0 ? a ~/ b : a ~/ b + 1;

  /// Importe sugerido para pagar exacto lo que falta en [currency].
  static Money exactAmount(PaymentStatus status, Currency currency) =>
      currency == Currency.usd ? status.remainingUsd : status.remainingCup;

  /// Billetes redondos sugeridos (ej. faltan 970 → 1 000, 2 000).
  static List<Money> quickCashSuggestions(Money remaining) {
    if (!remaining.isPositive) return const [];
    final steps = remaining.currency == Currency.cup
        ? const [100, 500, 1000, 2000, 5000]
        : const [1, 5, 10, 20, 50, 100];
    final result = <Money>[];
    for (final step in steps) {
      final stepCents = step * 100;
      // Primer múltiplo del billete que supera lo que falta.
      final candidate = Money(
        _ceilDiv(remaining.cents, stepCents) * stepCents,
        remaining.currency,
      );
      if (candidate > remaining && !result.contains(candidate)) {
        result.add(candidate);
      }
      if (result.length == 3) break;
    }
    return result;
  }
}

extension on Money {
  /// Redondea hacia arriba al múltiplo de CUP (para "lo que falta").
  Money roundUpCup(CupRounding rounding) {
    if (currency != Currency.cup || rounding == CupRounding.none) return this;
    final step = rounding.stepCents;
    return Money(((cents + step - 1) ~/ step) * step, currency);
  }
}
