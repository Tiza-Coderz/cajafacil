import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/utils/date_formatter.dart';
import 'package:cajafacil/features/exchange_rate/domain/entities/rate_entry.dart';
import 'package:cajafacil/features/exchange_rate/domain/services/rate_validator.dart';
import 'package:flutter/material.dart';

/// Historial de tasas con la variación respecto a la anterior.
class RateHistoryList extends StatelessWidget {
  const RateHistoryList({required this.entries, super.key});

  /// Más reciente primero.
  final List<RateEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _RateTile(
              entry: entries[i],
              previous: i + 1 < entries.length ? entries[i + 1] : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({required this.entry, this.previous});

  final RateEntry entry;
  final RateEntry? previous;

  @override
  Widget build(BuildContext context) {
    final prev = previous;
    final change = prev == null
        ? 0.0
        : RateValidator.changePercent(prev.rate, entry.rate);
    final (icon, color) = switch (change) {
      > 0 => (Icons.arrow_upward, AppColors.danger),
      < 0 => (Icons.arrow_downward, AppColors.success),
      _ => (Icons.remove, Theme.of(context).colorScheme.outline),
    };
    final subtitle = [
      AppDates.relativeDayTime(entry.effectiveDate),
      entry.createdByName,
      if (entry.note != null) entry.note!,
    ].join(' · ');

    return ListTile(
      title: Text(
        MoneyFormatter.format(Money.cup(entry.rate.cupPerUsdX100)),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: prev == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                Text(
                  '${change.abs().toStringAsFixed(1)} %',
                  style: TextStyle(color: color),
                ),
              ],
            ),
    );
  }
}
