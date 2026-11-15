import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/core/auth/permissions.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/utils/date_formatter.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/cash_register/presentation/providers/cash_register_providers.dart';
import 'package:cajafacil/features/pos/domain/entities/sale_receipt.dart';
import 'package:cajafacil/features/pos/domain/repositories/sale_repository.dart';
import 'package:cajafacil/features/pos/presentation/providers/cart_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Ventas del turno abierto, con reimpresión y anulación (con permiso).
class SessionSalesScreen extends ConsumerWidget {
  const SessionSalesScreen({super.key});

  Future<void> _void(
    BuildContext context,
    WidgetRef ref,
    SaleReceipt sale,
  ) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Anular ${sale.number}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Motivo',
            hintText: 'Ej.: error al marcar el producto',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Anular venta'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    final user = ref.read(sessionProvider);
    if (reason == null || reason.trim().isEmpty || user == null) return;
    try {
      await ref
          .read(saleRepositoryProvider)
          .voidSale(saleId: sale.id, reason: reason, userId: user.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Venta ${sale.number} anulada. La mercancía volvió al inventario.',
            ),
          ),
        );
      }
    } on SaleNotVoidableException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(openCashSessionProvider).value;
    final canVoid =
        ref.watch(sessionProvider)?.can(Permission.voidSale) ?? false;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ventas del turno')),
        body: const EmptyView(message: 'La caja está cerrada.'),
      );
    }
    final sales = ref.watch(sessionSalesProvider(session.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Ventas del turno')),
      body: sales.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(message: 'No se pudieron cargar.'),
        data: (list) => list.isEmpty
            ? const EmptyView(
                message: 'Aún no hay ventas en este turno.',
                icon: Icons.receipt_long_outlined,
              )
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = list[i];
                  return ListTile(
                    onTap: () => context.push('${Routes.pos}/ticket/${s.id}'),
                    leading: Icon(
                      s.isVoided ? Icons.block : Icons.receipt_outlined,
                      color: s.isVoided ? AppColors.danger : null,
                    ),
                    title: Text(
                      '${s.number} · ${MoneyFormatter.format(s.totalCup)}',
                      style: TextStyle(
                        decoration: s.isVoided
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      [
                        AppDates.time(s.createdAt),
                        s.cashierName,
                        '${s.lines.length} productos',
                        if (s.isVoided) 'Anulada: ${s.voidReason ?? ''}',
                      ].join(' · '),
                    ),
                    trailing: canVoid && !s.isVoided
                        ? IconButton(
                            tooltip: 'Anular venta',
                            icon: const Icon(Icons.undo),
                            onPressed: () => _void(context, ref, s),
                          )
                        : null,
                  );
                },
              ),
      ),
    );
  }
}
