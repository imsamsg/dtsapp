import 'package:flutter/material.dart';
import '../../domain/entities/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(product.productTitle),
      subtitle: Text('${product.productCode} · ${product.productBarcode}'),
      trailing: Text('\$${product.priceWithGst.toStringAsFixed(2)}'),
      onTap: onTap,
    );
  }
}
