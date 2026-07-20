import 'package:dio/dio.dart';
import 'api_exception.dart';

/// Runs [call] and translates any [DioException] it throws into the
/// corresponding [ApiException].
///
/// This runs strictly after Dio's own interceptor chain (including
/// [AuthInterceptor]'s 401 refresh-and-retry logic) has already finished:
/// datasource methods only see a [DioException] once Dio has given up on it,
/// so wrapping it here can never short-circuit a token refresh.
///
/// Without this, raw [DioException]s (including internal request URLs)
/// propagate all the way to the UI, which otherwise has no way to show a
/// friendly, differentiated error message.
Future<T> guardApiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiException.fromDioException(e);
  }
}
