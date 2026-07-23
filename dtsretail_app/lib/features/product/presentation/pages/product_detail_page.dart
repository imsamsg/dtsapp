import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../shared/widgets/info_section_card.dart';
import '../../domain/entities/product.dart';
import '../providers/product_providers.dart';
import '../widgets/product_badge.dart';
import '../widgets/product_image.dart';

class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({
    super.key,
    required this.companyId,
    required this.productTypeCode,
    required this.productCode,
  });

  final String companyId;
  final String productTypeCode;
  final String productCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (companyId: companyId, productTypeCode: productTypeCode, productCode: productCode);
    final productAsync = ref.watch(productDetailProvider(args));

    return Scaffold(
      appBar: AppBar(title: const Text('Product Detail')),
      body: productAsync.when(
        data: (product) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: ProductImage(imageUrl: product.imageUrl, heroTag: product.heroTag, borderRadius: 16, fallbackIconSize: 56),
            ),
            const SizedBox(height: 16),
            Text(product.productTitle, style: Theme.of(context).textTheme.titleLarge),
            if (product.productBrand.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(product.productBrand, style: const TextStyle(color: AppColors.neutral)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ProductBadge(product: product, kind: ProductBadgeKind.category),
                ProductBadge(product: product, kind: ProductBadgeKind.stock),
                if (product.status != ProductStatus.active) ProductBadge(product: product, kind: ProductBadgeKind.status),
              ],
            ),
            const SizedBox(height: 20),
            InfoSectionCard(
              title: 'Details',
              rows: [('Code', product.productCode), ('Barcode', product.productBarcode), ('UOM', product.uom)],
            ),
            const SizedBox(height: 12),
            InfoSectionCard(
              title: 'Pricing',
              rows: [
                ('Price (incl. GST)', '\$${product.priceWithGst.toStringAsFixed(2)}'),
                ('Price (excl. GST)', '\$${product.priceWithoutGst.toStringAsFixed(2)}'),
                ('Cost', '\$${product.cost.toStringAsFixed(2)}'),
                ('Qty on hand', product.qtyOnHand.toStringAsFixed(0)),
              ],
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error is ApiException ? error.message : 'An unexpected error occurred.',
          onRetry: () => ref.invalidate(productDetailProvider(args)),
        ),
      ),
    );
  }
}
