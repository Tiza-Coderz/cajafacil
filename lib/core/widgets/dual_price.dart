import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/money/money_formatter.dart';
import 'package:flutter/material.dart';

/// Precio en USD y su equivalente en CUP, alineados a la derecha.
class DualPrice extends StatelessWidget {
  const DualPrice({required this.usd, this.cup, this.dense = false, super.key});

  final Money usd;
  final Money? cup;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cupText = cup == null ? 'sin tasa' : MoneyFormatter.format(cup!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          MoneyFormatter.format(usd),
          style: (dense ? text.bodyMedium : text.titleSmall)?.copyWith(
            color: AppColors.usd,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          cupText,
          style: (dense ? text.bodySmall : text.bodyMedium)?.copyWith(
            color: AppColors.cup,
          ),
        ),
      ],
    );
  }
}
