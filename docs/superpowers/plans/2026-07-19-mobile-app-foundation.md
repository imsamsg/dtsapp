# dtsretail-app Mobile Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the `dtsretail-app` Flutter mobile app (Android) with feature-first architecture, wired to the existing `dtsapi` backend: login, dashboard, Product Catalog, and Stock Count (no Approve — see spec).

**Architecture:** Feature-first Clean Architecture (`data/domain/presentation` per feature) with Riverpod for state, GoRouter (`StatefulShellRoute`) for bottom-nav routing, Dio for API access with an auth-refresh interceptor, Freezed/json_serializable for DTOs, a mapper layer converting DTOs to domain entities so UI never touches raw JSON shapes.

**Tech Stack:** Flutter 3.32.1 / Dart 3.8.1, flutter_riverpod, go_router, dio, freezed + json_serializable, flutter_secure_storage, shared_preferences, mobile_scanner, build_runner.

## Global Constraints

- Base API URL: `http://<host>:8081/api/v1/` (configurable, not hardcoded — see Task 2).
- `dtsapi` is **never modified** by this plan.
- No local business-data database (Hive/Isar) in this pass — only `shared_preferences` for recent searches (non-business, device-local UX cache).
- No Approve action for Stock Count in this pass.
- Every feature follows `data/{datasource/remote,repository,models,mappers}`, `domain/{entities,repository,usecases}`, `presentation/{pages,widgets,providers}`.
- Android phone is the only target configured in this pass.

---

## File Structure

```
dtsretail_app/
  pubspec.yaml
  lib/
    main.dart
    app/
      app.dart
      router.dart
      theme/app_theme.dart
      constants/api_constants.dart
    core/
      api/dio_client.dart
      api/api_exception.dart
      api/auth_interceptor.dart
      storage/secure_token_storage.dart
      storage/recent_searches_storage.dart
      services/barcode_scanner_service.dart
      widgets/app_loading.dart
      widgets/app_error_view.dart
      widgets/app_empty_state.dart
    features/
      authentication/
        data/models/login_request_dto.dart
        data/models/login_response_dto.dart
        data/datasource/remote/auth_remote_datasource.dart
        data/mappers/auth_session_mapper.dart
        data/repository/auth_repository_impl.dart
        domain/entities/auth_session.dart
        domain/repository/auth_repository.dart
        domain/usecases/login_usecase.dart
        domain/usecases/logout_usecase.dart
        domain/usecases/refresh_token_usecase.dart
        presentation/providers/auth_providers.dart
        presentation/pages/login_page.dart
      dashboard/
        presentation/pages/dashboard_page.dart
        presentation/widgets/greeting_header.dart
        presentation/widgets/session_info_card.dart
        presentation/widgets/quick_actions_grid.dart
        presentation/widgets/feature_tile.dart
      product/
        data/models/product_dto.dart
        data/datasource/remote/product_remote_datasource.dart
        data/mappers/product_mapper.dart
        data/repository/product_repository_impl.dart
        domain/entities/product.dart
        domain/repository/product_repository.dart
        domain/usecases/search_products_usecase.dart
        domain/usecases/get_product_detail_usecase.dart
        presentation/providers/product_providers.dart
        presentation/pages/product_list_page.dart
        presentation/pages/product_detail_page.dart
        presentation/widgets/product_card.dart
        presentation/widgets/recent_searches_list.dart
      stock_count/
        data/models/stock_count_dto.dart
        data/models/stock_count_line_dto.dart
        data/models/warehouse_dto.dart
        data/datasource/remote/stock_count_remote_datasource.dart
        data/datasource/remote/warehouse_remote_datasource.dart
        data/mappers/stock_count_mapper.dart
        data/repository/stock_count_repository_impl.dart
        domain/entities/stock_count.dart
        domain/entities/stock_count_line.dart
        domain/entities/warehouse.dart
        domain/repository/stock_count_repository.dart
        domain/usecases/search_stock_counts_usecase.dart
        domain/usecases/get_stock_count_detail_usecase.dart
        domain/usecases/create_stock_count_usecase.dart
        domain/usecases/update_stock_count_usecase.dart
        presentation/providers/stock_count_providers.dart
        presentation/pages/stock_count_list_page.dart
        presentation/pages/stock_count_detail_page.dart
        presentation/pages/stock_count_form_page.dart
        presentation/widgets/stock_count_card.dart
        presentation/widgets/warehouse_selector.dart
        presentation/widgets/barcode_scan_line_entry.dart
      profile/
        presentation/pages/profile_page.dart
    shared/
      widgets/app_scaffold.dart
  test/
    core/api/auth_interceptor_test.dart
    features/authentication/domain/login_usecase_test.dart
    features/authentication/presentation/login_page_test.dart
    features/product/data/mappers/product_mapper_test.dart
    features/product/presentation/product_list_page_test.dart
    features/stock_count/data/mappers/stock_count_mapper_test.dart
    features/stock_count/presentation/stock_count_list_page_test.dart
```

---

## Task 1: Create Flutter project and add dependencies

**Files:**
- Create: `D:\Project\dtsretail-app\dtsretail_app\` (Flutter project root, via `flutter create`)
- Modify: `dtsretail_app/pubspec.yaml`

**Interfaces:**
- Produces: a runnable Flutter project skeleton with all packages this plan depends on already resolved, so every later task can `import` them without touching `pubspec.yaml` again.

- [ ] **Step 1: Create the Flutter project**

Run (from `D:\Project\dtsretail-app`):
```bash
flutter create --platforms=android --org com.dtsretail dtsretail_app
```
Expected: `dtsretail_app/` created with `lib/main.dart`, `android/`, `pubspec.yaml`.

- [ ] **Step 2: Add dependencies to `pubspec.yaml`**

Edit `dtsretail_app/pubspec.yaml`, replace the `dependencies:` and `dev_dependencies:` sections with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.0
  dio: ^5.4.3+1
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  flutter_secure_storage: ^9.2.2
  shared_preferences: ^2.2.3
  mobile_scanner: ^5.2.3
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.9
  freezed: ^2.5.2
  json_serializable: ^6.8.0
  mockito: ^5.4.4
```

- [ ] **Step 3: Fetch packages**

Run: `cd dtsretail_app && flutter pub get`
Expected: `Got dependencies!` with no version solving errors. If a version conflict is reported, bump the conflicting package to the version `flutter pub get` suggests — do not downgrade `flutter_riverpod`, `go_router`, or `dio` below the majors listed above.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock android ios lib test .gitignore
git commit -m "Scaffold Flutter project with core dependencies"
```

---

## Task 2: API constants, Dio client, and typed exceptions

**Files:**
- Create: `lib/app/constants/api_constants.dart`
- Create: `lib/core/api/api_exception.dart`
- Create: `lib/core/api/dio_client.dart`
- Test: `test/core/api/api_exception_test.dart`

**Interfaces:**
- Produces: `ApiConstants.baseUrl`; `ApiException` (sealed class) with subtypes `NetworkException`, `UnauthorizedException`, `ApiValidationException(String message)`, `ServerException`; `ApiException.fromDioException(DioException e) → ApiException`; `dioClientProvider → Provider<Dio>`.

- [ ] **Step 1: Write the failing test for exception mapping**

Create `test/core/api/api_exception_test.dart`:
```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/api/api_exception_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:dtsretail_app/core/api/api_exception.dart'`

- [ ] **Step 3: Create `lib/app/constants/api_constants.dart`**

```dart
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8081/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
```
Note: `10.0.2.2` is the Android emulator's alias for the host machine's `localhost`. Override with `--dart-define=API_BASE_URL=http://<lan-ip>:8081/api/v1` when running on a physical device.

- [ ] **Step 4: Create `lib/core/api/api_exception.dart`**

```dart
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
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/api/api_exception_test.dart`
Expected: `00:0X +4: All tests passed!`

- [ ] **Step 6: Create `lib/core/api/dio_client.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/constants/api_constants.dart';

final dioClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      contentType: 'application/json',
    ),
  );
  return dio;
});
```

- [ ] **Step 7: Commit**

```bash
git add lib/app/constants/api_constants.dart lib/core/api/api_exception.dart lib/core/api/dio_client.dart test/core/api/api_exception_test.dart
git commit -m "Add API constants, Dio client, and typed exception mapping"
```

---

## Task 3: Secure token storage and auth session model

**Files:**
- Create: `lib/features/authentication/domain/entities/auth_session.dart`
- Create: `lib/core/storage/secure_token_storage.dart`
- Test: `test/core/storage/secure_token_storage_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `AuthSession` (Freezed, fields: `loginId, firstName, lastName, fullName, companyId, branchId, roleName, features (List<String>), accessToken, refreshToken, accessTokenExpiresAt (DateTime)`); `SecureTokenStorage` with `Future<void> saveSession(AuthSession session)`, `Future<AuthSession?> readSession()`, `Future<void> clear()`; `secureTokenStorageProvider`.

- [ ] **Step 1: Create the `AuthSession` entity**

Create `lib/features/authentication/domain/entities/auth_session.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_session.freezed.dart';

@freezed
class AuthSession with _$AuthSession {
  const factory AuthSession({
    required String loginId,
    required String firstName,
    required String lastName,
    required String fullName,
    required String companyId,
    required String branchId,
    required String roleName,
    required List<String> features,
    required String accessToken,
    required String refreshToken,
    required DateTime accessTokenExpiresAt,
  }) = _AuthSession;

  const AuthSession._();

  bool get isAccessTokenExpired => DateTime.now().isAfter(accessTokenExpiresAt);
}
```

- [ ] **Step 2: Generate Freezed code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/features/authentication/domain/entities/auth_session.freezed.dart` generated, no errors.

- [ ] **Step 3: Write the failing test for `SecureTokenStorage`**

Create `test/core/storage/secure_token_storage_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dtsretail_app/core/storage/secure_token_storage.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';

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
        case 'deleteAll':
          fakeStore.clear();
          return null;
        default:
          return null;
      }
    });
  });

  test('saveSession then readSession round-trips the session', () async {
    final storage = SecureTokenStorage(const FlutterSecureStorage());
    final session = AuthSession(
      loginId: 'SAM',
      firstName: 'Sam',
      lastName: 'Tan',
      fullName: 'Sam Tan',
      companyId: 'BAS',
      branchId: 'BAS1',
      roleName: 'STAFF',
      features: const ['PRODUCT_VIEW', 'STOCK_COUNT'],
      accessToken: 'access-123',
      refreshToken: 'refresh-456',
      accessTokenExpiresAt: DateTime.utc(2026, 1, 1, 12),
    );

    await storage.saveSession(session);
    final result = await storage.readSession();

    expect(result, session);
  });

  test('readSession returns null when nothing stored', () async {
    final storage = SecureTokenStorage(const FlutterSecureStorage());
    expect(await storage.readSession(), isNull);
  });

  test('clear removes the stored session', () async {
    final storage = SecureTokenStorage(const FlutterSecureStorage());
    final session = AuthSession(
      loginId: 'SAM',
      firstName: 'Sam',
      lastName: 'Tan',
      fullName: 'Sam Tan',
      companyId: 'BAS',
      branchId: 'BAS1',
      roleName: 'STAFF',
      features: const [],
      accessToken: 'a',
      refreshToken: 'r',
      accessTokenExpiresAt: DateTime.utc(2026, 1, 1),
    );
    await storage.saveSession(session);
    await storage.clear();
    expect(await storage.readSession(), isNull);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/core/storage/secure_token_storage_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:dtsretail_app/core/storage/secure_token_storage.dart'`

- [ ] **Step 5: Implement `SecureTokenStorage`**

Create `lib/core/storage/secure_token_storage.dart`:
```dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/authentication/domain/entities/auth_session.dart';

class SecureTokenStorage {
  SecureTokenStorage(this._storage);

  final FlutterSecureStorage _storage;
  static const _sessionKey = 'auth_session_json';

  Future<void> saveSession(AuthSession session) async {
    final json = jsonEncode({
      'loginId': session.loginId,
      'firstName': session.firstName,
      'lastName': session.lastName,
      'fullName': session.fullName,
      'companyId': session.companyId,
      'branchId': session.branchId,
      'roleName': session.roleName,
      'features': session.features,
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      'accessTokenExpiresAt': session.accessTokenExpiresAt.toIso8601String(),
    });
    await _storage.write(key: _sessionKey, value: json);
  }

  Future<AuthSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return AuthSession(
      loginId: map['loginId'] as String,
      firstName: map['firstName'] as String,
      lastName: map['lastName'] as String,
      fullName: map['fullName'] as String,
      companyId: map['companyId'] as String,
      branchId: map['branchId'] as String,
      roleName: map['roleName'] as String,
      features: List<String>.from(map['features'] as List),
      accessToken: map['accessToken'] as String,
      refreshToken: map['refreshToken'] as String,
      accessTokenExpiresAt: DateTime.parse(map['accessTokenExpiresAt'] as String),
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
  }
}

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage(const FlutterSecureStorage());
});
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/core/storage/secure_token_storage_test.dart`
Expected: `00:0X +3: All tests passed!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/authentication/domain/entities/auth_session.dart lib/features/authentication/domain/entities/auth_session.freezed.dart lib/core/storage/secure_token_storage.dart test/core/storage/secure_token_storage_test.dart
git commit -m "Add AuthSession entity and secure token storage"
```

