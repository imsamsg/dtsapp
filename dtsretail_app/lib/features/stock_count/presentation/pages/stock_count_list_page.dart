import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/stock_count_providers.dart';
import '../widgets/stock_count_card.dart';

class StockCountListPage extends ConsumerWidget {
  const StockCountListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();
    final session = authState.session;

    final query = StockCountSearchQuery(companyId: session.companyId, branchId: session.branchId);
    final resultAsync = ref.watch(stockCountSearchProvider(query));

    return AppPageScaffold(
      currentPath: '/stock-counts',
      title: 'Stock Counts',
      actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: () => context.push('/stock-counts/new')),
      ],
      body: resultAsync.when(
        data: (result) {
          if (result.items.isEmpty) return const Center(child: Text('No stock counts found.'));
          return ListView.builder(
            itemCount: result.items.length,
            itemBuilder: (context, index) {
              final stockCount = result.items[index];
              return StockCountCard(
                stockCount: stockCount,
                onTap: () => context.push('/stock-counts/${stockCount.companyId}/${stockCount.branchId}/${stockCount.stockcntId}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error is ApiException ? error.message : 'An unexpected error occurred.',
          onRetry: () => ref.invalidate(stockCountSearchProvider(query)),
        ),
      ),
    );
  }
}
