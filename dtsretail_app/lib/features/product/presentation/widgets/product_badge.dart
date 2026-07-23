import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/product.dart';

enum ProductBadgeKind { category, status, stock }

class ProductBadge extends StatelessWidget {
  const ProductBadge({super.key, required this.product, required this.kind});

  final Product product;
  final ProductBadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labelAndColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  (String, Color) _labelAndColor() {
    switch (kind) {
      case ProductBadgeKind.category:
        return (product.productTypeCode, AppColors.accent);
      case ProductBadgeKind.status:
        switch (product.status) {
          case ProductStatus.active:
            return ('Active', AppColors.primary);
          case ProductStatus.inactive:
            return ('Inactive', AppColors.neutral);
          case ProductStatus.discontinued:
            return ('Discontinued', AppColors.danger);
        }
      case ProductBadgeKind.stock:
        switch (product.stockLevel) {
          case StockLevel.inStock:
            return ('In Stock', AppColors.primary);
          case StockLevel.lowStock:
            return ('Low Stock', AppColors.warning);
          case StockLevel.outOfStock:
            return ('Out of Stock', AppColors.danger);
        }
    }
  }
}
