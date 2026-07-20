import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/core/api/api_call_guard.dart';
import 'package:dtsretail_app/core/api/api_exception.dart';

void main() {
  group('guardApiCall', () {
    test('returns the value when the call succeeds', () async {
      final result = await guardApiCall(() async => 42);
      expect(result, 42);
    });

    test('translates a connection-error DioException into a NetworkException', () async {
      Future<int> throwing() async {
        throw DioException(
          requestOptions: RequestOptions(path: 'http://10.0.2.2:8081/inventory/products/search'),
          type: DioExceptionType.connectionError,
        );
      }

      await expectLater(guardApiCall(throwing), throwsA(isA<NetworkException>()));
    });

    test('translates a 401 response into an UnauthorizedException', () async {
      Future<int> throwing() async {
        throw DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: Response(requestOptions: RequestOptions(path: '/test'), statusCode: 401),
          type: DioExceptionType.badResponse,
        );
      }

      await expectLater(guardApiCall(throwing), throwsA(isA<UnauthorizedException>()));
    });

    test('lets non-Dio exceptions propagate unchanged', () async {
      Future<int> throwing() async => throw StateError('boom');
      await expectLater(guardApiCall(throwing), throwsA(isA<StateError>()));
    });
  });
}
