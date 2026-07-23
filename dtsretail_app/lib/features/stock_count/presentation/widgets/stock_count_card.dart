import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/stock_count.dart';
import 'stock_count_status_chip.dart';

class StockCountCard extends StatelessWidget {
  const StockCountCard({super.key, required this.stockCount, required this.onTap});

  final StockCount stockCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final variance = stockCount.totalVarQty;
    final varianceColor = variance > 0
        ? AppColors.primary
        : (variance < 0 ? AppColors.danger : AppColors.neutral);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(stockCount.stockcntId, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 8),
                      StockCountStatusChip(status: stockCount.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${stockCount.whseCode} · ${stockCount.totalItems} items',
                    style: const TextStyle(color: AppColors.neutral, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              variance.toStringAsFixed(1),
              style: TextStyle(fontWeight: FontWeight.w700, color: varianceColor, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
