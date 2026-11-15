import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/core/widgets/barcode_scanner_screen.dart';
import 'package:cajafacil/core/widgets/product_avatar.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/products/domain/entities/product.dart';
import 'package:cajafacil/features/products/domain/repositories/product_repository.dart';
import 'package:cajafacil/features/products/presentation/providers/product_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hoja inferior para elegir un producto (buscar o escanear).
Future<Product?> pickProduct(BuildContext context) =>
    showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: _ProductPicker(),
      ),
    );

class _ProductPicker extends ConsumerStatefulWidget {
  const _ProductPicker();

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  String _query = '';

  Future<void> _scan() async {
    final code = await BarcodeScannerScreen.open(context);
    if (code == null || !mounted) return;
    final product = await ref
        .read(productRepositoryProvider)
        .findByBarcode(code);
    if (!mounted) return;
    if (product != null) {
      Navigator.pop(context, product);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay productos con el código $code.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider(ProductFilter(query: _query)));
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final byId = {for (final c in categories) c.id: c};
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Buscar producto o código',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              IconButton(
                tooltip: 'Escanear',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scan,
              ),
            ],
          ),
        ),
        const SizedBox(height: Gaps.sm),
        Expanded(
          child: products.when(
            loading: () => const LoadingView(),
            error: (_, _) => const ErrorView(),
            data: (list) => list.isEmpty
                ? const EmptyView(message: 'Sin resultados.')
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final p = list[i];
                      final c = byId[p.categoryId];
                      return ListTile(
                        leading: ProductAvatar(
                          photo: p.photo,
                          iconKey: c?.iconKey,
                          color: c?.color,
                          size: 40,
                        ),
                        title: Text(p.name),
                        subtitle: Text(
                          'Stock: ${Qty.format(p.stockMilli, p.unit)}',
                        ),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
