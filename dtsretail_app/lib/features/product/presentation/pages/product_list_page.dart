import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/services/barcode_scanner_service.dart';
import '../../../../core/storage/recent_searches_storage.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/product_list_notifier.dart';
import '../widgets/product_card.dart';

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key, this.initialSearch});

  final String? initialSearch;

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _SortOption {
  const _SortOption(this.label, this.sortBy, this.sortDirection);
  final String label;
  final String sortBy;
  final String sortDirection;
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _submittedQuery = '';
  int _searchKey = 0;
  String _sortBy = 'productCode';
  String _sortDirection = 'asc';
  Timer? _debounce;

  static const _searchKeyLabels = {0: 'Any', 1: 'Code', 3: 'Barcode', 4: 'Title'};
  static const _sortOptions = [
    _SortOption('Code A-Z', 'productCode', 'asc'),
    _SortOption('Title A-Z', 'productTitle', 'asc'),
    _SortOption('Title Z-A', 'productTitle', 'desc'),
    _SortOption('Price Low-High', 'productPriceWgst', 'asc'),
    _SortOption('Price High-Low', 'productPriceWgst', 'desc'),
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSearch?.trim();
    if (initial != null && initial.isNotEmpty) {
      _searchController.text = initial;
      _submittedQuery = initial;
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_submittedQuery.isEmpty) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      final companyId = _companyId();
      if (companyId != null) {
        ref.read(productListProvider(_query(companyId)).notifier).loadMore();
      }
    }
  }

  String? _companyId() {
    final authState = ref.read(authStateProvider);
    return authState is AuthAuthenticated ? authState.session.companyId : null;
  }

  ProductListQuery _query(String companyId) {
    return ProductListQuery(
      companyId: companyId,
      searchString: _submittedQuery,
      searchKey: _searchKey,
      sortBy: _sortBy,
      sortDirection: _sortDirection,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final companyId = authState is AuthAuthenticated ? authState.session.companyId : null;

    return AppPageScaffold(
      currentPath: '/products',
      title: 'Product Catalog',
      actions: [IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: () => _scanAndSearch(companyId))],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search products',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => _onSearchChanged(value, companyId),
              onSubmitted: (value) => _submitSearch(value, companyId),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(child: _searchKeyDropdown(companyId)),
                const SizedBox(width: 8),
                Expanded(child: _sortDropdown(companyId)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: _buildResultsOrRecent(companyId)),
        ],
      ),
    );
  }

  // DropdownButtonFormField's `initialValue` only seeds the field's FIRST
  // build; visual updates thereafter flow through its own internal
  // FormFieldState via the `onChanged` callback below (which this widget
  // also uses to update `_searchKey`/`_sortBy`/`_sortDirection`), not through
  // rebuilding with a new `initialValue`. No extra sync code needed.
  Widget _searchKeyDropdown(String? companyId) {
    return DropdownButtonFormField<int>(
      initialValue: _searchKey,
      decoration: InputDecoration(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: _searchKeyLabels.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _searchKey = value);
        if (_submittedQuery.isNotEmpty) _submitSearch(_submittedQuery, companyId);
      },
    );
  }

  Widget _sortDropdown(String? companyId) {
    final currentIndex = _sortOptions.indexWhere((o) => o.sortBy == _sortBy && o.sortDirection == _sortDirection);
    return DropdownButtonFormField<int>(
      initialValue: currentIndex,
      decoration: InputDecoration(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: [for (var i = 0; i < _sortOptions.length; i++) DropdownMenuItem(value: i, child: Text(_sortOptions[i].label))],
      onChanged: (value) {
        if (value == null) return;
        final option = _sortOptions[value];
        setState(() {
          _sortBy = option.sortBy;
          _sortDirection = option.sortDirection;
        });
        if (_submittedQuery.isNotEmpty) _submitSearch(_submittedQuery, companyId);
      },
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
            if (terms.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: terms
                    .map(
                      (term) => ActionChip(
                        avatar: const Icon(Icons.history, size: 16),
                        label: Text(term),
                        onPressed: () {
                          _searchController.text = term;
                          _submitSearch(term, companyId);
                        },
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      );
    }

    final query = _query(companyId);
    final state = ref.watch(productListProvider(query));

    if (state.error != null) {
      return AppErrorView(
        message: 'Unable to load products. Please try again.',
        onRetry: () => ref.read(productListProvider(query).notifier).refresh(),
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      return const _EmptyResults();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(productListProvider(query).notifier).refresh(),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
          }
          final product = state.items[index];
          return ProductCard(
            product: product,
            onTap: () => context.push('/products/${product.companyId}/${product.productTypeCode}/${product.productCode}'),
          );
        },
      ),
    );
  }

  void _onSearchChanged(String value, String? companyId) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _submitSearch(value, companyId));
  }

  void _submitSearch(String value, String? companyId) {
    _debounce?.cancel();
    if (companyId == null) return;
    setState(() => _submittedQuery = value.trim());
    if (_submittedQuery.isNotEmpty) {
      ref.read(recentSearchesStorageProvider).whenData((storage) => storage.add('product', _submittedQuery));
    }
  }

  Future<void> _scanAndSearch(String? companyId) async {
    final scanner = ref.read(barcodeScannerServiceProvider);
    final barcode = await scanner.scan(context);
    if (barcode != null) {
      _searchController.text = barcode;
      _submitSearch(barcode, companyId);
    }
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.neutral.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          const Text('No products found.'),
        ],
      ),
    );
  }
}
