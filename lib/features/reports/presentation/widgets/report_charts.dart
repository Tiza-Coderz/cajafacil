import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/features/reports/domain/report_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Barras de ventas por día en la moneda elegida.
class DailySalesChart extends StatelessWidget {
  const DailySalesChart({
    required this.daily,
    required this.currency,
    super.key,
  });

  final List<DailySales> daily;
  final Currency currency;

  Money _value(DailySales d) =>
      currency == Currency.usd ? d.totalUsd : d.totalCup;

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) return const SizedBox(height: 200);
    final color = currency == Currency.usd ? AppColors.usd : AppColors.cup;
    final maxY = daily
        .map((d) => _value(d).cents / 100)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final dayFormat = DateFormat('d/M');
    final labelEvery = (daily.length / 7).ceil().clamp(1, 31);

    return Semantics(
      label: 'Gráfico de ventas por día en ${currency.code}',
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            maxY: maxY == 0 ? 1 : maxY * 1.15,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY == 0 ? 1 : maxY / 4,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Theme.of(context).dividerColor,
                strokeWidth: 0.5,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i % labelEvery != 0 || i >= daily.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        dayFormat.format(daily[i].day),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  '${dayFormat.format(daily[group.x].day)}\n'
                  '${MoneyFormatter.format(_value(daily[group.x]))}\n'
                  '${daily[group.x].salesCount} ventas',
                  const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            barGroups: [
              for (final (i, d) in daily.indexed)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: _value(d).cents / 100,
                      color: color,
                      width: daily.length > 20 ? 6 : 12,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Distribución de cobros por forma de pago (llevado a CUP).
class PaymentMethodsChart extends StatelessWidget {
  const PaymentMethodsChart({
    required this.totals,
    required this.toCup,
    super.key,
  });

  final List<PaymentMethodTotal> totals;
  final Money Function(Money) toCup;

  static const Map<PaymentMethod, Color> _colors = {
    PaymentMethod.cashCup: Color(0xFF0F4C75),
    PaymentMethod.cashUsd: Color(0xFF2E7D32),
    PaymentMethod.transfermovil: Color(0xFFEF6C00),
    PaymentMethod.enzona: Color(0xFF6A1B9A),
    PaymentMethod.transfer: Color(0xFF00838F),
  };

  @override
  Widget build(BuildContext context) {
    final byMethod = <PaymentMethod, int>{};
    for (final t in totals) {
      byMethod[t.method] = (byMethod[t.method] ?? 0) + toCup(t.amount).cents;
    }
    final total = byMethod.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    final entries = byMethod.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 30,
              sectionsSpace: 2,
              sections: [
                for (final e in entries)
                  PieChartSectionData(
                    value: e.value.toDouble(),
                    color: _colors[e.key],
                    radius: 28,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, color: _colors[e.key]),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.key.label)),
                      Text('${(e.value * 100 / total).toStringAsFixed(0)} %'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
