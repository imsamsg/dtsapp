import 'package:dio/dio.dart';

sealed class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  factory ApiException.fromDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkException('Unable to reach the server. Check your connection.');
    }

    final statusCode = e.response?.statusCode;
    if (statusCode == 401) {
      return const UnauthorizedException('Session expired. Please log in again.');
    }
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      return ApiValidationException(_extractMessage(e) ?? 'Request could not be processed.');
    }
    if (statusCode != null && statusCode >= 500) {
      return const ServerException('Server error. Please try again later.');
    }
    return const NetworkException('Unexpected network error.');
  }

  static String? _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return null;
  }
}

final class NetworkException extends ApiException {
  const NetworkException(super.message);
}

final class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message);
}

final class ApiValidationException extends ApiException {
  const ApiValidationException(super.message);
}

final class ServerException extends ApiException {
  const ServerException(super.message);
}
