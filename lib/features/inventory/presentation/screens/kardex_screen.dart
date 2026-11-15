import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/utils/date_formatter.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:cajafacil/features/products/presentation/providers/product_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kardex: historial de movimientos de un producto con saldo.
class KardexScreen extends ConsumerWidget {
  const KardexScreen({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId)).value;
    final entries = ref.watch(kardexProvider(productId));
    final unit = product?.unit;

    return Scaffold(
      appBar: AppBar(title: Text(product?.name ?? 'Kardex')),
      body: Column(
        children: [
          if (product != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Gaps.md),
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Text(
                'Existencia actual: ${Qty.format(product.stockMilli, product.unit)}'
                '   ·   Mínimo: ${Qty.format(product.minStockMilli, product.unit)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          Expanded(
            child: entries.when(
              loading: () => const LoadingView(),
              error: (_, _) => const ErrorView(),
              data: (list) => list.isEmpty || unit == null
                  ? const EmptyView(message: 'Sin movimientos.')
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = list[i];
                        final positive = e.qtyDeltaMilli > 0;
                        return ListTile(
                          leading: Icon(
                            positive ? Icons.south_west : Icons.north_east,
                            color: positive
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                          title: Text(e.label),
                          subtitle: Text(
                            [
                              AppDates.relativeDayTime(e.date),
                              e.userName,
                              if (e.note != null) e.note!,
                            ].join(' · '),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${positive ? '+' : ''}'
                                '${Qty.format(e.qtyDeltaMilli, unit)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: positive
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                              ),
                              Text(
                                'Saldo ${Qty.format(e.balanceAfterMilli, unit)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
