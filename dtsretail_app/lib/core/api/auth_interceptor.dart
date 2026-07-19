import 'package:dio/dio.dart';
import '../storage/secure_token_storage.dart';
import '../../features/authentication/domain/entities/auth_session.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._storage, this._refresh, this._onRefreshFailed);

  final Dio _dio;
  final SecureTokenStorage _storage;
  final Future<AuthSession?> Function(String refreshToken) _refresh;
  final void Function() _onRefreshFailed;

  bool _isRefreshing = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final session = await _storage.readSession();
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;

    if (!isUnauthorized || alreadyRetried || _isRefreshing) {
      if (isUnauthorized && !alreadyRetried) {
        _onRefreshFailed();
      }
      handler.next(err);
      return;
    }

    _isRefreshing = true;
    try {
      final session = await _storage.readSession();
      if (session == null) {
        _onRefreshFailed();
        handler.next(err);
        return;
      }

      final refreshed = await _refresh(session.refreshToken);
      if (refreshed == null) {
        await _storage.clear();
        _onRefreshFailed();
        handler.next(err);
        return;
      }

      await _storage.saveSession(refreshed);

      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';
      retryOptions.extra['retried'] = true;
      final response = await _dio.fetch(retryOptions);
      handler.resolve(response);
    } catch (_) {
      await _storage.clear();
      _onRefreshFailed();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }
}
