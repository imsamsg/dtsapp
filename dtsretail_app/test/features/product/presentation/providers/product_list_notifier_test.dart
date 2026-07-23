import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/product/domain/entities/product.dart';
import 'package:dtsretail_app/features/product/domain/repository/product_repository.dart';
import 'package:dtsretail_app/features/product/presentation/providers/product_list_notifier.dart';
import 'package:dtsretail_app/features/product/presentation/providers/product_providers.dart';

Product _product(String code) {
  return Product(
    companyId: 'BAS',
    productTypeCode: 'BOOK',
    productCode: code,
    productBarcode: '',
    productTitle: 'Product $code',
    productBrand: '',
    isEnabled: true,
    isDiscontinued: false,
    priceWithGst: 0,
    priceWithoutGst: 0,
    cost: 0,
    uom: '',
    qtyOnHand: 1,
  );
}

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository(this._pages);
  final List<List<Product>> _pages;
  int calls = 0;
  int? errorOnPage;

  @override
  Future<ProductSearchResult> search({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
    String sortBy = 'productCode',
    String sortDirection = 'asc',
  }) async {
    calls++;
    if (errorOnPage == page) throw StateError('simulated failure');
    final items = page < _pages.length ? _pages[page] : const <Product>[];
    return ProductSearchResult(items: items, totalElements: _pages.expand((p) => p).length, totalPages: _pages.length);
  }

  @override
  Future<Product> getDetail({required String companyId, required String productTypeCode, required String productCode}) {
    throw UnimplementedError();
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  const query = ProductListQuery(companyId: 'BAS', searchString: '');

  test('loads page 0 on construction and derives hasMore from totalPages', () async {
    final repo = _FakeProductRepository([
      [_product('A'), _product('B')],
      [_product('C')],
    ]);
    final container = ProviderContainer(overrides: [productRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    container.read(productListProvider(query).notifier);
    await _flush();

    final state = container.read(productListProvider(query));
    expect(state.items.map((p) => p.productCode), ['A', 'B']);
    expect(state.hasMore, isTrue);
    expect(state.isLoading, isFalse);
  });

  test('loadMore appends the next page and updates hasMore', () async {
    final repo = _FakeProductRepository([
      [_product('A')],
      [_product('B')],
    ]);
    final container = ProviderContainer(overrides: [productRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    final notifier = container.read(productListProvider(query).notifier);
    await _flush();
    await notifier.loadMore();

    final state = container.read(productListProvider(query));
    expect(state.items.map((p) => p.productCode), ['A', 'B']);
    expect(state.hasMore, isFalse);
  });

  test('loadMore is a no-op once hasMore is false', () async {
    final repo = _FakeProductRepository([
      [_product('A')],
    ]);
    final container = ProviderContainer(overrides: [productRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    final notifier = container.read(productListProvider(query).notifier);
    await _flush();
    await notifier.loadMore();
    final callsAfterFirstLoadMore = repo.calls;

    await notifier.loadMore();

    expect(repo.calls, callsAfterFirstLoadMore);
  });

  test('refresh replaces items rather than appending', () async {
    final repo = _FakeProductRepository([
      [_product('A')],
    ]);
    final container = ProviderContainer(overrides: [productRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    final notifier = container.read(productListProvider(query).notifier);
    await _flush();
    await notifier.loadMore();

    await notifier.refresh();

    final state = container.read(productListProvider(query));
    expect(state.items.map((p) => p.productCode), ['A']);
  });

  test('a failed loadMore keeps existing items and resets isLoadingMore', () async {
    final repo = _FakeProductRepository([
      [_product('A')],
      [_product('B')],
    ]);
    repo.errorOnPage = 1;
    final container = ProviderContainer(overrides: [productRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);

    final notifier = container.read(productListProvider(query).notifier);
    await _flush();

    await notifier.loadMore();

    final state = container.read(productListProvider(query));
    expect(state.items.map((p) => p.productCode), ['A']);
    expect(state.isLoadingMore, isFalse);
  });
}
