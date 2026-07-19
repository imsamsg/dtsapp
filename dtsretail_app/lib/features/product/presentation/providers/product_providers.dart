import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../data/datasource/remote/product_remote_datasource.dart';
import '../../data/repository/product_repository_impl.dart';
import '../../domain/entities/product.dart';
import '../../domain/repository/product_repository.dart';
import '../../domain/usecases/get_product_detail_usecase.dart';
import '../../domain/usecases/search_products_usecase.dart';

final productRemoteDatasourceProvider = Provider((ref) => ProductRemoteDatasource(ref.watch(dioClientProvider)));

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(ref.watch(productRemoteDatasourceProvider));
});

final searchProductsUsecaseProvider = Provider((ref) => SearchProductsUsecase(ref.watch(productRepositoryProvider)));
final getProductDetailUsecaseProvider = Provider((ref) => GetProductDetailUsecase(ref.watch(productRepositoryProvider)));

class ProductSearchQuery {
  const ProductSearchQuery({required this.companyId, required this.searchString, required this.page});
  final String companyId;
  final String searchString;
  final int page;

  @override
  bool operator ==(Object other) =>
      other is ProductSearchQuery && other.companyId == companyId && other.searchString == searchString && other.page == page;

  @override
  int get hashCode => Object.hash(companyId, searchString, page);
}

final productSearchProvider = FutureProvider.family<ProductSearchResult, ProductSearchQuery>((ref, query) {
  return ref.watch(searchProductsUsecaseProvider)(
    companyId: query.companyId,
    searchString: query.searchString.isEmpty ? null : query.searchString,
    page: query.page,
  );
});

final productDetailProvider = FutureProvider.family<Product, ({String companyId, String productTypeCode, String productCode})>(
  (ref, args) {
    return ref.watch(getProductDetailUsecaseProvider)(
      companyId: args.companyId,
      productTypeCode: args.productTypeCode,
      productCode: args.productCode,
    );
  },
);
