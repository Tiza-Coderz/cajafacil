import 'package:cajafacil/app/router/routes.dart';
import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/utils/date_formatter.dart';
import 'package:cajafacil/core/widgets/money_field.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/cash_register/domain/entities/cash_session.dart';
import 'package:cajafacil/features/cash_register/domain/repositories/cash_register_repository.dart';
import 'package:cajafacil/features/cash_register/domain/services/cash_reconciliation.dart';
import 'package:cajafacil/features/cash_register/presentation/providers/cash_register_providers.dart';
import 'package:cajafacil/features/cash_register/presentation/widgets/cash_summary_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CashRegisterScreen extends ConsumerWidget {
  const CashRegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(openCashSessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja'),
        actions: [
          IconButton(
            tooltip: 'Historial de cierres',
            icon: const Icon(Icons.history),
            onPressed: () => context.push('${Routes.cashRegister}/historial'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: session.when(
            loading: () => const LoadingView(),
            error: (_, _) => ErrorView(
              message: 'No se pudo leer el estado de la caja.',
              onRetry: () => ref.invalidate(openCashSessionProvider),
            ),
            data: (s) => s == null
                ? const _OpenCashForm()
                : _OpenSessionView(session: s),
          ),
        ),
      ),
    );
  }
}

class _OpenCashForm extends ConsumerStatefulWidget {
  const _OpenCashForm();

  @override
  ConsumerState<_OpenCashForm> createState() => _OpenCashFormState();
}

class _OpenCashFormState extends ConsumerState<_OpenCashForm> {
  final _usd = TextEditingController();
  final _cup = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _usd.dispose();
    _cup.dispose();
    super.dispose();
  }

  Money? _parse(TextEditingController c, Currency currency) =>
      c.text.trim().isEmpty
      ? Money.zero(currency)
      : Money.tryParse(c.text, currency);

  Future<void> _open() async {
    final usd = _parse(_usd, Currency.usd);
    final cup = _parse(_cup, Currency.cup);
    if (usd == null || cup == null || usd.isNegative || cup.isNegative) {
      setState(() => _error = 'Revise los importes del fondo.');
      return;
    }
    final user = ref.read(sessionProvider);
    if (user == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(cashRegisterRepositoryProvider)
          .open(
            opening: CurrencyPair(usd: usd, cup: cup),
            userId: user.id,
          );
    } on CashSessionAlreadyOpenException catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
        const SizedBox(height: Gaps.sm),
        Text(
          'La caja está cerrada',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: Gaps.xs),
        const Text(
          'Cuente el fondo (cambio) con el que empieza el turno.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Gaps.lg),
        MoneyField(
          controller: _cup,
          label: 'Fondo en CUP',
          currency: Currency.cup,
        ),
        const SizedBox(height: Gaps.md),
        MoneyField(
          controller: _usd,
          label: 'Fondo en USD',
          currency: Currency.usd,
          error: _error,
        ),
        const SizedBox(height: Gaps.lg),
        FilledButton.icon(
          onPressed: _busy ? null : _open,
          icon: const Icon(Icons.lock_open),
          label: const Text('Abrir caja'),
        ),
      ],
    );
  }
}

class _OpenSessionView extends ConsumerWidget {
  const _OpenSessionView({required this.session});

  final CashSession session;

  Future<void> _movement(
    BuildContext context,
    WidgetRef ref,
    CashMovementType type,
  ) async {
    final result = await showDialog<(Money, String)>(
      context: context,
      builder: (_) => _MovementDialog(type: type),
    );
    final user = ref.read(sessionProvider);
    if (result == null || user == null) return;
    await ref
        .read(cashRegisterRepositoryProvider)
        .addMovement(
          sessionId: session.id,
          type: type,
          amount: result.$1,
          reason: result.$2,
          userId: user.id,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${type.label} registrada: ${MoneyFormatter.format(result.$1)}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(cashSummaryProvider(session.id));
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(Gaps.md),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.lock_open)),
            title: const Text('Caja abierta'),
            subtitle: Text(
              'Por ${session.openedByName}, '
              '${AppDates.relativeDayTime(session.openedAt)}',
            ),
          ),
        ),
        const SizedBox(height: Gaps.md),
        summary.when(
          loading: () => const SizedBox(height: 200, child: LoadingView()),
          error: (_, _) =>
              const ErrorView(message: 'No se pudo calcular el resumen.'),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gaps.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Efectivo (${s.salesCount} ventas)',
                        style: text.titleMedium,
                      ),
                      const SizedBox(height: Gaps.sm),
                      CashSummaryTable(summary: s),
                    ],
                  ),
                ),
              ),
              if (s.electronicByMethod.isNotEmpty) ...[
                const SizedBox(height: Gaps.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Gaps.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pagos electrónicos', style: text.titleMedium),
                        const Text('No están en la gaveta'),
                        const SizedBox(height: Gaps.sm),
                        for (final e in s.electronicByMethod.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(e.key.label)),
                                Text(
                                  [
                                    if (!e.value.cup.isZero)
                                      MoneyFormatter.format(e.value.cup),
                                    if (!e.value.usd.isZero)
                                      MoneyFormatter.format(e.value.usd),
                                  ].join(' + '),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Gaps.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    _movement(context, ref, CashMovementType.cashIn),
                icon: const Icon(Icons.add),
                label: const Text('Entrada'),
              ),
            ),
            const SizedBox(width: Gaps.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    _movement(context, ref, CashMovementType.cashOut),
                icon: const Icon(Icons.remove),
                label: const Text('Salida'),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gaps.md),
        FilledButton.icon(
          onPressed: () =>
              context.push('${Routes.cashRegister}/cerrar/${session.id}'),
          icon: const Icon(Icons.lock),
          label: const Text('Cerrar caja y contar'),
        ),
      ],
    );
  }
}

class _MovementDialog extends StatefulWidget {
  const _MovementDialog({required this.type});

  final CashMovementType type;

  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  Currency _currency = Currency.cup;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = Money.tryParse(_amount.text, _currency);
    if (amount == null || !amount.isPositive) {
      setState(() => _error = 'Escriba un importe mayor que 0');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Indique el motivo');
      return;
    }
    Navigator.pop(context, (amount, _reason.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final isIn = widget.type == CashMovementType.cashIn;
    return AlertDialog(
      title: Text(widget.type.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<Currency>(
            segments: const [
              ButtonSegment(value: Currency.cup, label: Text('CUP')),
              ButtonSegment(value: Currency.usd, label: Text('USD')),
            ],
            selected: {_currency},
            onSelectionChanged: (s) => setState(() => _currency = s.first),
          ),
          const SizedBox(height: Gaps.md),
          MoneyField(
            controller: _amount,
            label: 'Importe',
            currency: _currency,
            autofocus: true,
          ),
          const SizedBox(height: Gaps.md),
          TextField(
            controller: _reason,
            decoration: InputDecoration(
              labelText: 'Motivo',
              hintText: isIn
                  ? 'Ej.: cambio traído por el dueño'
                  : 'Ej.: pago al proveedor de pan',
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
        FilledButton(onPressed: _submit, child: const Text('Registrar')),
      ],
    );
  }
}
