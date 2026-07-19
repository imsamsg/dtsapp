import '../entities/product.dart';
import '../repository/product_repository.dart';

class GetProductDetailUsecase {
  GetProductDetailUsecase(this._repository);

  final ProductRepository _repository;

  Future<Product> call({required String companyId, required String productTypeCode, required String productCode}) {
    return _repository.getDetail(companyId: companyId, productTypeCode: productTypeCode, productCode: productCode);
  }
}
