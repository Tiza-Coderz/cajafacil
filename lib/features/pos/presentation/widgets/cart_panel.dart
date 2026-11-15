import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/pos/presentation/providers/cart_controller.dart';
import 'package:cajafacil/features/pos/presentation/widgets/pos_dialogs.dart';
import 'package:cajafacil/features/products/presentation/providers/product_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Carrito con cantidades, descuentos y total. Se usa como panel lateral
/// en pantallas anchas y como página propia en el móvil.
class CartPanel extends ConsumerWidget {
  const CartPanel({required this.onCheckout, super.key});

  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final totals = ref.watch(cartTotalsProvider);
    final rate = ref.watch(pricingContextProvider).rate;
    final notifier = ref.read(cartProvider.notifier);
    final text = Theme.of(context).textTheme;

    if (cart.lines.isEmpty) {
      return const EmptyView(
        message: 'El carrito está vacío.\nToque un producto para añadirlo.',
        icon: Icons.shopping_cart_outlined,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: cart.lines.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final line = cart.lines[i];
              final lt = totals?.lines[i];
              return Dismissible(
                key: ValueKey('${line.productId}-$i'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: AppColors.danger,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: Gaps.md),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => notifier.remove(i),
                child: ListTile(
                  title: Text(line.name, maxLines: 2),
                  subtitle: Text(
                    [
                      '${MoneyFormatter.format(line.unitPriceCup)} c/u',
                      if (line.discount != null)
                        'Desc. ${line.discount!.describe()}',
                    ].join(' · '),
                  ),
                  onLongPress: rate == null
                      ? null
                      : () async {
                          final choice = await askDiscount(
                            context,
                            title: 'Descuento: ${line.name}',
                            rate: rate,
                            current: line.discount,
                          );
                          if (choice != null) {
                            notifier.setLineDiscount(i, choice.discount);
                          }
                        },
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        lt == null ? '' : MoneyFormatter.format(lt.totalCup),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      _QtyStepper(
                        label: Qty.format(line.qtyMilli, line.unit),
                        onMinus: () =>
                            notifier.setQty(i, line.qtyMilli - Qty.one),
                        onPlus: () =>
                            notifier.setQty(i, line.qtyMilli + Qty.one),
                        onTapLabel: () async {
                          final qty = await askQuantity(
                            context,
                            productName: line.name,
                            unit: line.unit,
                            initialMilli: line.qtyMilli,
                          );
                          if (qty != null) notifier.setQty(i, qty);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Material(
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Gaps.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (totals != null && totals.globalDiscountCup.isPositive)
                    Row(
                      children: [
                        Text(
                          'Descuento ${cart.globalDiscount!.describe()}',
                        ),
                        const Spacer(),
                        Text(
                          '-${MoneyFormatter.format(totals.globalDiscountCup)}',
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      Text('Total', style: text.titleLarge),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            totals == null
                                ? '—'
                                : MoneyFormatter.format(totals.totalCup),
                            style: text.titleLarge?.copyWith(
                              color: AppColors.cup,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (totals != null)
                            Text(
                              MoneyFormatter.format(totals.totalUsd),
                              style: text.bodyMedium?.copyWith(
                                color: AppColors.usd,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: Gaps.sm),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Vaciar carrito',
                        icon: const Icon(Icons.remove_shopping_cart_outlined),
                        onPressed: () => _confirmClear(context, notifier),
                      ),
                      IconButton(
                        tooltip: 'Descuento al total',
                        icon: const Icon(Icons.percent),
                        onPressed: rate == null
                            ? null
                            : () async {
                                final choice = await askDiscount(
                                  context,
                                  title: 'Descuento al total',
                                  rate: rate,
                                  current: cart.globalDiscount,
                                );
                                if (choice != null) {
                                  notifier.setGlobalDiscount(choice.discount);
                                }
                              },
                      ),
                      const SizedBox(width: Gaps.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: totals == null ? null : onCheckout,
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Cobrar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context, Cart notifier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Vaciar el carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (ok ?? false) notifier.clear();
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.label,
    required this.onMinus,
    required this.onPlus,
    required this.onTapLabel,
  });

  final String label;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onTapLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Quitar uno',
          icon: const Icon(Icons.remove, size: 18),
          onPressed: onMinus,
        ),
        InkWell(
          onTap: onTapLabel,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(label),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Añadir uno',
          icon: const Icon(Icons.add, size: 18),
          onPressed: onPlus,
        ),
      ],
    );
  }
}
