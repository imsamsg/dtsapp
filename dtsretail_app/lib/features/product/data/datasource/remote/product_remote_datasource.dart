import 'package:dio/dio.dart';
import '../../models/product_dto.dart';

class ProductRemoteDatasource {
  ProductRemoteDatasource(this._dio);

  final Dio _dio;

  Future<ProductSearchResponseDto> search({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get('/inventory/products/search', queryParameters: {
      'companyId': companyId,
      if (searchString != null && searchString.isNotEmpty) 'searchString': searchString,
      'searchKey': searchKey,
      'page': page,
      'size': size,
    });
    return ProductSearchResponseDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ProductDto> getDetail({
    required String companyId,
    required String productTypeCode,
    required String productCode,
  }) async {
    final response = await _dio.get('/inventory/products/$companyId/$productTypeCode/$productCode');
    return ProductDto.fromJson(response.data as Map<String, dynamic>);
  }
}
