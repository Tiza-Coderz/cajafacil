import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/widgets/money_field.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/cash_register/domain/services/cash_reconciliation.dart';
import 'package:cajafacil/features/cash_register/presentation/providers/cash_register_providers.dart';
import 'package:cajafacil/features/cash_register/presentation/widgets/cash_summary_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cierre de caja: conteo por billetes (o total directo) y diferencia.
class CloseCashScreen extends ConsumerStatefulWidget {
  const CloseCashScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<CloseCashScreen> createState() => _CloseCashScreenState();
}

class _CloseCashScreenState extends ConsumerState<CloseCashScreen> {
  final Map<Currency, Map<int, int>> _counts = {
    Currency.cup: {},
    Currency.usd: {},
  };
  final Map<Currency, TextEditingController> _totals = {
    Currency.cup: TextEditingController(),
    Currency.usd: TextEditingController(),
  };
  bool _byDenomination = true;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _totals.values) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  Money _counted(Currency currency) {
    if (_byDenomination) {
      return Denominations.total(currency, _counts[currency]!);
    }
    final text = _totals[currency]!.text;
    return text.trim().isEmpty
        ? Money.zero(currency)
        : Money.tryParse(text, currency) ?? Money.zero(currency);
  }

  CurrencyPair get _countedPair =>
      CurrencyPair(usd: _counted(Currency.usd), cup: _counted(Currency.cup));

  Future<void> _close(CashSummary summary) async {
    final counted = _countedPair;
    final diff = CashReconciliation.difference(
      counted: counted,
      expected: summary.expected,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar la caja?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contado: ${MoneyFormatter.format(counted.cup)} y '
              '${MoneyFormatter.format(counted.usd)}',
            ),
            const SizedBox(height: Gaps.sm),
            Row(
              children: [
                const Text('CUP: '),
                DifferenceText(difference: diff.cup),
              ],
            ),
            Row(
              children: [
                const Text('USD: '),
                DifferenceText(difference: diff.usd),
              ],
            ),
            const SizedBox(height: Gaps.sm),
            const Text('Después de cerrar no se podrá modificar el conteo.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar caja'),
          ),
        ],
      ),
    );
    final user = ref.read(sessionProvider);
    if (confirmed != true || user == null) return;
    setState(() => _busy = true);
    await ref
        .read(cashRegisterRepositoryProvider)
        .close(
          sessionId: widget.sessionId,
          counted: counted,
          userId: user.id,
          note: _note.text,
          countDetail: _byDenomination
              ? {
                  for (final e in _counts.entries)
                    e.key.code: Map.of(e.value)..removeWhere((_, v) => v == 0),
                }
              : null,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Caja cerrada.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(cashSummaryProvider(widget.sessionId));
    return Scaffold(
      appBar: AppBar(title: const Text('Cerrar caja')),
      body: summary.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(message: 'No se pudo leer el turno.'),
        data: (s) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(Gaps.md),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Contar por billetes'),
                  subtitle: const Text('O escriba el total de cada moneda'),
                  value: _byDenomination,
                  onChanged: (v) => setState(() => _byDenomination = v),
                ),
                for (final currency in [Currency.cup, Currency.usd]) ...[
                  _CurrencyCountCard(
                    currency: currency,
                    expected: s.expected.of(currency),
                    counted: _counted(currency),
                    child: _byDenomination
                        ? _DenominationCounter(
                            currency: currency,
                            counts: _counts[currency]!,
                            onChanged: () => setState(() {}),
                          )
                        : MoneyField(
                            controller: _totals[currency]!,
                            label: 'Total contado',
                            currency: currency,
                            onChanged: (_) => setState(() {}),
                          ),
                  ),
                  const SizedBox(height: Gaps.md),
                ],
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    hintText: 'Ej.: faltante por billete de 100 roto',
                  ),
                ),
                const SizedBox(height: Gaps.lg),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _close(s),
                  icon: const Icon(Icons.lock),
                  label: const Text('Cerrar caja'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyCountCard extends StatelessWidget {
  const _CurrencyCountCard({
    required this.currency,
    required this.expected,
    required this.counted,
    required this.child,
  });

  final Currency currency;
  final Money expected;
  final Money counted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(currency.label, style: text.titleMedium),
            const SizedBox(height: Gaps.sm),
            child,
            const Divider(height: Gaps.lg),
            _line('Debe haber', MoneyFormatter.format(expected)),
            _line('Contado', MoneyFormatter.format(counted)),
            Row(
              children: [
                const Expanded(child: Text('Diferencia')),
                DifferenceText(difference: counted - expected),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );
}

class _DenominationCounter extends StatelessWidget {
  const _DenominationCounter({
    required this.currency,
    required this.counts,
    required this.onChanged,
  });

  final Currency currency;
  final Map<int, int> counts;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final d in Denominations.of(currency))
          _DenominationRow(
            denomination: d,
            currency: currency,
            count: counts[d] ?? 0,
            onChanged: (value) {
              counts[d] = value < 0 ? 0 : value;
              onChanged();
            },
          ),
      ],
    );
  }
}

class _DenominationRow extends StatefulWidget {
  const _DenominationRow({
    required this.denomination,
    required this.currency,
    required this.count,
    required this.onChanged,
  });

  final int denomination;
  final Currency currency;
  final int count;
  final ValueChanged<int> onChanged;

  @override
  State<_DenominationRow> createState() => _DenominationRowState();
}

class _DenominationRowState extends State<_DenominationRow> {
  late final _controller = TextEditingController(text: '${widget.count}');

  @override
  void didUpdateWidget(covariant _DenominationRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincroniza cuando cambia por los botones +/−, sin pisar lo que se teclea.
    if (int.tryParse(_controller.text) != widget.count) {
      _controller.text = '${widget.count}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.denomination;
    final code = widget.currency.code;
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            '$d $code',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        IconButton(
          tooltip: 'Quitar uno de $d $code',
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => widget.onChanged(widget.count - 1),
        ),
        SizedBox(
          width: 56,
          child: TextField(
            controller: _controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(isDense: true),
            onChanged: (v) => widget.onChanged(int.tryParse(v) ?? 0),
          ),
        ),
        IconButton(
          tooltip: 'Añadir uno de $d $code',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => widget.onChanged(widget.count + 1),
        ),
        Expanded(
          child: Text(
            MoneyFormatter.format(
              Money(d * 100 * widget.count, widget.currency),
              withCode: false,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
