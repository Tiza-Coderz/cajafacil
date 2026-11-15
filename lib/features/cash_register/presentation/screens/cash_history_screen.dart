import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/auth/permissions.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/utils/date_formatter.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/cash_register/domain/entities/cash_session.dart';
import 'package:cajafacil/features/cash_register/presentation/providers/cash_register_providers.dart';
import 'package:cajafacil/features/cash_register/presentation/widgets/cash_summary_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cierres anteriores. El cajero solo ve los suyos.
class CashHistoryScreen extends ConsumerWidget {
  const CashHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    final seeAll = user?.can(Permission.viewAllCashSessions) ?? false;
    final sessions = ref.watch(
      closedCashSessionsProvider(userId: seeAll ? null : user?.id),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de cierres')),
      body: sessions.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            const ErrorView(message: 'No se pudo cargar el historial.'),
        data: (list) => list.isEmpty
            ? const EmptyView(
                message: 'Todavía no hay cierres de caja.',
                icon: Icons.history,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(Gaps.md),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: Gaps.sm),
                itemBuilder: (context, i) => _SessionCard(session: list[i]),
              ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final CashSession session;

  @override
  Widget build(BuildContext context) {
    final diff = session.difference;
    final counted = session.counted;
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        leading: Icon(
          session.isBalanced ? Icons.check_circle : Icons.error_outline,
          color: session.isBalanced ? Colors.green : Colors.orange,
        ),
        title: Text(
          AppDates.relativeDayTime(session.closedAt ?? session.openedAt),
        ),
        subtitle: Text(
          'Abrió ${session.openedByName} · Cerró ${session.closedByName ?? '—'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          Gaps.md,
          0,
          Gaps.md,
          Gaps.md,
        ),
        children: [
          if (counted != null && diff != null) ...[
            _line('Contado CUP', MoneyFormatter.format(counted.cup)),
            _diffLine('Diferencia CUP', DifferenceText(difference: diff.cup)),
            _line('Contado USD', MoneyFormatter.format(counted.usd)),
            _diffLine('Diferencia USD', DifferenceText(difference: diff.usd)),
          ],
          if (session.note != null) ...[
            const SizedBox(height: Gaps.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Nota: ${session.note}'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );

  Widget _diffLine(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        value,
      ],
    ),
  );
}
