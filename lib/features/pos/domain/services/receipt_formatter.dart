import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/features/pos/domain/entities/sale_receipt.dart';
import 'package:intl/intl.dart';

/// Datos del negocio que encabezan el ticket.
class ReceiptHeader {
  const ReceiptHeader({
    required this.businessName,
    this.address = '',
    this.nit = '',
    this.phone = '',
    this.footer = '',
  });

  final String businessName;
  final String address;
  final String nit;
  final String phone;
  final String footer;
}

/// Ticket en texto plano (para compartir por WhatsApp o imprimir en
/// impresoras térmicas de texto).
abstract final class ReceiptFormatter {
  static String plainText(SaleReceipt r, ReceiptHeader h) {
    final date = DateFormat('dd/MM/yyyy h:mm a', 'es').format(r.createdAt);
    String m(Money money) => MoneyFormatter.format(money);
    final b = StringBuffer()..writeln('*${h.businessName}*');
    if (h.address.isNotEmpty) b.writeln(h.address);
    if (h.nit.isNotEmpty) b.writeln('NIT: ${h.nit}');
    if (h.phone.isNotEmpty) b.writeln('Tel.: ${h.phone}');
    b
      ..writeln()
      ..writeln('Ticket ${r.number}')
      ..writeln(date)
      ..writeln('Atendió: ${r.cashierName}');
    if (r.isVoided) b.writeln('*** VENTA ANULADA ***');
    b.writeln('--------------------------------');
    for (final l in r.lines) {
      b
        ..writeln(l.name)
        ..writeln(
          '  ${Qty.format(l.qtyMilli, l.unit)} x ${m(l.unitPriceCup)}'
          '  = ${m(l.totalCup)}',
        );
      if (l.discountUsd.isPositive) {
        b.writeln('  Descuento: -${m(l.discountUsd)}');
      }
    }
    b
      ..writeln('--------------------------------')
      ..writeln('TOTAL: ${m(r.totalCup)}')
      ..writeln('       ${m(r.totalUsd)}')
      ..writeln('Tasa: 1 USD = ${m(r.rate.toCup(const Money.usd(100)))}');
    if (r.discountUsd.isPositive) {
      b.writeln('Ahorro: ${m(r.discountUsd)}');
    }
    b.writeln();
    for (final p in r.payments) {
      final ref = p.reference == null ? '' : ' (#${p.reference})';
      b.writeln('${p.method.label}: ${m(p.amount)}$ref');
    }
    if (r.change.isPositive) b.writeln('Vuelto: ${m(r.change)}');
    if (h.footer.isNotEmpty) {
      b
        ..writeln()
        ..writeln(h.footer);
    }
    return b.toString().trimRight();
  }
}
