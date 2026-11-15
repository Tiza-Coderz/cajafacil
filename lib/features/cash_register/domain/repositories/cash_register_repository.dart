import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/features/cash_register/domain/entities/cash_session.dart';
import 'package:cajafacil/features/cash_register/domain/services/cash_reconciliation.dart';

class CashSessionAlreadyOpenException implements Exception {
  const CashSessionAlreadyOpenException(this.openedByName);

  final String openedByName;

  @override
  String toString() =>
      'Ya hay una caja abierta por $openedByName. Ciérrela antes de abrir otra.';
}

class CashSessionNotOpenException implements Exception {
  const CashSessionNotOpenException();

  @override
  String toString() => 'La caja no está abierta.';
}

abstract interface class CashRegisterRepository {
  /// Turno abierto en este negocio (solo puede haber uno), o null.
  Stream<CashSession?> watchOpenSession();

  Future<CashSession?> openSession();

  Future<CashSession> open({
    required CurrencyPair opening,
    required String userId,
  });

  Future<void> addMovement({
    required String sessionId,
    required CashMovementType type,
    required Money amount,
    required String reason,
    required String userId,
  });

  /// Resumen en vivo del turno (se actualiza con cada venta o movimiento).
  Stream<CashSummary> watchSummary(String sessionId);

  Future<CashSession> close({
    required String sessionId,
    required CurrencyPair counted,
    required String userId,
    Map<String, Map<int, int>>? countDetail,
    String? note,
  });

  /// Turnos cerrados, más reciente primero. Con [userId] solo los suyos.
  Stream<List<CashSession>> watchClosedSessions({String? userId, int limit});
}