---

## Task 4: Auth interceptor (attach token, refresh-and-retry on 401)

**Files:**
- Create: `lib/core/api/auth_interceptor.dart`
- Test: `test/core/api/auth_interceptor_test.dart`

**Interfaces:**
- Consumes: `SecureTokenStorage` (Task 3), `Dio` (Task 2).
- Produces: `AuthInterceptor extends Interceptor`, constructed with `AuthInterceptor(Dio dio, SecureTokenStorage storage, Future<AuthSession?> Function(String refreshToken) refresh, void Function() onRefreshFailed)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/api/auth_interceptor_test.dart`:
```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/api/auth_interceptor_test.dart`
Expected: FAIL — `auth_interceptor.dart` doesn't exist.

- [ ] **Step 3: Implement `AuthInterceptor`**

Create `lib/core/api/auth_interceptor.dart`:
```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/api/auth_interceptor_test.dart`
Expected: `00:0X +3: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/api/auth_interceptor.dart test/core/api/auth_interceptor_test.dart
git commit -m "Add auth interceptor with 401 refresh-and-retry"
```

---

## Task 5: Authentication feature — DTOs, mapper, repository, usecases

**Files:**
- Create: `lib/features/authentication/data/models/login_request_dto.dart`
- Create: `lib/features/authentication/data/models/login_response_dto.dart`
- Create: `lib/features/authentication/data/mappers/auth_session_mapper.dart`
- Create: `lib/features/authentication/data/datasource/remote/auth_remote_datasource.dart`
- Create: `lib/features/authentication/domain/repository/auth_repository.dart`
- Create: `lib/features/authentication/data/repository/auth_repository_impl.dart`
- Create: `lib/features/authentication/domain/usecases/login_usecase.dart`
- Create: `lib/features/authentication/domain/usecases/logout_usecase.dart`
- Create: `lib/features/authentication/domain/usecases/refresh_token_usecase.dart`
- Test: `test/features/authentication/domain/login_usecase_test.dart`

**Interfaces:**
- Consumes: `Dio` (Task 2), `AuthSession`/`SecureTokenStorage` (Task 3).
- Produces: `AuthRepository` interface (`login`, `logout`, `refresh`); `LoginUsecase.call({required String username, required String password, String? companyId}) → Future<AuthSession>`; `LogoutUsecase.call() → Future<void>`; `RefreshTokenUsecase.call(String refreshToken) → Future<AuthSession>`.

- [ ] **Step 1: Create DTOs**

Create `lib/features/authentication/data/models/login_request_dto.dart`:
```dart
import 'package:json_annotation/json_annotation.dart';

part 'login_request_dto.g.dart';

@JsonSerializable()
class LoginRequestDto {
  LoginRequestDto({required this.username, required this.password, this.companyId});

  final String username;
  final String password;
  final String? companyId;

  Map<String, dynamic> toJson() => _$LoginRequestDtoToJson(this);
}
```

Create `lib/features/authentication/data/models/login_response_dto.dart`:
```dart
import 'package:json_annotation/json_annotation.dart';

part 'login_response_dto.g.dart';

@JsonSerializable()
class LoginResponseDto {
  LoginResponseDto({
    required this.loginId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.companyId,
    required this.branchId,
    required this.roleName,
    required this.features,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  final String loginId;
  final String firstName;
  final String lastName;
  final String fullName;
  final String companyId;
  final String branchId;
  final String roleName;
  final List<String> features;
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  factory LoginResponseDto.fromJson(Map<String, dynamic> json) => _$LoginResponseDtoFromJson(json);
}
```

- [ ] **Step 2: Generate JSON serialization code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `login_request_dto.g.dart` and `login_response_dto.g.dart` generated, no errors.

- [ ] **Step 3: Create the mapper**

Create `lib/features/authentication/data/mappers/auth_session_mapper.dart`:
```dart
import '../models/login_response_dto.dart';
import '../../domain/entities/auth_session.dart';

extension LoginResponseDtoMapper on LoginResponseDto {
  AuthSession toDomain() {
    return AuthSession(
      loginId: loginId,
      firstName: firstName,
      lastName: lastName,
      fullName: fullName,
      companyId: companyId,
      branchId: branchId,
      roleName: roleName,
      features: features,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }
}
```

- [ ] **Step 4: Create the remote datasource**

Create `lib/features/authentication/data/datasource/remote/auth_remote_datasource.dart`:
```dart
import 'package:dio/dio.dart';
import '../../models/login_request_dto.dart';
import '../../models/login_response_dto.dart';

class AuthRemoteDatasource {
  AuthRemoteDatasource(this._dio);

  final Dio _dio;

  Future<LoginResponseDto> login(LoginRequestDto request) async {
    final response = await _dio.post('/auth/login', data: request.toJson());
    return LoginResponseDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LoginResponseDto> refresh(String refreshToken) async {
    final response = await _dio.post(
      '/auth/refresh',
      options: Options(headers: {'X-Refresh-Token': refreshToken}),
    );
    return LoginResponseDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> revoke(String refreshToken) async {
    await _dio.post(
      '/auth/revoke',
      options: Options(headers: {'X-Refresh-Token': refreshToken}),
    );
  }
}
```

- [ ] **Step 5: Create the repository interface and implementation**

Create `lib/features/authentication/domain/repository/auth_repository.dart`:
```dart
import '../entities/auth_session.dart';

abstract interface class AuthRepository {
  Future<AuthSession> login({required String username, required String password, String? companyId});
  Future<AuthSession> refresh(String refreshToken);
  Future<void> logout(String refreshToken);
}
```

Create `lib/features/authentication/data/repository/auth_repository_impl.dart`:
```dart
import '../datasource/remote/auth_remote_datasource.dart';
import '../mappers/auth_session_mapper.dart';
import '../models/login_request_dto.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repository/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDatasource _remote;

  @override
  Future<AuthSession> login({required String username, required String password, String? companyId}) async {
    final dto = await _remote.login(LoginRequestDto(username: username, password: password, companyId: companyId));
    return dto.toDomain();
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    final dto = await _remote.refresh(refreshToken);
    return dto.toDomain();
  }

  @override
  Future<void> logout(String refreshToken) => _remote.revoke(refreshToken);
}
```

- [ ] **Step 6: Create usecases**

Create `lib/features/authentication/domain/usecases/login_usecase.dart`:
```dart
import '../entities/auth_session.dart';
import '../repository/auth_repository.dart';

class LoginUsecase {
  LoginUsecase(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call({required String username, required String password, String? companyId}) {
    return _repository.login(username: username, password: password, companyId: companyId);
  }
}
```

Create `lib/features/authentication/domain/usecases/refresh_token_usecase.dart`:
```dart
import '../entities/auth_session.dart';
import '../repository/auth_repository.dart';

class RefreshTokenUsecase {
  RefreshTokenUsecase(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call(String refreshToken) => _repository.refresh(refreshToken);
}
```

Create `lib/features/authentication/domain/usecases/logout_usecase.dart`:
```dart
import '../repository/auth_repository.dart';

class LogoutUsecase {
  LogoutUsecase(this._repository);

  final AuthRepository _repository;

  Future<void> call(String refreshToken) => _repository.logout(refreshToken);
}
```

- [ ] **Step 7: Write the failing test for `LoginUsecase`**

Create `test/features/authentication/domain/login_usecase_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';
import 'package:dtsretail_app/features/authentication/domain/repository/auth_repository.dart';
import 'package:dtsretail_app/features/authentication/domain/usecases/login_usecase.dart';

class _FakeAuthRepository implements AuthRepository {
  String? capturedUsername;
  String? capturedPassword;
  String? capturedCompanyId;

  @override
  Future<AuthSession> login({required String username, required String password, String? companyId}) async {
    capturedUsername = username;
    capturedPassword = password;
    capturedCompanyId = companyId;
    return AuthSession(
      loginId: username,
      firstName: 'Sam',
      lastName: 'Tan',
      fullName: 'Sam Tan',
      companyId: companyId ?? 'BAS',
      branchId: 'BAS1',
      roleName: 'STAFF',
      features: const ['PRODUCT_VIEW'],
      accessToken: 'access',
      refreshToken: 'refresh',
      accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<AuthSession> refresh(String refreshToken) => throw UnimplementedError();

  @override
  Future<void> logout(String refreshToken) => throw UnimplementedError();
}

void main() {
  test('LoginUsecase passes credentials through and returns the session', () async {
    final fakeRepo = _FakeAuthRepository();
    final usecase = LoginUsecase(fakeRepo);

    final session = await usecase(username: 'SAM', password: '270179', companyId: 'BAS');

    expect(fakeRepo.capturedUsername, 'SAM');
    expect(fakeRepo.capturedPassword, '270179');
    expect(fakeRepo.capturedCompanyId, 'BAS');
    expect(session.loginId, 'SAM');
    expect(session.features, contains('PRODUCT_VIEW'));
  });
}
```

- [ ] **Step 8: Run test to verify it fails, then passes**

Run: `flutter test test/features/authentication/domain/login_usecase_test.dart`
Expected first: FAIL if any file from steps 1-6 is missing an import; since all files are created in this task, it should already PASS once files exist — run once to confirm `00:0X +1: All tests passed!`.

- [ ] **Step 9: Commit**

```bash
git add lib/features/authentication/data lib/features/authentication/domain test/features/authentication/domain/login_usecase_test.dart
git commit -m "Add authentication data/domain layer: DTOs, mapper, repository, usecases"
```

---

## Task 6: Authentication providers and LoginPage

**Files:**
- Create: `lib/features/authentication/presentation/providers/auth_providers.dart`
- Create: `lib/features/authentication/presentation/pages/login_page.dart`
- Test: `test/features/authentication/presentation/login_page_test.dart`

**Interfaces:**
- Consumes: `LoginUsecase`, `LogoutUsecase`, `RefreshTokenUsecase` (Task 5), `AuthInterceptor` (Task 4), `dioClientProvider` (Task 2), `secureTokenStorageProvider` (Task 3).
- Produces: `authRepositoryProvider`, `authStateProvider → StateNotifierProvider<AuthStateNotifier, AuthState>` where `AuthState` is a sealed class `AuthState.unauthenticated() | AuthState.authenticated(AuthSession session) | AuthState.loading()`; `AuthStateNotifier.login(username, password, companyId)`, `.logout()`, `.restoreSession()`. `LoginPage` widget.

- [ ] **Step 1: Create `AuthState` and `AuthStateNotifier`**

Create `lib/features/authentication/presentation/providers/auth_providers.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/auth_interceptor.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../../data/datasource/remote/auth_remote_datasource.dart';
import '../../data/repository/auth_repository_impl.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repository/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/refresh_token_usecase.dart';

sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.errorMessage});
  final String? errorMessage;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);
  final AuthSession session;
}

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  return AuthRemoteDatasource(ref.watch(dioClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDatasourceProvider));
});

final loginUsecaseProvider = Provider((ref) => LoginUsecase(ref.watch(authRepositoryProvider)));
final logoutUsecaseProvider = Provider((ref) => LogoutUsecase(ref.watch(authRepositoryProvider)));
final refreshTokenUsecaseProvider = Provider((ref) => RefreshTokenUsecase(ref.watch(authRepositoryProvider)));

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this._ref) : super(const AuthLoading()) {
    _wireInterceptor();
    restoreSession();
  }

  final Ref _ref;

  void _wireInterceptor() {
    final dio = _ref.read(dioClientProvider);
    final storage = _ref.read(secureTokenStorageProvider);
    dio.interceptors.add(
      AuthInterceptor(
        dio,
        storage,
        (refreshToken) => _ref.read(refreshTokenUsecaseProvider)(refreshToken),
        () => state = const AuthUnauthenticated(),
      ),
    );
  }

  Future<void> restoreSession() async {
    final storage = _ref.read(secureTokenStorageProvider);
    final session = await storage.readSession();
    state = session == null ? const AuthUnauthenticated() : AuthAuthenticated(session);
  }

  Future<void> login({required String username, required String password, String? companyId}) async {
    state = const AuthLoading();
    try {
      final session = await _ref.read(loginUsecaseProvider)(
        username: username,
        password: password,
        companyId: companyId,
      );
      await _ref.read(secureTokenStorageProvider).saveSession(session);
      state = AuthAuthenticated(session);
    } on DioException catch (e) {
      final message = e.response?.statusCode == 401
          ? 'Invalid username or password.'
          : 'Unable to log in. Please try again.';
      state = AuthUnauthenticated(errorMessage: message);
    }
  }

  Future<void> logout() async {
    final current = state;
    if (current is AuthAuthenticated) {
      try {
        await _ref.read(logoutUsecaseProvider)(current.session.refreshToken);
      } catch (_) {
        // Best-effort revoke; clear local session regardless.
      }
    }
    await _ref.read(secureTokenStorageProvider).clear();
    state = const AuthUnauthenticated();
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(ref);
});
```

- [ ] **Step 2: Create `LoginPage`**

