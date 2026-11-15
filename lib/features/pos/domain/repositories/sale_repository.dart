import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/features/pos/domain/entities/cart_line.dart';
import 'package:cajafacil/features/pos/domain/entities/discount.dart';
import 'package:cajafacil/features/pos/domain/entities/sale_receipt.dart';
import 'package:cajafacil/features/pos/domain/services/payment_calculator.dart';
import 'package:cajafacil/features/pos/domain/services/sale_calculator.dart';
import 'package:meta/meta.dart';

/// Datos necesarios para registrar una venta cobrada.
@immutable
class CompleteSaleCommand {
  const CompleteSaleCommand({
    required this.sessionId,
    required this.cashierId,
    required this.rate,
    required this.lines,
    required this.totals,
    required this.payments,
    required this.changeCurrency,
    required this.change,
    this.globalDiscount,
    this.createdAt,
  });

  final String sessionId;
  final String cashierId;
  final ExchangeRate rate;
  final List<CartLine> lines;
  final SaleTotals totals;
  final List<Payment> payments;
  final Currency changeCurrency;
  final Money change;
  final Discount? globalDiscount;

  /// Solo para el seed de ventas históricas; normalmente es "ahora".
  final DateTime? createdAt;
}

class SaleNotVoidableException implements Exception {
  const SaleNotVoidableException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class SaleRepository {
  /// Registra venta, líneas, pagos y descuenta existencias en una sola
  /// transacción.
  Future<SaleReceipt> completeSale(CompleteSaleCommand command);

  /// Anula una venta del turno abierto y devuelve la mercancía al stock.
  Future<void> voidSale({
    required String saleId,
    required String reason,
    required String userId,
  });

  Future<SaleReceipt?> receipt(String saleId);

  /// Ventas del turno, más reciente primero.
  Stream<List<SaleReceipt>> watchSessionSales(String sessionId);
}
