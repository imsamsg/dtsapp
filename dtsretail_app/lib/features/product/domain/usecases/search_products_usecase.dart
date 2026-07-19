import '../entities/product.dart';
import '../repository/product_repository.dart';

class SearchProductsUsecase {
  SearchProductsUsecase(this._repository);

  final ProductRepository _repository;

  Future<ProductSearchResult> call({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
  }) {
    return _repository.search(
      companyId: companyId,
      searchString: searchString,
      searchKey: searchKey,
      page: page,
      size: size,
    );
  }
}