Create `lib/features/authentication/presentation/pages/login_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState is AuthLoading;
    final errorMessage = authState is AuthUnauthenticated ? authState.errorMessage : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('DTS Retail', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  TextFormField(
                    key: const Key('username_field'),
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                    validator: (value) => (value == null || value.isEmpty) ? 'Username is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('password_field'),
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) => (value == null || value.isEmpty) ? 'Password is required' : null,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(errorMessage, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('login_button'),
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Log In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authStateProvider.notifier).login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
  }
}
```

- [ ] **Step 3: Write the widget test**

Create `test/features/authentication/presentation/login_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/authentication/presentation/pages/login_page.dart';
import 'package:dtsretail_app/features/authentication/presentation/providers/auth_providers.dart';

void main() {
  testWidgets('shows validation errors when submitting empty form', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        overrides: [],
        child: MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pump();

    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('shows error message when auth state is unauthenticated with errorMessage', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => _StubNotifier(const AuthUnauthenticated(errorMessage: 'Invalid username or password.')),
          ),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invalid username or password.'), findsOneWidget);
  });
}

class _StubNotifier extends AuthStateNotifier {
  _StubNotifier(AuthState initial) : super(_NoopRef()) {
    state = initial;
  }
}

class _NoopRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
```

Note: `_NoopRef` works because `AuthStateNotifier`'s constructor calls `_wireInterceptor()` and `restoreSession()`, both of which call `_ref.read(...)` — since `_StubNotifier` immediately overwrites `state` after `super(...)` runs, any transient async work from `restoreSession()` resolving later is harmless (it's fire-and-forget in this stub context and the test doesn't await it). If this proves flaky in Step 4, replace `_NoopRef` with a real `ProviderContainer`-backed `Ref` scoped to a minimal override set instead of a `noSuchMethod` stub.

- [ ] **Step 4: Run the widget test**

Run: `flutter test test/features/authentication/presentation/login_page_test.dart`
Expected: `00:0X +2: All tests passed!`. If the second test is flaky due to the `_NoopRef` stub, replace it per the note above using `ProviderContainer(overrides: [dioClientProvider.overrideWithValue(Dio()), secureTokenStorageProvider.overrideWithValue(SecureTokenStorage(const FlutterSecureStorage()))])` and drive `AuthStateNotifier` through that container's `.read`/`.listen` instead of subclassing.

- [ ] **Step 5: Commit**

```bash
git add lib/features/authentication/presentation test/features/authentication/presentation/login_page_test.dart
git commit -m "Add auth providers and LoginPage"
```

---

## Task 7: Theme, router with auth guard, and bottom-nav shell

**Files:**
- Create: `lib/app/theme/app_theme.dart`
- Create: `lib/app/router.dart`
- Create: `lib/app/app.dart`
- Create: `lib/shared/widgets/app_scaffold.dart`
- Create: `lib/features/dashboard/presentation/pages/dashboard_page.dart` (stub for wiring; fleshed out in Task 9)
- Create: `lib/features/profile/presentation/pages/profile_page.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `authStateProvider` (Task 6).
- Produces: `appThemeLight`; `routerProvider → Provider<GoRouter>`; route paths `/login`, `/dashboard`, `/products`, `/stock-counts`, `/profile` mounted under a `StatefulShellRoute`.

- [ ] **Step 1: Create the theme**

Create `lib/app/theme/app_theme.dart`:
```dart
import 'package:flutter/material.dart';

final ThemeData appThemeLight = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
  appBarTheme: const AppBarTheme(centerTitle: false),
);
```

- [ ] **Step 2: Create placeholder `DashboardPage` and `ProfilePage`**

Create `lib/features/dashboard/presentation/pages/dashboard_page.dart`:
```dart
import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Dashboard')));
  }
}
```
(This is replaced with the real implementation in Task 9 — kept minimal here only so the router compiles.)

Create `lib/features/profile/presentation/pages/profile_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final session = authState is AuthAuthenticated ? authState.session : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          if (session != null)
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(session.fullName),
              subtitle: Text('${session.companyId} · ${session.branchId} · ${session.roleName}'),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & About'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Create the shared bottom-nav scaffold**

Create `lib/shared/widgets/app_scaffold.dart`:
```dart
import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Products'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Stock Count'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
```
Note: `StatefulNavigationShell` comes from `go_router`; import it in Step 4 alongside `router.dart`.

- [ ] **Step 4: Create the router**

Create `lib/app/router.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/authentication/presentation/pages/login_page.dart';
import '../features/authentication/presentation/providers/auth_providers.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/product/presentation/pages/product_list_page.dart';
import '../features/stock_count/presentation/pages/stock_count_list_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../shared/widgets/app_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateProvider.notifier);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (authState is AuthLoading) return null;
      if (!isAuthenticated && !isLoggingIn) return '/login';
      if (isAuthenticated && isLoggingIn) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/products', builder: (context, state) => const ProductListPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/stock-counts', builder: (context, state) => const StockCountListPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
          ]),
        ],
      ),
    ],
  );
});

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(this._ref) {
    _ref.listen(authStateProvider, (previous, next) => notifyListeners());
  }
  final Ref _ref;
}
```

- [ ] **Step 5: Create `app.dart` and update `main.dart`**

Create `lib/app/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class DtsRetailApp extends ConsumerWidget {
  const DtsRetailApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'DTS Retail',
      theme: appThemeLight,
      routerConfig: router,
    );
  }
}
```

Replace `lib/main.dart` with:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

void main() {
  runApp(const ProviderScope(child: DtsRetailApp()));
}
```

- [ ] **Step 6: Verify the app compiles and launches to the login screen**

Run: `flutter analyze`
Expected: no errors (warnings about unused stub pages are acceptable at this stage since Product/Stock Count pages are stubs until Tasks 8-9).

Since `product_list_page.dart` and `stock_count_list_page.dart` don't exist yet, add minimal stubs now so `flutter analyze` passes — these are replaced in Tasks 8 and 9:

Create `lib/features/product/presentation/pages/product_list_page.dart`:
```dart
import 'package:flutter/material.dart';

class ProductListPage extends StatelessWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Products')));
}
```

Create `lib/features/stock_count/presentation/pages/stock_count_list_page.dart`:
```dart
import 'package:flutter/material.dart';

class StockCountListPage extends StatelessWidget {
  const StockCountListPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Stock Counts')));
}
```

Run: `flutter analyze` again.
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/app lib/shared lib/features/dashboard/presentation/pages/dashboard_page.dart lib/features/profile lib/features/product/presentation/pages/product_list_page.dart lib/features/stock_count/presentation/pages/stock_count_list_page.dart lib/main.dart
git commit -m "Add theme, router with auth guard, and bottom-nav shell"
```

---

## Task 8: Product Catalog — data/domain layer

**Files:**
- Create: `lib/features/product/data/models/product_dto.dart`
- Create: `lib/features/product/data/datasource/remote/product_remote_datasource.dart`
- Create: `lib/features/product/data/mappers/product_mapper.dart`
- Create: `lib/features/product/domain/entities/product.dart`
- Create: `lib/features/product/domain/repository/product_repository.dart`
- Create: `lib/features/product/data/repository/product_repository_impl.dart`
- Create: `lib/features/product/domain/usecases/search_products_usecase.dart`
- Create: `lib/features/product/domain/usecases/get_product_detail_usecase.dart`
- Test: `test/features/product/data/mappers/product_mapper_test.dart`

**Interfaces:**
- Consumes: `Dio` (Task 2).
- Produces: `Product` entity (`companyId, productTypeCode, productCode, productBarcode, productTitle, productBrand, productPriceWgst, productPriceWogst, productCost, productUom, prodTotQtyOnHand, enableYn`); `ProductRepository` (`search`, `getDetail`); `SearchProductsUsecase.call({required String companyId, String? searchString, int searchKey, int page, int size}) → Future<ProductSearchResult>` where `ProductSearchResult` holds `List<Product> items, int totalElements, int totalPages`; `GetProductDetailUsecase.call({required String companyId, required String productTypeCode, required String productCode}) → Future<Product>`.

- [ ] **Step 1: Create the DTO**

Create `lib/features/product/data/models/product_dto.dart`:
```dart
import 'package:json_annotation/json_annotation.dart';

part 'product_dto.g.dart';

@JsonSerializable(fieldRename: FieldRename.none)
class ProductDto {
  ProductDto({
    required this.companyId,
    required this.productTypeCode,
    required this.productCode,
    this.productBarcode,
    this.productTitle,
    this.productBrand,
    this.enableyn,
    this.productPriceWgst,
    this.productPriceWogst,
    this.productCost,
    this.productUOM,
    this.prodTotQtyOnHand,
  });

  final String companyId;
  final String productTypeCode;
  final String productCode;
  final String? productBarcode;
  final String? productTitle;
  final String? productBrand;
  final bool? enableyn;
  final double? productPriceWgst;
  final double? productPriceWogst;
  final double? productCost;
  final String? productUOM;
  final double? prodTotQtyOnHand;

  factory ProductDto.fromJson(Map<String, dynamic> json) => _$ProductDtoFromJson(json);
}

@JsonSerializable()
class ProductSearchResponseDto {
  ProductSearchResponseDto({
    required this.content,
    required this.totalElements,
    required this.totalPages,
  });

  final List<ProductDto> content;
  final int totalElements;
  final int totalPages;

  factory ProductSearchResponseDto.fromJson(Map<String, dynamic> json) => _$ProductSearchResponseDtoFromJson(json);
}
```

- [ ] **Step 2: Generate JSON serialization code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `product_dto.g.dart` generated, no errors.

- [ ] **Step 3: Create the domain entity**

Create `lib/features/product/domain/entities/product.dart`:
```dart
class Product {
  const Product({
    required this.companyId,
    required this.productTypeCode,
    required this.productCode,
    required this.productBarcode,
    required this.productTitle,
    required this.productBrand,
    required this.isEnabled,
    required this.priceWithGst,
    required this.priceWithoutGst,
    required this.cost,
    required this.uom,
    required this.qtyOnHand,
  });

  final String companyId;
  final String productTypeCode;
  final String productCode;
  final String productBarcode;
  final String productTitle;
  final String productBrand;
  final bool isEnabled;
  final double priceWithGst;
  final double priceWithoutGst;
  final double cost;
  final String uom;
  final double qtyOnHand;
}

class ProductSearchResult {
  const ProductSearchResult({required this.items, required this.totalElements, required this.totalPages});

  final List<Product> items;
  final int totalElements;
  final int totalPages;
}
```

- [ ] **Step 4: Create the mapper**

Create `lib/features/product/data/mappers/product_mapper.dart`:
```dart
import '../models/product_dto.dart';
import '../../domain/entities/product.dart';

extension ProductDtoMapper on ProductDto {
  Product toDomain() {
    return Product(
      companyId: companyId,
      productTypeCode: productTypeCode,
      productCode: productCode,
      productBarcode: productBarcode ?? '',
      productTitle: productTitle ?? '',
      productBrand: productBrand ?? '',
      isEnabled: enableyn ?? true,
      priceWithGst: productPriceWgst ?? 0,
      priceWithoutGst: productPriceWogst ?? 0,
      cost: productCost ?? 0,
      uom: productUOM ?? '',
      qtyOnHand: prodTotQtyOnHand ?? 0,
    );
  }
}

extension ProductSearchResponseDtoMapper on ProductSearchResponseDto {
  ProductSearchResult toDomain() {
    return ProductSearchResult(
      items: content.map((dto) => dto.toDomain()).toList(),
      totalElements: totalElements,
      totalPages: totalPages,
    );
  }
}
```

- [ ] **Step 5: Write the failing mapper test**

Create `test/features/product/data/mappers/product_mapper_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/product/data/models/product_dto.dart';
import 'package:dtsretail_app/features/product/data/mappers/product_mapper.dart';

void main() {
  test('ProductDto.toDomain maps fields and defaults missing numeric fields to 0', () {
    final dto = ProductDto(
      companyId: 'BAS',
      productTypeCode: 'BOOK',
      productCode: '2007786553',
      productBarcode: '2007786553',
      productTitle: 'Test Title',
      productBrand: 'NATIO',
      enableyn: true,
      productPriceWgst: 29.9,
      productPriceWogst: 27.94,
      productCost: 13.08,
      productUOM: 'CPY',
      prodTotQtyOnHand: 10.0,
    );

    final product = dto.toDomain();

    expect(product.companyId, 'BAS');
    expect(product.productBarcode, '2007786553');
    expect(product.priceWithGst, 29.9);
    expect(product.qtyOnHand, 10.0);
  });

  test('ProductDto.toDomain defaults null optional fields safely', () {
    final dto = ProductDto(companyId: 'BAS', productTypeCode: 'BOOK', productCode: 'X');
    final product = dto.toDomain();

    expect(product.productTitle, '');
    expect(product.priceWithGst, 0);
    expect(product.isEnabled, true);
  });
}
```

- [ ] **Step 6: Run test to verify it fails then passes**

Run: `flutter test test/features/product/data/mappers/product_mapper_test.dart`
Expected after Steps 1-4 complete: `00:0X +2: All tests passed!`

- [ ] **Step 7: Create the remote datasource, repository, and usecases**

