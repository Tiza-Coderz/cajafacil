import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/core/widgets/barcode_scanner_screen.dart';
import 'package:cajafacil/core/widgets/product_avatar.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/cash_register/presentation/providers/cash_register_providers.dart';
import 'package:cajafacil/features/pos/presentation/providers/cart_controller.dart';
import 'package:cajafacil/features/pos/presentation/widgets/cart_panel.dart';
import 'package:cajafacil/features/pos/presentation/widgets/pos_dialogs.dart';
import 'package:cajafacil/features/products/domain/entities/product.dart';
import 'package:cajafacil/features/products/domain/repositories/product_repository.dart';
import 'package:cajafacil/features/products/presentation/providers/product_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Punto de venta. Exige caja abierta y tasa del día.
class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  static const wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(openCashSessionProvider);
    final pricing = ref.watch(pricingContextProvider);

    Widget body;
    if (session.isLoading) {
      body = const LoadingView();
    } else if (session.value == null) {
      body = EmptyView(
        icon: Icons.lock_outline,
        message: 'Para vender, primero abra la caja.',
        action: FilledButton.icon(
          onPressed: () => context.push(Routes.cashRegister),
          icon: const Icon(Icons.lock_open),
          label: const Text('Abrir caja'),
        ),
      );
    } else if (pricing.rate == null) {
      body = const EmptyView(
        icon: Icons.currency_exchange,
        message:
            'Falta la tasa del día.\nPida al encargado que la fije en '
            '"Tasa de cambio".',
      );
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) {
          void checkout() => context.push('${Routes.pos}/cobrar');
          if (constraints.maxWidth >= wideBreakpoint) {
            return Row(
              children: [
                const Expanded(child: _ProductPicker()),
                const VerticalDivider(width: 1),
                SizedBox(width: 400, child: CartPanel(onCheckout: checkout)),
              ],
            );
          }
          return Column(
            children: [
              const Expanded(child: _ProductPicker()),
              _CartBar(onOpen: () => context.push('${Routes.pos}/carrito')),
            ],
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vender'),
        actions: [
          if (session.value != null)
            IconButton(
              tooltip: 'Ventas del turno',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => context.push('${Routes.pos}/ventas'),
            ),
        ],
      ),
      body: body,
    );
  }
}

class _ProductPicker extends ConsumerStatefulWidget {
  const _ProductPicker();

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add(Product product) async {
    int? qty;
    if (product.unit.allowsFraction) {
      qty = await askQuantity(
        context,
        productName: product.name,
        unit: product.unit,
      );
      if (qty == null) return;
    }
    final added = ref.read(cartProvider.notifier).add(product, qtyMilli: qty);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (!added) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Falta la tasa del día.')),
      );
    } else if (product.isOutOfStock) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Atención: "${product.name}" figura sin existencia.'),
        ),
      );
    }
  }

  Future<void> _scan() async {
    final code = await BarcodeScannerScreen.open(context);
    if (code == null || !mounted) return;
    final product = await ref
        .read(productRepositoryProvider)
        .findByBarcode(code);
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay productos con el código $code.')),
      );
      return;
    }
    await _add(product);
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider(ProductFilter(query: _query)));
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final byId = {for (final c in categories) c.id: c};
    final pricing = ref.watch(pricingContextProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Gaps.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Buscar producto o código',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: (v) async {
                    // Lectores de código USB/Bluetooth escriben y pulsan Enter.
                    final product = await ref
                        .read(productRepositoryProvider)
                        .findByBarcode(v);
                    if (product != null) {
                      await _add(product);
                      _search.clear();
                      setState(() => _query = '');
                    }
                  },
                ),
              ),
              const SizedBox(width: Gaps.sm),
              IconButton.filledTonal(
                tooltip: 'Escanear código',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scan,
              ),
            ],
          ),
        ),
        Expanded(
          child: products.when(
            loading: () => const LoadingView(),
            error: (_, _) => const ErrorView(
              message: 'No se pudieron cargar los productos.',
            ),
            data: (list) => list.isEmpty
                ? const EmptyView(
                    message: 'Sin resultados.',
                    icon: Icons.search_off,
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Gaps.md,
                      0,
                      Gaps.md,
                      Gaps.md,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisExtent: 172,
                          crossAxisSpacing: Gaps.sm,
                          mainAxisSpacing: Gaps.sm,
                        ),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final p = list[i];
                      final category = byId[p.categoryId];
                      final cup = pricing.cupFor(p);
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _add(p),
                          child: Padding(
                            padding: const EdgeInsets.all(Gaps.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ProductAvatar(
                                  photo: p.photo,
                                  iconKey: category?.iconKey,
                                  color: category?.color,
                                  size: 40,
                                ),
                                const SizedBox(height: Gaps.xs),
                                Expanded(
                                  child: Text(
                                    p.name,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  cup == null
                                      ? '—'
                                      : MoneyFormatter.format(cup),
                                  style: const TextStyle(
                                    color: AppColors.cup,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${MoneyFormatter.format(p.priceUsd)} · '
                                  '${Qty.format(p.stockMilli, p.unit)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: p.isLowStock
                                            ? AppColors.warning
                                            : null,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _CartBar extends ConsumerWidget {
  const _CartBar({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final totals = ref.watch(cartTotalsProvider);
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.primary,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: cart.lines.isEmpty ? null : onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gaps.md,
              vertical: Gaps.md,
            ),
            child: Row(
              children: [
                Badge(
                  label: Text('${cart.itemCount}'),
                  isLabelVisible: cart.itemCount > 0,
                  child: const Icon(Icons.shopping_cart, color: Colors.white),
                ),
                const SizedBox(width: Gaps.md),
                Expanded(
                  child: Text(
                    cart.lines.isEmpty
                        ? 'Carrito vacío'
                        : '${MoneyFormatter.format(totals!.totalCup)} · '
                              '${MoneyFormatter.format(totals.totalUsd)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (cart.lines.isNotEmpty)
                  const Text(
                    'Ver carrito',
                    style: TextStyle(color: Colors.white),
                  ),
                if (cart.lines.isNotEmpty)
                  const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carrito a pantalla completa (móvil).
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carrito')),
      body: CartPanel(
        onCheckout: () => context.pushReplacement('${Routes.pos}/cobrar'),
      ),
    );
  }
}
