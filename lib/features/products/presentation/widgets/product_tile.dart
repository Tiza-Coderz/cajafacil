import 'package:cajafacil/app/theme/app_colors.dart';
import 'package:cajafacil/core/money/money.dart';
import 'package:cajafacil/core/utils/qty.dart';
import 'package:cajafacil/core/widgets/dual_price.dart';
import 'package:cajafacil/core/widgets/product_avatar.dart';
import 'package:cajafacil/features/products/domain/entities/product.dart';
import 'package:flutter/material.dart';

class ProductTile extends StatelessWidget {
  const ProductTile({
    required this.product,
    required this.priceCup,
    this.category,
    this.onTap,
    this.trailing,
    super.key,
  });

  final Product product;
  final Money? priceCup;
  final Category? category;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final low = product.isLowStock;
    final stockText = 'Stock: ${Qty.format(product.stockMilli, product.unit)}';
    return ListTile(
      onTap: onTap,
      leading: ProductAvatar(
        photo: product.photo,
        iconKey: category?.iconKey,
        color: category?.color,
      ),
      title: Text(
        product.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: product.active ? null : Theme.of(context).disabledColor,
        ),
      ),
      subtitle: Row(
        children: [
          if (low) ...[
            const Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: AppColors.warning,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              [
                if (product.categoryName != null) product.categoryName!,
                stockText,
                if (!product.active) 'Inactivo',
              ].join(' · '),
              overflow: TextOverflow.ellipsis,
              style: low ? const TextStyle(color: AppColors.warning) : null,
            ),
          ),
        ],
      ),
      trailing:
          trailing ??
          DualPrice(usd: product.priceUsd, cup: priceCup, dense: true),
    );
  }
}
