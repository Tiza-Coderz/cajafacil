import 'dart:typed_data';

import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/utils/image_compressor.dart'
    deferred as compressor;
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/core/widgets/barcode_scanner_screen.dart';
import 'package:cajafacil/core/widgets/product_avatar.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/products/domain/entities/product.dart';
import 'package:cajafacil/features/products/domain/entities/product_draft.dart';
import 'package:cajafacil/features/products/domain/repositories/product_repository.dart';
import 'package:cajafacil/features/products/domain/services/product_pricing.dart';
import 'package:cajafacil/features/products/presentation/providers/product_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Alta y edición de productos. Si [productId] es null, crea uno nuevo.
class ProductFormScreen extends ConsumerWidget {
  const ProductFormScreen({this.productId, this.initialBarcode, super.key});

  final String? productId;
  final String? initialBarcode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = productId;
    if (id == null) {
      return _ProductForm(initialBarcode: initialBarcode);
    }
    final product = ref.watch(productProvider(id));
    return product.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (_, _) => const Scaffold(
        body: ErrorView(message: 'No se pudo cargar el producto.'),
      ),
      data: (p) => p == null
          ? const Scaffold(
              body: EmptyView(message: 'El producto ya no existe.'),
            )
          : _ProductForm(product: p),
    );
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({this.product, this.initialBarcode});

  final Product? product;
  final String? initialBarcode;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _cost;
  late final TextEditingController _price;
  late final TextEditingController _cup;
  late final TextEditingController _initialStock;
  late final TextEditingController _minStock;

  late ProductUnit _unit;
  late CupPriceMode _mode;
  late bool _active;
  String? _categoryId;
  Uint8List? _photo;
  Map<ProductField, String> _errors = const {};
  bool _saving = false;

  bool get _isNew => widget.product == null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    String money(Money? m) => m == null
        ? ''
        : MoneyFormatter.format(
            m,
            withCode: false,
            decimals: true,
          ).replaceAll(' ', '');
    _name = TextEditingController(text: p?.name ?? '');
    _barcode = TextEditingController(
      text: p?.barcode ?? widget.initialBarcode ?? '',
    );
    _cost = TextEditingController(text: money(p?.costUsd));
    _price = TextEditingController(text: money(p?.priceUsd));
    _cup = TextEditingController(text: money(p?.manualPriceCup));
    _initialStock = TextEditingController();
    _minStock = TextEditingController(
      text: p == null ? '' : Qty.formatNumber(p.minStockMilli),
    );
    _unit = p?.unit ?? ProductUnit.unit;
    _mode = p?.cupPriceMode ?? CupPriceMode.auto;
    _active = p?.active ?? true;
    _categoryId = p?.categoryId;
    _photo = p?.photo;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _barcode,
      _cost,
      _price,
      _cup,
      _initialStock,
      _minStock,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Money _usd(TextEditingController c) =>
      Money.tryParse(c.text, Currency.usd) ?? const Money.usd(-1);

  int _qty(TextEditingController c) => c.text.trim().isEmpty
      ? 0
      : Qty.parse(c.text, allowFraction: _unit.allowsFraction) ?? -1;

  ProductDraft _draft() => ProductDraft(
    id: widget.product?.id,
    name: _name.text,
    unit: _unit,
    costUsd: _cost.text.trim().isEmpty ? const Money.usd(0) : _usd(_cost),
    priceUsd: _usd(_price),
    cupPriceMode: _mode,
    manualPriceCup: Money.tryParse(_cup.text, Currency.cup),
    minStockMilli: _qty(_minStock),
    initialStockMilli: _isNew ? _qty(_initialStock) : 0,
    categoryId: _categoryId,
    barcode: _barcode.text,
    photo: _photo,
    active: _active,
  );

  Future<void> _save() async {
    final draft = _draft();
    final errors = ProductValidator.validate(draft);
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    final user = ref.read(sessionProvider);
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(productRepositoryProvider).save(draft, userId: user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isNew ? 'Producto creado.' : 'Cambios guardados.'),
        ),
      );
      Navigator.of(context).pop();
    } on DuplicateBarcodeException catch (e) {
      setState(() => _errors = {ProductField.barcode: e.toString()});
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar. Intente de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Quitar foto'),
                onTap: () {
                  setState(() => _photo = null);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    await compressor.loadLibrary();
    final thumb = compressor.ImageCompressor.thumbnail(
      await file.readAsBytes(),
    );
    if (!mounted) return;
    if (thumb == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer la imagen.')),
      );
      return;
    }
    setState(() => _photo = thumb);
  }

  Future<void> _scanBarcode() async {
    final code = await BarcodeScannerScreen.open(context);
    if (code != null) setState(() => _barcode.text = code);
  }

  Future<void> _newCategory() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().isEmpty) return;
    final category = await ref
        .read(productRepositoryProvider)
        .createCategory(name);
    setState(() => _categoryId = category.id);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final pricing = ref.watch(pricingContextProvider);
    final price = Money.tryParse(_price.text, Currency.usd);
    final cost = Money.tryParse(_cost.text, Currency.usd) ?? const Money.usd(0);
    final margin = price == null || !price.isPositive
        ? null
        : ProductPricing.marginBasisPoints(cost: cost, price: price) / 100;
    final autoCup = price == null
        ? null
        : ProductPricing.cupPrice(
            priceUsd: price,
            mode: CupPriceMode.auto,
            rate: pricing.rate,
            rounding: pricing.rounding,
          );
    final selectedCategory = categories
        .where((c) => c.id == _categoryId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nuevo producto' : 'Editar producto'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gaps.md),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isNew ? 'Crear producto' : 'Guardar cambios'),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(Gaps.md),
            children: [
              Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      ProductAvatar(
                        photo: _photo,
                        iconKey: selectedCategory?.iconKey,
                        color: selectedCategory?.color,
                        size: 96,
                      ),
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 14,
                          child: Icon(Icons.photo_camera, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Gaps.md),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nombre *',
                  hintText: 'Ej.: Arroz 1 kg',
                  errorText: _errors[ProductField.name],
                ),
              ),
              const SizedBox(height: Gaps.md),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: [
                        const DropdownMenuItem(child: Text('Sin categoría')),
                        for (final c in categories)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Nueva categoría',
                    icon: const Icon(Icons.add),
                    onPressed: _newCategory,
                  ),
                ],
              ),
              const SizedBox(height: Gaps.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _barcode,
                      decoration: InputDecoration(
                        labelText: 'Código de barras',
                        errorText: _errors[ProductField.barcode],
                        suffixIcon: IconButton(
                          tooltip: 'Escanear',
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: _scanBarcode,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Gaps.md),
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<ProductUnit>(
                      value: _unit,
                      decoration: const InputDecoration(labelText: 'Unidad'),
                      items: [
                        for (final u in ProductUnit.values)
                          DropdownMenuItem(value: u, child: Text(u.label)),
                      ],
                      onChanged: (v) => setState(() => _unit = v ?? _unit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gaps.lg),
              Text('Precios', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Gaps.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _MoneyField(
                      controller: _cost,
                      label: 'Costo',
                      currency: Currency.usd,
                      error: _errors[ProductField.costUsd],
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: Gaps.md),
                  Expanded(
                    child: _MoneyField(
                      controller: _price,
                      label: 'Precio de venta *',
                      currency: Currency.usd,
                      error: _errors[ProductField.priceUsd],
                      helper: margin == null
                          ? null
                          : 'Margen: ${margin.toStringAsFixed(1)} %',
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gaps.md),
              SegmentedButton<CupPriceMode>(
                segments: [
                  for (final m in CupPriceMode.values)
                    ButtonSegment(value: m, label: Text(m.label)),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: Gaps.sm),
              if (_mode == CupPriceMode.auto)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.currency_exchange),
                  title: Text(
                    autoCup == null
                        ? (pricing.rate == null
                              ? 'Fije la tasa del día para calcular el precio en CUP'
                              : 'Escriba el precio en USD')
                        : 'Precio en CUP: ${MoneyFormatter.format(autoCup)}',
                  ),
                  subtitle: const Text('Se recalcula al cambiar la tasa'),
                )
              else
                _MoneyField(
                  controller: _cup,
                  label: 'Precio fijo en CUP *',
                  currency: Currency.cup,
                  error: _errors[ProductField.manualPriceCup],
                ),
              const SizedBox(height: Gaps.lg),
              Text(
                'Existencias',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Gaps.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isNew) ...[
                    Expanded(
                      child: TextField(
                        controller: _initialStock,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Existencia inicial',
                          suffixText: _unit.symbol,
                          errorText: _errors[ProductField.stock],
                        ),
                      ),
                    ),
                    const SizedBox(width: Gaps.md),
                  ],
                  Expanded(
                    child: TextField(
                      controller: _minStock,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Stock mínimo',
                        suffixText: _unit.symbol,
                        helperText: 'Avisa cuando quede poco',
                        errorText: _isNew ? null : _errors[ProductField.stock],
                      ),
                    ),
                  ),
                ],
              ),
              if (!_isNew) ...[
                const SizedBox(height: Gaps.sm),
                Text(
                  'Existencia actual: '
                  '${Qty.format(widget.product!.stockMilli, widget.product!.unit)}. '
                  'Para cambiarla use Inventario (entradas o ajustes).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.push(
                      '${Routes.inventory}/kardex/${widget.product!.id}',
                    ),
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Ver kardex'),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Producto activo'),
                  subtitle: const Text('Los inactivos no aparecen en el POS'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.controller,
    required this.label,
    required this.currency,
    this.error,
    this.helper,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final Currency currency;
  final String? error;
  final String? helper;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: currency.code,
        errorText: error,
        helperText: helper,
      ),
      onChanged: (_) => onChanged?.call(),
    );
  }
}
