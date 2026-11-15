import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/features/cash_register/domain/services/cash_reconciliation.dart';
import 'package:flutter/material.dart';

/// Tabla de dos columnas (USD | CUP) con el desglose del turno.
class CashSummaryTable extends StatelessWidget {
  const CashSummaryTable({required this.summary, super.key});

  final CashSummary summary;

  @override
  Widget build(BuildContext context) {
    final bold = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.6),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _row(context, '', 'USD', 'CUP', header: true),
        _pairRow(context, 'Fondo inicial', summary.opening),
        _pairRow(context, 'Ventas en efectivo', summary.cashSales, sign: '+'),
        _pairRow(context, 'Vuelto entregado', summary.changeGiven, sign: '−'),
        _pairRow(context, 'Entradas', summary.cashIn, sign: '+'),
        _pairRow(context, 'Salidas', summary.cashOut, sign: '−'),
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Debe haber en gaveta', style: bold),
            ),
            _amount(summary.expected.usd, bold),
            _amount(summary.expected.cup, bold),
          ],
        ),
      ],
    );
  }

  TableRow _pairRow(
    BuildContext context,
    String label,
    CurrencyPair pair, {
    String sign = '',
  }) => _row(
    context,
    label,
    pair.usd.isZero
        ? '—'
        : '$sign${MoneyFormatter.format(pair.usd, withCode: false)}',
    pair.cup.isZero
        ? '—'
        : '$sign${MoneyFormatter.format(pair.cup, withCode: false)}',
  );

  TableRow _row(
    BuildContext context,
    String label,
    String usd,
    String cup, {
    bool header = false,
  }) {
    final style = header
        ? Theme.of(context).textTheme.labelMedium
        : Theme.of(context).textTheme.bodyMedium;
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(label, style: style),
        ),
        Text(
          usd,
          textAlign: TextAlign.end,
          style: style?.copyWith(color: header ? AppColors.usd : null),
        ),
        Text(
          cup,
          textAlign: TextAlign.end,
          style: style?.copyWith(color: header ? AppColors.cup : null),
        ),
      ],
    );
  }

  Widget _amount(Money money, TextStyle? style) => Text(
    MoneyFormatter.format(money, withCode: false),
    textAlign: TextAlign.end,
    style: style,
  );
}

/// Diferencia de cuadre con color: verde cuadra, rojo falta, naranja sobra.
class DifferenceText extends StatelessWidget {
  const DifferenceText({required this.difference, super.key});

  final Money difference;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (difference.cents) {
      0 => ('Cuadra', AppColors.success),
      < 0 => (
        'Falta ${MoneyFormatter.format(difference.abs())}',
        AppColors.danger,
      ),
      _ => ('Sobra ${MoneyFormatter.format(difference)}', AppColors.warning),
    };
    return Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}
