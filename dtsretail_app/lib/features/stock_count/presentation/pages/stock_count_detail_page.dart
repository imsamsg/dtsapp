import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../domain/entities/stock_count.dart';
import '../providers/stock_count_providers.dart';

class StockCountDetailPage extends ConsumerWidget {
  const StockCountDetailPage({super.key, required this.companyId, required this.branchId, required this.stockcntId});

  final String companyId;
  final String branchId;
  final String stockcntId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (companyId: companyId, branchId: branchId, stockcntId: stockcntId);
    final detailAsync = ref.watch(stockCountDetailProvider(args));

    return Scaffold(
      appBar: AppBar(title: Text(stockcntId)),
      body: detailAsync.when(
        data: (stockCount) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusBanner(stockCount: stockCount),
                  const SizedBox(height: 12),
                  Text('Warehouse: ${stockCount.whseCode}'),
                  Text('Last updated: ${stockCount.dateUpdated}'),
                  Text('Total variance: ${stockCount.totalVarQty}'),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: stockCount.lines.length,
                itemBuilder: (context, index) {
                  final line = stockCount.lines[index];
                  return ListTile(
                    title: Text(line.productTitle),
                    subtitle: Text(line.productCode),
                    trailing: Text('Qty: ${line.countQty}'),
                  );
                },
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error is ApiException ? error.message : 'An unexpected error occurred.',
          onRetry: () => ref.invalidate(stockCountDetailProvider(args)),
        ),
      ),
      floatingActionButton: detailAsync.maybeWhen(
        data: (stockCount) => stockCount.isOpen
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/stock-counts/new?companyId=$companyId&branchId=$branchId&stockcntId=$stockcntId'),
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              )
            : null,
        orElse: () => null,
      ),
    );
  }
}

/// Prominent, color-coded banner surfacing the stock count's current status.
///
/// Task 13's edit flow only allows editing a count while it is `OPEN` (the
/// backend has no concurrency control and always resets status to `OPEN` on
/// update), so this detail page must make the current status unmistakable
/// before the user attempts to edit.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.stockCount});

  final StockCount stockCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = stockCount.isOpen;
    final color = isOpen ? Colors.green.shade700 : theme.colorScheme.outline;
    final background = isOpen ? Colors.green.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(isOpen ? Icons.lock_open : Icons.lock, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            'STATUS: ${stockCount.status}',
            style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
