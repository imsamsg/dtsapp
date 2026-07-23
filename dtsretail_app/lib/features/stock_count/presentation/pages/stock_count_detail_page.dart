import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../shared/widgets/info_section_card.dart';
import '../../domain/entities/stock_count_line.dart';
import '../providers/stock_count_providers.dart';
import '../widgets/stock_count_status_chip.dart';

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
        data: (stockCount) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusBanner(status: stockCount.status, isOpen: stockCount.isOpen),
            const SizedBox(height: 16),
            InfoSectionCard(
              title: 'Details',
              rows: [
                ('Warehouse', stockCount.whseCode),
                ('Last updated', stockCount.dateUpdated),
                ('Total variance', stockCount.totalVarQty.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: 20),
            Text('Lines', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in stockCount.lines) _LineRow(line: line),
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

/// Prominent, color-coded banner surfacing the stock count's current status
/// — the edit flow only allows editing while OPEN, so this must be
/// unmistakable before the user attempts to edit. Colors now come from
/// [stockCountStatusColor] (the same mapping StockCountCard's chip uses)
/// instead of the old hardcoded green/outline binary.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.isOpen});

  final String status;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final color = stockCountStatusColor(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(isOpen ? Icons.lock_open : Icons.lock, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            'STATUS: $status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final StockCountLine line;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.productTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(line.productCode, style: const TextStyle(color: AppColors.neutral, fontSize: 12)),
              ],
            ),
          ),
          Text('Qty: ${line.countQty}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
