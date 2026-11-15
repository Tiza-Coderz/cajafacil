import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/utils/date_formatter.dart';
import 'package:cajafacil/features/exchange_rate/domain/entities/rate_entry.dart';
import 'package:flutter/material.dart';

class CurrentRateCard extends StatelessWidget {
  const CurrentRateCard({required this.entry, super.key});

  final RateEntry? entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final current = entry;

    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(Gaps.lg),
        child: DefaultTextStyle(
          style: TextStyle(color: scheme.onPrimary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tasa vigente',
                style: text.labelLarge?.copyWith(color: scheme.onPrimary),
              ),
              const SizedBox(height: Gaps.sm),
              if (current == null)
                Text(
                  'Aún no ha fijado la tasa del día',
                  style: text.titleLarge?.copyWith(color: scheme.onPrimary),
                )
              else ...[
                Semantics(
                  label:
                      'Un dólar equivale a '
                      '${MoneyFormatter.format(Money.cup(current.rate.cupPerUsdX100))}',
                  child: ExcludeSemantics(
                    child: Text(
                      '1 USD = ${MoneyFormatter.format(Money.cup(current.rate.cupPerUsdX100))}',
                      style: text.headlineMedium?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Gaps.xs),
                Text(
                  'Fijada ${AppDates.relativeDayTime(current.effectiveDate)} '
                  'por ${current.createdByName}',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
