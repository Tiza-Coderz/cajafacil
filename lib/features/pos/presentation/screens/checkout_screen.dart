import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/widgets/money_field.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/pos/domain/services/payment_calculator.dart';
import 'package:cajafacil/features/pos/presentation/providers/cart_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  PaymentMethod _method = PaymentMethod.cashCup;
  Currency _currency = Currency.cup;
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _selectMethod(PaymentMethod method) => setState(() {
    _method = method;
    // Efectivo USD/CUP fija la moneda; los electrónicos permiten elegir.
    if (method == PaymentMethod.cashUsd) _currency = Currency.usd;
    if (method == PaymentMethod.cashCup) _currency = Currency.cup;
    if (!method.isCash) _currency = method.defaultCurrency;
    _error = null;
  });

  void _addPayment(Money amount) {
    if (!amount.isPositive) {
      setState(() => _error = 'Escriba un importe mayor que 0');
      return;
    }
    final ref0 = _reference.text.trim();
    ref
        .read(cartProvider.notifier)
        .addPayment(
          Payment(
            method: _method,
            amount: amount,
            reference: _method.isCash || ref0.isEmpty ? null : ref0,
          ),
        );
    _amount.clear();
    _reference.clear();
    setState(() => _error = null);
  }

  Future<void> _finish() async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    setState(() => _busy = true);
    try {
      final receipt = await ref
          .read(cartProvider.notifier)
          .checkout(cashierId: user.id);
      if (!mounted) return;
      context.pushReplacement('${Routes.pos}/ticket/${receipt.id}');
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'No se pudo registrar la venta: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final totals = ref.watch(cartTotalsProvider);
    final status = ref.watch(paymentStatusProvider);
    final text = Theme.of(context).textTheme;

    if (totals == null || status == null || cart.lines.isEmpty) {
      return const Scaffold(
        body: EmptyView(message: 'No hay nada que cobrar.'),
      );
    }

    final remaining = PaymentCalculator.exactAmount(status, _currency);
    final suggestions = _method.isCash
        ? PaymentCalculator.quickCashSuggestions(remaining)
        : const <Money>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Cobrar')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(Gaps.md),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primary,
                child: Padding(
                  padding: const EdgeInsets.all(Gaps.md),
                  child: Column(
                    children: [
                      Text(
                        'Total a cobrar',
                        style: text.labelLarge?.copyWith(color: Colors.white),
                      ),
                      Text(
                        MoneyFormatter.format(totals.totalCup),
                        style: text.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        MoneyFormatter.format(totals.totalUsd),
                        style: text.titleMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Gaps.md),
              Text('Forma de pago', style: text.titleMedium),
              const SizedBox(height: Gaps.sm),
              Wrap(
                spacing: Gaps.sm,
                runSpacing: Gaps.sm,
                children: [
                  for (final m in PaymentMethod.values)
                    ChoiceChip(
                      label: Text(m.label),
                      selected: _method == m,
                      onSelected: (_) => _selectMethod(m),
                    ),
                ],
              ),
              if (!_method.isCash) ...[
                const SizedBox(height: Gaps.sm),
                SegmentedButton<Currency>(
                  segments: const [
                    ButtonSegment(value: Currency.cup, label: Text('CUP')),
                    ButtonSegment(value: Currency.usd, label: Text('USD')),
                  ],
                  selected: {_currency},
                  onSelectionChanged: (s) =>
                      setState(() => _currency = s.first),
                ),
              ],
              const SizedBox(height: Gaps.md),
              if (!status.isPaid) ...[
                Row(
                  children: [
                    Expanded(
                      child: MoneyField(
                        controller: _amount,
                        label: 'Importe recibido',
                        currency: _currency,
                        error: _error,
                      ),
                    ),
                    const SizedBox(width: Gaps.sm),
                    FilledButton(
                      onPressed: () => _addPayment(
                        Money.tryParse(_amount.text, _currency) ??
                            Money.zero(_currency),
                      ),
                      child: const Text('Añadir'),
                    ),
                  ],
                ),
                if (!_method.isCash) ...[
                  const SizedBox(height: Gaps.sm),
                  TextField(
                    controller: _reference,
                    decoration: const InputDecoration(
                      labelText: 'Nº de transacción (opcional)',
                      isDense: true,
                    ),
                  ),
                ],
                const SizedBox(height: Gaps.sm),
                Wrap(
                  spacing: Gaps.sm,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.check, size: 18),
                      label: Text('Exacto ${MoneyFormatter.format(remaining)}'),
                      onPressed: () => _addPayment(remaining),
                    ),
                    for (final s in suggestions)
                      ActionChip(
                        label: Text(MoneyFormatter.format(s)),
                        onPressed: () => _addPayment(s),
                      ),
                  ],
                ),
              ],
              if (cart.payments.isNotEmpty) ...[
                const SizedBox(height: Gaps.md),
                Text('Pagos', style: text.titleMedium),
                Card(
                  child: Column(
                    children: [
                      for (final (i, p) in cart.payments.indexed)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            p.method.isCash
                                ? Icons.payments_outlined
                                : Icons.phone_android,
                          ),
                          title: Text(p.method.label),
                          subtitle: p.reference == null
                              ? null
                              : Text('#${p.reference}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(MoneyFormatter.format(p.amount)),
                              IconButton(
                                tooltip: 'Quitar pago',
                                icon: const Icon(Icons.close),
                                onPressed: () => ref
                                    .read(cartProvider.notifier)
                                    .removePayment(i),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Gaps.md),
              _StatusCard(
                status: status,
                changeCurrency: cart.changeCurrency,
                onChangeCurrency: (c) =>
                    ref.read(cartProvider.notifier).setChangeCurrency(c),
              ),
              if (_error != null && status.isPaid) ...[
                const SizedBox(height: Gaps.sm),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: Gaps.lg),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: status.canComplete && !_busy ? _finish : null,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Finalizar venta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.changeCurrency,
    required this.onChangeCurrency,
  });

  final PaymentStatus status;
  final Currency changeCurrency;
  final ValueChanged<Currency> onChangeCurrency;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!status.isPaid) {
      return Card(
        color: AppColors.warning.withValues(alpha: 0.12),
        child: ListTile(
          leading: const Icon(Icons.hourglass_bottom, color: AppColors.warning),
          title: const Text('Falta por cobrar'),
          subtitle: Text(
            '${MoneyFormatter.format(status.remainingCup)}  ·  '
            '${MoneyFormatter.format(status.remainingUsd)}',
            style: text.titleMedium,
          ),
        ),
      );
    }
    if (status.overpaidElectronic) {
      return Card(
        color: AppColors.danger.withValues(alpha: 0.1),
        child: const ListTile(
          leading: Icon(Icons.error_outline, color: AppColors.danger),
          title: Text('El pago electrónico supera el total'),
          subtitle: Text(
            'No se da vuelto de una transferencia. Corrija el importe.',
          ),
        ),
      );
    }
    return Card(
      color: AppColors.success.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: Gaps.sm),
                Text('Cobrado', style: text.titleMedium),
              ],
            ),
            const SizedBox(height: Gaps.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    status.change.isZero
                        ? 'Sin vuelto'
                        : 'Vuelto: ${MoneyFormatter.format(status.change)}',
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SegmentedButton<Currency>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: Currency.cup, label: Text('CUP')),
                    ButtonSegment(value: Currency.usd, label: Text('USD')),
                  ],
                  selected: {changeCurrency},
                  onSelectionChanged: (s) => onChangeCurrency(s.first),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
