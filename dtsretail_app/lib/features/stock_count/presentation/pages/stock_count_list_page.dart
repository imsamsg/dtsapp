import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';

class StockCountListPage extends StatelessWidget {
  const StockCountListPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppPageScaffold(currentPath: '/stock-counts', title: 'Stock Counts', body: Center(child: Text('Stock Counts')));
}
