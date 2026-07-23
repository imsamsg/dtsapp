import 'package:dio/dio.dart';
import '../../../../../core/api/api_call_guard.dart';
import '../../models/stock_count_dto.dart';

class StockCountRemoteDatasource {
  StockCountRemoteDatasource(this._dio);

  final Dio _dio;

  // NOTE: dtsapi's StockCountController wraps search/getById/create/update
  // responses in a common ApiResponse envelope ({success, data, message}) —
  // verified against com.dts.webapi.inventory.controller.StockCountController
  // in the dtsapi source. All four methods below unwrap `data` accordingly
  // (unlike Product's GET endpoints, which return the DTO directly).

  Future<StockCountSearchResponseDto> search({
    required String companyId,
    required String branchId,
    String? status,
    String? warehouse,
    int page = 0,
    int size = 20,
  }) {
    return guardApiCall(() async {
      final response = await _dio.get('/inventory/stock-counts/search', queryParameters: {
        'companyId': companyId,
        'branchId': branchId,
        if (status != null) 'status': status,
        if (warehouse != null) 'warehouse': warehouse,
        'page': page,
        'size': size,
      });
      final body = response.data as Map<String, dynamic>;
      return StockCountSearchResponseDto.fromJson(body['data'] as Map<String, dynamic>);
    });
  }

  Future<StockCountDto> getDetail({required String companyId, required String branchId, required String stockcntId}) {
    return guardApiCall(() async {
      final response = await _dio.get('/inventory/stock-counts/$companyId/$branchId/$stockcntId');
      final body = response.data as Map<String, dynamic>;
      return StockCountDto.fromJson(body['data'] as Map<String, dynamic>);
    });
  }

  Future<StockCountDto> create(StockCountDto dto, {required String userId}) {
    return guardApiCall(() async {
      final response = await _dio.post(
        '/inventory/stock-counts',
        data: dto.toJson(),
        options: Options(headers: {'X-User-Id': userId}),
      );
      final body = response.data as Map<String, dynamic>;
      return StockCountDto.fromJson(body['data'] as Map<String, dynamic>);
    });
  }

  Future<StockCountDto> update(
    StockCountDto dto, {
    required String companyId,
    required String branchId,
    required String stockcntId,
    required String userId,
  }) {
    return guardApiCall(() async {
      final response = await _dio.put(
        '/inventory/stock-counts/$companyId/$branchId/$stockcntId',
        data: dto.toJson(),
        options: Options(headers: {'X-User-Id': userId}),
      );
      final body = response.data as Map<String, dynamic>;
      return StockCountDto.fromJson(body['data'] as Map<String, dynamic>);
    });
  }
}
