import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/barcode_scanner_service.dart';
import '../../../../core/storage/recent_searches_storage.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/product_providers.dart';
import '../widgets/product_card.dart';
import '../widgets/recent_searches_list.dart';

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final _searchController = TextEditingController();
  String _submittedQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final companyId = authState is AuthAuthenticated ? authState.session.companyId : null;

    return AppPageScaffold(
      currentPath: '/products',
      title: 'Product Catalog',
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: () => _scanAndSearch(companyId),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(labelText: 'Search products', prefixIcon: Icon(Icons.search)),
              onSubmitted: (value) => _submitSearch(value, companyId),
            ),
          ),
          Expanded(child: _buildResultsOrRecent(companyId)),
        ],
      ),
    );
  }

  Widget _buildResultsOrRecent(String? companyId) {
    if (companyId == null) return const SizedBox.shrink();

    if (_submittedQuery.isEmpty) {
      final recentAsync = ref.watch(recentSearchesStorageProvider);
      return recentAsync.when(
        data: (storage) => FutureBuilder<List<String>>(
          future: storage.read('product'),
          builder: (context, snapshot) {
            final terms = snapshot.data ?? const [];
            return RecentSearchesList(
              terms: terms,
              onSelected: (term) {
                _searchController.text = term;
                _submitSearch(term, companyId);
              },
            );
          },
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      );
    }

    final query = ProductSearchQuery(companyId: companyId, searchString: _submittedQuery, page: 0);
    final resultAsync = ref.watch(productSearchProvider(query));

    return resultAsync.when(
      data: (result) {
        if (result.items.isEmpty) {
          return const Center(child: Text('No products found.'));
        }
        return ListView.builder(
          itemCount: result.items.length,
          itemBuilder: (context, index) {
            final product = result.items[index];
            return ProductCard(
              product: product,
              onTap: () => context.push('/products/${product.companyId}/${product.productTypeCode}/${product.productCode}'),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AppErrorView(message: error.toString(), onRetry: () => setState(() {})),
    );
  }

  void _submitSearch(String value, String? companyId) {
    if (companyId == null) return;
    setState(() => _submittedQuery = value.trim());
    ref.read(recentSearchesStorageProvider).whenData((storage) => storage.add('product', value));
  }

  Future<void> _scanAndSearch(String? companyId) async {
    const scanner = BarcodeScannerService();
    final barcode = await scanner.scan(context);
    if (barcode != null) {
      _searchController.text = barcode;
      _submitSearch(barcode, companyId);
    }
  }
}
