import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/inventory/domain/services/inventory_rules.dart';
import 'package:cajafacil/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:cajafacil/features/products/domain/entities/product.dart';
import 'package:cajafacil/features/products/presentation/widgets/product_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ajuste de inventario con motivo y vista previa de la nueva existencia.
class AdjustmentScreen extends ConsumerStatefulWidget {
  const AdjustmentScreen({super.key});

  @override
  ConsumerState<AdjustmentScreen> createState() => _AdjustmentScreenState();
}

class _AdjustmentScreenState extends ConsumerState<AdjustmentScreen> {
  Product? _product;
  AdjustmentReason _reason = AdjustmentReason.waste;
  final _qty = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _quantity {
    final p = _product;
    if (p == null) return null;
    return Qty.parse(_qty.text, allowFraction: p.unit.allowsFraction);
  }

  Future<void> _save() async {
    final p = _product;
    final qty = _quantity;
    final user = ref.read(sessionProvider);
    if (p == null || qty == null || user == null) return;
    setState(() => _saving = true);
    final newStock = await ref
        .read(inventoryRepositoryProvider)
        .adjust(
          productId: p.id,
          reason: _reason,
          quantityMilli: qty,
          userId: user.id,
          note: _note.text,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ajuste registrado. Existencia de ${p.name}: '
          '${Qty.format(newStock, p.unit)}',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    final qty = _quantity;
    final isRecount = _reason == AdjustmentReason.recount;
    final delta = p == null || qty == null
        ? null
        : InventoryRules.adjustmentDelta(
            reason: _reason,
            quantityMilli: qty,
            currentStockMilli: p.stockMilli,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Ajuste de inventario')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(Gaps.md),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(p?.name ?? 'Elegir producto'),
                  subtitle: p == null
                      ? null
                      : Text(
                          'Existencia actual: ${Qty.format(p.stockMilli, p.unit)}',
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await pickProduct(context);
                    if (picked != null) setState(() => _product = picked);
                  },
                ),
              ),
              const SizedBox(height: Gaps.md),
              Text('Motivo', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: Gaps.sm),
              Wrap(
                spacing: Gaps.sm,
                runSpacing: Gaps.sm,
                children: [
                  for (final r in AdjustmentReason.values)
                    ChoiceChip(
                      label: Text(r.label),
                      selected: _reason == r,
                      onSelected: (_) => setState(() => _reason = r),
                    ),
                ],
              ),
              const SizedBox(height: Gaps.md),
              TextField(
                controller: _qty,
                enabled: p != null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: isRecount
                      ? 'Cantidad contada'
                      : 'Cantidad perdida',
                  suffixText: p?.unit.symbol,
                  helperText: isRecount
                      ? 'Se ajusta a lo que hay físicamente'
                      : 'Se descuenta de la existencia',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Gaps.md),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Nota (opcional)',
                  hintText: 'Ej.: pollo descongelado por apagón',
                ),
              ),
              if (p != null && delta != null) ...[
                const SizedBox(height: Gaps.md),
                Card(
                  color: (delta < 0 ? AppColors.danger : AppColors.success)
                      .withValues(alpha: 0.08),
                  child: ListTile(
                    title: Text(
                      'Nueva existencia: '
                      '${Qty.format(p.stockMilli + delta, p.unit)}',
                    ),
                    subtitle: Text(
                      'Variación: ${delta > 0 ? '+' : ''}'
                      '${Qty.format(delta, p.unit)}',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Gaps.lg),
              FilledButton.icon(
                onPressed: p == null || qty == null || _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: const Text('Registrar ajuste'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
