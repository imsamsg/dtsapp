import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';
import '../../../authentication/domain/entities/auth_session.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/warehouse.dart';
import '../providers/stock_count_providers.dart';
import '../widgets/stock_count_card.dart';
import '../widgets/warehouse_picker_sheet.dart';

class StockCountListPage extends ConsumerStatefulWidget {
  const StockCountListPage({super.key});

  @override
  ConsumerState<StockCountListPage> createState() => _StockCountListPageState();
}

class _StockCountListPageState extends ConsumerState<StockCountListPage> {
  String? _status;
  String? _warehouse;

  static const _statusLabels = {null: 'All', 'OPEN': 'Open', 'APPROVED': 'Approved', 'POSTED': 'Posted'};

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();
    final session = authState.session;

    final query = StockCountSearchQuery(
      companyId: session.companyId,
      branchId: session.branchId,
      status: _status,
      warehouse: _warehouse,
    );
    final resultAsync = ref.watch(stockCountSearchProvider(query));
    final warehousesAsync = ref.watch(warehousesProvider(session.companyId));

    return AppPageScaffold(
      currentPath: '/stock-counts',
      title: 'Stock Counts',
      actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _openWarehousePicker(session))],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(child: _statusDropdown()),
                const SizedBox(width: 8),
                Expanded(child: _warehouseDropdown(warehousesAsync)),
              ],
            ),
          ),
          Expanded(
            child: resultAsync.when(
              data: (result) {
                if (result.items.isEmpty) {
                  return _EmptyResults(onCreate: () => _openWarehousePicker(session));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(stockCountSearchProvider(query).future),
                  child: ListView.builder(
                    itemCount: result.items.length,
                    itemBuilder: (context, index) {
                      final stockCount = result.items[index];
                      return StockCountCard(
                        stockCount: stockCount,
                        onTap: () =>
                            context.push('/stock-counts/${stockCount.companyId}/${stockCount.branchId}/${stockCount.stockcntId}'),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AppErrorView(
                message: error is ApiException ? error.message : 'An unexpected error occurred.',
                onRetry: () => ref.invalidate(stockCountSearchProvider(query)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDropdown() {
    final codes = _statusLabels.keys.toList();
    return DropdownButtonFormField<String?>(
      initialValue: _status,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: codes
          .map((code) => DropdownMenuItem(value: code, child: Text(_statusLabels[code]!, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (value) => setState(() => _status = value),
    );
  }

  Widget _warehouseDropdown(AsyncValue<List<Warehouse>> warehousesAsync) {
    return warehousesAsync.when(
      data: (warehouses) => DropdownButtonFormField<String?>(
        initialValue: _warehouse,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('All Warehouses', overflow: TextOverflow.ellipsis)),
          for (final w in warehouses) DropdownMenuItem(value: w.code, child: Text(w.code, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (value) => setState(() => _warehouse = value),
      ),
      loading: () => const SizedBox(height: 48),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _openWarehousePicker(AuthSession session) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WarehousePickerSheet(companyId: session.companyId, branchId: session.branchId),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checklist_outlined, size: 48, color: AppColors.neutral.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          const Text('No stock counts found.'),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Create Stock Count')),
        ],
      ),
    );
  }
}
