import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/features/cash_register/domain/services/cash_reconciliation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cash_session.freezed.dart';

/// Turno de caja: desde la apertura con fondo hasta el cierre con conteo.
@freezed
abstract class CashSession with _$CashSession {
  const factory CashSession({
    required String id,
    required String openedById,
    required String openedByName,
    required DateTime openedAt,
    required CurrencyPair opening,
    required CashSessionStatus status,
    String? closedByName,
    DateTime? closedAt,
    CurrencyPair? expected,
    CurrencyPair? counted,
    CurrencyPair? difference,
    String? note,
  }) = _CashSession;

  const CashSession._();

  bool get isOpen => status == CashSessionStatus.open;

  /// Cuadrada si no hay diferencia en ninguna moneda.
  bool get isBalanced => difference?.isZero ?? false;
}
