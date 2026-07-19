import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../providers/product_providers.dart';

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
            Text(product.productTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Brand: ${product.productBrand}'),
            Text('Code: ${product.productCode}'),
            Text('Barcode: ${product.productBarcode}'),
            Text('UOM: ${product.uom}'),
            const Divider(height: 32),
            Text('Price (incl. GST): \$${product.priceWithGst.toStringAsFixed(2)}'),
            Text('Price (excl. GST): \$${product.priceWithoutGst.toStringAsFixed(2)}'),
            Text('Cost: \$${product.cost.toStringAsFixed(2)}'),
            Text('Qty on hand: ${product.qtyOnHand}'),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(message: error.toString(), onRetry: () => ref.invalidate(productDetailProvider(args))),
      ),
    );
  }
}
