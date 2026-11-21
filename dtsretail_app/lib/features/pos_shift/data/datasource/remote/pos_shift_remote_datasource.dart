import 'package:dio/dio.dart';
import '../../../../../core/api/api_call_guard.dart';
import '../../models/pos_shift_dto.dart';

class PosShiftRemoteDatasource {
  PosShiftRemoteDatasource(this._dio);

  final Dio _dio;

  Future<List<PosShiftDto>> search({
    required String companyId,
    required String branchId,
    String? terminalId,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return guardApiCall(() async {
      final response = await _dio.get('/pos/posshifts', queryParameters: {
        'companyId': companyId,
        'branchId': branchId,
        if (terminalId != null) 'terminalId': terminalId,
        if (fromDate != null) 'fromDate': _formatDate(fromDate),
        if (toDate != null) 'toDate': _formatDate(toDate),
      });
      final body = response.data as Map<String, dynamic>;
      final list = body['data'] as List;
      return list.map((e) => PosShiftDto.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