Create `lib/features/product/data/datasource/remote/product_remote_datasource.dart`:
```dart
import 'package:dio/dio.dart';
import '../../models/product_dto.dart';

class ProductRemoteDatasource {
  ProductRemoteDatasource(this._dio);

  final Dio _dio;

  Future<ProductSearchResponseDto> search({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get('/inventory/products/search', queryParameters: {
      'companyId': companyId,
      if (searchString != null && searchString.isNotEmpty) 'searchString': searchString,
      'searchKey': searchKey,
      'page': page,
      'size': size,
    });
    return ProductSearchResponseDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ProductDto> getDetail({
    required String companyId,
    required String productTypeCode,
    required String productCode,
  }) async {
    final response = await _dio.get('/inventory/products/$companyId/$productTypeCode/$productCode');
    return ProductDto.fromJson(response.data as Map<String, dynamic>);
  }
}
```

Create `lib/features/product/domain/repository/product_repository.dart`:
```dart
import '../entities/product.dart';

abstract interface class ProductRepository {
  Future<ProductSearchResult> search({
    required String companyId,
    String? searchString,
    int searchKey,
    int page,
    int size,
  });

  Future<Product> getDetail({
    required String companyId,
    required String productTypeCode,
    required String productCode,
  });
}
```

Create `lib/features/product/data/repository/product_repository_impl.dart`:
```dart
import '../datasource/remote/product_remote_datasource.dart';
import '../mappers/product_mapper.dart';
import '../../domain/entities/product.dart';
import '../../domain/repository/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._remote);

  final ProductRemoteDatasource _remote;

  @override
  Future<ProductSearchResult> search({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
  }) async {
    final dto = await _remote.search(
      companyId: companyId,
      searchString: searchString,
      searchKey: searchKey,
      page: page,
      size: size,
    );
    return dto.toDomain();
  }

  @override
  Future<Product> getDetail({
    required String companyId,
    required String productTypeCode,
    required String productCode,
  }) async {
    final dto = await _remote.getDetail(companyId: companyId, productTypeCode: productTypeCode, productCode: productCode);
    return dto.toDomain();
  }
}
```

Create `lib/features/product/domain/usecases/search_products_usecase.dart`:
```dart
import '../entities/product.dart';
import '../repository/product_repository.dart';

class SearchProductsUsecase {
  SearchProductsUsecase(this._repository);

  final ProductRepository _repository;

  Future<ProductSearchResult> call({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
  }) {
    return _repository.search(
      companyId: companyId,
      searchString: searchString,
      searchKey: searchKey,
      page: page,
      size: size,
    );
  }
}
```

Create `lib/features/product/domain/usecases/get_product_detail_usecase.dart`:
```dart
import '../entities/product.dart';
import '../repository/product_repository.dart';

class GetProductDetailUsecase {
  GetProductDetailUsecase(this._repository);

  final ProductRepository _repository;

  Future<Product> call({required String companyId, required String productTypeCode, required String productCode}) {
    return _repository.getDetail(companyId: companyId, productTypeCode: productTypeCode, productCode: productCode);
  }
}
```

- [ ] **Step 8: Commit**

```bash
git add lib/features/product/data lib/features/product/domain test/features/product/data/mappers/product_mapper_test.dart
git commit -m "Add Product Catalog data/domain layer"
```

---

## Task 9: Recent searches storage and barcode scanner service

**Files:**
- Create: `lib/core/storage/recent_searches_storage.dart`
- Create: `lib/core/services/barcode_scanner_service.dart`
- Test: `test/core/storage/recent_searches_storage_test.dart`

**Interfaces:**
- Produces: `RecentSearchesStorage` with `Future<List<String>> read(String scope)`, `Future<void> add(String scope, String term)` (dedupes, caps at 10, most-recent-first); `recentSearchesStorageProvider`. `BarcodeScannerService.scan(BuildContext context) → Future<String?>` (pushes a full-screen `MobileScanner` view, returns the first decoded barcode value or `null` if cancelled).

- [ ] **Step 1: Write the failing test**

Create `test/core/storage/recent_searches_storage_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dtsretail_app/core/storage/recent_searches_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('add stores the term, most recent first', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RecentSearchesStorage(prefs);

    await storage.add('product', 'garden plants');
    await storage.add('product', 'barcode 123');

    expect(await storage.read('product'), ['barcode 123', 'garden plants']);
  });

  test('add deduplicates a repeated term by moving it to the front', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RecentSearchesStorage(prefs);

    await storage.add('product', 'apple');
    await storage.add('product', 'banana');
    await storage.add('product', 'apple');

    expect(await storage.read('product'), ['apple', 'banana']);
  });

  test('add caps history at 10 entries', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RecentSearchesStorage(prefs);

    for (var i = 0; i < 12; i++) {
      await storage.add('product', 'term-$i');
    }

    final result = await storage.read('product');
    expect(result.length, 10);
    expect(result.first, 'term-11');
  });

  test('scopes are independent', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = RecentSearchesStorage(prefs);

    await storage.add('product', 'apple');
    await storage.add('stock_count', 'SC0001');

    expect(await storage.read('product'), ['apple']);
    expect(await storage.read('stock_count'), ['SC0001']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/storage/recent_searches_storage_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement `RecentSearchesStorage`**

Create `lib/core/storage/recent_searches_storage.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchesStorage {
  RecentSearchesStorage(this._prefs);

  final SharedPreferences _prefs;
  static const _maxEntries = 10;

  String _key(String scope) => 'recent_searches_$scope';

  Future<List<String>> read(String scope) async {
    return _prefs.getStringList(_key(scope)) ?? const [];
  }

  Future<void> add(String scope, String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;

    final current = await read(scope);
    final updated = [trimmed, ...current.where((t) => t != trimmed)];
    final capped = updated.take(_maxEntries).toList();
    await _prefs.setStringList(_key(scope), capped);
  }
}

final recentSearchesStorageProvider = FutureProvider<RecentSearchesStorage>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return RecentSearchesStorage(prefs);
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/storage/recent_searches_storage_test.dart`
Expected: `00:0X +4: All tests passed!`

- [ ] **Step 5: Implement `BarcodeScannerService`**

Create `lib/core/services/barcode_scanner_service.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerService {
  const BarcodeScannerService();

  Future<String?> scan(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()),
    );
  }
}

class _BarcodeScannerPage extends StatelessWidget {
  const _BarcodeScannerPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: MobileScanner(
        onDetect: (capture) {
          final barcode = capture.barcodes.firstOrNull?.rawValue;
          if (barcode != null) {
            Navigator.of(context).pop(barcode);
          }
        },
      ),
    );
  }
}
```
Note: `firstOrNull` requires `package:collection` extension methods, already transitively available via `mobile_scanner`'s SDK constraints in Flutter 3.32; if `flutter analyze` flags it as undefined, add `collection: ^1.18.0` to `pubspec.yaml` dependencies and `import 'package:collection/collection.dart';` at the top of this file.

- [ ] **Step 6: Verify analyze passes**

Run: `flutter analyze lib/core/services/barcode_scanner_service.dart`
Expected: `No issues found!` (or apply the `collection` fallback from Step 5's note, then re-run).

- [ ] **Step 7: Commit**

```bash
git add lib/core/storage/recent_searches_storage.dart lib/core/services/barcode_scanner_service.dart test/core/storage/recent_searches_storage_test.dart pubspec.yaml pubspec.lock
git commit -m "Add recent-searches storage and reusable barcode scanner service"
```

---

## Task 10: Product Catalog UI — providers, list page, detail page

**Files:**
- Create: `lib/features/product/presentation/providers/product_providers.dart`
- Modify: `lib/features/product/presentation/pages/product_list_page.dart` (replace stub from Task 7)
- Create: `lib/features/product/presentation/pages/product_detail_page.dart`
- Create: `lib/features/product/presentation/widgets/product_card.dart`
- Create: `lib/features/product/presentation/widgets/recent_searches_list.dart`
- Modify: `lib/app/router.dart` (add product detail route)
- Test: `test/features/product/presentation/product_list_page_test.dart`

**Interfaces:**
- Consumes: `SearchProductsUsecase`, `GetProductDetailUsecase` (Task 8), `RecentSearchesStorage` (Task 9), `authStateProvider` (Task 6, for `companyId`), `BarcodeScannerService` (Task 9).
- Produces: `productListProvider` (`FutureProvider.family` keyed by search query), navigable route `/products/:companyId/:productTypeCode/:productCode`.

- [ ] **Step 1: Create product providers**

Create `lib/features/product/presentation/providers/product_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../data/datasource/remote/product_remote_datasource.dart';
import '../../data/repository/product_repository_impl.dart';
import '../../domain/entities/product.dart';
import '../../domain/repository/product_repository.dart';
import '../../domain/usecases/get_product_detail_usecase.dart';
import '../../domain/usecases/search_products_usecase.dart';

final productRemoteDatasourceProvider = Provider((ref) => ProductRemoteDatasource(ref.watch(dioClientProvider)));

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(ref.watch(productRemoteDatasourceProvider));
});

final searchProductsUsecaseProvider = Provider((ref) => SearchProductsUsecase(ref.watch(productRepositoryProvider)));
final getProductDetailUsecaseProvider = Provider((ref) => GetProductDetailUsecase(ref.watch(productRepositoryProvider)));

class ProductSearchQuery {
  const ProductSearchQuery({required this.companyId, required this.searchString, required this.page});
  final String companyId;
  final String searchString;
  final int page;

  @override
  bool operator ==(Object other) =>
      other is ProductSearchQuery && other.companyId == companyId && other.searchString == searchString && other.page == page;

  @override
  int get hashCode => Object.hash(companyId, searchString, page);
}

final productSearchProvider = FutureProvider.family<ProductSearchResult, ProductSearchQuery>((ref, query) {
  return ref.watch(searchProductsUsecaseProvider)(
    companyId: query.companyId,
    searchString: query.searchString.isEmpty ? null : query.searchString,
    page: query.page,
  );
});

final productDetailProvider = FutureProvider.family<Product, ({String companyId, String productTypeCode, String productCode})>(
  (ref, args) {
    return ref.watch(getProductDetailUsecaseProvider)(
      companyId: args.companyId,
      productTypeCode: args.productTypeCode,
      productCode: args.productCode,
    );
  },
);
```

- [ ] **Step 2: Create `ProductCard` and `RecentSearchesList` widgets**

Create `lib/features/product/presentation/widgets/product_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../../domain/entities/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(product.productTitle),
      subtitle: Text('${product.productCode} · ${product.productBarcode}'),
      trailing: Text('\$${product.priceWithGst.toStringAsFixed(2)}'),
      onTap: onTap,
    );
  }
}
```

Create `lib/features/product/presentation/widgets/recent_searches_list.dart`:
```dart
import 'package:flutter/material.dart';

class RecentSearchesList extends StatelessWidget {
  const RecentSearchesList({super.key, required this.terms, required this.onSelected});

  final List<String> terms;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Recent searches', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...terms.map(
          (term) => ListTile(
            leading: const Icon(Icons.history),
            title: Text(term),
            onTap: () => onSelected(term),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Replace `ProductListPage` stub with the real implementation**

Replace `lib/features/product/presentation/pages/product_list_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/barcode_scanner_service.dart';
import '../../../../core/storage/recent_searches_storage.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/product_providers.dart';
import '../widgets/product_card.dart';
import '../widgets/recent_searches_list.dart';

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final _searchController = TextEditingController();
  String _submittedQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final companyId = authState is AuthAuthenticated ? authState.session.companyId : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _scanAndSearch(companyId),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(labelText: 'Search products', prefixIcon: Icon(Icons.search)),
              onSubmitted: (value) => _submitSearch(value, companyId),
            ),
          ),
          Expanded(child: _buildResultsOrRecent(companyId)),
        ],
      ),
    );
  }

  Widget _buildResultsOrRecent(String? companyId) {
    if (companyId == null) return const SizedBox.shrink();

    if (_submittedQuery.isEmpty) {
      final recentAsync = ref.watch(recentSearchesStorageProvider);
      return recentAsync.when(
        data: (storage) => FutureBuilder<List<String>>(
          future: storage.read('product'),
          builder: (context, snapshot) {
            final terms = snapshot.data ?? const [];
            return RecentSearchesList(
              terms: terms,
              onSelected: (term) {
                _searchController.text = term;
                _submitSearch(term, companyId);
              },
            );
          },
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      );
    }

    final query = ProductSearchQuery(companyId: companyId, searchString: _submittedQuery, page: 0);
    final resultAsync = ref.watch(productSearchProvider(query));

    return resultAsync.when(
      data: (result) {
        if (result.items.isEmpty) {
          return const Center(child: Text('No products found.'));
        }
        return ListView.builder(
          itemCount: result.items.length,
          itemBuilder: (context, index) {
            final product = result.items[index];
            return ProductCard(
              product: product,
              onTap: () => context.push('/products/${product.companyId}/${product.productTypeCode}/${product.productCode}'),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AppErrorView(message: error.toString(), onRetry: () => setState(() {})),
    );
  }

  void _submitSearch(String value, String? companyId) {
    if (companyId == null) return;
    setState(() => _submittedQuery = value.trim());
    ref.read(recentSearchesStorageProvider).whenData((storage) => storage.add('product', value));
  }

  Future<void> _scanAndSearch(String? companyId) async {
    const scanner = BarcodeScannerService();
    final barcode = await scanner.scan(context);
    if (barcode != null) {
      _searchController.text = barcode;
      _submitSearch(barcode, companyId);
    }
  }
}
```

- [ ] **Step 4: Create `AppErrorView` (referenced above, not yet created)**

Create `lib/core/widgets/app_error_view.dart`:
```dart
import 'package:flutter/material.dart';

class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(message, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Create `ProductDetailPage`**

Create `lib/features/product/presentation/pages/product_detail_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../providers/product_providers.dart';

class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({
    super.key,
    required this.companyId,
    required this.productTypeCode,
    required this.productCode,
  });

  final String companyId;
  final String productTypeCode;
  final String productCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (companyId: companyId, productTypeCode: productTypeCode, productCode: productCode);
    final productAsync = ref.watch(productDetailProvider(args));

    return Scaffold(
      appBar: AppBar(title: const Text('Product Detail')),
      body: productAsync.when(
        data: (product) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(product.productTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Brand: ${product.productBrand}'),
            Text('Code: ${product.productCode}'),
            Text('Barcode: ${product.productBarcode}'),
            Text('UOM: ${product.uom}'),
            const Divider(height: 32),
            Text('Price (incl. GST): \$${product.priceWithGst.toStringAsFixed(2)}'),
            Text('Price (excl. GST): \$${product.priceWithoutGst.toStringAsFixed(2)}'),
            Text('Cost: \$${product.cost.toStringAsFixed(2)}'),
            Text('Qty on hand: ${product.qtyOnHand}'),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(message: error.toString(), onRetry: () => ref.invalidate(productDetailProvider(args))),
      ),
    );
  }
}
```

- [ ] **Step 6: Wire the detail route into the router**

Modify `lib/app/router.dart` — add the import and nest the detail route under the products branch:
```dart
import '../features/product/presentation/pages/product_detail_page.dart';
```
Replace the products branch:
```dart
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/products',
              builder: (context, state) => const ProductListPage(),
              routes: [
                GoRoute(
                  path: ':companyId/:productTypeCode/:productCode',
                  builder: (context, state) => ProductDetailPage(
                    companyId: state.pathParameters['companyId']!,
                    productTypeCode: state.pathParameters['productTypeCode']!,
                    productCode: state.pathParameters['productCode']!,
                  ),
                ),
              ],
            ),
          ]),
