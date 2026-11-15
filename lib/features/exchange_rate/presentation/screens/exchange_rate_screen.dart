import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/widgets/state_views.dart';
import 'package:cajafacil/features/auth/presentation/providers/auth_providers.dart';
import 'package:cajafacil/features/exchange_rate/domain/services/rate_validator.dart';
import 'package:cajafacil/features/exchange_rate/presentation/providers/exchange_rate_providers.dart';
import 'package:cajafacil/features/exchange_rate/presentation/widgets/current_rate_card.dart';
import 'package:cajafacil/features/exchange_rate/presentation/widgets/rate_history_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExchangeRateScreen extends ConsumerStatefulWidget {
  const ExchangeRateScreen({super.key});

  @override
  ConsumerState<ExchangeRateScreen> createState() => _ExchangeRateScreenState();
}

class _ExchangeRateScreenState extends ConsumerState<ExchangeRateScreen> {
  final _rateCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _rateCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final previous = ref.read(currentRateProvider).value?.rate;
    final validation = RateValidator.validate(
      _rateCtrl.text,
      previous: previous,
    );
    switch (validation) {
      case RateInvalid(:final message):
        setState(() => _error = message);
        return;
      case RateValid(:final rate, :final warning):
        if (warning != null && !await _confirm(warning)) return;
        final user = ref.read(sessionProvider);
        if (user == null) return;
        setState(() {
          _saving = true;
          _error = null;
        });
        try {
          await ref
              .read(exchangeRateRepositoryProvider)
              .setRate(rate: rate, userId: user.id, note: _noteCtrl.text);
          _rateCtrl.clear();
          _noteCtrl.clear();
          if (mounted) {
            FocusScope.of(context).unfocus();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Tasa guardada. Los precios en CUP ya usan la nueva tasa.',
                ),
              ),
            );
          }
        } on Exception {
          setState(() => _error = 'No se pudo guardar. Intente de nuevo.');
        } finally {
          if (mounted) setState(() => _saving = false);
        }
    }
  }

  Future<bool> _confirm(String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambio grande de tasa'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, guardar'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentRateProvider);
    final history = ref.watch(rateHistoryProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tasa de cambio')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(Gaps.md),
            children: [
              current.when(
                data: (entry) => CurrentRateCard(entry: entry),
                loading: () => const SizedBox(
                  height: 120,
                  child: LoadingView(),
                ),
                error: (_, _) => ErrorView(
                  message: 'No se pudo leer la tasa.',
                  onRetry: () => ref.invalidate(currentRateProvider),
                ),
              ),
              const SizedBox(height: Gaps.md),
              _SetRateCard(
                rateCtrl: _rateCtrl,
                noteCtrl: _noteCtrl,
                error: _error,
                saving: _saving,
                onSave: _save,
                onChanged: () => setState(() => _error = null),
              ),
              const SizedBox(height: Gaps.lg),
              Text('Historial', style: text.titleMedium),
              const SizedBox(height: Gaps.sm),
              history.when(
                data: (entries) => entries.isEmpty
                    ? const EmptyView(
                        message: 'Todavía no hay tasas registradas.',
                        icon: Icons.history,
                      )
                    : RateHistoryList(entries: entries),
                loading: () => const LoadingView(),
                error: (_, _) => ErrorView(
                  message: 'No se pudo cargar el historial.',
                  onRetry: () => ref.invalidate(rateHistoryProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetRateCard extends StatelessWidget {
  const _SetRateCard({
    required this.rateCtrl,
    required this.noteCtrl,
    required this.error,
    required this.saving,
    required this.onSave,
    required this.onChanged,
  });

  final TextEditingController rateCtrl;
  final TextEditingController noteCtrl;
  final String? error;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final validation = RateValidator.validate(rateCtrl.text);
    final preview = validation is RateValid
        ? '10 USD = ${MoneyFormatter.format(validation.rate.toCup(const Money.usd(1000)))}'
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gaps.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Fijar tasa del día',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Gaps.md),
            TextField(
              controller: rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'CUP por 1 USD',
                hintText: 'Ej.: 440',
                suffixText: 'CUP',
                errorText: error,
                helperText: preview,
              ),
              onChanged: (_) => onChanged(),
              onSubmitted: (_) => onSave(),
            ),
            const SizedBox(height: Gaps.md),
            TextField(
              controller: noteCtrl,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: 'Ej.: tasa informal de la mañana',
              ),
            ),
            const SizedBox(height: Gaps.sm),
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Guardar tasa'),
            ),
          ],
        ),
      ),
    );
  }
}
