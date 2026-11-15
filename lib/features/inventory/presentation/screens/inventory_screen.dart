import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/utils/date_formatter.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:cajafacil/features/products/presentation/widgets/product_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Centro de inventario: acciones rápidas y últimas entradas.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(purchasesProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(Gaps.md),
            children: [
              Wrap(
                spacing: Gaps.md,
                runSpacing: Gaps.md,
                children: [
                  _Action(
                    icon: Icons.local_shipping_outlined,
                    title: 'Entrada de mercancía',
                    subtitle: 'Compra a proveedor',
                    onTap: () => context.push('${Routes.inventory}/entrada'),
                  ),
                  _Action(
                    icon: Icons.tune,
                    title: 'Ajuste',
                    subtitle: 'Merma, rotura, consumo, robo o conteo',
                    onTap: () => context.push('${Routes.inventory}/ajuste'),
                  ),
                  _Action(
                    icon: Icons.list_alt,
                    title: 'Kardex',
                    subtitle: 'Movimientos de un producto',
                    onTap: () async {
                      final product = await pickProduct(context);
                      if (product != null && context.mounted) {
                        await context.push(
                          '${Routes.inventory}/kardex/${product.id}',
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: Gaps.lg),
              Text('Últimas entradas', style: text.titleMedium),
              const SizedBox(height: Gaps.sm),
              purchases.when(
                loading: () => const LoadingView(),
                error: (_, _) => const ErrorView(),
                data: (list) => list.isEmpty
                    ? const EmptyView(
                        message: 'Todavía no hay entradas registradas.',
                        icon: Icons.inventory_2_outlined,
                      )
                    : Card(
                        child: Column(
                          children: [
                            for (final p in list)
                              ListTile(
                                leading: const Icon(
                                  Icons.local_shipping_outlined,
                                ),
                                title: Text(p.supplierName ?? 'Sin proveedor'),
                                subtitle: Text(
                                  [
                                    AppDates.relativeDayTime(p.date),
                                    '${p.itemCount} productos',
                                    if (p.invoiceRef != null)
                                      'Fact. ${p.invoiceRef}',
                                    p.userName,
                                  ].join(' · '),
                                ),
                                trailing: Text(
                                  MoneyFormatter.format(p.totalCostUsd),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Gaps.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: Gaps.sm),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
