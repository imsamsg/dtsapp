import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/product/domain/entities/product.dart';
import 'package:dtsretail_app/features/product/domain/repository/product_repository.dart';
import 'package:dtsretail_app/features/product/domain/usecases/search_products_usecase.dart';

class _FakeProductRepository implements ProductRepository {
  String? capturedSortBy;
  String? capturedSortDirection;
  int? capturedPage;

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
    capturedSortBy = sortBy;
    capturedSortDirection = sortDirection;
    capturedPage = page;
    return const ProductSearchResult(items: [], totalElements: 0, totalPages: 0);
  }

  @override
  Future<Product> getDetail({required String companyId, required String productTypeCode, required String productCode}) {
    throw UnimplementedError();
  }
}

void main() {
  test('SearchProductsUsecase defaults sortBy/sortDirection to productCode/asc', () async {
    final repo = _FakeProductRepository();
    final usecase = SearchProductsUsecase(repo);

    await usecase(companyId: 'BAS');

    expect(repo.capturedSortBy, 'productCode');
    expect(repo.capturedSortDirection, 'asc');
  });

  test('SearchProductsUsecase forwards a custom sortBy/sortDirection/page', () async {
    final repo = _FakeProductRepository();
    final usecase = SearchProductsUsecase(repo);

    await usecase(companyId: 'BAS', sortBy: 'productPriceWgst', sortDirection: 'desc', page: 2);

    expect(repo.capturedSortBy, 'productPriceWgst');
    expect(repo.capturedSortDirection, 'desc');
    expect(repo.capturedPage, 2);
  });
}
