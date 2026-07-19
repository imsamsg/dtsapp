import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/core/api/auth_interceptor.dart';
import 'package:dtsretail_app/core/storage/secure_token_storage.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

AuthSession _session(String accessToken) => AuthSession(
      loginId: 'SAM',
      firstName: 'Sam',
      lastName: 'Tan',
      fullName: 'Sam Tan',
      companyId: 'BAS',
      branchId: 'BAS1',
      roleName: 'STAFF',
      features: const [],
      accessToken: accessToken,
      refreshToken: 'refresh-1',
      accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> fakeStore = {};

  setUp(() {
    fakeStore.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'write':
          fakeStore[call.arguments['key']] = call.arguments['value'];
          return null;
        case 'read':
          return fakeStore[call.arguments['key']];
        case 'delete':
          fakeStore.remove(call.arguments['key']);
          return null;
        default:
          return null;
      }
    });
  });

  test('attaches Authorization header from stored session', () async {
    final storage = SecureTokenStorage(const FlutterSecureStorage());
    await storage.saveSession(_session('access-123'));

    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.httpClientAdapter = _RecordingAdapter();
    final interceptor = AuthInterceptor(
      dio,
      storage,
      (refreshToken) async => _session('access-999'),
      () {},
    );
    dio.interceptors.add(interceptor);

    try {
      await dio.get('/inventory/products/search');
    } catch (_) {
      // adapter throws after recording; ignore
    }

    expect(_RecordingAdapter.lastHeaders?['Authorization'], 'Bearer access-123');
  });

  test('on 401 refreshes token and retries once with new token', () async {
    final storage = SecureTokenStorage(const FlutterSecureStorage());
    await storage.saveSession(_session('expired-token'));

    var refreshCalls = 0;
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.httpClientAdapter = _OneTimeUnauthorizedAdapter();
    final interceptor = AuthInterceptor(
      dio,
      storage,
      (refreshToken) async {
        refreshCalls++;
        return _session('refreshed-token');
      },
      () {},
    );
    dio.interceptors.add(interceptor);

    final response = await dio.get('/inventory/products/search');

    expect(refreshCalls, 1);
    expect(response.statusCode, 200);
    final saved = await storage.readSession();
    expect(saved?.accessToken, 'refreshed-token');
  });

  test('calls onRefreshFailed and does not retry when refresh throws', () async {
    final storage = SecureTokenStorage(const FlutterSecureStorage());
    await storage.saveSession(_session('expired-token'));

    var refreshFailedCalled = false;
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.httpClientAdapter = _AlwaysUnauthorizedAdapter();
    final interceptor = AuthInterceptor(
      dio,
      storage,
      (refreshToken) async => throw Exception('refresh rejected'),
      () => refreshFailedCalled = true,
    );
    dio.interceptors.add(interceptor);

    await expectLater(dio.get('/inventory/products/search'), throwsA(isA<DioException>()));
    expect(refreshFailedCalled, isTrue);
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  static Map<String, dynamic>? lastHeaders;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastHeaders = options.headers;
    throw Exception('stop after recording');
  }
}

class _OneTimeUnauthorizedAdapter implements HttpClientAdapter {
  int _calls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _calls++;
    if (_calls == 1) {
      return ResponseBody.fromString('{"error":"unauthorized"}', 401,
          headers: {Headers.contentTypeHeader: ['application/json']});
    }
    return ResponseBody.fromString('{"result":"ok"}', 200,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }
}

class _AlwaysUnauthorizedAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{"error":"unauthorized"}', 401,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }
}