```

- [ ] **Step 7: Write the widget test**

Create `test/features/product/presentation/product_list_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';
import 'package:dtsretail_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dtsretail_app/features/product/domain/entities/product.dart';
import 'package:dtsretail_app/features/product/domain/repository/product_repository.dart';
import 'package:dtsretail_app/features/product/presentation/pages/product_list_page.dart';
import 'package:dtsretail_app/features/product/presentation/providers/product_providers.dart';

class _FakeProductRepository implements ProductRepository {
  @override
  Future<ProductSearchResult> search({
    required String companyId,
    String? searchString,
    int searchKey = 0,
    int page = 0,
    int size = 20,
  }) async {
    return ProductSearchResult(
      items: [
        const Product(
          companyId: 'BAS',
          productTypeCode: 'BOOK',
          productCode: '2007786553',
          productBarcode: '2007786553',
          productTitle: 'Test Product',
          productBrand: 'NATIO',
          isEnabled: true,
          priceWithGst: 29.9,
          priceWithoutGst: 27.94,
          cost: 13.08,
          uom: 'CPY',
          qtyOnHand: 10,
        ),
      ],
      totalElements: 1,
      totalPages: 1,
    );
  }

  @override
  Future<Product> getDetail({required String companyId, required String productTypeCode, required String productCode}) {
    throw UnimplementedError();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows search results after submitting a query', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(_FakeProductRepository()),
          authStateProvider.overrideWith((ref) => _AuthenticatedStub()),
        ],
        child: const MaterialApp(home: ProductListPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'garden');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Test Product'), findsOneWidget);
  });
}

class _AuthenticatedStub extends AuthStateNotifier {
  _AuthenticatedStub() : super(_NoopRef()) {
    state = AuthAuthenticated(
      AuthSession(
        loginId: 'SAM',
        firstName: 'Sam',
        lastName: 'Tan',
        fullName: 'Sam Tan',
        companyId: 'BAS',
        branchId: 'BAS1',
        roleName: 'STAFF',
        features: const ['PRODUCT_VIEW'],
        accessToken: 'a',
        refreshToken: 'r',
        accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
      ),
    );
  }
}

class _NoopRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
```

- [ ] **Step 8: Run the widget test**

Run: `flutter test test/features/product/presentation/product_list_page_test.dart`
Expected: `00:0X +1: All tests passed!`. If `_NoopRef` causes the `AuthStateNotifier` constructor's `_wireInterceptor`/`restoreSession` calls to throw during the test, replace it with a real `ProviderContainer` the same way noted in Task 6 Step 3.

- [ ] **Step 9: Run full analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/features/product/presentation lib/core/widgets/app_error_view.dart lib/app/router.dart test/features/product/presentation/product_list_page_test.dart
git commit -m "Add Product Catalog UI: search, recent searches, barcode scan entry, detail page"
```

---

## Task 11: Stock Count and Warehouse — data/domain layer

**Files:**
- Create: `lib/features/stock_count/data/models/stock_count_dto.dart`
- Create: `lib/features/stock_count/data/models/stock_count_line_dto.dart`
- Create: `lib/features/stock_count/data/models/warehouse_dto.dart`
- Create: `lib/features/stock_count/data/datasource/remote/stock_count_remote_datasource.dart`
- Create: `lib/features/stock_count/data/datasource/remote/warehouse_remote_datasource.dart`
- Create: `lib/features/stock_count/data/mappers/stock_count_mapper.dart`
- Create: `lib/features/stock_count/domain/entities/stock_count.dart`
- Create: `lib/features/stock_count/domain/entities/stock_count_line.dart`
- Create: `lib/features/stock_count/domain/entities/warehouse.dart`
- Create: `lib/features/stock_count/domain/repository/stock_count_repository.dart`
- Create: `lib/features/stock_count/data/repository/stock_count_repository_impl.dart`
- Create: `lib/features/stock_count/domain/usecases/search_stock_counts_usecase.dart`
- Create: `lib/features/stock_count/domain/usecases/get_stock_count_detail_usecase.dart`
- Create: `lib/features/stock_count/domain/usecases/create_stock_count_usecase.dart`
- Create: `lib/features/stock_count/domain/usecases/update_stock_count_usecase.dart`
- Test: `test/features/stock_count/data/mappers/stock_count_mapper_test.dart`

**Interfaces:**
- Consumes: `Dio` (Task 2).
- Produces: `StockCount` entity (`companyId, branchId, stockcntId, cntType, status, stockcntDate, whseCode, totalItems, totalCountQty, totalVarQty, dateUpdated, lines`); `StockCountLine` (`productCode, productTypeCode, productTitle, productPriceWgst, productCost, countQty`); `Warehouse` (`companyId, whse, description, branchCode`); usecases mirroring Product's shape.

- [ ] **Step 1: Create DTOs**

Create `lib/features/stock_count/data/models/stock_count_line_dto.dart`:
```dart
import 'package:json_annotation/json_annotation.dart';

part 'stock_count_line_dto.g.dart';

@JsonSerializable()
class StockCountLineDto {
  StockCountLineDto({
    required this.productCode,
    required this.productTypeCode,
    this.productTitle,
    this.productPriceWgst,
    this.productCost,
    required this.countQty,
    this.compQty,
    this.varQty,
  });

  final String productCode;
  final String productTypeCode;
  final String? productTitle;
  final double? productPriceWgst;
  final double? productCost;
  final double countQty;
  final double? compQty;
  final double? varQty;

  factory StockCountLineDto.fromJson(Map<String, dynamic> json) => _$StockCountLineDtoFromJson(json);
  Map<String, dynamic> toJson() => _$StockCountLineDtoToJson(this);
}
```

Create `lib/features/stock_count/data/models/stock_count_dto.dart`:
```dart
import 'package:json_annotation/json_annotation.dart';
import 'stock_count_line_dto.dart';

part 'stock_count_dto.g.dart';

@JsonSerializable()
class StockCountDto {
  StockCountDto({
    required this.companyId,
    required this.branchId,
    this.stockcntId,
    required this.cntType,
    required this.status,
    this.stockcntDate,
    required this.whseCode,
    this.totalItems,
    this.totalCountQty,
    this.totalVarQty,
    this.dateUpdated,
    this.details,
  });

  final String companyId;
  final String branchId;
  final String? stockcntId;
  final String cntType;
  final String status;
  final String? stockcntDate;
  final String whseCode;
  final int? totalItems;
  final double? totalCountQty;
  final double? totalVarQty;
  final String? dateUpdated;
  final List<StockCountLineDto>? details;

  factory StockCountDto.fromJson(Map<String, dynamic> json) => _$StockCountDtoFromJson(json);
  Map<String, dynamic> toJson() => _$StockCountDtoToJson(this);
}

@JsonSerializable()
class StockCountSearchResponseDto {
  StockCountSearchResponseDto({required this.content, required this.totalElements, required this.totalPages});

  final List<StockCountDto> content;
  final int totalElements;
  final int totalPages;

  factory StockCountSearchResponseDto.fromJson(Map<String, dynamic> json) => _$StockCountSearchResponseDtoFromJson(json);
}
```

Create `lib/features/stock_count/data/models/warehouse_dto.dart`:
```dart
import 'package:json_annotation/json_annotation.dart';

part 'warehouse_dto.g.dart';

@JsonSerializable()
class WarehouseDto {
  WarehouseDto({required this.whse, this.description, this.branchCode});

  final String whse;
  final String? description;

  @JsonKey(name: 'branch_code')
  final String? branchCode;

  factory WarehouseDto.fromJson(Map<String, dynamic> json) => _$WarehouseDtoFromJson(json);
}
```
Note: the exact JSON key casing for the warehouse branch field (`branch_code` vs `branchCode`) was not shown in a sample response in the API docs — only the DB column `branch_code` was confirmed. Before running this task, hit `GET /inventory/warehouses?companyId=<real company>` against the running `dtsapi` and adjust the `@JsonKey(name: ...)` to match the actual field name returned; if the field is absent entirely from the response, drop branch-based default selection and default to the first warehouse returned instead (update `WarehouseSelector` in Task 13 accordingly).

- [ ] **Step 2: Generate JSON serialization code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `.g.dart` files generated for all three DTOs, no errors.

- [ ] **Step 3: Create domain entities**

Create `lib/features/stock_count/domain/entities/stock_count_line.dart`:
```dart
class StockCountLine {
  const StockCountLine({
    required this.productCode,
    required this.productTypeCode,
    required this.productTitle,
    required this.priceWithGst,
    required this.cost,
    required this.countQty,
  });

  final String productCode;
  final String productTypeCode;
  final String productTitle;
  final double priceWithGst;
  final double cost;
  final double countQty;
}
```

Create `lib/features/stock_count/domain/entities/stock_count.dart`:
```dart
import 'stock_count_line.dart';

class StockCount {
  const StockCount({
    required this.companyId,
    required this.branchId,
    required this.stockcntId,
    required this.cntType,
    required this.status,
    required this.stockcntDate,
    required this.whseCode,
    required this.totalItems,
    required this.totalCountQty,
    required this.totalVarQty,
    required this.dateUpdated,
    required this.lines,
  });

  final String companyId;
  final String branchId;
  final String stockcntId;
  final String cntType;
  final String status;
  final String stockcntDate;
  final String whseCode;
  final int totalItems;
  final double totalCountQty;
  final double totalVarQty;
  final String dateUpdated;
  final List<StockCountLine> lines;

  bool get isOpen => status == 'OPEN';
}

class StockCountSearchResult {
  const StockCountSearchResult({required this.items, required this.totalElements, required this.totalPages});

  final List<StockCount> items;
  final int totalElements;
  final int totalPages;
}
```

Create `lib/features/stock_count/domain/entities/warehouse.dart`:
```dart
class Warehouse {
  const Warehouse({required this.code, required this.description, required this.branchCode});

  final String code;
  final String description;
  final String branchCode;
}
```

- [ ] **Step 4: Create the mapper**

