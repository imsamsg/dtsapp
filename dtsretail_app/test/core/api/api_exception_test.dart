import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/core/api/api_exception.dart';

void main() {
  group('ApiException.fromDioException', () {
    test('maps connection timeout to NetworkException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );
      expect(ApiException.fromDioException(dioException), isA<NetworkException>());
    });

    test('maps 401 response to UnauthorizedException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(requestOptions: RequestOptions(path: '/test'), statusCode: 401),
        type: DioExceptionType.badResponse,
      );
      expect(ApiException.fromDioException(dioException), isA<UnauthorizedException>());
    });

    test('maps 400 response with error body to ApiValidationException with message', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
          data: {'error': 'Stock count not found'},
        ),
        type: DioExceptionType.badResponse,
      );
      final result = ApiException.fromDioException(dioException);
      expect(result, isA<ApiValidationException>());
      expect((result as ApiValidationException).message, 'Stock count not found');
    });

    test('maps 500 response to ServerException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(requestOptions: RequestOptions(path: '/test'), statusCode: 500),
        type: DioExceptionType.badResponse,
      );
      expect(ApiException.fromDioException(dioException), isA<ServerException>());
    });
  });
}
