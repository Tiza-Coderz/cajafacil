import 'package:cajafacil/app/theme/app_theme.dart';
import 'package:cajafacil/core/domain/enums.dart';
import 'package:cajafacil/core/money/currency.dart';
import 'package:cajafacil/core/money/exchange_rate.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/core/widgets/money_field.dart';
import 'package:cajafacil/features/pos/domain/entities/discount.dart';
import 'package:flutter/material.dart';

/// Pide una cantidad (admite decimales si la unidad lo permite).
Future<int?> askQuantity(
  BuildContext context, {
  required String productName,
  required ProductUnit unit,
  int? initialMilli,
}) {
  final ctrl = TextEditingController(
    text: initialMilli == null ? '' : Qty.formatNumber(initialMilli),
  );
  return showDialog<int>(
    context: context,
    builder: (context) {
      String? error;
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final qty = Qty.parse(
              ctrl.text,
              allowFraction: unit.allowsFraction,
            );
            if (qty == null || qty <= 0) {
              setState(
                () => error = unit.allowsFraction
                    ? 'Escriba una cantidad, ej. 1.5'
                    : 'Escriba una cantidad entera',
              );
              return;
            }
            Navigator.pop(context, qty);
          }

          return AlertDialog(
            title: Text(productName),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(
                decimal: unit.allowsFraction,
              ),
              decoration: InputDecoration(
                labelText: 'Cantidad',
                suffixText: unit.symbol,
                errorText: error,
              ),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(onPressed: submit, child: const Text('Aceptar')),
            ],
          );
        },
      );
    },
  ).whenComplete(ctrl.dispose);
}

/// Resultado del diálogo de descuento: `null` = cancelado.
class DiscountChoice {
  const DiscountChoice(this.discount);

  /// `null` = quitar el descuento.
  final Discount? discount;
}

/// Pide un descuento en % o importe fijo (en CUP o USD, se guarda en USD).
Future<DiscountChoice?> askDiscount(
  BuildContext context, {
  required String title,
  required ExchangeRate rate,
  Discount? current,
}) {
  return showDialog<DiscountChoice>(
    context: context,
    builder: (_) => _DiscountDialog(title: title, rate: rate, current: current),
  );
}

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog({
    required this.title,
    required this.rate,
    this.current,
  });

  final String title;
  final ExchangeRate rate;
  final Discount? current;

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

enum _Mode { percent, cup, usd }

class _DiscountDialogState extends State<_DiscountDialog> {
  late _Mode _mode;
  late final TextEditingController _value;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _mode = c?.type == DiscountType.amount ? _Mode.usd : _Mode.percent;
    _value = TextEditingController(
      text: c == null
          ? ''
          : c.type == DiscountType.percent
          ? (c.value / 100).toString()
          : (c.value / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _value.text;
    Discount? discount;
    switch (_mode) {
      case _Mode.percent:
        final pct = Money.tryParse(text, Currency.usd); // reutiliza el parseo
        if (pct == null || pct.cents <= 0 || pct.cents > 10000) {
          setState(() => _error = 'Entre 0.01 y 100 %');
          return;
        }
        discount = Discount.percent(pct.cents);
      case _Mode.cup:
        final cup = Money.tryParse(text, Currency.cup);
        if (cup == null || !cup.isPositive) {
          setState(() => _error = 'Escriba un importe');
          return;
        }
        discount = Discount.amountUsd(widget.rate.toUsd(cup).cents);
      case _Mode.usd:
        final usd = Money.tryParse(text, Currency.usd);
        if (usd == null || !usd.isPositive) {
          setState(() => _error = 'Escriba un importe');
          return;
        }
        discount = Discount.amountUsd(usd.cents);
    }
    Navigator.pop(context, DiscountChoice(discount));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(value: _Mode.percent, label: Text('%')),
              ButtonSegment(value: _Mode.cup, label: Text('CUP')),
              ButtonSegment(value: _Mode.usd, label: Text('USD')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: Gaps.md),
          MoneyField(
            controller: _value,
            autofocus: true,
            label: _mode == _Mode.percent ? 'Porcentaje' : 'Importe',
            currency: _mode == _Mode.usd ? Currency.usd : Currency.cup,
            error: _error,
          ),
        ],
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () => Navigator.pop(context, const DiscountChoice(null)),
            child: const Text('Quitar'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Aplicar')),
      ],
    );
  }
}
