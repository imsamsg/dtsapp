import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';

class ProductListPage extends StatelessWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppPageScaffold(currentPath: '/products', title: 'Product Catalog', body: Center(child: Text('Products')));
}
