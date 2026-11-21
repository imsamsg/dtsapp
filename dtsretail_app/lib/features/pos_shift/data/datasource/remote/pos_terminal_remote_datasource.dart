import 'package:dio/dio.dart';
import '../../../../../core/api/api_call_guard.dart';
import '../../models/pos_terminal_dto.dart';

class PosTerminalRemoteDatasource {
  PosTerminalRemoteDatasource(this._dio);

  final Dio _dio;

  Future<List<PosTerminalDto>> getTerminalsByBranch({required String companyId, required String branchId}) {
    return guardApiCall(() async {
      final response = await _dio.get('/pos/terminals/branch/$companyId/$branchId');
      final list = response.data as List;
      return list.map((e) => PosTerminalDto.fromJson(e as Map<String, dynamic>)).toList();
    });
  }
}
