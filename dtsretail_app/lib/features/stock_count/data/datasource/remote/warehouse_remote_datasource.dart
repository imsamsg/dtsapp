import 'package:dio/dio.dart';
import '../../../../../core/api/api_call_guard.dart';
import '../../models/warehouse_dto.dart';

class WarehouseRemoteDatasource {
  WarehouseRemoteDatasource(this._dio);

  final Dio _dio;

  Future<List<WarehouseDto>> getAll({required String companyId}) {
    return guardApiCall(() async {
      final response = await _dio.get('/inventory/warehouses', queryParameters: {'companyId': companyId});
      final list = response.data as List;
      return list.map((e) => WarehouseDto.fromJson(e as Map<String, dynamic>)).toList();
    });
  }
}
