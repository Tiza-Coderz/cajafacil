import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/inventory/domain/entities/inventory_entities.dart';
import 'package:cajafacil/features/inventory/domain/services/inventory_rules.dart';
import 'package:cajafacil/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:cajafacil/features/products/presentation/widgets/product_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entrada de mercancía: proveedor, factura y líneas con cantidad y costo.
class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _items = <PurchaseItemDraft>[];
  final _invoice = TextEditingController();
  final _note = TextEditingController();
  String? _supplierId;
  bool _saving = false;

  @override
  void dispose() {
    _invoice.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final product = await pickProduct(context);
    if (product == null || !mounted) return;
    final item = await showDialog<PurchaseItemDraft>(
      context: context,
      builder: (_) => _ItemDialog(
        draft: PurchaseItemDraft(
          productId: product.id,
          productName: product.name,
          unit: product.unit,
          qtyMilli: 0,
          unitCostUsd: product.costUsd,
        ),
      ),
    );
    if (item != null) setState(() => _items.add(item));
  }

  Future<void> _newSupplier() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo proveedor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: Gaps.md),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if ((ok ?? false) && name.text.trim().isNotEmpty) {
      final s = await ref
          .read(inventoryRepositoryProvider)
          .createSupplier(name: name.text, phone: phone.text);
      setState(() => _supplierId = s.id);
    }
    name.dispose();
    phone.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(sessionProvider);
    if (user == null || _items.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .registerPurchase(
            PurchaseDraft(
              items: List.of(_items),
              supplierId: _supplierId,
              invoiceRef: _invoice.text,
              note: _note.text,
            ),
            userId: user.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Entrada registrada. Existencias y costos actualizados.',
          ),
        ),
      );
      Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo registrar la entrada.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider);
    final total = InventoryRules.purchaseTotal(
      _items.map((i) => (i.qtyMilli, i.unitCostUsd)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Entrada de mercancía')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Producto'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gaps.md),
          child: FilledButton.icon(
            onPressed: _items.isEmpty || _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text('Registrar · ${MoneyFormatter.format(total)}'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.md, Gaps.md, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: suppliers.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text('Error al cargar proveedores'),
                  data: (list) => DropdownButtonFormField<String?>(
                    value: _supplierId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Proveedor'),
                    items: [
                      const DropdownMenuItem(child: Text('Sin proveedor')),
                      for (final s in list)
                        DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setState(() => _supplierId = v),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Nuevo proveedor',
                icon: const Icon(Icons.person_add_alt),
                onPressed: _newSupplier,
              ),
            ],
          ),
          const SizedBox(height: Gaps.md),
          TextField(
            controller: _invoice,
            decoration: const InputDecoration(
              labelText: 'Nº de factura o vale (opcional)',
            ),
          ),
          const SizedBox(height: Gaps.md),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Nota (opcional)'),
          ),
          const SizedBox(height: Gaps.lg),
          if (_items.isEmpty)
            const EmptyView(
              message: 'Añada los productos recibidos con el botón "Producto".',
              icon: Icons.add_box_outlined,
            )
          else
            Card(
              child: Column(
                children: [
                  for (final (i, item) in _items.indexed)
                    ListTile(
                      title: Text(item.productName),
                      subtitle: Text(
                        '${Qty.format(item.qtyMilli, item.unit)} × '
                        '${MoneyFormatter.format(item.unitCostUsd)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            MoneyFormatter.format(
                              item.unitCostUsd.timesQty(item.qtyMilli),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Quitar',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _items.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.draft});

  final PurchaseItemDraft draft;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final _qty = TextEditingController();
  late final _cost = TextEditingController(
    text: (widget.draft.unitCostUsd.cents / 100).toStringAsFixed(2),
  );
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    _cost.dispose();
    super.dispose();
  }

  void _submit() {
    final unit = widget.draft.unit;
    final qty = Qty.parse(_qty.text, allowFraction: unit.allowsFraction);
    final cost = Money.tryParse(_cost.text, Currency.usd);
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Cantidad no válida');
      return;
    }
    if (cost == null || cost.isNegative) {
      setState(() => _error = 'Costo no válido');
      return;
    }
    Navigator.pop(
      context,
      widget.draft.copyWith(qtyMilli: qty, unitCostUsd: cost),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.draft.productName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _qty,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Cantidad recibida',
              suffixText: widget.draft.unit.symbol,
            ),
          ),
          const SizedBox(height: Gaps.md),
          TextField(
            controller: _cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Costo unitario',
              suffixText: 'USD',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Añadir')),
      ],
    );
  }
}
