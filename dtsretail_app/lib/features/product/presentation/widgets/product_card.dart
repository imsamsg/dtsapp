import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/product.dart';
import 'product_badge.dart';
import 'product_image.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(child: ProductImage(imageUrl: product.imageUrl, heroTag: product.heroTag)),
                  Positioned(top: 6, left: 6, child: ProductBadge(product: product, kind: ProductBadgeKind.category)),
                  Positioned(top: 6, right: 6, child: ProductBadge(product: product, kind: ProductBadgeKind.stock)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.productTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            if (product.productBrand.isNotEmpty)
              Text(product.productBrand, style: const TextStyle(fontSize: 11, color: AppColors.neutral)),
            if (product.status != ProductStatus.active) ...[
              const SizedBox(height: 4),
              ProductBadge(product: product, kind: ProductBadgeKind.status),
            ],
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${product.priceWithGst.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14),
                ),
                const SizedBox(width: 6),
                Text('cost \$${product.cost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: AppColors.neutral)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