Create `lib/features/stock_count/data/mappers/stock_count_mapper.dart`:
```dart
import '../models/stock_count_dto.dart';
import '../models/stock_count_line_dto.dart';
import '../models/warehouse_dto.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/stock_count_line.dart';
import '../../domain/entities/warehouse.dart';

extension StockCountLineDtoMapper on StockCountLineDto {
  StockCountLine toDomain() {
    return StockCountLine(
      productCode: productCode,
      productTypeCode: productTypeCode,
      productTitle: productTitle ?? '',
      priceWithGst: productPriceWgst ?? 0,
      cost: productCost ?? 0,
      countQty: countQty,
    );
  }

  static StockCountLineDto fromDomain(StockCountLine line) {
    return StockCountLineDto(
      productCode: line.productCode,
      productTypeCode: line.productTypeCode,
      productTitle: line.productTitle,
      productPriceWgst: line.priceWithGst,
      productCost: line.cost,
      countQty: line.countQty,
    );
  }
}

extension StockCountDtoMapper on StockCountDto {
  StockCount toDomain() {
    return StockCount(
      companyId: companyId,
      branchId: branchId,
      stockcntId: stockcntId ?? '',
      cntType: cntType,
      status: status,
      stockcntDate: stockcntDate ?? '',
      whseCode: whseCode,
      totalItems: totalItems ?? (details?.length ?? 0),
      totalCountQty: totalCountQty ?? 0,
      totalVarQty: totalVarQty ?? 0,
      dateUpdated: dateUpdated ?? '',
      lines: (details ?? const []).map((d) => d.toDomain()).toList(),
    );
  }
}

extension StockCountSearchResponseDtoMapper on StockCountSearchResponseDto {
  StockCountSearchResult toDomain() {
    return StockCountSearchResult(
      items: content.map((dto) => dto.toDomain()).toList(),
      totalElements: totalElements,
      totalPages: totalPages,
    );
  }
}

extension WarehouseDtoMapper on WarehouseDto {
  Warehouse toDomain() {
    return Warehouse(code: whse, description: description ?? whse, branchCode: branchCode ?? '');
  }
}

StockCountDto stockCountToCreateDto({
  required String companyId,
  required String branchId,
  required String cntType,
  required String whseCode,
  required List<StockCountLine> lines,
}) {
  return StockCountDto(
    companyId: companyId,
    branchId: branchId,
    cntType: cntType,
    status: 'OPEN',
    whseCode: whseCode,
    details: lines.map(StockCountLineDtoMapper.fromDomain).toList(),
  );
}
```

- [ ] **Step 5: Write the failing mapper test**

Create `test/features/stock_count/data/mappers/stock_count_mapper_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/stock_count/data/models/stock_count_dto.dart';
import 'package:dtsretail_app/features/stock_count/data/models/stock_count_line_dto.dart';
import 'package:dtsretail_app/features/stock_count/data/mappers/stock_count_mapper.dart';

void main() {
  test('StockCountDto.toDomain maps header and line items', () {
    final dto = StockCountDto(
      companyId: 'BAS',
      branchId: 'BAS1',
      stockcntId: 'SC0089',
      cntType: 'POSCNT',
      status: 'OPEN',
      stockcntDate: '2020-08-02',
      whseCode: 'BBPOS',
      totalItems: 1,
      totalCountQty: 45.0,
      totalVarQty: -2.0,
      dateUpdated: '2020-08-02T10:00:00',
      details: [
        StockCountLineDto(
          productCode: '12016',
          productTypeCode: 'MAGAZINE',
          productTitle: 'ARCHIVE 1 /2016',
          productPriceWgst: 23.0,
          productCost: 12.7,
          countQty: 45.0,
        ),
      ],
    );

    final domain = dto.toDomain();

    expect(domain.stockcntId, 'SC0089');
    expect(domain.isOpen, isTrue);
    expect(domain.lines, hasLength(1));
    expect(domain.lines.first.productTitle, 'ARCHIVE 1 /2016');
  });

  test('stockCountToCreateDto builds a create-ready DTO with OPEN status', () {
    final dto = stockCountToCreateDto(
      companyId: 'BAS',
      branchId: 'BAS1',
      cntType: 'CNT',
      whseCode: 'BBPOS',
      lines: const [
        StockCountLine(
          productCode: '2007786553',
          productTypeCode: 'BOOK',
          productTitle: 'Test Product',
          priceWithGst: 29.9,
          cost: 13.08,
          countQty: 10,
        ),
      ],
    );

    expect(dto.status, 'OPEN');
    expect(dto.details, hasLength(1));
    expect(dto.details!.first.productCode, '2007786553');
  });
}
```

- [ ] **Step 6: Run test to verify it fails then passes**

Run: `flutter test test/features/stock_count/data/mappers/stock_count_mapper_test.dart`
Expected after Steps 1-4: `00:0X +2: All tests passed!`

- [ ] **Step 7: Create remote datasources**

Create `lib/features/stock_count/data/datasource/remote/stock_count_remote_datasource.dart`:
```dart
import 'package:dio/dio.dart';
import '../../models/stock_count_dto.dart';

class StockCountRemoteDatasource {
  StockCountRemoteDatasource(this._dio);

  final Dio _dio;

  Future<StockCountSearchResponseDto> search({
    required String companyId,
    required String branchId,
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get('/inventory/stock-counts/search', queryParameters: {
      'companyId': companyId,
      'branchId': branchId,
      if (status != null) 'status': status,
      'page': page,
      'size': size,
    });
    return StockCountSearchResponseDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StockCountDto> getDetail({required String companyId, required String branchId, required String stockcntId}) async {
    final response = await _dio.get('/inventory/stock-counts/$companyId/$branchId/$stockcntId');
    return StockCountDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StockCountDto> create(StockCountDto dto, {required String userId}) async {
    final response = await _dio.post(
      '/inventory/stock-counts',
      data: dto.toJson(),
      options: Options(headers: {'X-User-Id': userId}),
    );
    final body = response.data as Map<String, dynamic>;
    return StockCountDto.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<StockCountDto> update(
    StockCountDto dto, {
    required String companyId,
    required String branchId,
    required String stockcntId,
    required String userId,
  }) async {
    final response = await _dio.put(
      '/inventory/stock-counts/$companyId/$branchId/$stockcntId',
      data: dto.toJson(),
      options: Options(headers: {'X-User-Id': userId}),
    );
    final body = response.data as Map<String, dynamic>;
    return StockCountDto.fromJson(body['data'] as Map<String, dynamic>);
  }
}
```

Create `lib/features/stock_count/data/datasource/remote/warehouse_remote_datasource.dart`:
```dart
import 'package:dio/dio.dart';
import '../../models/warehouse_dto.dart';

class WarehouseRemoteDatasource {
  WarehouseRemoteDatasource(this._dio);

  final Dio _dio;

  Future<List<WarehouseDto>> getAll({required String companyId}) async {
    final response = await _dio.get('/inventory/warehouses', queryParameters: {'companyId': companyId});
    final list = response.data as List;
    return list.map((e) => WarehouseDto.fromJson(e as Map<String, dynamic>)).toList();
  }
}
```

- [ ] **Step 8: Create the repository interface, implementation, and usecases**

Create `lib/features/stock_count/domain/repository/stock_count_repository.dart`:
```dart
import '../entities/stock_count.dart';
import '../entities/stock_count_line.dart';
import '../entities/warehouse.dart';

abstract interface class StockCountRepository {
  Future<StockCountSearchResult> search({
    required String companyId,
    required String branchId,
    String? status,
    int page,
    int size,
  });

  Future<StockCount> getDetail({required String companyId, required String branchId, required String stockcntId});

  Future<StockCount> create({
    required String companyId,
    required String branchId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  });

  Future<StockCount> update({
    required String companyId,
    required String branchId,
    required String stockcntId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  });

  Future<List<Warehouse>> getWarehouses({required String companyId});
}
```

Create `lib/features/stock_count/data/repository/stock_count_repository_impl.dart`:
```dart
import '../datasource/remote/stock_count_remote_datasource.dart';
import '../datasource/remote/warehouse_remote_datasource.dart';
import '../mappers/stock_count_mapper.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/stock_count_line.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/repository/stock_count_repository.dart';

class StockCountRepositoryImpl implements StockCountRepository {
  StockCountRepositoryImpl(this._remote, this._warehouseRemote);

  final StockCountRemoteDatasource _remote;
  final WarehouseRemoteDatasource _warehouseRemote;

  @override
  Future<StockCountSearchResult> search({
    required String companyId,
    required String branchId,
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    final dto = await _remote.search(companyId: companyId, branchId: branchId, status: status, page: page, size: size);
    return dto.toDomain();
  }

  @override
  Future<StockCount> getDetail({required String companyId, required String branchId, required String stockcntId}) async {
    final dto = await _remote.getDetail(companyId: companyId, branchId: branchId, stockcntId: stockcntId);
    return dto.toDomain();
  }

  @override
  Future<StockCount> create({
    required String companyId,
    required String branchId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) async {
    final requestDto = stockCountToCreateDto(
      companyId: companyId,
      branchId: branchId,
      cntType: cntType,
      whseCode: whseCode,
      lines: lines,
    );
    final resultDto = await _remote.create(requestDto, userId: userId);
    return resultDto.toDomain();
  }

  @override
  Future<StockCount> update({
    required String companyId,
    required String branchId,
    required String stockcntId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) async {
    final requestDto = stockCountToCreateDto(
      companyId: companyId,
      branchId: branchId,
      cntType: cntType,
      whseCode: whseCode,
      lines: lines,
    );
    final resultDto = await _remote.update(
      requestDto,
      companyId: companyId,
      branchId: branchId,
      stockcntId: stockcntId,
      userId: userId,
    );
    return resultDto.toDomain();
  }

  @override
  Future<List<Warehouse>> getWarehouses({required String companyId}) async {
    final dtos = await _warehouseRemote.getAll(companyId: companyId);
    return dtos.map((dto) => dto.toDomain()).toList();
  }
}
```

Create `lib/features/stock_count/domain/usecases/search_stock_counts_usecase.dart`:
```dart
import '../entities/stock_count.dart';
import '../repository/stock_count_repository.dart';

class SearchStockCountsUsecase {
  SearchStockCountsUsecase(this._repository);

  final StockCountRepository _repository;

  Future<StockCountSearchResult> call({
    required String companyId,
    required String branchId,
    String? status,
    int page = 0,
    int size = 20,
  }) {
    return _repository.search(companyId: companyId, branchId: branchId, status: status, page: page, size: size);
  }
}
```

Create `lib/features/stock_count/domain/usecases/get_stock_count_detail_usecase.dart`:
```dart
import '../entities/stock_count.dart';
import '../repository/stock_count_repository.dart';

class GetStockCountDetailUsecase {
  GetStockCountDetailUsecase(this._repository);

  final StockCountRepository _repository;

  Future<StockCount> call({required String companyId, required String branchId, required String stockcntId}) {
    return _repository.getDetail(companyId: companyId, branchId: branchId, stockcntId: stockcntId);
  }
}
```

Create `lib/features/stock_count/domain/usecases/create_stock_count_usecase.dart`:
```dart
import '../entities/stock_count.dart';
import '../entities/stock_count_line.dart';
import '../repository/stock_count_repository.dart';

class CreateStockCountUsecase {
  CreateStockCountUsecase(this._repository);

  final StockCountRepository _repository;

  Future<StockCount> call({
    required String companyId,
    required String branchId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) {
    return _repository.create(
      companyId: companyId,
      branchId: branchId,
      cntType: cntType,
      whseCode: whseCode,
      lines: lines,
      userId: userId,
    );
  }
}
```

Create `lib/features/stock_count/domain/usecases/update_stock_count_usecase.dart`:
```dart
import '../entities/stock_count.dart';
import '../entities/stock_count_line.dart';
import '../repository/stock_count_repository.dart';

class UpdateStockCountUsecase {
  UpdateStockCountUsecase(this._repository);

  final StockCountRepository _repository;

  Future<StockCount> call({
    required String companyId,
    required String branchId,
    required String stockcntId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) {
    return _repository.update(
      companyId: companyId,
      branchId: branchId,
      stockcntId: stockcntId,
      cntType: cntType,
      whseCode: whseCode,
      lines: lines,
      userId: userId,
    );
  }
}
```

- [ ] **Step 9: Commit**

```bash
git add lib/features/stock_count/data lib/features/stock_count/domain test/features/stock_count/data/mappers/stock_count_mapper_test.dart
git commit -m "Add Stock Count and Warehouse data/domain layer"
```

---

## Task 12: Stock Count UI — providers, list page, detail page

**Files:**
- Create: `lib/features/stock_count/presentation/providers/stock_count_providers.dart`
- Modify: `lib/features/stock_count/presentation/pages/stock_count_list_page.dart` (replace stub from Task 7)
- Create: `lib/features/stock_count/presentation/pages/stock_count_detail_page.dart`
- Create: `lib/features/stock_count/presentation/widgets/stock_count_card.dart`
- Modify: `lib/app/router.dart` (add stock count detail + form routes)
- Test: `test/features/stock_count/presentation/stock_count_list_page_test.dart`

**Interfaces:**
- Consumes: `SearchStockCountsUsecase`, `GetStockCountDetailUsecase` (Task 11), `authStateProvider` (Task 6).
- Produces: `stockCountSearchProvider`, `stockCountDetailProvider`, routes `/stock-counts/:companyId/:branchId/:stockcntId` and `/stock-counts/new`.

- [ ] **Step 1: Create providers**

