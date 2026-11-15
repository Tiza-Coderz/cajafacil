import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/features/reports/domain/report_models.dart';
import 'package:intl/intl.dart';

/// CSV pensado para abrirse con doble clic en Excel en español:
/// BOM UTF-8 (acentos), `;` como separador y coma decimal.
abstract final class ReportCsv {
  static const _bom = '﻿';
  static const _sep = ';';

  static String byProduct(SalesReport r, {required bool includeCosts}) {
    final rows = <List<String>>[
      [
        'Producto',
        'Cantidad',
        'Unidad',
        'Venta USD',
        'Venta CUP',
        if (includeCosts) ...['Costo USD', 'Ganancia USD'],
      ],
      for (final p in r.byProduct)
        [
          p.name,
          _qty(p.qtyMilli),
          p.unit.symbol,
          _money(p.totalUsd),
          _money(p.totalCup),
          if (includeCosts) ...[
            _money(p.costUsd),
            _money(p.grossProfitUsd),
          ],
        ],
    ];
    return _encode(rows);
  }

  static String daily(SalesReport r, {required bool includeCosts}) {
    final date = DateFormat('dd/MM/yyyy');
    final rows = <List<String>>[
      [
        'Fecha',
        'Ventas',
        'Total USD',
        'Total CUP',
        if (includeCosts) ...['Costo USD', 'Ganancia USD'],
      ],
      for (final d in r.daily)
        [
          date.format(d.day),
          '${d.salesCount}',
          _money(d.totalUsd),
          _money(d.totalCup),
          if (includeCosts) ...[_money(d.costUsd), _money(d.grossProfitUsd)],
        ],
    ];
    return _encode(rows);
  }

  static String _money(Money m) =>
      (m.cents / 100).toStringAsFixed(2).replaceAll('.', ',');

  static String _qty(int milli) => Qty.formatNumber(milli).replaceAll('.', ',');

  static String _encode(List<List<String>> rows) =>
      _bom + rows.map((r) => r.map(_escape).join(_sep)).join('\r\n');

  /// Escapa según RFC 4180 (comillas, separador y saltos de línea).
  static String _escape(String value) {
    if (value.contains(_sep) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
