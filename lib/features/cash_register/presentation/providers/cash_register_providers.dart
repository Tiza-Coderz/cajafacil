import 'package:cajafacil/core/database/database_providers.dart';
import 'package:cajafacil/features/cash_register/data/cash_register_repository_impl.dart';
import 'package:cajafacil/features/cash_register/domain/entities/cash_session.dart';
import 'package:cajafacil/features/cash_register/domain/repositories/cash_register_repository.dart';
import 'package:cajafacil/features/cash_register/domain/services/cash_reconciliation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cash_register_providers.g.dart';

@Riverpod(keepAlive: true)
CashRegisterRepository cashRegisterRepository(Ref ref) =>
    CashRegisterRepositoryImpl(ref.watch(appDatabaseProvider));

/// Turno abierto (null si la caja está cerrada). El POS lo exige para vender.
@Riverpod(keepAlive: true)
Stream<CashSession?> openCashSession(Ref ref) =>
    ref.watch(cashRegisterRepositoryProvider).watchOpenSession();

@riverpod
Stream<CashSummary> cashSummary(Ref ref, String sessionId) =>
    ref.watch(cashRegisterRepositoryProvider).watchSummary(sessionId);

@riverpod
Stream<List<CashSession>> closedCashSessions(Ref ref, {String? userId}) => ref
    .watch(cashRegisterRepositoryProvider)
    .watchClosedSessions(userId: userId);