Create `lib/features/stock_count/presentation/providers/stock_count_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../data/datasource/remote/stock_count_remote_datasource.dart';
import '../../data/datasource/remote/warehouse_remote_datasource.dart';
import '../../data/repository/stock_count_repository_impl.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/repository/stock_count_repository.dart';
import '../../domain/usecases/create_stock_count_usecase.dart';
import '../../domain/usecases/get_stock_count_detail_usecase.dart';
import '../../domain/usecases/search_stock_counts_usecase.dart';
import '../../domain/usecases/update_stock_count_usecase.dart';

final stockCountRemoteDatasourceProvider = Provider((ref) => StockCountRemoteDatasource(ref.watch(dioClientProvider)));
final warehouseRemoteDatasourceProvider = Provider((ref) => WarehouseRemoteDatasource(ref.watch(dioClientProvider)));

final stockCountRepositoryProvider = Provider<StockCountRepository>((ref) {
  return StockCountRepositoryImpl(
    ref.watch(stockCountRemoteDatasourceProvider),
    ref.watch(warehouseRemoteDatasourceProvider),
  );
});

final searchStockCountsUsecaseProvider = Provider((ref) => SearchStockCountsUsecase(ref.watch(stockCountRepositoryProvider)));
final getStockCountDetailUsecaseProvider = Provider((ref) => GetStockCountDetailUsecase(ref.watch(stockCountRepositoryProvider)));
final createStockCountUsecaseProvider = Provider((ref) => CreateStockCountUsecase(ref.watch(stockCountRepositoryProvider)));
final updateStockCountUsecaseProvider = Provider((ref) => UpdateStockCountUsecase(ref.watch(stockCountRepositoryProvider)));

class StockCountSearchQuery {
  const StockCountSearchQuery({required this.companyId, required this.branchId, this.status});
  final String companyId;
  final String branchId;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is StockCountSearchQuery && other.companyId == companyId && other.branchId == branchId && other.status == status;

  @override
  int get hashCode => Object.hash(companyId, branchId, status);
}

final stockCountSearchProvider = FutureProvider.family<StockCountSearchResult, StockCountSearchQuery>((ref, query) {
  return ref.watch(searchStockCountsUsecaseProvider)(companyId: query.companyId, branchId: query.branchId, status: query.status);
});

final stockCountDetailProvider = FutureProvider.family<StockCount, ({String companyId, String branchId, String stockcntId})>(
  (ref, args) {
    return ref.watch(getStockCountDetailUsecaseProvider)(
      companyId: args.companyId,
      branchId: args.branchId,
      stockcntId: args.stockcntId,
    );
  },
);

final warehousesProvider = FutureProvider.family<List<Warehouse>, String>((ref, companyId) {
  return ref.watch(stockCountRepositoryProvider).getWarehouses(companyId: companyId);
});
```

- [ ] **Step 2: Create `StockCountCard`**

Create `lib/features/stock_count/presentation/widgets/stock_count_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../../domain/entities/stock_count.dart';

class StockCountCard extends StatelessWidget {
  const StockCountCard({super.key, required this.stockCount, required this.onTap});

  final StockCount stockCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(stockCount.stockcntId),
      subtitle: Text('${stockCount.whseCode} · ${stockCount.status} · ${stockCount.totalItems} items'),
      trailing: Text(stockCount.totalVarQty.toStringAsFixed(1)),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 3: Replace `StockCountListPage` stub**

Replace `lib/features/stock_count/presentation/pages/stock_count_list_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/stock_count_providers.dart';
import '../widgets/stock_count_card.dart';

class StockCountListPage extends ConsumerWidget {
  const StockCountListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();
    final session = authState.session;

    final query = StockCountSearchQuery(companyId: session.companyId, branchId: session.branchId);
    final resultAsync = ref.watch(stockCountSearchProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Counts'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => context.push('/stock-counts/new')),
        ],
      ),
      body: resultAsync.when(
        data: (result) {
          if (result.items.isEmpty) return const Center(child: Text('No stock counts found.'));
          return ListView.builder(
            itemCount: result.items.length,
            itemBuilder: (context, index) {
              final stockCount = result.items[index];
              return StockCountCard(
                stockCount: stockCount,
                onTap: () => context.push('/stock-counts/${stockCount.companyId}/${stockCount.branchId}/${stockCount.stockcntId}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(message: error.toString(), onRetry: () => ref.invalidate(stockCountSearchProvider(query))),
      ),
    );
  }
}
```

- [ ] **Step 4: Create `StockCountDetailPage`**

Create `lib/features/stock_count/presentation/pages/stock_count_detail_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../providers/stock_count_providers.dart';

class StockCountDetailPage extends ConsumerWidget {
  const StockCountDetailPage({super.key, required this.companyId, required this.branchId, required this.stockcntId});

  final String companyId;
  final String branchId;
  final String stockcntId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (companyId: companyId, branchId: branchId, stockcntId: stockcntId);
    final detailAsync = ref.watch(stockCountDetailProvider(args));

    return Scaffold(
      appBar: AppBar(title: Text(stockcntId)),
      body: detailAsync.when(
        data: (stockCount) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Warehouse: ${stockCount.whseCode}'),
                  Text('Status: ${stockCount.status}'),
                  Text('Last updated: ${stockCount.dateUpdated}'),
                  Text('Total variance: ${stockCount.totalVarQty}'),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: stockCount.lines.length,
                itemBuilder: (context, index) {
                  final line = stockCount.lines[index];
                  return ListTile(
                    title: Text(line.productTitle),
                    subtitle: Text(line.productCode),
                    trailing: Text('Qty: ${line.countQty}'),
                  );
                },
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(message: error.toString(), onRetry: () => ref.invalidate(stockCountDetailProvider(args))),
      ),
      floatingActionButton: detailAsync.maybeWhen(
        data: (stockCount) => stockCount.isOpen
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/stock-counts/new?companyId=$companyId&branchId=$branchId&stockcntId=$stockcntId'),
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              )
            : null,
        orElse: () => null,
      ),
    );
  }
}
```

- [ ] **Step 5: Wire detail route into router**

Modify `lib/app/router.dart` — add import and nest under the stock-counts branch:
```dart
import '../features/stock_count/presentation/pages/stock_count_detail_page.dart';
```
Replace the stock-counts branch:
```dart
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/stock-counts',
              builder: (context, state) => const StockCountListPage(),
              routes: [
                GoRoute(
                  path: ':companyId/:branchId/:stockcntId',
                  builder: (context, state) => StockCountDetailPage(
                    companyId: state.pathParameters['companyId']!,
                    branchId: state.pathParameters['branchId']!,
                    stockcntId: state.pathParameters['stockcntId']!,
                  ),
                ),
              ],
            ),
          ]),
```
(The `/stock-counts/new` route is added in Task 13 alongside the form page it renders.)

- [ ] **Step 6: Write the widget test**

Create `test/features/stock_count/presentation/stock_count_list_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtsretail_app/features/authentication/domain/entities/auth_session.dart';
import 'package:dtsretail_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/warehouse.dart';
import 'package:dtsretail_app/features/stock_count/domain/repository/stock_count_repository.dart';
import 'package:dtsretail_app/features/stock_count/domain/entities/stock_count_line.dart';
import 'package:dtsretail_app/features/stock_count/presentation/pages/stock_count_list_page.dart';
import 'package:dtsretail_app/features/stock_count/presentation/providers/stock_count_providers.dart';

