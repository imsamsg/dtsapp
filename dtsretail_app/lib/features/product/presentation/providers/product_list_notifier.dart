import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import 'product_providers.dart';

class ProductListQuery {
  const ProductListQuery({
    required this.companyId,
    required this.searchString,
    this.searchKey = 0,
    this.sortBy = 'productCode',
    this.sortDirection = 'asc',
  });

  final String companyId;
  final String searchString;
  final int searchKey;
  final String sortBy;
  final String sortDirection;

  @override
  bool operator ==(Object other) =>
      other is ProductListQuery &&
      other.companyId == companyId &&
      other.searchString == searchString &&
      other.searchKey == searchKey &&
      other.sortBy == sortBy &&
      other.sortDirection == sortDirection;

  @override
  int get hashCode => Object.hash(companyId, searchString, searchKey, sortBy, sortDirection);
}

class ProductListState {
  const ProductListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.page = 0,
  });

  final List<Product> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;
  final int page;

  /// Note: does not carry [error] through — [error] is only ever set via a
  /// fresh [ProductListState] construction in [ProductListNotifier.refresh],
  /// so any successful copyWith implicitly clears a stale error.
  ProductListState copyWith({
    List<Product>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
  }) {
    return ProductListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
    );
  }
}

class ProductListNotifier extends StateNotifier<ProductListState> {
  ProductListNotifier(this._ref, this.query) : super(const ProductListState()) {
    refresh();
  }

  final Ref _ref;
  final ProductListQuery query;
  static const _pageSize = 20;

  Future<void> refresh() async {
    state = const ProductListState(isLoading: true);
    try {
      final result = await _search(page: 0);
      state = ProductListState(items: result.items, hasMore: 1 < result.totalPages, page: 0);
    } catch (error) {
      state = ProductListState(error: error);
    }
  }

  /// A failed [loadMore] deliberately keeps existing items and does not set
  /// [ProductListState.error] — that field's meaning is "the whole list
  /// failed to load" (drives [AppErrorView] in the page). A load-more
  /// failure instead silently resets [ProductListState.isLoadingMore],
  /// letting the next near-bottom scroll retry.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _search(page: nextPage);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false,
        hasMore: nextPage + 1 < result.totalPages,
        page: nextPage,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<ProductSearchResult> _search({required int page}) {
    return _ref.read(searchProductsUsecaseProvider)(
      companyId: query.companyId,
      searchString: query.searchString.isEmpty ? null : query.searchString,
      searchKey: query.searchKey,
      page: page,
      size: _pageSize,
      sortBy: query.sortBy,
      sortDirection: query.sortDirection,
    );
  }
}

final productListProvider = StateNotifierProvider.family<ProductListNotifier, ProductListState, ProductListQuery>(
  (ref, query) => ProductListNotifier(ref, query),
);
