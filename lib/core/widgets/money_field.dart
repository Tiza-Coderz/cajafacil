import 'package:cajafacil/core/money/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de importe: teclado numérico, solo dígitos y separador decimal.
class MoneyField extends StatelessWidget {
  const MoneyField({
    required this.controller,
    required this.label,
    required this.currency,
    this.error,
    this.helper,
    this.onChanged,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final Currency currency;
  final String? error;
  final String? helper;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: currency.code,
        errorText: error,
        helperText: helper,
      ),
      onChanged: onChanged,
    );
  }
}
