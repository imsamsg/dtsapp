import 'package:dio/dio.dart';
import '../../../../../core/api/api_call_guard.dart';
import '../../models/login_request_dto.dart';
import '../../models/login_response_dto.dart';

class AuthRemoteDatasource {
  AuthRemoteDatasource(this._dio);

  final Dio _dio;

  Future<LoginResponseDto> login(LoginRequestDto request) {
    return guardApiCall(() async {
      final response = await _dio.post('/auth/login', data: request.toJson());
      return LoginResponseDto.fromJson(response.data as Map<String, dynamic>);
    });
  }

  Future<LoginResponseDto> refresh(String refreshToken) {
    return guardApiCall(() async {
      final response = await _dio.post(
        '/auth/refresh',
        options: Options(headers: {'X-Refresh-Token': refreshToken}),
      );
      return LoginResponseDto.fromJson(response.data as Map<String, dynamic>);
    });
  }

  Future<void> revoke(String refreshToken) {
    return guardApiCall(() async {
      await _dio.post(
        '/auth/revoke',
        options: Options(headers: {'X-Refresh-Token': refreshToken}),
      );
    });
  }
}
