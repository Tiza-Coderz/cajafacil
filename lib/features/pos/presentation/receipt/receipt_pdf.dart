import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/features/pos/domain/entities/sale_receipt.dart';
import 'package:cajafacil/features/pos/domain/services/receipt_formatter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Genera el ticket en PDF con ancho de rollo térmico de 80 mm.
/// Usa la Roboto empaquetada: no descarga fuentes de internet.
abstract final class ReceiptPdf {
  static Future<Uint8List> build(SaleReceipt r, ReceiptHeader h) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    String m(Money money) => MoneyFormatter.format(money);
    const small = pw.TextStyle(fontSize: 8);
    final doc =
        pw.Document(
          title: 'Ticket ${r.number}',
          author: h.businessName,
          theme: theme,
        )..addPage(
          pw.Page(
            pageFormat: PdfPageFormat.roll80,
            margin: const pw.EdgeInsets.all(8),
            build: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  h.businessName,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (h.address.isNotEmpty)
                  pw.Text(
                    h.address,
                    textAlign: pw.TextAlign.center,
                    style: small,
                  ),
                if (h.nit.isNotEmpty)
                  pw.Text(
                    'NIT: ${h.nit}',
                    textAlign: pw.TextAlign.center,
                    style: small,
                  ),
                if (h.phone.isNotEmpty)
                  pw.Text(
                    'Tel.: ${h.phone}',
                    textAlign: pw.TextAlign.center,
                    style: small,
                  ),
                pw.SizedBox(height: 6),
                pw.Text('Ticket ${r.number}', style: small),
                pw.Text(
                  DateFormat('dd/MM/yyyy h:mm a', 'es').format(r.createdAt),
                  style: small,
                ),
                pw.Text('Atendió: ${r.cashierName}', style: small),
                if (r.isVoided)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Text(
                      'VENTA ANULADA',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                pw.Divider(thickness: 0.5),
                for (final l in r.lines) ...[
                  pw.Text(l.name, style: const pw.TextStyle(fontSize: 9)),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${Qty.format(l.qtyMilli, l.unit)} x ${m(l.unitPriceCup)}',
                          style: small,
                        ),
                      ),
                      pw.Text(
                        m(l.totalCup),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                ],
                pw.Divider(thickness: 0.5),
                _row('TOTAL', m(r.totalCup), bold: true),
                _row('', m(r.totalUsd)),
                _row(
                  'Tasa',
                  '1 USD = ${m(r.rate.toCup(const Money.usd(100)))}',
                  small: true,
                ),
                if (r.discountUsd.isPositive)
                  _row('Ahorro', m(r.discountUsd), small: true),
                pw.SizedBox(height: 6),
                for (final p in r.payments)
                  _row(p.method.label, m(p.amount), small: true),
                if (r.change.isPositive)
                  _row('Vuelto', m(r.change), small: true),
                if (h.footer.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(
                    h.footer,
                    textAlign: pw.TextAlign.center,
                    style: small,
                  ),
                ],
              ],
            ),
          ),
        );
    return doc.save();
  }

  static pw.Widget _row(
    String label,
    String value, {
    bool bold = false,
    bool small = false,
  }) {
    final style = pw.TextStyle(
      fontSize: small ? 8 : 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      children: [
        pw.Expanded(child: pw.Text(label, style: style)),
        pw.Text(value, style: style),
      ],
    );
  }
}