class _FakeStockCountRepository implements StockCountRepository {
  @override
  Future<StockCountSearchResult> search({
    required String companyId,
    required String branchId,
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    return const StockCountSearchResult(
      items: [
        StockCount(
          companyId: 'BAS',
          branchId: 'BAS1',
          stockcntId: 'SC0089',
          cntType: 'POSCNT',
          status: 'OPEN',
          stockcntDate: '2020-08-02',
          whseCode: 'BBPOS',
          totalItems: 1,
          totalCountQty: 45,
          totalVarQty: -2,
          dateUpdated: '2020-08-02T10:00:00',
          lines: [],
        ),
      ],
      totalElements: 1,
      totalPages: 1,
    );
  }

  @override
  Future<StockCount> getDetail({required String companyId, required String branchId, required String stockcntId}) {
    throw UnimplementedError();
  }

  @override
  Future<StockCount> create({
    required String companyId,
    required String branchId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<StockCount> update({
    required String companyId,
    required String branchId,
    required String stockcntId,
    required String cntType,
    required String whseCode,
    required List<StockCountLine> lines,
    required String userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Warehouse>> getWarehouses({required String companyId}) async => const [];
}

class _AuthenticatedStub extends AuthStateNotifier {
  _AuthenticatedStub() : super(_NoopRef()) {
    state = AuthAuthenticated(
      AuthSession(
        loginId: 'SAM',
        firstName: 'Sam',
        lastName: 'Tan',
        fullName: 'Sam Tan',
        companyId: 'BAS',
        branchId: 'BAS1',
        roleName: 'STAFF',
        features: const ['STOCK_COUNT'],
        accessToken: 'a',
        refreshToken: 'r',
        accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
      ),
    );
  }
}

class _NoopRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('shows stock count results for the authenticated session', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stockCountRepositoryProvider.overrideWithValue(_FakeStockCountRepository()),
          authStateProvider.overrideWith((ref) => _AuthenticatedStub()),
        ],
        child: const MaterialApp(home: StockCountListPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SC0089'), findsOneWidget);
  });
}
```

- [ ] **Step 7: Run the widget test**

Run: `flutter test test/features/stock_count/presentation/stock_count_list_page_test.dart`
Expected: `00:0X +1: All tests passed!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/stock_count/presentation lib/app/router.dart test/features/stock_count/presentation/stock_count_list_page_test.dart
git commit -m "Add Stock Count list and detail pages"
```

---

## Task 13: Stock Count form — warehouse selector, barcode line entry, create/update

**Files:**
- Create: `lib/features/stock_count/presentation/widgets/warehouse_selector.dart`
- Create: `lib/features/stock_count/presentation/widgets/barcode_scan_line_entry.dart`
- Create: `lib/features/stock_count/presentation/pages/stock_count_form_page.dart`
- Modify: `lib/app/router.dart` (add `/stock-counts/new` route)

**Interfaces:**
- Consumes: `warehousesProvider`, `createStockCountUsecaseProvider`, `updateStockCountUsecaseProvider` (Task 12/11), `BarcodeScannerService` (Task 9), `getProductDetailUsecaseProvider`/`searchProductsUsecaseProvider` (Task 10, for barcode→product lookup), `authStateProvider` (Task 6).
- Produces: fully working create/edit flow at `/stock-counts/new` (optional query params `companyId`, `branchId`, `stockcntId` to load an existing OPEN count for editing).

- [ ] **Step 1: Create `WarehouseSelector`**

Create `lib/features/stock_count/presentation/widgets/warehouse_selector.dart`:
```dart
import 'package:flutter/material.dart';
import '../../domain/entities/warehouse.dart';

class WarehouseSelector extends StatelessWidget {
  const WarehouseSelector({
    super.key,
    required this.warehouses,
    required this.selected,
    required this.onChanged,
  });

  final List<Warehouse> warehouses;
  final Warehouse? selected;
  final ValueChanged<Warehouse> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Warehouse>(
      decoration: const InputDecoration(labelText: 'Warehouse'),
      value: selected,
      items: warehouses
          .map((w) => DropdownMenuItem(value: w, child: Text('${w.code} · ${w.description}')))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      validator: (value) => value == null ? 'Select a warehouse' : null,
    );
  }
}
```

- [ ] **Step 2: Create `BarcodeScanLineEntry`**

Create `lib/features/stock_count/presentation/widgets/barcode_scan_line_entry.dart`:
```dart
import 'package:flutter/material.dart';
import '../../domain/entities/stock_count_line.dart';

class BarcodeScanLineEntry extends StatelessWidget {
  const BarcodeScanLineEntry({
    super.key,
    required this.lines,
    required this.onScanPressed,
    required this.onQtyChanged,
    required this.onRemove,
  });

  final List<StockCountLine> lines;
  final VoidCallback onScanPressed;
  final void Function(int index, double qty) onQtyChanged;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            onPressed: onScanPressed,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan barcode to add line'),
          ),
        ),
        ...lines.asMap().entries.map((entry) {
          final index = entry.key;
          final line = entry.value;
          return ListTile(
            title: Text(line.productTitle.isEmpty ? line.productCode : line.productTitle),
            subtitle: Text(line.productCode),
            trailing: SizedBox(
              width: 140,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: line.countQty.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Qty'),
                      onChanged: (value) => onQtyChanged(index, double.tryParse(value) ?? line.countQty),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => onRemove(index)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
```

- [ ] **Step 3: Create `StockCountFormPage`**

Create `lib/features/stock_count/presentation/pages/stock_count_form_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/barcode_scanner_service.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../product/presentation/providers/product_providers.dart';
import '../../domain/entities/stock_count_line.dart';
import '../../domain/entities/warehouse.dart';
import '../providers/stock_count_providers.dart';
import '../widgets/barcode_scan_line_entry.dart';
import '../widgets/warehouse_selector.dart';

class StockCountFormPage extends ConsumerStatefulWidget {
  const StockCountFormPage({super.key, this.companyId, this.branchId, this.stockcntId});

  final String? companyId;
  final String? branchId;
  final String? stockcntId;

  bool get isEditing => stockcntId != null;

  @override
  ConsumerState<StockCountFormPage> createState() => _StockCountFormPageState();
}

class _StockCountFormPageState extends ConsumerState<StockCountFormPage> {
  final _formKey = GlobalKey<FormState>();
  Warehouse? _selectedWarehouse;
  final List<StockCountLine> _lines = [];
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      Future.microtask(_loadExisting);
    }
  }

  Future<void> _loadExisting() async {
    final args = (companyId: widget.companyId!, branchId: widget.branchId!, stockcntId: widget.stockcntId!);
    final existing = await ref.read(stockCountDetailProvider(args).future);
    setState(() => _lines.addAll(existing.lines));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();
    final session = authState.session;

    final warehousesAsync = ref.watch(warehousesProvider(session.companyId));

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Stock Count' : 'New Stock Count')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            warehousesAsync.when(
              data: (warehouses) {
                _selectedWarehouse ??= warehouses
                    .where((w) => w.branchCode == session.branchId)
                    .cast<Warehouse?>()
                    .firstWhere((w) => w != null, orElse: () => warehouses.isNotEmpty ? warehouses.first : null);
                return WarehouseSelector(
                  warehouses: warehouses,
                  selected: _selectedWarehouse,
                  onChanged: (w) => setState(() => _selectedWarehouse = w),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Could not load warehouses: $error'),
            ),
            const SizedBox(height: 16),
            BarcodeScanLineEntry(
              lines: _lines,
              onScanPressed: () => _scanAndAddLine(session.companyId),
              onQtyChanged: (index, qty) => setState(() {
                final line = _lines[index];
                _lines[index] = StockCountLine(
                  productCode: line.productCode,
                  productTypeCode: line.productTypeCode,
                  productTitle: line.productTitle,
                  priceWithGst: line.priceWithGst,
                  cost: line.cost,
                  countQty: qty,
                );
              }),
              onRemove: (index) => setState(() => _lines.removeAt(index)),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : () => _submit(session),
              child: _isSaving ? const CircularProgressIndicator() : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanAndAddLine(String companyId) async {
    const scanner = BarcodeScannerService();
    final barcode = await scanner.scan(context);
    if (barcode == null) return;

    final result = await ref.read(searchProductsUsecaseProvider)(
      companyId: companyId,
      searchString: barcode,
      searchKey: 3,
      size: 1,
    );
    if (result.items.isEmpty) {
      setState(() => _errorMessage = 'No product found for barcode $barcode');
      return;
    }

    final product = result.items.first;
    setState(() {
      _errorMessage = null;
      _lines.add(StockCountLine(
        productCode: product.productCode,
        productTypeCode: product.productTypeCode,
        productTitle: product.productTitle,
        priceWithGst: product.priceWithGst,
        cost: product.cost,
        countQty: 1,
      ));
    });
  }

  Future<void> _submit(dynamic session) async {
    if (_selectedWarehouse == null || _lines.isEmpty) {
      setState(() => _errorMessage = 'Select a warehouse and add at least one line.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (widget.isEditing) {
        await ref.read(updateStockCountUsecaseProvider)(
          companyId: session.companyId,
          branchId: session.branchId,
          stockcntId: widget.stockcntId!,
          cntType: 'CNT',
          whseCode: _selectedWarehouse!.code,
          lines: _lines,
          userId: session.loginId,
        );
      } else {
        await ref.read(createStockCountUsecaseProvider)(
          companyId: session.companyId,
          branchId: session.branchId,
          cntType: 'CNT',
          whseCode: _selectedWarehouse!.code,
          lines: _lines,
          userId: session.loginId,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _errorMessage = 'Failed to save: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
```

- [ ] **Step 4: Wire the `/stock-counts/new` route**

Modify `lib/app/router.dart` — add import:
```dart
import '../features/stock_count/presentation/pages/stock_count_form_page.dart';
```
Add a sibling route inside the stock-counts branch (alongside the `:companyId/:branchId/:stockcntId` route added in Task 12):
```dart
                GoRoute(
                  path: 'new',
                  builder: (context, state) => StockCountFormPage(
                    companyId: state.uri.queryParameters['companyId'],
                    branchId: state.uri.queryParameters['branchId'],
                    stockcntId: state.uri.queryParameters['stockcntId'],
                  ),
                ),
```

- [ ] **Step 5: Run full analyze and full test suite**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: all tests across the project pass (this includes every test file created in Tasks 2-12).

- [ ] **Step 6: Commit**

```bash
git add lib/features/stock_count/presentation/widgets lib/features/stock_count/presentation/pages/stock_count_form_page.dart lib/app/router.dart
git commit -m "Add Stock Count create/edit form with warehouse selector and barcode line entry"
```

---

## Task 14: Dashboard — real content from session

**Files:**
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart` (replace stub from Task 7)
- Create: `lib/features/dashboard/presentation/widgets/greeting_header.dart`
- Create: `lib/features/dashboard/presentation/widgets/session_info_card.dart`
- Create: `lib/features/dashboard/presentation/widgets/quick_actions_grid.dart`
- Create: `lib/features/dashboard/presentation/widgets/feature_tile.dart`

**Interfaces:**
- Consumes: `authStateProvider` (Task 6), `BarcodeScannerService` (Task 9).
- Produces: fully populated `DashboardPage` per the spec (greeting, session info, quick actions, feature tiles — no fabricated "last login").

- [ ] **Step 1: Create `GreetingHeader`**

Create `lib/features/dashboard/presentation/widgets/greeting_header.dart`:
```dart
import 'package:flutter/material.dart';

class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key, required this.firstName});

  final String firstName;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Text('$_greeting, $firstName', style: Theme.of(context).textTheme.headlineSmall);
  }
}
```

- [ ] **Step 2: Create `SessionInfoCard`**

Create `lib/features/dashboard/presentation/widgets/session_info_card.dart`:
```dart
import 'package:flutter/material.dart';

class SessionInfoCard extends StatelessWidget {
  const SessionInfoCard({super.key, required this.companyId, required this.branchId, required this.roleName});

  final String companyId;
  final String branchId;
  final String roleName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _InfoColumn(label: 'Company', value: companyId),
            _InfoColumn(label: 'Branch', value: branchId),
            _InfoColumn(label: 'Role', value: roleName),
          ],
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
```

- [ ] **Step 3: Create `QuickActionsGrid`**

Create `lib/features/dashboard/presentation/widgets/quick_actions_grid.dart`:
```dart
import 'package:flutter/material.dart';

class QuickAction {
  const QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: actions
          .map((action) => Card(
                child: InkWell(
                  onTap: action.onTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(action.icon, size: 32),
                      const SizedBox(height: 8),
                      Text(action.label),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}
```

- [ ] **Step 4: Create `FeatureTile`**

Create `lib/features/dashboard/presentation/widgets/feature_tile.dart`:
```dart
import 'package:flutter/material.dart';

class FeatureTile extends StatelessWidget {
  const FeatureTile({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(label), trailing: const Icon(Icons.chevron_right), onTap: onTap);
  }
}
```

- [ ] **Step 5: Replace `DashboardPage` with the real implementation**

Replace `lib/features/dashboard/presentation/pages/dashboard_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/barcode_scanner_service.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../widgets/feature_tile.dart';
import '../widgets/greeting_header.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/session_info_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  static const _knownFeatures = {
    'PRODUCT_VIEW': 'Product Catalog',
    'STOCK_COUNT': 'Stock Count',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();
    final session = authState.session;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(authStateProvider.notifier).restoreSession(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GreetingHeader(firstName: session.firstName),
            const SizedBox(height: 16),
            SessionInfoCard(companyId: session.companyId, branchId: session.branchId, roleName: session.roleName),
            const SizedBox(height: 24),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            QuickActionsGrid(
              actions: [
                QuickAction(icon: Icons.search, label: 'Product Search', onTap: () => context.go('/products')),
                QuickAction(icon: Icons.add_box_outlined, label: 'New Stock Count', onTap: () => context.push('/stock-counts/new')),
                QuickAction(
                  icon: Icons.qr_code_scanner,
                  label: 'Scan Barcode',
                  onTap: () => _scanFromDashboard(context),
                ),
                QuickAction(icon: Icons.fact_check_outlined, label: 'Stock Counts', onTap: () => context.go('/stock-counts')),
              ],
            ),
            const SizedBox(height: 24),
            Text('Modules', style: Theme.of(context).textTheme.titleMedium),
            for (final entry in _knownFeatures.entries)
              if (session.features.contains(entry.key))
                FeatureTile(
                  icon: entry.key == 'PRODUCT_VIEW' ? Icons.inventory_2_outlined : Icons.fact_check_outlined,
                  label: entry.value,
                  onTap: () => context.go(entry.key == 'PRODUCT_VIEW' ? '/products' : '/stock-counts'),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanFromDashboard(BuildContext context) async {
    const scanner = BarcodeScannerService();
    final barcode = await scanner.scan(context);
    if (barcode != null && context.mounted) {
      context.push('/products');
    }
  }
}
```
Note: `_knownFeatures` keys (`PRODUCT_VIEW`, `STOCK_COUNT`) are illustrative — confirm the exact string values `dtsapi` returns in the login response's `features[]` array (grep `StockCountController`/`SecurityConfig`/auth service in `D:\Backend\dtsapi\src\main\java` for the actual feature-code constants, or log a real login response) and update this map before relying on it to gate tiles.

- [ ] **Step 6: Verify analyze and run full test suite**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dashboard
git commit -m "Add real dashboard content: greeting, session info, quick actions, feature tiles"
```

---

## Task 15: Manual verification against the running dtsapi backend

**Files:** none (verification only)

**Interfaces:** none — this task exercises the full app built in Tasks 1-14 against the real backend.

- [ ] **Step 1: Start `dtsapi` locally**

In a separate terminal:
```bash
cd D:/Backend/dtsapi
mvn spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=local"
```
Expected: server starts on port 8081, `GET http://localhost:8081/api/v1/health` returns `{"status":"UP"}`.

- [ ] **Step 2: Launch an Android emulator and run the app**

Run: `flutter emulators --launch <emulator_id>` (list available with `flutter emulators`), then:
```bash
cd D:/Project/dtsretail-app/dtsretail_app
flutter run
```
Expected: app builds and launches to the Login screen (base URL defaults to `http://10.0.2.2:8081/api/v1`, which reaches the host's `localhost:8081` from the emulator).

- [ ] **Step 3: Verify login and session persistence**

Log in with known-valid credentials for the `nexgen` database (e.g. the `SAM` account referenced in `dtsapi`'s own API docs, if still valid, or ask for current test credentials). Expected: navigates to Dashboard, shows greeting with real first name, company/branch/role.

Force-close and reopen the app. Expected: lands on Dashboard directly (no re-login), confirming `SecureTokenStorage` persistence and `restoreSession()` work.

- [ ] **Step 4: Verify Product Catalog**

Search a known product code/barcode for a real company in `nexgen` (e.g. `BAS` / `2007786553` per the API docs sample). Expected: result appears, tapping it opens detail with matching title/price/cost. Try the barcode-scan button (use a printed/on-screen barcode or the emulator's camera passthrough) — expected: same product resolves.

- [ ] **Step 5: Verify Stock Count list, detail, and create**

Open Stock Count tab. Expected: list of existing counts for the session's company/branch loads with correct statuses. Tap an OPEN count. Expected: detail with line items and an Edit FAB. Tap "+" to create a new count, pick a warehouse, scan or search a product to add a line, set quantity, save. Expected: returns to the list and the new count appears.

- [ ] **Step 6: Verify error handling**

Stop the `dtsapi` server, then pull-to-refresh the Dashboard or retry a search. Expected: `AppErrorView` shows a network error message with a working Retry button, not a raw exception or blank screen.

- [ ] **Step 7: Record verification results**

If every check in Steps 3-6 passes, this task is done — no code changes. If any check fails, file it as a bug against the specific task that introduced the behavior (do not silently patch without a task reference) and fix before considering the foundation complete.

---

## Self-Review

**Spec coverage:**
- Project scaffolding, theme, routing, API client — Tasks 1, 2, 7. ✓
- Authentication (login, token storage, refresh, logout) — Tasks 3, 4, 5, 6. ✓
- Dashboard (real content, no fabricated last-login, feature-gated tiles) — Task 14. ✓
- Product Catalog (search, barcode, recent searches, detail) — Tasks 8, 9, 10. ✓
- Stock Count (list, detail, create/update, warehouse selector, barcode line entry, no Approve) — Tasks 11, 12, 13. ✓
- Reusable barcode scanner service — Task 9. ✓
- Offline-ready repository layering (remote-only today) — baked into Tasks 8 and 11's `data/datasource/remote/` structure. ✓
- DTO/mapper/entity separation — every data-layer task (5, 8, 11) follows `models → mappers → domain`. ✓
- Bottom navigation — Task 7. ✓
- Concurrency/optimistic-locking note and Approve deferral — documented in Task 13 (no Approve UI built) and the spec; backend fix tracked separately (task_5acd0d8d). ✓
- Manual end-to-end verification against real `dtsapi` — Task 15. ✓

**Placeholder scan:** No "TBD"/"implement later" found. The one open item (Task 11 Step 1's `WarehouseDto.branchCode` JSON key) is flagged with an explicit, actionable fallback instruction, not a vague placeholder.

**Type consistency:** `AuthSession`, `Product`, `ProductSearchResult`, `StockCount`, `StockCountLine`, `Warehouse` are defined once (Tasks 3, 8, 11) and referenced by identical names/fields in every later task. `StockCountRepository`'s method signatures (Task 11) match the calls made in `stock_count_providers.dart` (Task 12) and `stock_count_form_page.dart` (Task 13). `BarcodeScannerService.scan(BuildContext)` (Task 9) is called identically in Tasks 10, 13, and 14.

---

Plan complete and saved to `docs/superpowers/plans/2026-07-19-mobile-app-foundation.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
