import 'package:flutter/material.dart';
import '../../domain/entities/stock_count.dart';

class StockCountCard extends StatelessWidget {
  const StockCountCard({super.key, required this.stockCount, required this.onTap});

  final StockCount stockCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(stockCount.stockcntId),
      subtitle: Text('${stockCount.whseCode} · ${stockCount.status} · ${stockCount.totalItems} items'),
      trailing: Text(stockCount.totalVarQty.toStringAsFixed(1)),
      onTap: onTap,
    );
  }
}
