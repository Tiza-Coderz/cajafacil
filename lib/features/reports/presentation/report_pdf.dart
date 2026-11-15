import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/features/reports/domain/report_models.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Informe de ventas en PDF (A4) para imprimir o enviar al dueño.
abstract final class ReportPdf {
  static Future<Uint8List> build(
    SalesReport r, {
    required String businessName,
    required bool includeCosts,
  }) async {
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      ),
      bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf')),
    );
    final date = DateFormat('dd/MM/yyyy', 'es');
    String m(Money money) => MoneyFormatter.format(money);
    final s = r.summary;
    const brand = PdfColor.fromInt(0xFF0F4C75);

    pw.Widget kpi(String label, String value) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.all(4),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    final lastDay = r.range.to.subtract(const Duration(days: 1));
    return (pw.Document(
          title: 'Reporte de ventas',
          author: businessName,
          theme: theme,
        )..addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            header: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  businessName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: brand,
                  ),
                ),
                pw.Text(
                  'Reporte de ventas · ${r.range.label} '
                  '(${date.format(r.range.from)} – ${date.format(lastDay)})',
                ),
                pw.SizedBox(height: 8),
              ],
            ),
            footer: (context) => pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount} · '
                'Generado con CajaFácil',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ),
            build: (context) => [
              pw.Row(
                children: [
                  kpi('Ventas', '${s.salesCount}'),
                  kpi('Total CUP', m(s.totalCup)),
                  kpi('Total USD', m(s.totalUsd)),
                  kpi('Ticket promedio', m(s.averageTicketCup)),
                ],
              ),
              if (includeCosts)
                pw.Row(
                  children: [
                    kpi('Costo', m(s.costUsd)),
                    kpi('Ganancia bruta', m(s.grossProfitUsd)),
                    kpi(
                      'Margen',
                      '${(s.marginBasisPoints / 100).toStringAsFixed(1)} %',
                    ),
                    kpi('Descuentos', m(s.discountUsd)),
                  ],
                ),
              pw.SizedBox(height: 12),
              _title('Ventas por día'),
              pw.TableHelper.fromTextArray(
                headers: ['Fecha', 'Ventas', 'CUP', 'USD'],
                data: [
                  for (final d in r.daily)
                    [
                      date.format(d.day),
                      '${d.salesCount}',
                      m(d.totalCup),
                      m(d.totalUsd),
                    ],
                ],
                headerDecoration: const pw.BoxDecoration(color: brand),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellAlignments: {
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 12),
              _title('Top 10 productos'),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Producto',
                  'Cantidad',
                  'USD',
                  if (includeCosts) 'Ganancia',
                ],
                data: [
                  for (final p in r.top10)
                    [
                      p.name,
                      Qty.format(p.qtyMilli, p.unit),
                      m(p.totalUsd),
                      if (includeCosts) m(p.grossProfitUsd),
                    ],
                ],
                headerDecoration: const pw.BoxDecoration(color: brand),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 12),
              _title('Por cajero'),
              pw.TableHelper.fromTextArray(
                headers: ['Cajero', 'Ventas', 'CUP', 'USD'],
                data: [
                  for (final c in r.byCashier)
                    [
                      c.cashierName,
                      '${c.salesCount}',
                      m(c.totalCup),
                      m(c.totalUsd),
                    ],
                ],
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
              if (r.lowStock.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                _title('Bajo stock'),
                pw.TableHelper.fromTextArray(
                  headers: ['Producto', 'Existencia', 'Mínimo', 'Pedir'],
                  data: [
                    for (final l in r.lowStock)
                      [
                        l.name,
                        Qty.format(l.stockMilli, l.unit),
                        Qty.format(l.minStockMilli, l.unit),
                        Qty.format(l.suggestedOrderMilli, l.unit),
                      ],
                  ],
                  cellStyle: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ],
          ),
        ))
        .save();
  }

  static pw.Widget _title(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
    ),
  );
}
