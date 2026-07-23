import '../datasource/remote/product_remote_datasource.dart';
import '../mappers/product_mapper.dart';
import '../../domain/entities/product.dart';
import '../../domain/repository/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._remote);

  final ProductRemoteDatasource _remote;

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
    final dto = await _remote.search(
      companyId: companyId,
      searchString: searchString,
      searchKey: searchKey,
      page: page,
      size: size,
      sortBy: sortBy,
      sortDirection: sortDirection,
    );
    return dto.toDomain();
  }

  @override
  Future<Product> getDetail({
    required String companyId,
    required String productTypeCode,
    required String productCode,
  }) async {
    final dto = await _remote.getDetail(companyId: companyId, productTypeCode: productTypeCode, productCode: productCode);
    return dto.toDomain();
  }
}
