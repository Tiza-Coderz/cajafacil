import 'package:cajafacil/core/database/database_providers.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/features/cash_register/presentation/providers/cash_register_providers.dart';
import 'package:cajafacil/features/pos/data/sale_repository_impl.dart';
import 'package:cajafacil/features/pos/domain/entities/cart_line.dart';
import 'package:cajafacil/features/pos/domain/entities/discount.dart';
import 'package:cajafacil/features/pos/domain/entities/sale_receipt.dart';
import 'package:cajafacil/features/pos/domain/repositories/sale_repository.dart';
import 'package:cajafacil/features/pos/domain/services/payment_calculator.dart';
import 'package:cajafacil/features/pos/domain/services/sale_calculator.dart';
import 'package:cajafacil/features/products/domain/entities/product.dart';
import 'package:cajafacil/features/products/presentation/providers/product_providers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cart_controller.freezed.dart';
part 'cart_controller.g.dart';

@Riverpod(keepAlive: true)
SaleRepository saleRepository(Ref ref) => SaleRepositoryImpl(
  ref.watch(appDatabaseProvider),
  ref.watch(stockLedgerProvider),
);

@freezed
abstract class CartState with _$CartState {
  const factory CartState({
    @Default([]) List<CartLine> lines,
    @Default([]) List<Payment> payments,
    @Default(Currency.cup) Currency changeCurrency,
    Discount? globalDiscount,
  }) = _CartState;

  const CartState._();

  int get itemCount => lines.length;
}

/// Venta en curso. Vive mientras la app esté abierta para no perder el
/// carrito al navegar.
@Riverpod(keepAlive: true)
class Cart extends _$Cart {
  @override
  CartState build() => const CartState();

  /// Añade un producto (o suma 1 si ya está). Devuelve false si no hay
  /// precio en CUP (falta la tasa del día).
  bool add(Product product, {int? qtyMilli}) {
    final pricing = ref.read(pricingContextProvider);
    final priceCup = pricing.cupFor(product);
    if (priceCup == null) return false;
    final qty = qtyMilli ?? Qty.one;
    final index = state.lines.indexWhere((l) => l.productId == product.id);
    if (index >= 0) {
      final line = state.lines[index];
      _replace(index, line.copyWith(qtyMilli: line.qtyMilli + qty));
    } else {
      state = state.copyWith(
        lines: [
          ...state.lines,
          CartLine(
            productId: product.id,
            name: product.name,
            unit: product.unit,
            qtyMilli: qty,
            unitPriceUsd: product.priceUsd,
            unitPriceCup: priceCup,
            unitCostUsd: product.costUsd,
          ),
        ],
      );
    }
    return true;
  }

  void setQty(int index, int qtyMilli) {
    if (qtyMilli <= 0) {
      remove(index);
    } else {
      _replace(index, state.lines[index].copyWith(qtyMilli: qtyMilli));
    }
  }

  void remove(int index) {
    final lines = [...state.lines]..removeAt(index);
    state = state.copyWith(lines: lines);
  }

  void setLineDiscount(int index, Discount? discount) => _replace(
    index,
    state.lines[index].copyWith(
      discount: (discount?.isNone ?? true) ? null : discount,
    ),
  );

  void setGlobalDiscount(Discount? discount) => state = state.copyWith(
    globalDiscount: (discount?.isNone ?? true) ? null : discount,
  );

  void addPayment(Payment payment) =>
      state = state.copyWith(payments: [...state.payments, payment]);

  void removePayment(int index) => state = state.copyWith(
    payments: [...state.payments]..removeAt(index),
  );

  void clearPayments() => state = state.copyWith(payments: const []);

  void setChangeCurrency(Currency currency) =>
      state = state.copyWith(changeCurrency: currency);

  void clear() => state = const CartState();

  void _replace(int index, CartLine line) {
    final lines = [...state.lines];
    lines[index] = line;
    state = state.copyWith(lines: lines);
  }

  /// Registra la venta y vacía el carrito. Lanza si no se puede cobrar.
  Future<SaleReceipt> checkout({required String cashierId}) async {
    final session = ref.read(openCashSessionProvider).value;
    final rate = ref.read(pricingContextProvider).rate;
    final totals = ref.read(cartTotalsProvider);
    final status = ref.read(paymentStatusProvider);
    if (session == null) throw StateError('La caja no está abierta.');
    if (rate == null || totals == null || status == null) {
      throw StateError('Falta la tasa del día.');
    }
    if (!status.canComplete) throw StateError('El cobro no está completo.');

    final receipt = await ref
        .read(saleRepositoryProvider)
        .completeSale(
          CompleteSaleCommand(
            sessionId: session.id,
            cashierId: cashierId,
            rate: rate,
            lines: state.lines,
            totals: totals,
            payments: state.payments,
            changeCurrency: state.changeCurrency,
            change: status.change,
            globalDiscount: state.globalDiscount,
          ),
        );
    clear();
    return receipt;
  }
}

/// Totales del carrito; null si aún no hay tasa del día.
@riverpod
SaleTotals? cartTotals(Ref ref) {
  final cart = ref.watch(cartProvider);
  final pricing = ref.watch(pricingContextProvider);
  final rate = pricing.rate;
  if (rate == null) return null;
  return SaleCalculator.totals(
    lines: cart.lines,
    rate: rate,
    rounding: pricing.rounding,
    globalDiscount: cart.globalDiscount,
  );
}

@riverpod
PaymentStatus? paymentStatus(Ref ref) {
  final cart = ref.watch(cartProvider);
  final totals = ref.watch(cartTotalsProvider);
  final pricing = ref.watch(pricingContextProvider);
  final rate = pricing.rate;
  if (totals == null || rate == null) return null;
  return PaymentCalculator.evaluate(
    totals: totals,
    payments: cart.payments,
    rate: rate,
    changeCurrency: cart.changeCurrency,
    rounding: pricing.rounding,
  );
}

@riverpod
Stream<List<SaleReceipt>> sessionSales(Ref ref, String sessionId) =>
    ref.watch(saleRepositoryProvider).watchSessionSales(sessionId);

@riverpod
Future<SaleReceipt?> saleReceipt(Ref ref, String saleId) =>
    ref.watch(saleRepositoryProvider).receipt(saleId);
