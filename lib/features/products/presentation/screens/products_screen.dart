import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/widgets/barcode_scanner_screen.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/products/domain/repositories/product_repository.dart';
import 'package:cajafacil/features/products/presentation/providers/product_providers.dart';
import 'package:cajafacil/features/products/presentation/widgets/product_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _search = TextEditingController();
  ProductFilter _filter = const ProductFilter(includeInactive: true);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _update(ProductFilter filter) => setState(() => _filter = filter);

  ProductFilter _copy({
    String? query,
    String? categoryId,
    bool clearCategory = false,
    bool? lowStockOnly,
  }) => ProductFilter(
    query: query ?? _filter.query,
    categoryId: clearCategory ? null : (categoryId ?? _filter.categoryId),
    lowStockOnly: lowStockOnly ?? _filter.lowStockOnly,
    includeInactive: true,
  );

  Future<void> _scan() async {
    final code = await BarcodeScannerScreen.open(context);
    if (code == null || !mounted) return;
    final product = await ref
        .read(productRepositoryProvider)
        .findByBarcode(code);
    if (!mounted) return;
    if (product != null) {
      await context.push('${Routes.products}/${product.id}');
    } else {
      final create = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código no registrado'),
          content: Text(
            'No hay productos con el código $code. ¿Desea crearlo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Crear producto'),
            ),
          ],
        ),
      );
      if ((create ?? false) && mounted) {
        await context.push('${Routes.products}/nuevo?codigo=$code');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider(_filter));
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final pricing = ref.watch(pricingContextProvider);
    final categoryById = {for (final c in categories) c.id: c};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            tooltip: 'Buscar por código de barras',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scan,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('${Routes.products}/nuevo'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.md, Gaps.md, 0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o código',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _update(_copy(query: ''));
                        },
                      ),
              ),
              onChanged: (value) => _update(_copy(query: value)),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: Gaps.md,
                vertical: Gaps.sm,
              ),
              children: [
                FilterChip(
                  label: const Text('Bajo stock'),
                  avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                  selected: _filter.lowStockOnly,
                  onSelected: (v) => _update(_copy(lowStockOnly: v)),
                ),
                const SizedBox(width: Gaps.sm),
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _filter.categoryId == null,
                  onSelected: (_) => _update(_copy(clearCategory: true)),
                ),
                for (final c in categories) ...[
                  const SizedBox(width: Gaps.sm),
                  ChoiceChip(
                    label: Text(c.name),
                    selected: _filter.categoryId == c.id,
                    onSelected: (_) => _update(_copy(categoryId: c.id)),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: products.when(
              loading: () => const LoadingView(),
              error: (_, _) => ErrorView(
                message: 'No se pudieron cargar los productos.',
                onRetry: () => ref.invalidate(productsProvider(_filter)),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyView(
                      message: 'No hay productos que coincidan.',
                      icon: Icons.search_off,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = list[i];
                        return ProductTile(
                          product: p,
                          category: categoryById[p.categoryId],
                          priceCup: pricing.cupFor(p),
                          onTap: () =>
                              context.push('${Routes.products}/${p.id}'),
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
