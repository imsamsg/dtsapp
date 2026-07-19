import '../entities/product.dart';

abstract interface class ProductRepository {
  Future<ProductSearchResult> search({
    required String companyId,
    String? searchString,
    int searchKey,
    int page,
    int size,
  });

  Future<Product> getDetail({
    required String companyId,
    required String productTypeCode,
    required String productCode,
  });
}
